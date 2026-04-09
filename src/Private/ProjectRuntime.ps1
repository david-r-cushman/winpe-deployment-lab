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

    try {
        $config = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to read or parse project configuration at '$configPath'. $($_.Exception.Message)"
    }
    $requiredProperties = @(
        'BootISOName',
        'WIMName',
        'DeployISOName',
        'ImageDescription',
        'CaptureLocation'
    )

    foreach ($property in $requiredProperties) {
        if ([string]::IsNullOrWhiteSpace($config.$property)) {
            throw "Project configuration is missing required value '$property'."
        }
    }

    $paths = [pscustomobject]@{
        BuildRoot           = Join-Path $ProjectRoot 'Build'
        IsoRoot             = Join-Path $ProjectRoot 'Build\ISO'
        WimRoot             = Join-Path $ProjectRoot 'Build\WIM'
        LogRoot             = Join-Path $ProjectRoot 'Build\Logs'
        MountRoot           = Join-Path $ProjectRoot 'Build\Mount'
        CaptureMountRoot    = Join-Path $ProjectRoot 'Build\Mount\Capture'
        DeployMountRoot     = Join-Path $ProjectRoot 'Build\Mount\Deploy'
        WimMountRoot        = Join-Path $ProjectRoot 'Build\Mount\WIM'
        WinPERoot           = Join-Path $ProjectRoot 'Build\WinPE'
        CaptureWorkRoot     = Join-Path $ProjectRoot 'Build\WinPE\Capture'
        DeployWorkRoot      = Join-Path $ProjectRoot 'Build\WinPE\Deploy'
        PayloadTemplateRoot = Join-Path $ProjectRoot 'PayloadTemplates'
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
            try {
                New-Item -Path $path -ItemType Directory -Force -ErrorAction Stop | Out-Null
            }
            catch {
                throw "Failed to create required project directory at '$path'. $($_.Exception.Message)"
            }
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

    $templatePath = Join-Path $Context.Paths.PayloadTemplateRoot 'Unattend.Template.xml'
    $workingPath = Join-Path $Context.Paths.PayloadTemplateRoot 'Unattend.xml'

    if (-not (Test-Path -LiteralPath $templatePath)) {
        throw "Unattend template not found at '$templatePath'."
    }

    if (-not (Test-Path -LiteralPath $workingPath)) {
        try {
            Copy-Item -LiteralPath $templatePath -Destination $workingPath -Force -ErrorAction Stop
        }
        catch {
            throw "Failed to create local unattend working file from template '$templatePath' to '$workingPath'. $($_.Exception.Message)"
        }
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
        throw 'This script must be run as Administrator.'
    }
}

function Assert-AdkEnvironment {
    [CmdletBinding()]
    param()

    if (-not (Get-Command 'copype.cmd' -ErrorAction SilentlyContinue)) {
        throw 'copype.cmd not found. Run from the Deployment and Imaging Tools Environment shell provided by the Windows ADK.'
    }
}

function Get-WinPEOptionalComponentPath {
    [CmdletBinding()]
    param()

    $kitsRoot = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Windows Kits\10'
    $optionalComponentsPath = Join-Path -Path $kitsRoot -ChildPath 'Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs'

    if (Test-Path -LiteralPath $optionalComponentsPath) {
        return $optionalComponentsPath
    }

    throw "WinPE optional components path not found for architecture 'amd64' at '$optionalComponentsPath'. Ensure the Windows ADK WinPE add-on is installed for the required architecture."
}

function Enable-WinPEPowerShellSupport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$MountPath,

        [Parameter()]
        [string]$Culture = 'en-us'
    )

    $ocRoot = Get-WinPEOptionalComponentPath
    $packages = @(
        'WinPE-WMI',
        'WinPE-NetFX',
        'WinPE-Scripting',
        'WinPE-PowerShell',
        'WinPE-StorageWMI',
        'WinPE-DismCmdlets'
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

        try {
            Add-WindowsPackage -Path $MountPath -PackagePath $packagePath -ErrorAction Stop | Out-Null
            Add-WindowsPackage -Path $MountPath -PackagePath $languagePackagePath -ErrorAction Stop | Out-Null
        }
        catch {
            throw "Failed to add WinPE package '$package' for mount path '$MountPath'. Package path: '$packagePath'. Language package path: '$languagePackagePath'. $($_.Exception.Message)"
        }
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
        try {
            Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        }
        catch {
            throw "Failed to remove item at '$Path'. $($_.Exception.Message)"
        }
    }
}

function Prepare-MountDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    $existingItems = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)
    if ($existingItems.Count -gt 0) {
        try {
            foreach ($item in $existingItems) {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
            }
        }
        catch {
            throw "Failed to prepare mount directory '$Path'. The directory must exist and be empty before mounting. $($_.Exception.Message)"
        }
    }
}

function Invoke-ExternalTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $resolvedCommand = (Get-Command -Name $FilePath -ErrorAction Stop).Source
    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()

    try {
        $process = if ([System.IO.Path]::GetExtension($resolvedCommand) -in @('.cmd', '.bat')) {
            $quotedCommand = '"{0}"' -f $resolvedCommand
            $quotedArguments = foreach ($argument in $ArgumentList) {
                if ($argument -match '[\s"]') {
                    '"{0}"' -f ($argument -replace '"', '""')
                }
                else {
                    $argument
                }
            }

            Start-Process -FilePath $env:ComSpec `
                -ArgumentList @('/c', "$quotedCommand $($quotedArguments -join ' ')") `
                -Wait -PassThru -NoNewWindow `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath
        }
        else {
            Start-Process -FilePath $resolvedCommand `
                -ArgumentList $ArgumentList `
                -Wait -PassThru -NoNewWindow `
                -RedirectStandardOutput $stdoutPath `
                -RedirectStandardError $stderrPath
        }

        $output = @()
        if (Test-Path -LiteralPath $stdoutPath) {
            $output += Get-Content -LiteralPath $stdoutPath
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $output += Get-Content -LiteralPath $stderrPath
        }

        if ($process.ExitCode -ne 0) {
            $outputText = ($output | Out-String).Trim()
            if ([string]::IsNullOrWhiteSpace($outputText)) {
                throw "$Description failed with exit code $($process.ExitCode)."
            }

            throw "$Description failed with exit code $($process.ExitCode). Output: $outputText"
        }

        return $output
    }
    finally {
        if (Test-Path -LiteralPath $stdoutPath) {
            Remove-Item -LiteralPath $stdoutPath -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $stderrPath) {
            Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
        }
    }
}
