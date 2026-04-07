function Initialize-WinPEProject {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProjectRoot = $PSScriptRoot
    )

    $context = Get-WinPEProjectContext -ProjectRoot $ProjectRoot
    Initialize-WinPEProjectRuntime -Context $context
    Initialize-WorkspaceLogging -WorkspaceRoot $context.ProjectRoot -LogRoot $context.Paths.LogRoot

    Write-WorkspaceLog "Validated project configuration: $($context.ConfigPath)" -Level SUCCESS
    Write-WorkspaceLog "Runtime root ready at $($context.Paths.BuildRoot)" -Level SUCCESS
    Write-WorkspaceLog "WIM working folder: $($context.Paths.WimRoot)" -Level INFO
    Write-WorkspaceLog "ISO output folder: $($context.Paths.IsoRoot)" -Level INFO
    Write-WorkspaceLog "Log folder: $($context.Paths.LogRoot)" -Level INFO
    Write-WorkspaceLog "Mount folder: $($context.Paths.MountRoot)" -Level INFO
}
