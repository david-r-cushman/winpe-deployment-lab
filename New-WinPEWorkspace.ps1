<#
.SYNOPSIS
    Initializes the repository-local runtime structure for WinPE media work.

.DESCRIPTION
    This command validates the checked-in project configuration and ensures that the
    transient runtime folders used for ISO creation, WIM maintenance, and logging exist
    under the repository itself. The repository is the workspace; this script no longer
    creates a second copy of the project elsewhere on disk or generates an unattended
    answer file. It has been tested from an elevated Deployment and Imaging Tools
    Environment session using both Windows PowerShell 5.1 and PowerShell 7 (pwsh).

.EXAMPLE
    PowerShell.exe .\New-WinPEWorkspace.ps1

    Validates config\osd-config.json and ensures the local Build folder structure exists
    for logs, mount paths, WIM working files, and ISO output.

.EXAMPLE
    pwsh .\New-WinPEWorkspace.ps1

    Runs the same initialization flow from PowerShell 7 in an elevated Deployment and
    Imaging Tools Environment session.

.NOTES
    Author: David R. Cushman
    Script: New-WinPEWorkspace.ps1
#>

[CmdletBinding()]
param()

. "$PSScriptRoot\Write-WorkspaceLog.ps1"
. "$PSScriptRoot\src\Private\ProjectRuntime.ps1"
. "$PSScriptRoot\src\Public\Initialize-WinPEProject.ps1"

try {
    Initialize-WinPEProject -ProjectRoot $PSScriptRoot
}
catch {
    Write-WorkspaceLog "Project initialization failed: $($_.Exception.Message)" -Level ERROR
    exit 1
}
