function Get-WinPEProjectContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $configPath = Join-Path $ProjectRoot "config\osd-config.json"
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Project configuration file not found at '$configPath'."
    }

    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $requiredProperties = @(
        "BootISOName",
        "WIMName",
        "DeployISOName",
        "ImageDescription",
        "CaptureLocation"
    )

    foreach ($property in $requiredProperties) {
        if ([string]::IsNullOrWhiteSpace($config.$property)) {
            throw "Project configuration is missing required value '$property'."
        }
    }

    $paths = [pscustomobject]@{
        BuildRoot          = Join-Path $ProjectRoot "Build"
        IsoRoot            = Join-Path $ProjectRoot "Build\ISO"
        WimRoot            = Join-Path $ProjectRoot "Build\WIM"
        LogRoot            = Join-Path $ProjectRoot "Build\Logs"
        MountRoot          = Join-Path $ProjectRoot "Build\Mount"
        CaptureMountRoot   = Join-Path $ProjectRoot "Build\Mount\Capture"
        DeployMountRoot    = Join-Path $ProjectRoot "Build\Mount\Deploy"
        WimMountRoot       = Join-Path $ProjectRoot "Build\Mount\WIM"
        WinPERoot          = Join-Path $ProjectRoot "Build\WinPE"
        CaptureWorkRoot    = Join-Path $ProjectRoot "Build\WinPE\Capture"
        DeployWorkRoot     = Join-Path $ProjectRoot "Build\WinPE\Deploy"
        PayloadTemplateRoot = Join-Path $ProjectRoot "PayloadTemplates"
    }

    [pscustomobject]@{
        ProjectRoot = $ProjectRoot
        ConfigPath  = $configPath
        Config      = $config
        Paths       = $paths
    }
}

function Initialize-WinPEProjectRuntime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Context
    )

    $requiredPaths = @(
        $Context.Paths.BuildRoot,
        $Context.Paths.IsoRoot,
        $Context.Paths.WimRoot,
        $Context.Paths.LogRoot,
        $Context.Paths.MountRoot,
        $Context.Paths.CaptureMountRoot,
        $Context.Paths.DeployMountRoot,
        $Context.Paths.WimMountRoot,
        $Context.Paths.WinPERoot
    )

    foreach ($path in $requiredPaths) {
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }

    if (-not (Test-Path -LiteralPath $Context.Paths.PayloadTemplateRoot)) {
        throw "Payload template folder not found at '$($Context.Paths.PayloadTemplateRoot)'."
    }
}

function Assert-AdministratorSession {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator."
    }
}

function Assert-AdkEnvironment {
    [CmdletBinding()]
    param()

    if (-not (Get-Command "copype.cmd" -ErrorAction SilentlyContinue)) {
        throw "copype.cmd not found. Run from the Deployment and Imaging Tools Environment shell provided by the Windows ADK."
    }
}

function Remove-ItemIfPresent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}
