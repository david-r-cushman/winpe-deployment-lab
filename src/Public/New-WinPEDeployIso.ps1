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
            if ($file -eq "Unattend.xml") {
                throw "Required file missing: $sourceFile. Run .\New-WinPEWorkspace.ps1 to create the local working copy, then update it in Windows System Image Manager before building deployment media."
            }

            throw "Required file missing: $sourceFile"
        }

        Copy-Item -Path $sourceFile -Destination $deployFolder -Force
        Write-WorkspaceLog "Copied $file into Deploy folder" -Level SUCCESS
    }

    Copy-Item -Path $wimPath -Destination $deployFolder -Force
    Write-WorkspaceLog "Copied captured WIM into Deploy folder: $wimName" -Level SUCCESS

    $deployScript = @"
`$ErrorActionPreference = 'Stop'

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = `$true)]
        [string]`$FilePath,

        [Parameter()]
        [string[]]`$ArgumentList = @(),

        [Parameter(Mandatory = `$true)]
        [string]`$Description
    )

    Write-Host "[INFO] `$Description"
    & `$FilePath @ArgumentList

    if (`$LASTEXITCODE -ne 0) {
        throw "`$Description failed with exit code `$LASTEXITCODE."
    }
}

function Get-IsoDrive {
    `$drive = Get-PSDrive -PSProvider FileSystem |
        ForEach-Object { `$_.Root.TrimEnd('\') } |
        Where-Object { Test-Path -LiteralPath "`$_\Deploy\Unattend.xml" } |
        Select-Object -First 1

    if (`$drive) {
        return `$drive
    }

    throw 'Could not locate ISO drive.'
}

`$isoDrive = Get-IsoDrive
Write-Host "[SUCCESS] ISO mounted as: `$isoDrive"

`$wimFile = "`$isoDrive\Deploy\$wimName"
if (-not (Test-Path -LiteralPath `$wimFile)) {
    throw "WIM file not found: `$wimFile"
}

Write-Host "[SUCCESS] WIM file resolved: `$wimFile"

Invoke-NativeCommand -FilePath 'diskpart' -ArgumentList @('/s', "`$isoDrive\Deploy\Diskconfig.txt") -Description 'Partitioning disk'
Invoke-NativeCommand -FilePath 'dism' -ArgumentList @('/apply-image', "/imagefile:`$wimFile", '/index:1', '/applydir:C:\') -Description 'Applying WIM image'
Invoke-NativeCommand -FilePath 'bcdboot' -ArgumentList @('C:\Windows', '/s', 'S:', '/f', 'UEFI') -Description 'Configuring boot files'

`$pantherPath = 'C:\Windows\Panther'
`$unattendTarget = Join-Path `$pantherPath 'Unattend.xml'

if (-not (Test-Path -LiteralPath `$pantherPath)) {
    New-Item -Path `$pantherPath -ItemType Directory -Force | Out-Null
}

Copy-Item -LiteralPath "`$isoDrive\Deploy\Unattend.xml" -Destination `$unattendTarget -Force
& attrib -R -S -H `$unattendTarget
& icacls `$unattendTarget /inheritance:e | Out-Null
Write-Host '[SUCCESS] Copied Unattend.xml into C:\Windows\Panther'

Invoke-NativeCommand -FilePath 'wpeutil' -ArgumentList @('shutdown') -Description 'Shutting down WinPE'
"@
    Set-Content -Path (Join-Path $deployFolder "Deploy.ps1") -Value $deployScript
    Write-WorkspaceLog "Generated Deploy.ps1 in Deploy folder" -Level SUCCESS

    $bootWim = Join-Path "$winPEWorkDir\Media\sources" "boot.wim"
    $mountPath = $context.Paths.DeployMountRoot

    Mount-WindowsImage -ImagePath $bootWim -Index 1 -Path $mountPath
    Write-WorkspaceLog "Mounted boot.wim at $mountPath" -Level SUCCESS

    Enable-WinPEPowerShellSupport -MountPath $mountPath

    $startnet = @"
@echo off
REM WinPE Deployment Bootstrap
wpeinit
X:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File X:\Deploy\Deploy.ps1
"@
    Set-Content "$mountPath\Windows\System32\startnet.cmd" $startnet
    Write-WorkspaceLog "Injected custom startnet.cmd into boot.wim" -Level SUCCESS

    $deployScriptInBootImagePath = Join-Path $mountPath "Deploy\Deploy.ps1"
    New-Item -Path (Split-Path $deployScriptInBootImagePath -Parent) -ItemType Directory -Force | Out-Null
    Copy-Item -Path (Join-Path $deployFolder "Deploy.ps1") -Destination $deployScriptInBootImagePath -Force
    Write-WorkspaceLog "Copied Deploy.ps1 into boot.wim" -Level SUCCESS

    Dismount-WindowsImage -Path $mountPath -Save
    Write-WorkspaceLog "Dismounted boot.wim and saved changes" -Level SUCCESS

    MakeWinPEMedia /ISO $winPEWorkDir $deployISOPath
    Write-WorkspaceLog "WinPE Deploy ISO created: $deployISOPath" -Level SUCCESS

    Write-WorkspaceLog "New-WinPEDeployISO.ps1 steps complete. WinPE-Deploy.iso created successfully." -Level SUCCESS
}
