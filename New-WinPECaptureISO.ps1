<#
.SYNOPSIS
    Creates a customized WinPE ISO for automated image capture from the reference VM.

.DESCRIPTION
    This script reads project settings from config\osd-config.json, uses the repository-local
    Build folder as its working area, and generates a bootable capture ISO with embedded
    capture logic. It mounts boot.wim, injects a customized startnet.cmd, and copies
    Assign-C.txt to ensure C: is assigned before capture.

    Logging is lifecycle-safe and recruiter-friendly:
      * All messages are written to the console immediately.
      * Buffered messages are flushed into Build\Logs\Workspace.log once logging is initialized.
      * All subsequent events are appended directly to the log file.

    The resulting ISO automatically captures a WIM image of the reference VM and saves
    it to the capture location defined in config\osd-config.json.

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

$context = Get-WinPEProjectContext -ProjectRoot $PSScriptRoot
Initialize-WinPEProjectRuntime -Context $context
Initialize-WorkspaceLogging -WorkspaceRoot $context.ProjectRoot -LogRoot $context.Paths.LogRoot

try {
    Assert-AdministratorSession
    Assert-AdkEnvironment
}
catch {
    Write-WorkspaceLog $_.Exception.Message -Level ERROR
    exit 1
}

# Construct artifact names
$bootISOName      = $context.Config.BootISOName
$bootISOPath      = Join-Path $context.Paths.IsoRoot $bootISOName
$wimName          = $context.Config.WIMName
$imageDescription = $context.Config.ImageDescription
$captureLocation  = $context.Config.CaptureLocation

# Define and clean the temporary WinPE build directory
$winPEWorkDir = $context.Paths.CaptureWorkRoot
if (Test-Path -LiteralPath $winPEWorkDir) {
    Write-WorkspaceLog "Removing existing temporary WinPE build directory: $winPEWorkDir" -Level WARNING
    Remove-ItemIfPresent -Path $winPEWorkDir
}

# Create the temporary WinPE build directory
copype.cmd amd64 $winPEWorkDir
Write-WorkspaceLog "Created temporary WinPE build directory at $winPEWorkDir" -Level SUCCESS

# Set boot.wim location and mount directory
$bootWim   = Join-Path "$winPEWorkDir\Media\sources" "boot.wim"
$mountPath = $context.Paths.CaptureMountRoot

# Mount boot.wim
Mount-WindowsImage -ImagePath $bootWim -Index 1 -Path $mountPath
Write-WorkspaceLog "Mounted boot.wim at $mountPath" -Level SUCCESS

# Build startnet.cmd content
$startnet = @"
wpeinit
@echo off
wpeutil UpdateBootInfo

set CAPTUREPATH=$captureLocation

REM Check if C: is assigned
dir C:\ >nul 2>&1
if errorlevel 1 (
    echo C: not assigned. Running diskpart...
    diskpart /s assign-c.txt
) else (
    echo C: is already assigned.
)

REM Create capture folder if needed
if not exist %CAPTUREPATH% (
    echo Creating %CAPTUREPATH%...
    md %CAPTUREPATH%
)

REM Run capture
dism /Capture-Image /ImageFile:%CAPTUREPATH%\$wimName /CaptureDir:C:\ /Name:"$wimName" /Description:"$imageDescription" /Compress:Max /CheckIntegrity
"@

# Inject new startnet.cmd into the mounted boot.wim
Set-Content "$mountPath\Windows\System32\startnet.cmd" $startnet
Write-WorkspaceLog "Injected custom startnet.cmd into boot.wim" -Level SUCCESS

# Set source and destination for Diskpart script copy
$assignSource = Join-Path $context.Paths.PayloadTemplateRoot "Assign-C.txt"
$assignDest   = Join-Path $mountPath "Windows\System32\assign-c.txt"

# Ensure that assign-c.txt is available and hard fail if it is not
if (-not (Test-Path $assignSource)) {
    Write-WorkspaceLog "Required file missing: $assignSource" -Level ERROR
    Exit 1
}

Copy-Item -Path $assignSource -Destination $assignDest -Force
Write-WorkspaceLog "Copied assign-c.txt into boot.wim" -Level SUCCESS

# Dismount boot.wim and save changes
Dismount-WindowsImage -Path $mountPath -Save
Write-WorkspaceLog "Dismounted boot.wim and saved changes" -Level SUCCESS

# Create bootable ISO
MakeWinPEMedia /ISO $winPEWorkDir $bootISOPath
Write-WorkspaceLog "WinPE ISO created: $bootISOPath" -Level SUCCESS

Write-WorkspaceLog "New-WinPECaptureISO.ps1 steps complete. WinPE-Capture.iso created successfully." -Level SUCCESS
