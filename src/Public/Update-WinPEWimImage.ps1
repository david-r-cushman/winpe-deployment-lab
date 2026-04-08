<#
.SYNOPSIS
    Applies offline maintenance to the configured captured WIM.

.DESCRIPTION
    Validates and mounts the configured WIM from the repo-local Build\WIM
    folder, applies the scripted maintenance step, and saves or discards
    changes based on success.

.PARAMETER ProjectRoot
    The repository root for the WinPE project. Defaults to the current script root.

.EXAMPLE
    Update-WinPEWimImage -ProjectRoot 'E:\Git\winpe-deployment-lab'

    Mounts the configured WIM, applies offline maintenance, and saves the image.
#>
function Update-WinPEWimImage {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProjectRoot = $PSScriptRoot
    )

    $context = Get-WinPEProjectContext -ProjectRoot $ProjectRoot
    Initialize-WinPEProjectRuntime -Context $context
    Initialize-WorkspaceLogging -WorkspaceRoot $context.ProjectRoot -LogRoot $context.Paths.LogRoot

    Assert-AdministratorSession

    $wimName = $context.Config.WIMName
    $wimPath = Join-Path $context.Paths.WimRoot $wimName
    $mountPath = $context.Paths.WimMountRoot

    if (-not (Test-Path -LiteralPath $wimPath)) {
        throw "Expected WIM file not found: $wimPath. Ensure the captured image exists in Build\WIM."
    }
    Write-WorkspaceLog "Validated captured WIM file: $wimPath" -Level SUCCESS

    try {
        $wimInfo = Get-WindowsImage -ImagePath $wimPath -ErrorAction Stop
        Write-WorkspaceLog "WIM integrity check passed. Image contains $($wimInfo.Count) index(es)." -Level SUCCESS
        foreach ($image in $wimInfo) {
            Write-WorkspaceLog "Index $($image.ImageIndex): $($image.ImageName) - $($image.ImageDescription)" -Level INFO
        }
    }
    catch {
        throw "WIM integrity check failed: $($_.Exception.Message)"
    }

    if (-not (Test-Path -LiteralPath $mountPath)) {
        New-Item -Path $mountPath -ItemType Directory -Force | Out-Null
        Write-WorkspaceLog "Created mount path: $mountPath" -Level SUCCESS
    }

    $wimMounted = $false
    $saveChanges = $false

    try {
        Mount-WindowsImage -ImagePath $wimPath -Index 1 -Path $mountPath -ErrorAction Stop
        $wimMounted = $true
        Write-WorkspaceLog "Mounted WIM at $mountPath" -Level SUCCESS

        $capturedImagesPath = Join-Path $mountPath 'CapturedImages'
        if (Test-Path -LiteralPath $capturedImagesPath) {
            try {
                Remove-Item -LiteralPath $capturedImagesPath -Recurse -Force -ErrorAction Stop
                Write-WorkspaceLog 'Removed offline folder: C:\CapturedImages' -Level SUCCESS
            }
            catch {
                Write-WorkspaceLog "Failed to remove offline folder: $($_.Exception.Message)" -Level ERROR
                throw
            }
        }
        else {
            Write-WorkspaceLog 'Offline folder not present: C:\CapturedImages' -Level INFO
        }

        $saveChanges = $true
    }
    finally {
        if ($wimMounted) {
            try {
                if ($saveChanges) {
                    Dismount-WindowsImage -Path $mountPath -Save -ErrorAction Stop
                    Write-WorkspaceLog 'Dismounted WIM and saved changes' -Level SUCCESS
                }
                else {
                    Dismount-WindowsImage -Path $mountPath -Discard -ErrorAction Stop
                    Write-WorkspaceLog 'Dismounted WIM and discarded changes after a failure' -Level WARNING
                }
            }
            catch {
                throw "Failed to dismount WIM: $($_.Exception.Message)"
            }
        }
    }

    Write-WorkspaceLog 'Maintain-WIMImage.ps1 steps complete. Offline maintenance applied successfully.' -Level SUCCESS
}
