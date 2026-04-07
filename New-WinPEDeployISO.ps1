<#
.SYNOPSIS
    Creates a customized WinPE ISO for automated deployment of a captured WIM image.

.DESCRIPTION
    This script reads project settings from config\osd-config.json, validates that the
    captured WIM exists in the repository-local Build\WIM folder, and builds a deployment
    ISO in the repository-local Build area. It adds WinPE PowerShell support to boot.wim,
    injects a minimal startnet.cmd launcher, writes a generated Deploy.ps1 payload into the
    boot image, copies required payload files, and ensures the captured WIM is accessible
    from the ISO drive rather than the RAM drive.

    Logging is lifecycle-safe and recruiter-friendly:
      * All messages are written to the console immediately.
      * Buffered messages are flushed into Build\Logs\Workspace.log once logging is initialized.
      * All subsequent events are appended directly to the log file.

    The resulting ISO launches PowerShell in WinPE, automates disk partitioning, applies
    the captured WIM to C:\, configures boot files, injects Unattend.xml, and shuts down
    the VM.

.PARAMETER None
    All configuration is driven by the checked-in config\osd-config.json file.

.EXAMPLE
    PowerShell.exe .\New-WinPEWorkspace.ps1
    Copy-Item .\SomeReferenceImage.wim .\Build\WIM\<Configured-WIMName>.wim
    PowerShell.exe .\New-WinPEDeployISO.ps1

    Initializes the repository-local runtime folders, places the captured WIM in Build\WIM,
    and builds the deployment ISO in Build\ISO.

.NOTES
    Author: David R. Cushman
    Script: New-WinPEDeployISO.ps1
    Last Updated: 2025-12-04

    IMPORTANT:
    This script must be executed from within the "Deployment and Imaging Tools Environment"
    shell provided by the Windows ADK, launched as Administrator. Required tools include
    copype.cmd, MakeWinPEMedia, and DISM.
#>

. "$PSScriptRoot\Write-WorkspaceLog.ps1"
. "$PSScriptRoot\src\Private\ProjectRuntime.ps1"
. "$PSScriptRoot\src\Public\New-WinPEDeployIso.ps1"

try {
    New-WinPEDeployIso -ProjectRoot $PSScriptRoot
}
catch {
    Write-WorkspaceLog $_.Exception.Message -Level ERROR
    exit 1
}
