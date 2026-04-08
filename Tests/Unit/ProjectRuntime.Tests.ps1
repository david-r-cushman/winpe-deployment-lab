Describe 'Get-WinPEProjectContext' {
    BeforeAll {
        $projectRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent

        function Write-WorkspaceLog {
            param(
                [Parameter(Mandatory)]
                [string]$Message,

                [Parameter()]
                [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
                [string]$Level = 'INFO'
            )
        }

        . (Join-Path $projectRoot 'src\Private\ProjectRuntime.ps1')
    }

    It 'returns config values and derived repo-local paths for a valid project root' {
        $root = Join-Path $TestDrive 'Project'
        $configRoot = Join-Path $root 'config'
        $payloadRoot = Join-Path $root 'PayloadTemplates'

        New-Item -Path $configRoot -ItemType Directory -Force | Out-Null
        New-Item -Path $payloadRoot -ItemType Directory -Force | Out-Null

        @'
{
  "BootISOName": "WinPE-Capture.iso",
  "WIMName": "Reference.wim",
  "DeployISOName": "WinPE-Deploy.iso",
  "ImageDescription": "Reference image",
  "CaptureLocation": "C:\\CapturedImages"
}
'@ | Set-Content -Path (Join-Path $configRoot 'osd-config.json')

        $context = Get-WinPEProjectContext -ProjectRoot $root

        $context.Config.BootISOName | Should -Be 'WinPE-Capture.iso'
        $context.Paths.BuildRoot | Should -Be (Join-Path $root 'Build')
        $context.Paths.IsoRoot | Should -Be (Join-Path $root 'Build\ISO')
        $context.Paths.PayloadTemplateRoot | Should -Be (Join-Path $root 'PayloadTemplates')
    }

    It 'throws when the config file is missing' {
        $root = Join-Path $TestDrive 'MissingConfig'
        New-Item -Path $root -ItemType Directory -Force | Out-Null

        { Get-WinPEProjectContext -ProjectRoot $root } | Should -Throw '*Project configuration file not found*'
    }

    It 'throws when a required config value is blank' {
        $root = Join-Path $TestDrive 'BlankConfigValue'
        $configRoot = Join-Path $root 'config'

        New-Item -Path $configRoot -ItemType Directory -Force | Out-Null

        @'
{
  "BootISOName": "",
  "WIMName": "Reference.wim",
  "DeployISOName": "WinPE-Deploy.iso",
  "ImageDescription": "Reference image",
  "CaptureLocation": "C:\\CapturedImages"
}
'@ | Set-Content -Path (Join-Path $configRoot 'osd-config.json')

        { Get-WinPEProjectContext -ProjectRoot $root } | Should -Throw "*Project configuration is missing required value 'BootISOName'.*"
    }
}

Describe 'Initialize-WinPEProjectRuntime' {
    BeforeAll {
        $projectRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent

        function Write-WorkspaceLog {
            param(
                [Parameter(Mandatory)]
                [string]$Message,

                [Parameter()]
                [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
                [string]$Level = 'INFO'
            )
        }

        . (Join-Path $projectRoot 'src\Private\ProjectRuntime.ps1')
    }

    It 'creates the expected repo-local runtime folders' {
        $root = Join-Path $TestDrive 'RuntimeProject'
        $configRoot = Join-Path $root 'config'
        $payloadRoot = Join-Path $root 'PayloadTemplates'

        New-Item -Path $configRoot -ItemType Directory -Force | Out-Null
        New-Item -Path $payloadRoot -ItemType Directory -Force | Out-Null

        @'
{
  "BootISOName": "WinPE-Capture.iso",
  "WIMName": "Reference.wim",
  "DeployISOName": "WinPE-Deploy.iso",
  "ImageDescription": "Reference image",
  "CaptureLocation": "C:\\CapturedImages"
}
'@ | Set-Content -Path (Join-Path $configRoot 'osd-config.json')

        $context = Get-WinPEProjectContext -ProjectRoot $root

        Initialize-WinPEProjectRuntime -Context $context

        $context.Paths.BuildRoot | Should -Exist
        $context.Paths.IsoRoot | Should -Exist
        $context.Paths.WimRoot | Should -Exist
        $context.Paths.LogRoot | Should -Exist
        $context.Paths.CaptureMountRoot | Should -Exist
        $context.Paths.DeployMountRoot | Should -Exist
        $context.Paths.WimMountRoot | Should -Exist
        $context.Paths.WinPERoot | Should -Exist
    }

    It 'throws when PayloadTemplates is missing' {
        $context = [pscustomobject]@{
            Paths = [pscustomobject]@{
                BuildRoot           = Join-Path $TestDrive 'Build'
                IsoRoot             = Join-Path $TestDrive 'Build\ISO'
                WimRoot             = Join-Path $TestDrive 'Build\WIM'
                LogRoot             = Join-Path $TestDrive 'Build\Logs'
                MountRoot           = Join-Path $TestDrive 'Build\Mount'
                CaptureMountRoot    = Join-Path $TestDrive 'Build\Mount\Capture'
                DeployMountRoot     = Join-Path $TestDrive 'Build\Mount\Deploy'
                WimMountRoot        = Join-Path $TestDrive 'Build\Mount\WIM'
                WinPERoot           = Join-Path $TestDrive 'Build\WinPE'
                PayloadTemplateRoot = Join-Path $TestDrive 'PayloadTemplates'
            }
        }

        { Initialize-WinPEProjectRuntime -Context $context } | Should -Throw '*Payload template folder not found*'
    }
}

Describe 'Initialize-UnattendWorkingCopy' {
    BeforeAll {
        $projectRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent

        function Write-WorkspaceLog {
            param(
                [Parameter(Mandatory)]
                [string]$Message,

                [Parameter()]
                [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
                [string]$Level = 'INFO'
            )
        }

        . (Join-Path $projectRoot 'src\Private\ProjectRuntime.ps1')
    }

    It 'creates a local unattend working copy from the tracked template when missing' {
        $payloadRoot = Join-Path $TestDrive 'PayloadTemplates'
        New-Item -Path $payloadRoot -ItemType Directory -Force | Out-Null

        '<unattend />' | Set-Content -Path (Join-Path $payloadRoot 'Unattend.Template.xml')

        $context = [pscustomobject]@{
            Paths = [pscustomobject]@{
                PayloadTemplateRoot = $payloadRoot
            }
        }

        Initialize-UnattendWorkingCopy -Context $context

        $workingPath = Join-Path $payloadRoot 'Unattend.xml'
        $workingPath | Should -Exist
        (Get-Content -Path $workingPath -Raw) | Should -Be "<unattend />$([Environment]::NewLine)"
    }

    It 'does not overwrite an existing unattend working copy' {
        $payloadRoot = Join-Path $TestDrive 'PayloadTemplatesExisting'
        New-Item -Path $payloadRoot -ItemType Directory -Force | Out-Null

        '<template />' | Set-Content -Path (Join-Path $payloadRoot 'Unattend.Template.xml')
        '<working />' | Set-Content -Path (Join-Path $payloadRoot 'Unattend.xml')

        $context = [pscustomobject]@{
            Paths = [pscustomobject]@{
                PayloadTemplateRoot = $payloadRoot
            }
        }

        Initialize-UnattendWorkingCopy -Context $context

        (Get-Content -Path (Join-Path $payloadRoot 'Unattend.xml') -Raw) | Should -Be "<working />$([Environment]::NewLine)"
    }
}

Describe 'Enable-WinPEPowerShellSupport' {
    BeforeAll {
        $projectRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent

        function Write-WorkspaceLog {
            param(
                [Parameter(Mandatory)]
                [string]$Message,

                [Parameter()]
                [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
                [string]$Level = 'INFO'
            )
        }

        . (Join-Path $projectRoot 'src\Private\ProjectRuntime.ps1')
    }

    It 'adds the required WinPE packages and language packages in order' {
        Mock Get-WinPEOptionalComponentPath { 'C:\WinPE_OCs' }
        Mock Test-Path { $true }
        Mock Add-WindowsPackage {}
        Mock Write-WorkspaceLog {}

        Enable-WinPEPowerShellSupport -MountPath 'C:\Mount'

        Should -Invoke Add-WindowsPackage -Times 12
        Should -Invoke Write-WorkspaceLog -Times 6 -ParameterFilter { $Level -eq 'SUCCESS' }
    }

    It 'throws when a required package is missing' {
        Mock Get-WinPEOptionalComponentPath { 'C:\WinPE_OCs' }
        Mock Test-Path {
            param($LiteralPath)
            if ($LiteralPath -like '*WinPE-PowerShell.cab') { return $false }
            return $true
        }
        Mock Add-WindowsPackage {}
        Mock Write-WorkspaceLog {}

        { Enable-WinPEPowerShellSupport -MountPath 'C:\Mount' } | Should -Throw '*Required WinPE package not found*'
    }
}

Describe 'Remove-ItemIfPresent' {
    BeforeAll {
        $projectRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent

        function Write-WorkspaceLog {
            param(
                [Parameter(Mandatory)]
                [string]$Message,

                [Parameter()]
                [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
                [string]$Level = 'INFO'
            )
        }

        . (Join-Path $projectRoot 'src\Private\ProjectRuntime.ps1')
    }

    It 'removes a path when it exists and does nothing when it does not' {
        $path = Join-Path $TestDrive 'RemoveMe'
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        'content' | Set-Content -Path (Join-Path $path 'file.txt')

        Remove-ItemIfPresent -Path $path
        $path | Should -Not -Exist

        { Remove-ItemIfPresent -Path $path } | Should -Not -Throw
    }
}
