<#
.SYNOPSIS
    Validates repository version pins against the central runtime policy.

.DESCRIPTION
    Reports drift between eng/runtime-policy.json and files that intentionally
    pin the development runtime, CI runner, and baseline PowerShell tooling.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$PolicyPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\eng\runtime-policy.json')
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath '..')).Path
$resolvedPolicyPath = (Resolve-Path -LiteralPath $PolicyPath).Path
$policy = Get-Content -Raw -LiteralPath $resolvedPolicyPath | ConvertFrom-Json
$failures = [System.Collections.Generic.List[object]]::new()

function Add-PolicyFailure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Expected,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Reason,

        [Parameter()]
        [string]$Actual
    )

    $failure = [pscustomobject]@{
        Path = $RelativePath
        Description = $Description
        Expected = $Expected
        Actual = $Actual
        Reason = $Reason
    }

    $failures.Add($failure)
}

function Get-RepoFileContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Expected
    )

    $path = Join-Path -Path $repoRoot -ChildPath $RelativePath

    if (-not (Test-Path -LiteralPath $path)) {
        Add-PolicyFailure -RelativePath $RelativePath -Description $Description -Expected $Expected -Reason 'File not found'
        return
    }

    return Get-Content -Raw -LiteralPath $path
}

function Test-PolicyText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExpectedText,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description
    )

    $content = Get-RepoFileContent -RelativePath $RelativePath -Description $Description -Expected $ExpectedText
    if ($null -eq $content) {
        return
    }

    if (-not $content.Contains($ExpectedText)) {
        Add-PolicyFailure -RelativePath $RelativePath -Description $Description -Expected $ExpectedText -Reason 'Expected text not found'
    }
}

function Test-PolicyRegexValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExpectedValue,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Description
    )

    $content = Get-RepoFileContent -RelativePath $RelativePath -Description $Description -Expected $ExpectedValue
    if ($null -eq $content) {
        return
    }

    $match = [regex]::Match($content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        Add-PolicyFailure -RelativePath $RelativePath -Description $Description -Expected $ExpectedValue -Reason 'Pattern not found'
        return
    }

    $actualValue = $match.Groups['Value'].Value
    if ($actualValue -ne $ExpectedValue) {
        Add-PolicyFailure -RelativePath $RelativePath -Description $Description -Expected $ExpectedValue -Actual $actualValue -Reason 'Value mismatch'
    }
}

Test-PolicyRegexValue -RelativePath '.github/workflows/ci.yml' -Pattern '^\s*runs-on:\s+(?<Value>\S+)\s*$' -ExpectedValue $policy.githubActions.runnerImage -Description 'CI workflow runner image'
Test-PolicyRegexValue -RelativePath '.github/workflows/ci.yml' -Pattern '^\s*Install-Module\s+-Name\s+Pester\s+.*?-RequiredVersion\s+(?<Value>\S+)\s+.*$' -ExpectedValue $policy.tooling.pesterVersion -Description 'CI workflow Pester version'
Test-PolicyRegexValue -RelativePath '.github/workflows/ci.yml' -Pattern '^\s*Install-Module\s+-Name\s+PSScriptAnalyzer\s+.*?-RequiredVersion\s+(?<Value>\S+)\s+.*$' -ExpectedValue $policy.tooling.psScriptAnalyzerVersion -Description 'PSScriptAnalyzer workflow version'

Test-PolicyText -RelativePath 'README.md' -ExpectedText ('PowerShell {0}' -f $policy.runtime.powershellVersion) -Description 'README PowerShell version'
Test-PolicyText -RelativePath 'README.md' -ExpectedText $policy.runtime.developmentHost -Description 'README development host'
Test-PolicyText -RelativePath 'templates/downstream/README.md' -ExpectedText ('PowerShell {0}' -f $policy.runtime.powershellVersion) -Description 'Downstream README skeleton PowerShell version'
Test-PolicyText -RelativePath 'templates/downstream/README.md' -ExpectedText $policy.runtime.developmentHost -Description 'Downstream README skeleton development host'
Test-PolicyText -RelativePath '.github/Instructions/environment-setup.md' -ExpectedText ('PowerShell {0}' -f $policy.runtime.powershellVersion) -Description 'Environment setup PowerShell version'
Test-PolicyText -RelativePath '.github/Instructions/environment-setup.md' -ExpectedText $policy.runtime.developmentHost -Description 'Environment setup development host'
Test-PolicyText -RelativePath '.github/copilot-instructions.md' -ExpectedText ('PowerShell {0}' -f $policy.runtime.powershellVersionLabel) -Description 'Copilot instruction PowerShell compatibility target'

if ($failures.Count -gt 0) {
    $failures | Format-Table -AutoSize | Out-String | Write-Output
    throw ('Version policy drift detected in {0} location(s).' -f $failures.Count)
}

Write-Verbose ('Version policy validated: {0}' -f $resolvedPolicyPath)
