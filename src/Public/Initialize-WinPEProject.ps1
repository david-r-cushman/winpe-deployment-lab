<#
.SYNOPSIS
    Initializes the repository-local runtime structure for the project.

.DESCRIPTION
    Validates the checked-in project configuration, ensures the required
    repo-local runtime folders exist under Build, initializes logging,
    and creates a local ignored Unattend.xml working copy from the tracked
    template when needed.

.PARAMETER ProjectRoot
    The repository root for the WinPE project. Defaults to the current script root.

.EXAMPLE
    Initialize-WinPEProject -ProjectRoot 'E:\Git\winpe-deployment-lab'

    Validates configuration and prepares the repo-local runtime structure.
#>
function Initialize-WinPEProject {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProjectRoot = $PSScriptRoot
    )

    $context = Get-WinPEProjectContext -ProjectRoot $ProjectRoot
    Initialize-WinPEProjectRuntime -Context $context
    Initialize-WorkspaceLogging -WorkspaceRoot $context.ProjectRoot -LogRoot $context.Paths.LogRoot
    Initialize-UnattendWorkingCopy -Context $context

    Write-WorkspaceLog "Validated project configuration: $($context.ConfigPath)" -Level SUCCESS
    Write-WorkspaceLog "Runtime root ready at $($context.Paths.BuildRoot)" -Level SUCCESS
    Write-WorkspaceLog "WIM working folder: $($context.Paths.WimRoot)" -Level INFO
    Write-WorkspaceLog "ISO output folder: $($context.Paths.IsoRoot)" -Level INFO
    Write-WorkspaceLog "Log folder: $($context.Paths.LogRoot)" -Level INFO
    Write-WorkspaceLog "Mount folder: $($context.Paths.MountRoot)" -Level INFO
}
