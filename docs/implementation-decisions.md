# Implementation Decisions

This document captures the key design choices, tradeoffs, and debugging lessons behind the current implementation while they are still fresh.

It is meant to complement the main [README](../README.md), not replace it. The README explains what the project does and how to use it. This document explains why the project is shaped the way it is.

## Why Repo-as-Workspace

The original version of this project generated a second working directory elsewhere on disk and copied scripts into it before doing any real work.

That model worked, but it created several problems:

- runtime state was separated from the repository that defined it
- copied scripts could drift from the tracked source
- cleanup and troubleshooting were harder because logs, ISO output, and mounted-image paths lived outside the repo
- the workflow felt more like a one-off lab script bundle than a maintainable project

The current model treats the repository itself as the workspace. Tracked source and configuration stay in the repo, and transient artifacts live under `Build`.

This made the workflow easier to reason about:

- the repo contains the source of truth
- runtime paths are predictable and derived from project structure
- logs, WIMs, ISOs, and mount paths are easy to inspect
- the project is simpler to clone, customize, and run directly

## Why PowerShell in WinPE

The project originally used batch files in WinPE. That worked, but it became harder to evolve once the deploy and capture logic started needing more validation, clearer error handling, and better path handling.

Adding the WinPE PowerShell optional components was worth the extra setup because it enabled:

- clearer runtime logic
- better native command orchestration
- easier drive discovery
- more maintainable payload generation
- more readable debugging output during testing

WinPE still requires `startnet.cmd` as the entry point, so the project keeps that file as a thin launcher. The real work now happens in generated PowerShell payloads such as `Capture.ps1` and `Deploy.ps1`.

## Why Unattend.xml Is Local-Only

Earlier iterations of the project tracked a sample `Unattend.Template.xml` and automatically created a local `Unattend.xml` working copy from it.

That was convenient, but it blurred an important line:

- the answer file is the most likely place for credentials and other sensitive deployment settings
- answer file authoring is a separate skill and workflow, typically done in Windows System Image Manager
- the repo should not pretend to be a WSIM training project

The current model is simpler and safer:

- the repo ignores `PayloadTemplates\Unattend.xml`
- the deploy build requires that file to be present locally
- the build fails early with a clear message if it is missing
- the user is responsible for creating and validating the answer file separately

This keeps the repo aligned with the real operational boundary: deployment automation lives here, but unattended answer-file authoring remains a separate activity.

Even though full answer-file authoring is out of scope, the repo does rely on a few specific behaviors from `Unattend.xml`:

- the built-in `Administrator` account needs a known password
- the answer file needs to configure one automatic logon as `Administrator`

Those settings are not arbitrary. The deployment flow stages a `RunOnce` post-deploy action, and that action depends on reaching the desktop automatically after OOBE. Other answer-file settings, such as locale or prompt-suppression choices, are still up to the project user, but the administrator password and one-time autologon are core requirements for this repo's intended flow.

## Why Post-Deploy Install Uses RunOnce

The project includes a post-deploy example that installs PowerShell 7 after first logon.

Several possible handoff points were considered:

- embedding more logic in `Unattend.xml`
- running the full install directly in `SetupComplete.cmd`
- deferring the install until after first logon

Running the full install inside `SetupComplete.cmd` technically worked, but the user experience was poor. The VM could sit at a black screen for a long time while setup finished in the background, which made the system look broken.

The current approach stages:

- `SetupComplete.cmd`
- `PostDeploy.ps1`

`SetupComplete.cmd` now registers a one-time `RunOnce` entry, and the actual software installation runs after first logon. That produced a much cleaner result:

- OOBE completes normally
- autologon reaches the desktop
- the post-deploy action is visible and understandable
- the image itself stays broadly reusable

## Major Issues Encountered and How They Were Resolved

### Invalid Quote Handling in Generated PowerShell

Early generated `Deploy.ps1` content contained doubled quotes that produced parser errors in WinPE.

Resolution:

- corrected payload string generation
- validated the actual file contents from inside the ISO

### Drive Discovery in WinPE

The original PowerShell rewrite tried to iterate drive letters in a way that PowerShell did not accept.

Resolution:

- replaced the fragile drive-letter loop with `Get-PSDrive -PSProvider FileSystem`
- searched for a marker file to identify the mounted ISO

### Unattend.xml Access Denied During OOBE

Deployment initially completed but showed a Windows setup error before continuing. Investigation of Panther and `UnattendGC` logs showed `oobeSystem` processing hitting `0x80070005`.

Resolution:

- staged `Unattend.xml` more carefully into `C:\Windows\Panther`
- created the directory explicitly
- cleared restrictive attributes
- re-enabled inheritance on the deployed file

That removed the setup interruption while preserving unattended behavior.

### SetupComplete Worked but Produced a Poor Experience

The first post-deploy implementation ran the full PowerShell 7 install directly from `SetupComplete.cmd`.

Resolution:

- kept `SetupComplete.cmd` only as the handoff mechanism
- moved the real work into `RunOnce` via `PostDeploy.ps1`

This improved the post-OOBE experience significantly.

### Logging and Encoding Drift

PowerShell-version differences created a few subtle issues around file encoding and console/error behavior.

Resolution:

- used explicit ASCII where WinPE bootstrap files required it
- used a UTF-8 no BOM writer for `Workspace.log`
- kept logging predictable across Windows PowerShell and PowerShell 7

### WIM Mount Lifecycle and Cleanup

Mount-related failures can leave subsequent runs in a bad state if the mounted image is not dismounted cleanly.

Resolution:

- wrapped mount/dismount sequences in `try/finally`
- saved only on success
- discarded on failure
- prepared mount directories before each mount

### Native Tool Invocation

External tools such as `copype.cmd` and `MakeWinPEMedia` needed stronger exit-code handling than the first pass provided.

Resolution:

- added a shared external-tool helper
- captured output and checked real exit codes
- hardened command invocation and quoting for `.cmd` / `.bat` tools

## What This Project Demonstrates

From an endpoint-engineering perspective, this project is intended to demonstrate:

- understanding of WinPE outside higher-level deployment products
- PowerShell automation across capture, maintenance, and deployment
- safe handling of local-only sensitive deployment material
- practical troubleshooting of imaging, OOBE, and post-deploy issues
- ability to refine a working prototype into a cleaner, more maintainable project

## What Is Intentionally Out of Scope

This project is intentionally narrower than a full enterprise imaging framework.

It does not try to be:

- a full WSIM tutorial
- a driver-injection framework for physical hardware
- a general-purpose application deployment catalog
- a replacement for ConfigMgr or MDT in enterprise-scale scenarios

Its focus is deliberate: fast, repeatable, known-good local Hyper-V dev and test deployments that demonstrate the underlying mechanics clearly.
