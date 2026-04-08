# WinPE Deployment Lab

This repository is a PowerShell-based lab for building and maintaining WinPE media and offline Windows image artifacts from a repo-local workflow.

Rather than creating a second generated workspace elsewhere on disk, the repository itself is the workspace. A new project can be created from this template, cloned locally, customized, and then used directly to build capture and deployment media.

## Why I Built This

While MDT and SCCM are powerful, they often mask the underlying mechanics of OS deployment. I built this framework to work closer to the underlying WinPE, DISM, WIM, and unattended deployment layers so the process stays visible, scriptable, and portable.

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
4. Review and customize the payload templates in [`PayloadTemplates`](PayloadTemplates).
5. Use the configured `WIMName`, `ImageDescription`, and related values to match the image you actually intend to capture or deploy.
6. Run [`New-WinPEWorkspace.ps1`](New-WinPEWorkspace.ps1) once to initialize the local runtime folders and create a local `PayloadTemplates/Unattend.xml` working copy from the tracked template.
7. Open the local `PayloadTemplates/Unattend.xml` in Windows System Image Manager, update the required password values, and save the file locally.
8. Place the project-specific WIM file in [`Build/WIM`](Build/WIM) using the filename configured in [`config/osd-config.json`](config/osd-config.json) when needed.
9. Run the PowerShell scripts from the repository root in an elevated Windows ADK Deployment and Imaging Tools Environment session.

The repository contains tracked source, templates, and configuration. Runtime artifacts stay local and are ignored by git.

WinPE now boots into a PowerShell-enabled runtime. The generated media still uses `startnet.cmd` as the entry point required by WinPE, but that file now acts only as a thin launcher for PowerShell payload scripts generated during ISO creation.

## Repository Layout

- [`config/osd-config.json`](config/osd-config.json): checked-in project configuration for artifact names and image metadata
- [`PayloadTemplates`](PayloadTemplates): deployment payload templates such as `Unattend.Template.xml`, `Diskconfig.txt`, `Assign-C.txt`, and post-deploy bootstrap scripts
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

Creates or validates the repo-local `Build` structure used for logs, mounts, WIM working files, and ISO output. It also creates a local ignored [`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) working copy from [`PayloadTemplates/Unattend.Template.xml`](PayloadTemplates/Unattend.Template.xml) when needed.

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

[`PayloadTemplates/Unattend.Template.xml`](PayloadTemplates/Unattend.Template.xml) is the tracked template/example file. [`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) is the local working copy created during initialization and is ignored by git.

- The tracked template uses placeholder password values for demonstration only.
- The local working copy should be reviewed and finalized locally with Windows System Image Manager.
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

## Current Direction

This repository began with original project files dropped into the root from an earlier iteration. The current refactor is moving that work into a cleaner template-aligned structure that fits the broader PowerShell project conventions used across this portfolio.
