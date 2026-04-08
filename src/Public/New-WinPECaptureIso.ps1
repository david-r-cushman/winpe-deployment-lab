<#
.SYNOPSIS
    Builds a PowerShell-enabled WinPE capture ISO.

.DESCRIPTION
    Uses the current repo configuration to create a capture ISO, adds
    WinPE PowerShell support to boot.wim, injects generated capture logic,
    and prepares the ISO to capture a reference image to the configured
    capture location.

.PARAMETER ProjectRoot
    The repository root for the WinPE project. Defaults to the current script root.

.EXAMPLE
    New-WinPECaptureIso -ProjectRoot 'E:\Git\winpe-deployment-lab'

    Builds the capture ISO using the current repo configuration.
#>
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

    Invoke-ExternalTool -FilePath 'copype.cmd' -ArgumentList @('amd64', $winPEWorkDir) -Description "copype.cmd failed while creating temporary WinPE build directory at '$winPEWorkDir'"
    Write-WorkspaceLog "Created temporary WinPE build directory at $winPEWorkDir" -Level SUCCESS

    $bootWim = Join-Path "$winPEWorkDir\Media\sources" 'boot.wim'
    $mountPath = $context.Paths.CaptureMountRoot

    $captureScript = @"
`$ErrorActionPreference = 'Stop'

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]`$FilePath,

        [Parameter()]
        [string[]]`$ArgumentList = @(),

        [Parameter(Mandatory)]
        [string]`$Description
    )

    Write-Host "[INFO] `$Description"
    & `$FilePath @ArgumentList

    if (`$LASTEXITCODE -ne 0) {
        throw "`$Description failed with exit code `$LASTEXITCODE."
    }
}

Invoke-NativeCommand -FilePath 'wpeutil' -ArgumentList @('UpdateBootInfo') -Description 'Refreshing WinPE boot information'

if (-not (Test-Path -LiteralPath 'C:\')) {
    Write-Host '[INFO] C: not assigned. Running diskpart...'
    Invoke-NativeCommand -FilePath 'diskpart' -ArgumentList @('/s', 'X:\Windows\System32\assign-c.txt') -Description 'Assigning C: drive'
}
else {
    Write-Host '[SUCCESS] C: is already assigned.'
}

`$capturePath = '$captureLocation'
if (-not (Test-Path -LiteralPath `$capturePath)) {
    New-Item -Path `$capturePath -ItemType Directory -Force | Out-Null
    Write-Host "[SUCCESS] Created capture folder: `$capturePath"
}
else {
    Write-Host "[SUCCESS] Capture folder already present: `$capturePath"
}

`$imagePath = Join-Path `$capturePath '$wimName'
Invoke-NativeCommand -FilePath 'dism' -ArgumentList @(
    '/Capture-Image',
    "/ImageFile:`$imagePath",
    '/CaptureDir:C:\',
    '/Name:$wimName',
    '/Description:$imageDescription',
    '/Compress:Max',
    '/CheckIntegrity'
) -Description 'Capturing reference image'
"@

    $bootWimMounted = $false
    $saveBootWimChanges = $false
    try {
        Mount-WindowsImage -ImagePath $bootWim -Index 1 -Path $mountPath -ErrorAction Stop
        $bootWimMounted = $true
        Write-WorkspaceLog "Mounted boot.wim at $mountPath" -Level SUCCESS

        Enable-WinPEPowerShellSupport -MountPath $mountPath

        Set-Content -Path (Join-Path $mountPath 'Capture.ps1') -Value $captureScript -Encoding ascii
        Write-WorkspaceLog 'Copied Capture.ps1 into boot.wim' -Level SUCCESS

        $startnet = @"
@echo off
REM WinPE Capture Bootstrap
wpeinit
X:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File X:\Capture.ps1
"@

        Set-Content -Path "$mountPath\Windows\System32\startnet.cmd" -Value $startnet -Encoding ascii
        Write-WorkspaceLog 'Injected custom startnet.cmd into boot.wim' -Level SUCCESS

        $assignSource = Join-Path $context.Paths.PayloadTemplateRoot 'Assign-C.txt'
        $assignDest = Join-Path $mountPath 'Windows\System32\assign-c.txt'

        if (-not (Test-Path $assignSource)) {
            throw "Required file missing: $assignSource"
        }

        Copy-Item -Path $assignSource -Destination $assignDest -Force
        Write-WorkspaceLog 'Copied assign-c.txt into boot.wim' -Level SUCCESS

        $saveBootWimChanges = $true
    }
    finally {
        if ($bootWimMounted) {
            if ($saveBootWimChanges) {
                Dismount-WindowsImage -Path $mountPath -Save -ErrorAction Stop
                Write-WorkspaceLog 'Dismounted boot.wim and saved changes' -Level SUCCESS
            }
            else {
                Dismount-WindowsImage -Path $mountPath -Discard -ErrorAction Stop
                Write-WorkspaceLog 'Dismounted boot.wim and discarded changes after a failure' -Level WARNING
            }
        }
    }

    Invoke-ExternalTool -FilePath 'MakeWinPEMedia' -ArgumentList @('/ISO', $winPEWorkDir, $bootISOPath) -Description "MakeWinPEMedia failed to create WinPE Capture ISO at '$bootISOPath'"
    Write-WorkspaceLog "WinPE ISO created: $bootISOPath" -Level SUCCESS

    Write-WorkspaceLog 'New-WinPECaptureISO.ps1 steps complete. WinPE-Capture.iso created successfully.' -Level SUCCESS
}
