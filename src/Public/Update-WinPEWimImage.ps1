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

    if (-not (Test-Path $wimPath)) {
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

    if (-not (Test-Path $mountPath)) {
        New-Item -Path $mountPath -ItemType Directory -Force | Out-Null
        Write-WorkspaceLog "Created mount path: $mountPath" -Level SUCCESS
    }

    try {
        Mount-WindowsImage -ImagePath $wimPath -Index 1 -Path $mountPath -ErrorAction Stop
        Write-WorkspaceLog "Mounted WIM at $mountPath" -Level SUCCESS
    }
    catch {
        throw "Failed to mount WIM: $($_.Exception.Message)"
    }

    $capturedImagesPath = Join-Path $mountPath "CapturedImages"
    if (Test-Path $capturedImagesPath) {
        try {
            Remove-Item -Path $capturedImagesPath -Recurse -Force -ErrorAction Stop
            Write-WorkspaceLog "Removed offline folder: C:\CapturedImages" -Level SUCCESS
        }
        catch {
            Write-WorkspaceLog "Failed to remove offline folder: $($_.Exception.Message)" -Level ERROR
        }
    }
    else {
        Write-WorkspaceLog "Offline folder not present: C:\CapturedImages" -Level INFO
    }

    try {
        Dismount-WindowsImage -Path $mountPath -Save -ErrorAction Stop
        Write-WorkspaceLog "Dismounted WIM and saved changes" -Level SUCCESS
    }
    catch {
        throw "Failed to dismount WIM: $($_.Exception.Message)"
    }

    Write-WorkspaceLog "Maintain-WIMImage.ps1 steps complete. Offline maintenance applied successfully." -Level SUCCESS
}
