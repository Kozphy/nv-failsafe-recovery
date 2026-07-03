#Requires -Version 5.1
<#
.SYNOPSIS
    Removes NV-Failsafe Recovery logon scheduled task.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TaskName = 'NvFailsafeRecovery-ReportOnLogon'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Output "Scheduled task '$TaskName' is not installed."
    return
}

if ($PSCmdlet.ShouldProcess($TaskName, 'Unregister scheduled task')) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Output "Scheduled task '$TaskName' removed."
}
