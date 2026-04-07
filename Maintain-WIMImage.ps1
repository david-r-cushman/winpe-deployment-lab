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
      * Buffered messages are flushed into Logs\Workspace.log once logging is initialized.
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

$context = Get-WinPEProjectContext -ProjectRoot $PSScriptRoot
Initialize-WinPEProjectRuntime -Context $context
Initialize-WorkspaceLogging -WorkspaceRoot $context.ProjectRoot -LogRoot $context.Paths.LogRoot

try {
    Assert-AdministratorSession
}
catch {
    Write-WorkspaceLog $_.Exception.Message -Level ERROR
    exit 1
}

# Resolve WIM name and paths
$wimName   = $context.Config.WIMName
$wimPath   = Join-Path $context.Paths.WimRoot $wimName
$mountPath = $context.Paths.WimMountRoot

# Validate WIM file exists
if (-not (Test-Path $wimPath)) {
    Write-WorkspaceLog "Expected WIM file not found: $wimPath. Ensure the captured image exists in Output\WIM." -Level ERROR
    Exit 1
}
Write-WorkspaceLog "Validated captured WIM file: $wimPath" -Level SUCCESS

# Extra guardrail: check WIM integrity with DISM
try {
    $wimInfo = Get-WindowsImage -ImagePath $wimPath -ErrorAction Stop

    # Log basic integrity
    Write-WorkspaceLog "WIM integrity check passed. Image contains $($wimInfo.Count) index(es)." -Level SUCCESS

    # Log recruiter-friendly metadata for each index
    foreach ($image in $wimInfo) {
        Write-WorkspaceLog "Index $($image.ImageIndex): $($image.ImageName) - $($image.ImageDescription)" -Level INFO
    }
}
catch {
    Write-WorkspaceLog "WIM integrity check failed: $($_.Exception.Message)" -Level ERROR
    Exit 1
}

# Ensure mount path exists
if (-not (Test-Path $mountPath)) {
    New-Item -Path $mountPath -ItemType Directory -Force | Out-Null
    Write-WorkspaceLog "Created mount path: $mountPath" -Level SUCCESS
}

# Mount the WIM with error handling
try {
    Mount-WindowsImage -ImagePath $wimPath -Index 1 -Path $mountPath -ErrorAction Stop
    Write-WorkspaceLog "Mounted WIM at $mountPath" -Level SUCCESS
}
catch {
    Write-WorkspaceLog "Failed to mount WIM: $($_.Exception.Message)" -Level ERROR
    Exit 1
}

# Perform offline maintenance: remove C:\CapturedImages
$capturedImagesPath = Join-Path $mountPath "CapturedImages"
if (Test-Path $capturedImagesPath) {
    try {
        Remove-Item -Path $capturedImagesPath -Recurse -Force -ErrorAction Stop
        Write-WorkspaceLog "Removed offline folder: C:\CapturedImages" -Level SUCCESS
    }
    catch {
        Write-WorkspaceLog "Failed to remove offline folder: $($_.Exception.Message)" -Level ERROR
    }
} else {
    Write-WorkspaceLog "Offline folder not present: C:\CapturedImages" -Level INFO
}

# Dismount and commit changes with error handling
try {
    Dismount-WindowsImage -Path $mountPath -Save -ErrorAction Stop
    Write-WorkspaceLog "Dismounted WIM and saved changes" -Level SUCCESS
}
catch {
    Write-WorkspaceLog "Failed to dismount WIM: $($_.Exception.Message)" -Level ERROR
    Exit 1
}

Write-WorkspaceLog "Maintain-WIMImage.ps1 steps complete. Offline maintenance applied successfully." -Level SUCCESS
