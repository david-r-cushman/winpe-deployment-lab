# WinPE Deployment Lab

This repository is a PowerShell-based lab for building and maintaining WinPE media and offline Windows image artifacts from a repo-local workflow.

Rather than creating a second generated workspace elsewhere on disk, the repository itself is the workspace. A new project can be created from this template, cloned locally, customized, and then used directly to build capture and deployment media.

## Why I Built This

While MDT and SCCM are powerful, they often mask the underlying mechanics of OS deployment. I built this framework to work closer to the underlying WinPE, DISM, WIM, and unattended deployment layers so the process stays visible, scriptable, and portable.

The goal is to show practical endpoint engineering skills through:

- WinPE boot media creation
- offline WIM maintenance
- unattended deployment payload preparation
- repository-driven automation and repeatable project structure

## Workflow Model

The expected workflow is:

1. Create a new repository from this template.
2. Clone the new repository locally.
3. Review and customize [`config/osd-config.json`](config/osd-config.json) for that specific image project.
4. Review and customize the payload templates in [`PayloadTemplates`](PayloadTemplates).
5. Place the project-specific WIM file in [`Build/WIM`](Build/WIM) when needed.
6. Run the PowerShell scripts from the repository root in an elevated Windows ADK Deployment and Imaging Tools Environment session.

The repository contains tracked source, templates, and configuration. Runtime artifacts stay local and are ignored by git.

## Repository Layout

- [`config/osd-config.json`](config/osd-config.json): checked-in project configuration for artifact names and image metadata
- [`PayloadTemplates`](PayloadTemplates): deployment payload templates such as `Unattend.xml`, `Diskconfig.txt`, and `Assign-C.txt`
- [`Build`](Build): repo-local runtime workspace for logs, mount paths, WIM files, ISO output, and temporary WinPE build content
- [`src/Private`](src/Private): shared runtime helpers used by the script entry points
- root-level script entry points:
  - [`New-WinPEWorkspace.ps1`](New-WinPEWorkspace.ps1)
  - [`New-WinPECaptureISO.ps1`](New-WinPECaptureISO.ps1)
  - [`New-WinPEDeployISO.ps1`](New-WinPEDeployISO.ps1)
  - [`Maintain-WIMImage.ps1`](Maintain-WIMImage.ps1)

## Configuration

[`config/osd-config.json`](config/osd-config.json) currently defines:

- `BootISOName`
- `WIMName`
- `DeployISOName`
- `ImageDescription`
- `CaptureLocation`

These values are intended to be customized per derived project repo. Runtime paths are not stored in config; they are calculated from the repository layout.

## Script Usage

Run these from the repository root unless noted otherwise.

### Initialize Local Runtime Structure

```powershell
PowerShell.exe .\New-WinPEWorkspace.ps1
```

Creates or validates the repo-local `Build` structure used for logs, mounts, WIM working files, and ISO output.

### Build Capture ISO

```powershell
PowerShell.exe .\New-WinPEWorkspace.ps1
PowerShell.exe .\New-WinPECaptureISO.ps1
```

Builds a WinPE capture ISO in [`Build/ISO`](Build/ISO) using values from [`config/osd-config.json`](config/osd-config.json).

### Maintain a Captured WIM

```powershell
PowerShell.exe .\New-WinPEWorkspace.ps1
PowerShell.exe .\Maintain-WIMImage.ps1
```

Mounts the configured WIM from [`Build/WIM`](Build/WIM), applies the scripted maintenance step, and saves the image.

### Build Deployment ISO

```powershell
PowerShell.exe .\New-WinPEWorkspace.ps1
Copy-Item .\SomeReferenceImage.wim .\Build\WIM\WinSvr2022-RefImage.wim
PowerShell.exe .\New-WinPEDeployISO.ps1
```

Builds a deployment ISO in [`Build/ISO`](Build/ISO) using the configured WIM and payload templates.

## Prerequisites

- Windows
- PowerShell
- Windows ADK Deployment Tools / WinPE tooling
- elevated session when running ADK and DISM-dependent operations
- Deployment and Imaging Tools Environment for `copype.cmd` and `MakeWinPEMedia`

## Security Notes

[`PayloadTemplates/Unattend.xml`](PayloadTemplates/Unattend.xml) is a template/example file, not a place to store real credentials in source control.

- The tracked file uses placeholder password values for demonstration only.
- A real unattended answer file should be reviewed and finalized locally, typically with Windows System Image Manager.
- Do not commit real passwords, secret-bearing unattended files, WIM artifacts, ISO artifacts, or operational logs.

## Git Hygiene

[`.gitignore`](.gitignore) is configured to ignore local runtime artifacts such as:

- `*.wim`
- `*.iso`
- `*.log`
- repo-local `Build` output and mount contents

This keeps project configuration and source under version control while preventing accidental commits of large artifacts or operational state.

## Current Direction

This repository began with original project files dropped into the root from an earlier iteration. The current refactor is moving that work into a cleaner template-aligned structure that fits the broader PowerShell project conventions used across this portfolio.
