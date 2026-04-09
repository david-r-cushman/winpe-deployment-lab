# WinPE Deployment Lab

[![Pester](https://github.com/david-r-cushman/winpe-deployment-lab/actions/workflows/pester.yml/badge.svg?branch=main)](https://github.com/david-r-cushman/winpe-deployment-lab/actions/workflows/pester.yml)

This repository is a PowerShell-based lab for building and maintaining WinPE media and offline Windows image artifacts from a repo-local workflow.

Rather than creating a second generated workspace elsewhere on disk, the repository itself is the workspace. A new project can be created from this template, cloned locally, customized, and then used directly to build capture and deployment media.

## Why I Built This

While MDT and SCCM are powerful, they often mask the underlying mechanics of OS deployment. I built this framework to work closer to the underlying WinPE, DISM, WIM, and unattended deployment layers so the process stays visible, scriptable, and portable.

The intended use case is narrow on purpose: rapidly building consistent local Hyper-V development and test VMs from a known-good reference image. This project is not intended to be a full enterprise deployment framework or a hardware-imaging solution for physical devices.

The goal is to show practical endpoint engineering skills through:

- WinPE boot media creation
- offline WIM maintenance
- unattended deployment payload preparation
- post-deployment software installation
- repository-driven automation and repeatable project structure

## Workflow Model

The expected workflow is:

1. Create a new repository from this template.
2. Clone the new repository locally.
3. Review and customize [`config/osd-config.json`](config/osd-config.json) for that specific image project.
4. Review and customize the payload files in [`PayloadTemplates`](PayloadTemplates).
5. Use the configured `WIMName`, `ImageDescription`, and related values to match the image you actually intend to capture or deploy.
6. Create a project-specific local [`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) and keep it ignored by git.
7. Author and validate that answer file separately, for example in Windows System Image Manager, before attempting to build deployment media.
8. Run [`New-WinPEWorkspace.ps1`](New-WinPEWorkspace.ps1) once to initialize the local runtime folders.
9. Place the project-specific WIM file in [`Build/WIM`](Build/WIM) using the filename configured in [`config/osd-config.json`](config/osd-config.json) when needed.
10. Run the PowerShell scripts from the repository root in an elevated Windows ADK Deployment and Imaging Tools Environment session.

The repository contains tracked source, templates, and configuration. Runtime artifacts stay local and are ignored by git.

WinPE now boots into a PowerShell-enabled runtime. The generated media still uses `startnet.cmd` as the entry point required by WinPE, but that file now acts only as a thin launcher for PowerShell payload scripts generated during ISO creation.

## Repository Layout

- [`config/osd-config.json`](config/osd-config.json): checked-in project configuration for artifact names and image metadata
- [`PayloadTemplates`](PayloadTemplates): deployment payload files such as `Diskconfig.txt`, `Assign-C.txt`, `Unattend.xml` (local/ignored), and post-deploy bootstrap scripts
- [`Build`](Build): repo-local runtime workspace for logs, mount paths, WIM files, ISO output, and temporary WinPE build content
- [`src/Public`](src/Public): public command implementations used by the root-level script wrappers
- [`src/Private`](src/Private): shared runtime helpers used by the script entry points
- root-level script entry points:
  - [`New-WinPEWorkspace.ps1`](New-WinPEWorkspace.ps1)
  - [`New-WinPECaptureISO.ps1`](New-WinPECaptureISO.ps1)
  - [`New-WinPEDeployISO.ps1`](New-WinPEDeployISO.ps1)
  - [`Maintain-WIMImage.ps1`](Maintain-WIMImage.ps1)

The root scripts are intentionally thin wrappers. They preserve a simple script-first operator experience while delegating the actual implementation to functions under `src/Public` and shared helpers under `src/Private`.

## Configuration

[`config/osd-config.json`](config/osd-config.json) currently defines:

- `BootISOName`
- `WIMName`
- `DeployISOName`
- `ImageDescription`
- `CaptureLocation`

These values are intended to be customized per derived project repo. Runtime paths are not stored in config; they are calculated from the repository layout.

Typical customization examples include changing the configured image name and description to match a target such as Windows 11 by edition, build, and architecture, or a specific Windows Server build.

## Intended Scope

- This workflow is designed for local virtual machine deployment, especially repeatable Hyper-V-based dev and test systems.
- The reference image is meant to produce standardized, disposable lab systems in a known-good state before additional testing begins.
- The current implementation intentionally prioritizes image capture, offline servicing, deployment, and a small amount of post-deploy bootstrap work over broader enterprise imaging concerns.
- Hardware-specific workflows such as driver injection are out of scope for this project because the target environment is virtualized rather than physical.
- The bundled post-deploy software installation is intentionally minimal. PowerShell 7.6 is included as a practical example of post-deployment automation and a useful baseline for further testing.

## Script Usage

Run these from the repository root unless noted otherwise.

Internally, each root script loads and calls a corresponding public function:

- `New-WinPEWorkspace.ps1` -> `Initialize-WinPEProject`
- `New-WinPECaptureISO.ps1` -> `New-WinPECaptureIso`
- `New-WinPEDeployISO.ps1` -> `New-WinPEDeployIso`
- `Maintain-WIMImage.ps1` -> `Update-WinPEWimImage`

### Initialize Local Runtime Structure

```powershell
PowerShell.exe .\New-WinPEWorkspace.ps1
```

Creates or validates the repo-local `Build` structure used for logs, mounts, WIM working files, and ISO output. It does not generate an answer file; deployment builds expect a local ignored [`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) to already exist.

### Build Capture ISO

```powershell
PowerShell.exe .\New-WinPEWorkspace.ps1
PowerShell.exe .\New-WinPECaptureISO.ps1
```

Builds a PowerShell-enabled WinPE capture ISO in [`Build/ISO`](Build/ISO) using values from [`config/osd-config.json`](config/osd-config.json). The ISO boot image launches a generated `Capture.ps1` payload inside WinPE.

### Maintain a Captured WIM

```powershell
PowerShell.exe .\New-WinPEWorkspace.ps1
PowerShell.exe .\Maintain-WIMImage.ps1
```

Mounts the configured WIM from [`Build/WIM`](Build/WIM), applies the scripted maintenance step, and saves the image.

### Build Deployment ISO

```powershell
PowerShell.exe .\New-WinPEWorkspace.ps1
# Example only: use the filename configured in config\osd-config.json
Copy-Item .\SomeReferenceImage.wim .\Build\WIM\<Configured-WIMName>.wim
PowerShell.exe .\New-WinPEDeployISO.ps1
```

Builds a PowerShell-enabled deployment ISO in [`Build/ISO`](Build/ISO) using the configured WIM and payload templates. The filename placed in [`Build/WIM`](Build/WIM) must match the `WIMName` value in [`config/osd-config.json`](config/osd-config.json). The ISO boot image launches a generated `Deploy.ps1` payload inside WinPE.

The current deployment payload also stages a post-deploy bootstrap under `C:\Windows\Setup\Scripts`. `SetupComplete.cmd` registers a one-time `RunOnce` launch for `PostDeploy.ps1`, which is currently used to install PowerShell 7.6 after the first automatic logon.

## Prerequisites

- Windows
- PowerShell
- Windows ADK Deployment Tools / WinPE tooling
- WinPE optional components that ship with the ADK so the build process can add PowerShell support to `boot.wim`
- elevated session when running ADK and DISM-dependent operations
- Deployment and Imaging Tools Environment for `copype.cmd` and `MakeWinPEMedia`
- outbound internet access from the deployed VM if you want the bundled post-deploy PowerShell 7 installer bootstrap to succeed

## Security Notes

[`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) is expected to be a local, ignored, project-specific answer file.

- Authoring the unattended answer file itself is intentionally out of scope for this repository.
- Create and validate `PayloadTemplates/Unattend.xml` separately, for example with Windows System Image Manager, then keep it local and ignored by git.
- Do not commit real passwords, secret-bearing unattended files, WIM artifacts, ISO artifacts, or operational logs.
- This workflow assumes an unattended OOBE-based deployment path and is therefore not intended for Windows Server Core deployment media in its current form.

## Git Hygiene

[`.gitignore`](.gitignore) is configured to ignore local runtime artifacts such as:

- `*.wim`
- `*.iso`
- `*.log`
- `PayloadTemplates/Unattend.xml`
- repo-local `Build` output and mount contents

This keeps project configuration and source under version control while preventing accidental commits of large artifacts or operational state.

## Design Decisions And Lessons Learned

- The repository is the workspace. The original project created a second generated workspace and copied scripts into it. I refactored that model so the repo itself became the working area, with repo-local runtime folders under `Build`.
- Configuration stays tracked, runtime paths stay derived. The old generated JSON handoff was replaced by [`config/osd-config.json`](config/osd-config.json), which keeps meaningful image settings while allowing the scripts to calculate repo-relative paths at runtime.
- Sensitive unattended content should never be tracked. This repo expects a local ignored [`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) supplied by the project user.
- PowerShell in WinPE was worth the added setup cost. WinPE still requires `startnet.cmd` as its entry point, but adding the WinPE PowerShell optional components made the capture and deploy logic easier to evolve and debug than the original batch-based approach.
- The migration surfaced a few real implementation issues that had to be solved:
  - generated PowerShell payloads initially broke because of incorrect quote handling
  - the deploy bootstrap needed a more PowerShell-native method for locating the ISO drive
  - `Unattend.xml` staging initially triggered an `oobeSystem` access-denied error until file handling in `C:\Windows\Panther` was tightened
  - running a full software install directly inside `SetupComplete.cmd` worked, but created a poor black-screen user experience; switching to `RunOnce` produced a much cleaner handoff
- Offline image maintenance is intentional, not cosmetic. Capturing the WIM locally to `C:\CapturedImages` is simpler and more reliable than introducing networking into the capture phase, and [`Maintain-WIMImage.ps1`](Maintain-WIMImage.ps1) exists to remove that artifact cleanly before deployment.
- Post-deploy software installation belongs after imaging, not inside the base image by default. The current example installs PowerShell 7.6 after first logon, which keeps the image reusable while still demonstrating application deployment and post-deployment automation.

## Current State

This repository began as a set of original project files dropped into the repo root from an earlier iteration. It has since been refactored into a cleaner template-aligned PowerShell project with:

- repo-local runtime structure under `Build`
- tracked project configuration in [`config/osd-config.json`](config/osd-config.json)
- thin root script wrappers over `src/Public` and `src/Private`
- PowerShell-enabled WinPE media for both capture and deployment
- offline WIM maintenance
- safe unattended file handling
- a validated post-deploy PowerShell 7.6 bootstrap

The current focus is no longer on reorganizing the project, but on keeping the workflow reliable, understandable, and useful as a repeatable VM deployment template.
