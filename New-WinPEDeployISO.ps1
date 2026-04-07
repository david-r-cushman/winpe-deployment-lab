<#
.SYNOPSIS
    Creates a customized WinPE ISO for automated deployment of a captured WIM image.

.DESCRIPTION
    This script reads project settings from config\osd-config.json, validates that the
    captured WIM exists in the repository-local Build\WIM folder, and builds a deployment
    ISO in the repository-local Build area. It injects startnet.cmd and Deploy.cmd logic,
    copies required payload files, and ensures the captured WIM is accessible from the
    ISO drive rather than the RAM drive.

    Logging is lifecycle-safe and recruiter-friendly:
      * All messages are written to the console immediately.
      * Buffered messages are flushed into Logs\Workspace.log once logging is initialized.
      * All subsequent events are appended directly to the log file.

    The resulting ISO automates disk partitioning, applies the captured WIM to C:\,
    configures boot files, injects Unattend.xml, and shuts down the VM.

.PARAMETER None
    All configuration is driven by the checked-in config\osd-config.json file.

.EXAMPLE
    PowerShell.exe .\New-WinPEWorkspace.ps1
    Copy-Item .\SomeReferenceImage.wim .\Build\WIM\WinSvr2022-RefImage.wim
    PowerShell.exe .\New-WinPEDeployISO.ps1

    Initializes the repository-local runtime folders, places the captured WIM in Build\WIM,
    and builds the deployment ISO in Build\ISO.

.NOTES
    Author: David R. Cushman
    Script: New-WinPEDeployISO.ps1
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

# Resolve WIM name and path
$wimName = $context.Config.WIMName
$wimPath = Join-Path $context.Paths.WimRoot $wimName

# Validate WIM file exists
if (-not (Test-Path $wimPath)) {
    Write-WorkspaceLog "Expected WIM file not found: $wimPath. Ensure the captured image has been copied to Output\WIM." -Level ERROR
    Exit 1
}
Write-WorkspaceLog "Validated captured WIM file: $wimPath" -Level SUCCESS

# Construct deploy ISO name and path
$deployISOName = $context.Config.DeployISOName
$deployISOPath = Join-Path $context.Paths.IsoRoot $deployISOName

# Define WinPE workspace path
$winPEWorkDir = $context.Paths.DeployWorkRoot
if (Test-Path $winPEWorkDir) {
    Write-WorkspaceLog "Removing existing WinPE workspace: $winPEWorkDir" -Level WARNING
    Remove-ItemIfPresent -Path $winPEWorkDir
}

# Create WinPE workspace
copype.cmd amd64 $winPEWorkDir
Write-WorkspaceLog "Created WinPE workspace at $winPEWorkDir" -Level SUCCESS

# Create Deploy folder inside Media
$deployFolder = Join-Path $winPEWorkDir "Media\Deploy"
New-Item -Path $deployFolder -ItemType Directory -Force | Out-Null
Write-WorkspaceLog "Created Deploy folder at $deployFolder" -Level SUCCESS

# Copy required payload files
$payloadSource = $context.Paths.PayloadTemplateRoot
$payloadFiles = @("Diskconfig.txt", "Unattend.xml")

foreach ($file in $payloadFiles) {
    $sourceFile = Join-Path $payloadSource $file
    if (-not (Test-Path $sourceFile)) {
        Write-WorkspaceLog "Required file missing: $sourceFile" -Level ERROR
        Exit 1
    }
    Copy-Item -Path $sourceFile -Destination $deployFolder -Force
    Write-WorkspaceLog "Copied $file into Deploy folder" -Level SUCCESS
}

# Copy captured WIM into Deploy folder
Copy-Item -Path $wimPath -Destination $deployFolder -Force
Write-WorkspaceLog "Copied captured WIM into Deploy folder: $wimName" -Level SUCCESS

# Generate Deploy.cmd dynamically
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

# Mount boot.wim and inject startnet.cmd
$bootWim   = Join-Path "$winPEWorkDir\Media\sources" "boot.wim"
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

# Create bootable ISO
MakeWinPEMedia /ISO $winPEWorkDir $deployISOPath
Write-WorkspaceLog "WinPE Deploy ISO created: $deployISOPath" -Level SUCCESS

Write-WorkspaceLog "New-WinPEDeployISO.ps1 steps complete. WinPE-Deploy.iso created successfully." -Level SUCCESS
