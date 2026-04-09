<#
.SYNOPSIS
    Creates a customized WinPE ISO for automated image capture from the reference VM.

.DESCRIPTION
    This script reads project settings from config\osd-config.json, uses the repository-local
    Build folder as its working area, and generates a bootable capture ISO with embedded
    capture logic. It mounts boot.wim, adds WinPE PowerShell support, injects a minimal
    startnet.cmd launcher, writes a generated Capture.ps1 payload into the boot image, and
    copies Assign-C.txt to ensure C: is assigned before capture.

    Logging is lifecycle-safe and recruiter-friendly:
      * All messages are written to the console immediately.
      * Buffered messages are flushed into Build\Logs\Workspace.log once logging is initialized.
      * All subsequent events are appended directly to the log file.

    The resulting ISO automatically launches PowerShell in WinPE, captures a WIM image of
    the reference VM, and saves it to the capture location defined in config\osd-config.json.

.PARAMETER None
    All configuration is driven by the checked-in config\osd-config.json file.

.EXAMPLE
    PowerShell.exe .\New-WinPEWorkspace.ps1
    PowerShell.exe .\New-WinPECaptureISO.ps1

    Initializes the repository-local runtime folders, then builds the capture ISO in
    Build\ISO using values from config\osd-config.json.

.NOTES
    Author: David R. Cushman
    Script: New-WinPECaptureISO.ps1
    Last Updated: 2025-12-04

    IMPORTANT:
    This script must be executed from within the "Deployment and Imaging Tools Environment"
    shell provided by the Windows ADK, launched as Administrator. Required tools include
    copype.cmd, MakeWinPEMedia, and DISM.
#>

. "$PSScriptRoot\Write-WorkspaceLog.ps1"
. "$PSScriptRoot\src\Private\ProjectRuntime.ps1"
. "$PSScriptRoot\src\Public\New-WinPECaptureIso.ps1"

try {
    New-WinPECaptureIso -ProjectRoot $PSScriptRoot
}
catch {
    Write-WorkspaceLog $_.Exception.Message -Level ERROR
    exit 1
}
