function New-WinPEDeployIso {
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

    $wimName = $context.Config.WIMName
    $wimPath = Join-Path $context.Paths.WimRoot $wimName

    if (-not (Test-Path $wimPath)) {
        throw "Expected WIM file not found: $wimPath. Ensure the captured image has been copied to Build\WIM."
    }
    Write-WorkspaceLog "Validated captured WIM file: $wimPath" -Level SUCCESS

    $deployISOName = $context.Config.DeployISOName
    $deployISOPath = Join-Path $context.Paths.IsoRoot $deployISOName

    $winPEWorkDir = $context.Paths.DeployWorkRoot
    if (Test-Path $winPEWorkDir) {
        Write-WorkspaceLog "Removing existing temporary WinPE build directory: $winPEWorkDir" -Level WARNING
        Remove-ItemIfPresent -Path $winPEWorkDir
    }

    copype.cmd amd64 $winPEWorkDir
    Write-WorkspaceLog "Created temporary WinPE build directory at $winPEWorkDir" -Level SUCCESS

    $deployFolder = Join-Path $winPEWorkDir "Media\Deploy"
    New-Item -Path $deployFolder -ItemType Directory -Force | Out-Null
    Write-WorkspaceLog "Created Deploy folder at $deployFolder" -Level SUCCESS

    $payloadSource = $context.Paths.PayloadTemplateRoot
    $payloadFiles = @("Diskconfig.txt", "Unattend.xml")

    foreach ($file in $payloadFiles) {
        $sourceFile = Join-Path $payloadSource $file
        if (-not (Test-Path $sourceFile)) {
            throw "Required file missing: $sourceFile"
        }
        Copy-Item -Path $sourceFile -Destination $deployFolder -Force
        Write-WorkspaceLog "Copied $file into Deploy folder" -Level SUCCESS
    }

    Copy-Item -Path $wimPath -Destination $deployFolder -Force
    Write-WorkspaceLog "Copied captured WIM into Deploy folder: $wimName" -Level SUCCESS

    $deployCmd = @"
@echo off
setlocal enabledelayedexpansion

REM Search for the ISO drive by looking for Deploy.cmd
for %%i in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if exist %%i:\Deploy\Unattend.xml (
    set ISODRIVE=%%i:
    goto :found
  )
)

echo [ERROR] Could not locate ISO drive. Aborting.
exit /b 1

:found
echo [SUCCESS] ISO mounted as: %ISODRIVE%

REM Partition disk
diskpart /s %ISODRIVE%\Deploy\Diskconfig.txt

REM Resolve WIM file
set WIMFILE=%ISODRIVE%\Deploy\$wimName

if not exist %WIMFILE% (
    echo [ERROR] WIM file not found: %WIMFILE%
    exit /b 1
)

echo [SUCCESS] WIM file resolved: %WIMFILE%

REM Apply image
dism /apply-image /imagefile:%WIMFILE% /index:1 /applydir:C:\

REM Configure boot
bcdboot C:\Windows /s S: /f UEFI

REM Inject Unattend.xml
copy %ISODRIVE%\Deploy\Unattend.xml C:\Windows\Panther\Unattend.xml

REM Shutdown
wpeutil shutdown
"@
    Set-Content -Path (Join-Path $deployFolder "Deploy.cmd") -Value $deployCmd
    Write-WorkspaceLog "Generated Deploy.cmd in Deploy folder" -Level SUCCESS

    $bootWim = Join-Path "$winPEWorkDir\Media\sources" "boot.wim"
    $mountPath = $context.Paths.DeployMountRoot

    Mount-WindowsImage -ImagePath $bootWim -Index 1 -Path $mountPath
    Write-WorkspaceLog "Mounted boot.wim at $mountPath" -Level SUCCESS

    $startnet = @"
@echo off
REM WinPE Deployment Bootstrap
setlocal enabledelayedexpansion

REM Locate ISO drive and call Deploy.cmd
for %%i in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if exist %%i:\Deploy\Deploy.cmd (
    set ISODRIVE=%%i:
    goto :found
  )
)

echo [ERROR] Could not locate ISO drive. Aborting.
exit /b 1

:found
echo [SUCCESS] ISO mounted as: %ISODRIVE%
call %ISODRIVE%\Deploy\Deploy.cmd
"@
    Set-Content "$mountPath\Windows\System32\startnet.cmd" $startnet
    Write-WorkspaceLog "Injected custom startnet.cmd into boot.wim" -Level SUCCESS

    Dismount-WindowsImage -Path $mountPath -Save
    Write-WorkspaceLog "Dismounted boot.wim and saved changes" -Level SUCCESS

    MakeWinPEMedia /ISO $winPEWorkDir $deployISOPath
    Write-WorkspaceLog "WinPE Deploy ISO created: $deployISOPath" -Level SUCCESS

    Write-WorkspaceLog "New-WinPEDeployISO.ps1 steps complete. WinPE-Deploy.iso created successfully." -Level SUCCESS
}
