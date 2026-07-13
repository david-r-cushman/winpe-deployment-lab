# WinPE Deployment Lab

[![CI](https://github.com/david-r-cushman/winpe-deployment-lab/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/david-r-cushman/winpe-deployment-lab/actions/workflows/ci.yml)
<!-- BEGIN generated:readme-powershell-badge -->
![PowerShell 7.4](https://img.shields.io/badge/PowerShell-7.4-blue)
<!-- END generated:readme-powershell-badge -->
![Template Version](https://img.shields.io/badge/template-0.15.0-blue)

This repository is a PowerShell-based lab for building and maintaining WinPE media and offline Windows image artifacts from a repo-local workflow.

Rather than creating a second generated workspace elsewhere on disk, the repository itself is the workspace. A new project can be created from this template, cloned locally, customized, and then used directly to build capture and deployment media.

Quick navigation:

- [Portfolio Context](#portfolio-context)
- [Engineering Principles in Practice](#engineering-principles-in-practice)
- [Validation And Maintenance](#validation-and-maintenance)
- [Repository Structure](#repository-structure)

<!-- BEGIN generated:readme-runtime-focus -->
- PowerShell 7.4 development on Windows
<!-- END generated:readme-runtime-focus -->

## Portfolio Context

This repository is part of my PowerShell portfolio built from [david-r-cushman/pwsh-dev-template](https://github.com/david-r-cushman/pwsh-dev-template). It serves as both a practical deployment lab and a documented exploration of what it means for me to say that I understand Windows deployment.

Rather than treating Microsoft Deployment Toolkit (MDT) or Microsoft Configuration Manager (ConfigMgr) as black boxes, this repository intentionally exposes the mechanics they build upon: WinPE, DISM, WIM creation and servicing, unattended deployment, offline image maintenance, and the bootstrap processes that transform those individual components into a repeatable deployment workflow.

The objective is not to demonstrate that I can use enterprise deployment tooling. It is to demonstrate that I understand the mechanics those tools abstract, and that I can deconstruct those mechanics, reason about their behaviour, validate their implementation, and reassemble them into a working deployment solution.

The scope is intentionally focused on repeatable local lab and Hyper-V-based development scenarios. By keeping the environment intentionally narrow, the underlying deployment mechanics remain visible, understandable, and easy to validate without the additional complexity of a full enterprise deployment environment.

If you are reviewing the repository for the first time, begin with the root script entry points, the tracked configuration in [`config/osd-config.json`](config/osd-config.json), and the supporting implementation notes in [`docs/implementation-decisions.md`](docs/implementation-decisions.md) and [`docs/project-architecture-overview.md`](docs/project-architecture-overview.md).

## Engineering Principles in Practice

<!-- BEGIN generated:readme-runtime-philosophy -->
- **Deterministic Development Runtime:** PowerShell 7.4 is the maintained development baseline, while WinPE build and servicing work stays on a Windows host with the ADK toolchain it requires
<!-- END generated:readme-runtime-philosophy -->
- **Repository-As-Workspace:** The repository itself is the working area. Tracked source, configuration, and payload templates live alongside repo-local runtime folders so the full workflow stays visible and repeatable.
- **Tracked Configuration, Local Runtime State:** Project configuration belongs in version control, while generated artifacts, mount paths, logs, and deployment runtime state stay local under `Build` and out of git.
- **Visible Deployment Mechanics:** Rather than hiding the process behind higher-level tooling, this repository keeps WinPE, DISM, WIM handling, unattended deployment, and bootstrap logic explicit so each stage can be inspected and understood.
- **PowerShell-First WinPE Automation:** WinPE still requires `startnet.cmd`, but the actual capture and deployment flow is driven through PowerShell so the logic is easier to evolve, debug, and reason about than a batch-only approach.
- **Offline Servicing By Design:** Capturing and maintaining WIM files offline is a deliberate part of the workflow. It keeps servicing predictable and avoids adding unnecessary environmental dependencies during image preparation.
- **Untracked Sensitive Deployment Inputs:** Files such as `PayloadTemplates/Unattend.xml` are intentionally kept local and ignored so deployment-specific secrets and machine-specific answer-file details do not leak into source control.
- **Post-Deploy Bootstrap Over Image Bloat:** Software installation and final configuration belong after imaging when practical. The repository favors a smaller, reusable base image plus targeted post-deployment automation over embedding every change directly into the reference image.

## Use This Repository

If you want to inspect or reproduce the workflow this repository demonstrates, use it like this:

1. Review [`config/osd-config.json`](config/osd-config.json) for the project-specific image names and metadata.
2. Review the payload content under [`PayloadTemplates`](PayloadTemplates), especially the unattended deployment inputs and bootstrap scripts.
3. Create a local, ignored [`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) that matches the image and deployment flow you want to test.
4. Run [`New-WinPEWorkspace.ps1`](New-WinPEWorkspace.ps1) to initialize the repo-local runtime folders under [`Build`](Build).
5. Place the project-specific WIM in [`Build/WIM`](Build/WIM) when capture servicing or deployment media generation requires it.
6. Run the root-level PowerShell entry points from an elevated Windows ADK Deployment and Imaging Tools Environment session.

## Runtime And Environment

<!-- BEGIN generated:readme-runtime-stack -->
- **Runtime:** PowerShell 7.4.x for repository development on Windows with the Windows ADK Deployment Tools and WinPE optional components
<!-- END generated:readme-runtime-stack -->
- **Operator Host:** Windows with the Windows ADK Deployment Tools and WinPE optional components available for ISO creation and image servicing
- **Execution Model:** Root scripts are intended to be run with PowerShell 7 (`pwsh`) from an elevated Deployment and Imaging Tools Environment session
- **Workspace Model:** The repository itself is the working area, with runtime artifacts created under repo-local `Build` paths instead of a second generated workspace
- **Development Modes:** Local Windows editing and validation are the intended workflow, with WinPE build and servicing operations run from an elevated ADK shell because the required DISM and media tools are Windows-specific

## Tooling

<!-- BEGIN generated:readme-tooling-list -->
- **Pester 6.0.0:** For unit and integration testing
- **PSScriptAnalyzer 1.25.0:** To enforce PowerShell best practices and security rules
- **PSReadLine 2.4.5:** Configured for a more efficient terminal experience
<!-- END generated:readme-tooling-list -->

Repository-specific build and deployment work also depends on:

- **Windows ADK Deployment Tools:** For `copype.cmd`, `MakeWinPEMedia`, and the WinPE build toolchain
- **WinPE Optional Components:** So the generated boot media can launch PowerShell-based payloads
- **DISM tooling:** For offline WIM mount, servicing, and save operations

When runtime or tooling versions are updated, keep `eng/runtime-policy.json`, generated Markdown, and validation scripts aligned.

## Repository Structure

- [`config/osd-config.json`](config/osd-config.json): checked-in project configuration for artifact names and image metadata
- [`PayloadTemplates`](PayloadTemplates): deployment payload files such as `Diskconfig.txt`, `Assign-C.txt`, `Unattend.xml` (local/ignored), and post-deploy bootstrap scripts
- [`Build`](Build): repo-local runtime workspace for logs, mount paths, WIM files, ISO output, and temporary WinPE build content
- [`docs`](docs): supporting notes on project evolution, implementation decisions, and operating model
- [`src/Public`](src/Public): workflow implementations invoked by the root operator entry scripts
- [`src/Private`](src/Private): shared runtime helpers used by the workflow implementations
- [`Write-WorkspaceLog.ps1`](Write-WorkspaceLog.ps1): shared root-scoped logging helper sourced by the entry scripts and workflow functions
- root-level operator entry scripts:
  - [`New-WinPEWorkspace.ps1`](New-WinPEWorkspace.ps1)
  - [`New-WinPECaptureISO.ps1`](New-WinPECaptureISO.ps1)
  - [`New-WinPEDeployISO.ps1`](New-WinPEDeployISO.ps1)
  - [`Maintain-WIMImage.ps1`](Maintain-WIMImage.ps1)

The root scripts are intentionally thin operator-facing wrappers. They preserve a simple script-first experience while delegating the actual workflow implementation to functions under `src/Public`. A separate root-scoped `Write-WorkspaceLog.ps1` helper provides shared logging for those entry scripts and the workflow functions they load, while `src/Private` contains the shared runtime helpers.

For deeper background on why the project is structured this way, see [`docs/implementation-decisions.md`](docs/implementation-decisions.md).
For a script-and-runtime architecture map of the current implementation, see [`docs/project-architecture-overview.md`](docs/project-architecture-overview.md).

## Validation And Maintenance

Run the standard repository checks before committing meaningful changes:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-RepoChecks.ps1
```

If this repository keeps the template-managed generated Markdown blocks, refresh or validate them through:

```powershell
pwsh -NoProfile -File ./scripts/Update-GeneratedMarkdown.ps1 -Check
```

For implementation-specific validation, the repository also keeps a Windows-focused Pester workflow and should continue to review diffs for generated payload content, configuration changes, and documentation accuracy before merging changes.

## Downstream Guidance Sync

Use `.codex/skills/downstream-guidance-sync/SKILL.md` with `scripts/Invoke-TemplateGuidanceSync.ps1` when you want to adopt newer template guidance or README workflow assets from `pwsh-dev-template` without overwriting repository-owned implementation.

## Prerequisites And Setup

- Use Windows for WinPE build and deployment operations.
- Install the Windows ADK Deployment Tools and the WinPE add-on / optional components needed for PowerShell-enabled boot media.
- Use an elevated Deployment and Imaging Tools Environment session when running capture, deployment, and WIM-servicing scripts.
- Create and validate a local ignored [`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) before attempting deployment-media generation.
- Review `docs/agent-workflows.md`, `AGENTS.md`, and `.github/copilot-instructions.md` before using repo-local agent workflows to modify the repository.

## Template Versioning

The template version badge tracks inherited guidance and workflow baseline alignment. It does not mean this repository remains fully identical to the source template. Customize this section if you need to explain intentional divergence from the parent template.

## Workflow Model

The working model in this repository is intentionally simple:

1. Tracked configuration in [`config/osd-config.json`](config/osd-config.json) defines the image names, descriptions, and artifact expectations for the current project.
2. Tracked payload content in [`PayloadTemplates`](PayloadTemplates) provides the disk configuration, deployment helpers, and bootstrap material that get staged into generated media.
3. A project-specific [`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) stays local and ignored by git so unattended setup details can be validated separately without tracking sensitive or environment-specific content.
4. [`New-WinPEWorkspace.ps1`](New-WinPEWorkspace.ps1) initializes the repo-local `Build` workspace used for logs, mounts, WIM handling, and ISO output.
5. Capture, maintenance, and deployment scripts then use that tracked configuration plus the local runtime workspace to build media, service WIMs, and assemble the deployment flow.

The repository keeps source, templates, and configuration under version control while leaving runtime artifacts local and ignored by git.

WinPE boots into a PowerShell-enabled runtime in this workflow. The generated media still uses `startnet.cmd` as the entry point required by WinPE, but that file now acts only as a thin launcher for PowerShell payload scripts generated during ISO creation.

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
- The bundled post-deploy software installation is intentionally minimal. The repository itself is maintained on PowerShell 7.4, while the deployed VM currently installs PowerShell 7.6 as a practical example of post-deployment automation and a useful baseline for further testing.
- This workflow is currently validated for unattended Desktop Experience-style OOBE deployments. While Windows Server Core uses the same Sysprep and unattend mechanisms, the current post-deployment flow assumes an automatic Administrator logon and RunOnce-based bootstrap, which has not been validated against Server Core.

## Script Usage

Run these from the repository root unless noted otherwise.

The root scripts are intended to be run with PowerShell 7 (`pwsh`) from an elevated Deployment and Imaging Tools Environment session.

Example host shells:

```powershell
pwsh .\New-WinPEWorkspace.ps1
```

Internally, each root script loads and calls a corresponding public function:

- `New-WinPEWorkspace.ps1` -> `Initialize-WinPEProject`
- `New-WinPECaptureISO.ps1` -> `New-WinPECaptureIso`
- `New-WinPEDeployISO.ps1` -> `New-WinPEDeployIso`
- `Maintain-WIMImage.ps1` -> `Update-WinPEWimImage`

### Initialize Local Runtime Structure

```powershell
pwsh .\New-WinPEWorkspace.ps1
```

Creates or validates the repo-local `Build` structure used for logs, mounts, WIM working files, and ISO output. It does not generate an answer file; deployment builds expect a local ignored [`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) to already exist.

### Build Capture ISO

```powershell
pwsh .\New-WinPEWorkspace.ps1
pwsh .\New-WinPECaptureISO.ps1
```

Builds a PowerShell-enabled WinPE capture ISO in [`Build/ISO`](Build/ISO) using values from [`config/osd-config.json`](config/osd-config.json). The ISO boot image launches a generated `Capture.ps1` payload inside WinPE.

### Maintain a Captured WIM

```powershell
pwsh .\New-WinPEWorkspace.ps1
pwsh .\Maintain-WIMImage.ps1
```

Mounts the configured WIM from [`Build/WIM`](Build/WIM), applies the scripted maintenance step, and saves the image.

### Build Deployment ISO

```powershell
pwsh .\New-WinPEWorkspace.ps1
# Example only: use the filename configured in config\osd-config.json
Copy-Item .\SomeReferenceImage.wim .\Build\WIM\<Configured-WIMName>.wim
pwsh .\New-WinPEDeployISO.ps1
```

Builds a PowerShell-enabled deployment ISO in [`Build/ISO`](Build/ISO) using the configured WIM and payload templates. The filename placed in [`Build/WIM`](Build/WIM) must match the `WIMName` value in [`config/osd-config.json`](config/osd-config.json). The ISO boot image launches a generated `Deploy.ps1` payload inside WinPE.

The current deployment payload also stages a post-deploy bootstrap under `C:\Windows\Setup\Scripts`. `SetupComplete.cmd` registers a one-time `RunOnce` launch for `PostDeploy.ps1`, which is currently used to install PowerShell 7.6 inside the deployed VM after the first automatic logon.

## Prerequisites

- Windows
- PowerShell 7 (`pwsh`)
- Windows ADK Deployment Tools / WinPE tooling
- WinPE optional components that ship with the ADK so the build process can add PowerShell support to `boot.wim`
- elevated session when running ADK and DISM-dependent operations
- Deployment and Imaging Tools Environment for `copype.cmd` and `MakeWinPEMedia`
- outbound internet access from the deployed VM if you want the bundled post-deploy PowerShell 7 installer bootstrap to succeed

## Security Notes

[`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) is expected to be a local, ignored, project-specific answer file.

- Authoring the unattended answer file itself is intentionally out of scope for this repository.
- Create and validate `PayloadTemplates/Unattend.xml` separately, for example with Windows System Image Manager, then keep it local and ignored by git.
- For this repo's intended flow, the answer file must set the built-in `Administrator` password and configure one automatic logon as `Administrator`.
- Additional OOBE and locale settings are strongly recommended so deployment reaches the desktop without manual prompts.
- Do not commit real passwords, secret-bearing unattended files, WIM artifacts, ISO artifacts, or operational logs.

## Git Hygiene

[`.gitignore`](.gitignore) is configured to ignore local runtime artifacts such as:

- `*.wim`
- `*.iso`
- `*.log`
- `PayloadTemplates/Unattend.xml`
- repo-local `Build` output and mount contents

This keeps project configuration and source under version control while preventing accidental commits of large artifacts or operational state.

## Project Versioning

This repository versions the WinPE deployment lab project itself using Semantic Versioning.

- Current project version: see [`VERSION`](VERSION)
- Version history: see [`CHANGELOG.md`](CHANGELOG.md)

The project version is separate from the template-version badge at the top of this README. The badge records the `pwsh-dev-template` guidance version used for synced AI guidance and guardrails.

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
- Post-deploy software installation belongs after imaging, not inside the base image by default. The current example installs PowerShell 7.6 inside the deployed VM after first logon, which keeps the image reusable while still demonstrating application deployment and post-deployment automation.

## Current State

This repository began as a set of original project files dropped into the repo root from an earlier iteration. It has since been refactored into a cleaner template-aligned PowerShell project with:

- repo-local runtime structure under `Build`
- tracked project configuration in [`config/osd-config.json`](config/osd-config.json)
- thin root script wrappers over `src/Public` and `src/Private`
- PowerShell-enabled WinPE media for both capture and deployment
- offline WIM maintenance
- safe unattended file handling
- a validated post-deploy PowerShell 7.6 bootstrap inside the deployed VM

The current focus is no longer on reorganizing the project, but on keeping the workflow reliable, understandable, and useful as a repeatable VM deployment template.
