$ErrorActionPreference = 'Stop'

$logPath = 'C:\Windows\Temp\PostDeploy.log'
$installerPath = 'C:\Windows\Temp\PowerShell-7.6.0-win-x64.msi'
$installerLogPath = 'C:\Windows\Temp\PowerShell-7.6.0-install.log'
$powerShellMsiUrl = 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.0/PowerShell-7.6.0-win-x64.msi'

function Write-PostDeployLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $logPath -Value "[$timestamp] $Message"
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter()]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory)]
        [string]$Description
    )

    Write-PostDeployLog "Starting: $Description"
    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -ne 0) {
        throw "$Description failed with exit code $($process.ExitCode)."
    }

    Write-PostDeployLog "Completed: $Description"
}

try {
    New-Item -Path (Split-Path $logPath -Parent) -ItemType Directory -Force | Out-Null
    Write-PostDeployLog 'Post-deploy bootstrap started.'

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (Test-Path -LiteralPath "$env:ProgramFiles\PowerShell\7\pwsh.exe") {
        Write-PostDeployLog 'PowerShell 7 is already installed. Skipping installation.'
        exit 0
    }

    Write-PostDeployLog "Downloading PowerShell MSI from $powerShellMsiUrl"
    Invoke-WebRequest -Uri $powerShellMsiUrl -OutFile $installerPath
    Write-PostDeployLog "Downloaded PowerShell MSI to $installerPath"

    Invoke-NativeCommand -FilePath 'msiexec.exe' -ArgumentList @(
        '/i',
        $installerPath,
        '/qn',
        '/norestart',
        '/l*v',
        $installerLogPath
    ) -Description 'Installing PowerShell 7.6.0'

    if (-not (Test-Path -LiteralPath "$env:ProgramFiles\PowerShell\7\pwsh.exe")) {
        throw 'PowerShell 7 installation completed without producing pwsh.exe.'
    }

    Write-PostDeployLog 'PowerShell 7.6.0 installed successfully.'
}
catch {
    Write-PostDeployLog "ERROR: $($_.Exception.Message)"
    throw
}
