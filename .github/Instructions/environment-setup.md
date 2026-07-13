# Environment Setup: WinPE Deployment Lab

## Overview

This repository is intended to be developed and operated locally on Windows. The implementation relies on DISM plus the Windows ADK Deployment Tools and WinPE optional components, so the actual WinPE build and offline servicing workflow does not map cleanly to Linux containers or GitHub Codespaces.

The goal of the environment is to keep the operator workflow explicit and reproducible: the repository stays local, the ADK toolchain stays on the Windows host, and the PowerShell entry points run from an elevated Deployment and Imaging Tools Environment session when build, capture, deployment, or WIM-servicing work is being performed.

## Development Model

- **Local Windows Host:** Use the repository directly from a Windows workstation or VM with the ADK toolchain installed.
- **VS Code Editing:** Use VS Code for editing, navigation, and review if desired, but run WinPE build operations from an elevated ADK shell.
- **Repo-Local Workspace:** Runtime folders are created under `Build` inside the repository rather than in a second generated workspace.

## Technical Stack

<!-- BEGIN generated:environment-runtime-stack -->
- **Runtime:** PowerShell 7.4.x for repository development on Windows with the Windows ADK Deployment Tools and WinPE optional components
<!-- END generated:environment-runtime-stack -->
- **Operator Shell:** Elevated Deployment and Imaging Tools Environment session for `copype.cmd`, `MakeWinPEMedia`, and DISM-backed image servicing
- **Image Toolchain:** Windows ADK Deployment Tools, WinPE add-on / optional components, and DISM
<!-- BEGIN generated:environment-tooling-stack -->
- **Tooling:** Pester 6.0.0, PSScriptAnalyzer 1.25.0, and PSReadLine 2.4.5
<!-- END generated:environment-tooling-stack -->
- **Governance:** `.editorconfig`, repository guidance, generated Markdown validation, and repo checks

## Local Prerequisites

Before running the WinPE workflow, ensure the host machine is configured as follows:

1. **Windows:** Use a Windows host for build, capture, deployment, and WIM-servicing operations.
2. **PowerShell:** Install PowerShell 7.4 (`pwsh`) for the maintained development and operator baseline.
3. **Windows ADK Deployment Tools:** Install the ADK components that provide `copype.cmd` and `MakeWinPEMedia`.
4. **WinPE Optional Components:** Install the WinPE add-on so boot media can include PowerShell-enabled payloads.
5. **Elevation:** Run ADK and DISM-dependent operations from an elevated session.

Recommended supporting tools include:

- `ms-vscode.PowerShell`
- `ms-vscode.editorconfig`
- `DavidAnson.vscode-markdownlint`

## Getting Started

1. Open the repository locally on a Windows host.
2. Review the tracked configuration in `config/osd-config.json` and the payload content under `PayloadTemplates`.
3. Create and validate a local ignored `PayloadTemplates/Unattend.xml` for the image and deployment flow you want to test.
4. Launch an elevated Deployment and Imaging Tools Environment session.
5. Run the root PowerShell entry points from the repository root as needed.

## PowerShell Profile And Shell Use

Normal editing and validation should use PowerShell 7 (`pwsh`), and WinPE build operations should be driven from the elevated ADK shell so the required Microsoft tooling is already on `PATH`.

That split keeps day-to-day repository work flexible while preserving a predictable execution path for DISM and media-generation operations.

## Design Principles

<!-- BEGIN generated:environment-runtime-principle -->
- **Controlled Operator Environment:** WinPE build and servicing work stays on a Windows host with the ADK Deployment Tools and WinPE optional components installed
<!-- END generated:environment-runtime-principle -->
- **Repository-As-Workspace:** The repository itself remains the working area, with runtime state created locally under `Build`.
- **Visible Deployment Mechanics:** The environment is designed to keep WinPE, DISM, WIM handling, and unattended deployment steps easy to inspect and validate.
- **Windows-Native Tooling:** The repository deliberately leans on the Microsoft toolchain this workflow actually requires rather than wrapping it in a container abstraction that cannot execute the full build path.

## Troubleshooting

- **ADK Commands Not Found:** Reopen an elevated Deployment and Imaging Tools Environment session and confirm the ADK Deployment Tools are installed.
- **WinPE PowerShell Support Missing:** Verify the WinPE add-on / optional components are installed and that the build process is staging the required packages into `boot.wim`.
- **DISM Access Errors:** Confirm the session is elevated before mounting or servicing WIM files.
- **Unattend Issues:** Revalidate the local ignored `PayloadTemplates/Unattend.xml` and confirm it matches the intended image and deployment flow.
