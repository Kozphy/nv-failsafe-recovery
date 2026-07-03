#Requires -Version 5.1
<#
.SYNOPSIS
    Installs logon scheduled task for Report-only NV-Failsafe monitoring.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TaskName = 'NvFailsafeRecovery-ReportOnLogon',
    [string]$ScriptPath = '',
    [string]$OutputDirectory = "$env:LOCALAPPDATA\NvFailsafeRecovery"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
    $ScriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\NvFailsafeRecovery.ps1'
}

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Main script not found: $ScriptPath"
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$outputPath = Join-Path $OutputDirectory 'nv-failsafe-report.json'
$auditPath = Join-Path $OutputDirectory 'nv-failsafe-audit.jsonl'

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -Mode Report -OutputPath `"$outputPath`" -AuditPath `"$auditPath`" -Quiet"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

if ($PSCmdlet.ShouldProcess($TaskName, 'Register scheduled task')) {
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Write-Output "Scheduled task '$TaskName' installed."
    Write-Output "Report output: $outputPath"
    Write-Output 'This task runs Report mode only and never runs Fix automatically.'
}
