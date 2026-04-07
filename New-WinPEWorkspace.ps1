<#
.SYNOPSIS
    Initializes the repository-local runtime structure for WinPE media work.

.DESCRIPTION
    This command validates the checked-in project configuration and ensures that the
    transient runtime folders used for ISO creation, WIM maintenance, and logging exist
    under the repository itself. The repository is the workspace; this script no longer
    creates a second copy of the project elsewhere on disk.

.EXAMPLE
    PowerShell.exe .\New-WinPEWorkspace.ps1

    Validates config\osd-config.json and ensures the local Build folder structure exists
    for logs, mount paths, WIM working files, and ISO output.

.NOTES
    Author: David R. Cushman
    Script: New-WinPEWorkspace.ps1
#>

[CmdletBinding()]
param()

. "$PSScriptRoot\Write-WorkspaceLog.ps1"
. "$PSScriptRoot\src\Private\ProjectRuntime.ps1"

try {
    $context = Get-WinPEProjectContext -ProjectRoot $PSScriptRoot
    Initialize-WinPEProjectRuntime -Context $context
    Initialize-WorkspaceLogging -WorkspaceRoot $context.ProjectRoot -LogRoot $context.Paths.LogRoot

    Write-WorkspaceLog "Validated project configuration: $($context.ConfigPath)" -Level SUCCESS
    Write-WorkspaceLog "Runtime root ready at $($context.Paths.BuildRoot)" -Level SUCCESS
    Write-WorkspaceLog "WIM working folder: $($context.Paths.WimRoot)" -Level INFO
    Write-WorkspaceLog "ISO output folder: $($context.Paths.IsoRoot)" -Level INFO
    Write-WorkspaceLog "Log folder: $($context.Paths.LogRoot)" -Level INFO
    Write-WorkspaceLog "Mount folder: $($context.Paths.MountRoot)" -Level INFO
}
catch {
    Write-Warning "Project initialization failed: $($_.Exception.Message)"
    exit 1
}
