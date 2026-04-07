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
        BuildRoot           = Join-Path $ProjectRoot "Build"
        IsoRoot             = Join-Path $ProjectRoot "Build\ISO"
        WimRoot             = Join-Path $ProjectRoot "Build\WIM"
        LogRoot             = Join-Path $ProjectRoot "Build\Logs"
        MountRoot           = Join-Path $ProjectRoot "Build\Mount"
        CaptureMountRoot    = Join-Path $ProjectRoot "Build\Mount\Capture"
        DeployMountRoot     = Join-Path $ProjectRoot "Build\Mount\Deploy"
        WimMountRoot        = Join-Path $ProjectRoot "Build\Mount\WIM"
        WinPERoot           = Join-Path $ProjectRoot "Build\WinPE"
        CaptureWorkRoot     = Join-Path $ProjectRoot "Build\WinPE\Capture"
        DeployWorkRoot      = Join-Path $ProjectRoot "Build\WinPE\Deploy"
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

function Initialize-UnattendWorkingCopy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Context
    )

    $templatePath = Join-Path $Context.Paths.PayloadTemplateRoot "Unattend.Template.xml"
    $workingPath = Join-Path $Context.Paths.PayloadTemplateRoot "Unattend.xml"

    if (-not (Test-Path -LiteralPath $templatePath)) {
        throw "Unattend template not found at '$templatePath'."
    }

    if (-not (Test-Path -LiteralPath $workingPath)) {
        Copy-Item -LiteralPath $templatePath -Destination $workingPath -Force
        Write-WorkspaceLog "Created local unattend working file from template: $workingPath" -Level SUCCESS
        Write-WorkspaceLog "Review and update $workingPath locally with Windows System Image Manager before building deployment media." -Level WARNING
    }
    else {
        Write-WorkspaceLog "Local unattend working file already exists: $workingPath" -Level INFO
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

function Get-WinPEOptionalComponentPath {
    [CmdletBinding()]
    param()

    $kitsRoot = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Windows Kits\10"
    $candidates = @(
        (Join-Path -Path $kitsRoot -ChildPath "Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"),
        (Join-Path -Path $kitsRoot -ChildPath "Assessment and Deployment Kit\Windows Preinstallation Environment\x86\WinPE_OCs")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "WinPE optional components path not found under '$kitsRoot'. Ensure the Windows ADK WinPE add-on is installed."
}

function Enable-WinPEPowerShellSupport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountPath,

        [Parameter()]
        [string]$Culture = "en-us"
    )

    $ocRoot = Get-WinPEOptionalComponentPath
    $packages = @(
        "WinPE-WMI",
        "WinPE-NetFX",
        "WinPE-Scripting",
        "WinPE-PowerShell",
        "WinPE-StorageWMI",
        "WinPE-DismCmdlets"
    )

    foreach ($package in $packages) {
        $packagePath = Join-Path $ocRoot "$package.cab"
        $languagePackagePath = Join-Path $ocRoot "$Culture\$package`_$Culture.cab"

        if (-not (Test-Path -LiteralPath $packagePath)) {
            throw "Required WinPE package not found: $packagePath"
        }

        if (-not (Test-Path -LiteralPath $languagePackagePath)) {
            throw "Required WinPE language package not found: $languagePackagePath"
        }

        Add-WindowsPackage -Path $MountPath -PackagePath $packagePath | Out-Null
        Add-WindowsPackage -Path $MountPath -PackagePath $languagePackagePath | Out-Null
        Write-WorkspaceLog "Added WinPE package: $package" -Level SUCCESS
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
