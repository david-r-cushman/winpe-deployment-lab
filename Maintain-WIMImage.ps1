<#
.SYNOPSIS
    Performs optional offline maintenance on a captured WIM image.

.DESCRIPTION
    This script reads project settings from config\osd-config.json, mounts the captured
    WIM from the repository-local Build\WIM folder, performs offline maintenance tasks,
    and commits changes. Example maintenance included here: removing the empty
    C:\CapturedImages folder so that deployed systems do not contain a distracting
    placeholder directory.

    Logging is lifecycle-safe and recruiter-friendly:
      * All messages are written to the console immediately.
      * Buffered messages are flushed into Build\Logs\Workspace.log once logging is initialized.
      * All subsequent events are appended directly to the log file.

.EXAMPLE
    PowerShell.exe .\New-WinPEWorkspace.ps1
    PowerShell.exe .\Maintain-WIMImage.ps1

    Initializes the repository-local runtime folders, mounts the configured WIM from
    Build\WIM, applies the offline maintenance step, and saves the image.

.NOTES
    Author: David R. Cushman
    Script: Maintain-WIMImage.ps1
    Last Updated: 2025-12-04
#>

. "$PSScriptRoot\Write-WorkspaceLog.ps1"
. "$PSScriptRoot\src\Private\ProjectRuntime.ps1"
. "$PSScriptRoot\src\Public\Update-WinPEWimImage.ps1"

try {
    Update-WinPEWimImage -ProjectRoot $PSScriptRoot
}
catch {
    Write-WorkspaceLog $_.Exception.Message -Level ERROR
    exit 1
}
