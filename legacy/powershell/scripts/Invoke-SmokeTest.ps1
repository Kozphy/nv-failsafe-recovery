#Requires -Version 5.1
<#
.SYNOPSIS
    Lightweight smoke validation for NV-Failsafe Recovery toolkit.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$legacyRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $failures.Add($Message) }
}

$requiredFiles = @(
    'scripts\NvFailsafeRecovery.ps1',
    'src\Evidence.ps1',
    'src\Classifier.ps1',
    'src\Policy.ps1',
    'src\Remediation.ps1',
    'src\Reporting.ps1',
    'src\Audit.ps1',
    'src\Utilities.ps1'
)

foreach ($relative in $requiredFiles) {
    $path = Join-Path $legacyRoot $relative
    Assert-True -Condition (Test-Path -LiteralPath $path) -Message "Missing required file: $relative"
}

$ps1Files = Get-ChildItem -Path $legacyRoot -Recurse -Filter '*.ps1' | Where-Object { $_.FullName -notmatch '\\\.git\\' }
foreach ($file in $ps1Files) {
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        $failures.Add("Parse error in $($file.FullName): $($errors[0].Message)")
    }
}

$detectOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $legacyRoot 'scripts\NvFailsafeRecovery.ps1') -Mode Detect -Quiet 2>&1
$detectText = ($detectOutput | Out-String)
Assert-True -Condition ($LASTEXITCODE -eq 0) -Message 'Detect mode failed to execute.'
Assert-True -Condition ($detectText -notmatch 'Disable-PnpDevice|pnputil /scan-devices|Stop-Process -Name explorer') -Message 'Detect mode appears to execute remediation commands.'

if ($failures.Count -gt 0) {
    Write-Output 'SMOKE TEST FAILED'
    $failures | ForEach-Object { Write-Output " - $_" }
    exit 1
}

Write-Output 'SMOKE TEST PASSED'
exit 0
