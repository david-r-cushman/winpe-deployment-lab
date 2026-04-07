function New-WinPECaptureIso {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProjectRoot = $PSScriptRoot
    )

    $context = Get-WinPEProjectContext -ProjectRoot $ProjectRoot
    Initialize-WinPEProjectRuntime -Context $context
    Initialize-WorkspaceLogging -WorkspaceRoot $context.ProjectRoot -LogRoot $context.Paths.LogRoot

    Assert-AdministratorSession
    Assert-AdkEnvironment

    $bootISOName = $context.Config.BootISOName
    $bootISOPath = Join-Path $context.Paths.IsoRoot $bootISOName
    $wimName = $context.Config.WIMName
    $imageDescription = $context.Config.ImageDescription
    $captureLocation = $context.Config.CaptureLocation

    $winPEWorkDir = $context.Paths.CaptureWorkRoot
    if (Test-Path -LiteralPath $winPEWorkDir) {
        Write-WorkspaceLog "Removing existing temporary WinPE build directory: $winPEWorkDir" -Level WARNING
        Remove-ItemIfPresent -Path $winPEWorkDir
    }

    copype.cmd amd64 $winPEWorkDir
    Write-WorkspaceLog "Created temporary WinPE build directory at $winPEWorkDir" -Level SUCCESS

    $bootWim = Join-Path "$winPEWorkDir\Media\sources" "boot.wim"
    $mountPath = $context.Paths.CaptureMountRoot

    Mount-WindowsImage -ImagePath $bootWim -Index 1 -Path $mountPath
    Write-WorkspaceLog "Mounted boot.wim at $mountPath" -Level SUCCESS

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

    Set-Content "$mountPath\Windows\System32\startnet.cmd" $startnet
    Write-WorkspaceLog "Injected custom startnet.cmd into boot.wim" -Level SUCCESS

    $assignSource = Join-Path $context.Paths.PayloadTemplateRoot "Assign-C.txt"
    $assignDest = Join-Path $mountPath "Windows\System32\assign-c.txt"

    if (-not (Test-Path $assignSource)) {
        throw "Required file missing: $assignSource"
    }

    Copy-Item -Path $assignSource -Destination $assignDest -Force
    Write-WorkspaceLog "Copied assign-c.txt into boot.wim" -Level SUCCESS

    Dismount-WindowsImage -Path $mountPath -Save
    Write-WorkspaceLog "Dismounted boot.wim and saved changes" -Level SUCCESS

    MakeWinPEMedia /ISO $winPEWorkDir $bootISOPath
    Write-WorkspaceLog "WinPE ISO created: $bootISOPath" -Level SUCCESS

    Write-WorkspaceLog "New-WinPECaptureISO.ps1 steps complete. WinPE-Capture.iso created successfully." -Level SUCCESS
}
