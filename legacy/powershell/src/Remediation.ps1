#Requires -Version 5.1
<#
.SYNOPSIS
    Policy-gated remediation actions for NV-Failsafe Recovery.
#>

Set-StrictMode -Version Latest

. "$PSScriptRoot\Utilities.ps1"
. "$PSScriptRoot\Evidence.ps1"
. "$PSScriptRoot\Policy.ps1"
. "$PSScriptRoot\Audit.ps1"

function Invoke-SafeDisplayRefresh {
    [CmdletBinding()]
    param(
        [bool]$Apply = $false,
        [string]$AuditPath = '.\nv-failsafe-audit.jsonl',
        [string]$Mode = 'Fix',
        [string]$Classification = ''
    )

    $result = [ordered]@{
        action   = 'DISPLAY_REFRESH_HINT'
        mode     = if ($Apply) { 'apply' } else { 'preview' }
        messages = @(
            'Recommended manual step: press Win+Ctrl+Shift+B to reset the graphics subsystem.',
            'This is a low-risk user action and does not require administrator privileges.'
        )
        explorerRestarted = $false
        exitCode = 0
    }

    Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_preview' -Mode $Mode -Classification $Classification -Action 'DISPLAY_REFRESH_HINT' -Result 'preview' -PolicyDecision @{ allowed = $true }

    if ($Apply) {
        $explorerDecision = Get-RemediationPolicyDecision -Action 'EXPLORER_RESTART' -Apply:$true -FixLevel 'safe'
        if ($explorerDecision.allowed) {
            try {
                Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_start' -Mode $Mode -Classification $Classification -Action 'EXPLORER_RESTART' -PolicyDecision $explorerDecision
                Get-Process -Name explorer -ErrorAction Stop | Stop-Process -Force
                Start-Process explorer.exe
                $result.explorerRestarted = $true
                $result.messages += 'Explorer was restarted as part of safe display refresh.'
                Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_complete' -Mode $Mode -Classification $Classification -Action 'EXPLORER_RESTART' -Result 'success'
            }
            catch {
                $result.exitCode = 1
                $result.messages += "Explorer restart failed: $($_.Exception.Message)"
                Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_error' -Mode $Mode -Classification $Classification -Action 'EXPLORER_RESTART' -Result 'error' -Error $_.Exception.Message
            }
        }
        else {
            $result.messages += 'Explorer restart blocked by policy; manual Win+Ctrl+Shift+B remains recommended.'
        }
    }

    return [PSCustomObject]$result
}

function Invoke-PnpRescan {
    [CmdletBinding()]
    param(
        [bool]$Apply = $false,
        [bool]$Force = $false,
        [string]$AuditPath = '.\nv-failsafe-audit.jsonl',
        [string]$Mode = 'Fix',
        [string]$Classification = '',
        [ValidateSet('none', 'safe', 'monitor', 'adapter')]
        [string]$FixLevel = 'monitor'
    )

    $decision = Get-RemediationPolicyDecision -Action 'PNP_RESCAN' -Apply:$Apply -Force:$Force -FixLevel $FixLevel
    if (-not $decision.allowed) {
        Write-AuditEvent -AuditPath $AuditPath -EventType 'policy_blocked' -Mode $Mode -Classification $Classification -Action 'PNP_RESCAN' -PolicyDecision $decision -Result 'blocked'
        return [PSCustomObject]@{
            action   = 'PNP_RESCAN'
            mode     = 'blocked'
            allowed  = $false
            reason   = $decision.reason
            exitCode = 0
            stdout   = ''
            stderr   = ''
        }
    }

    if (-not $Apply) {
        Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_preview' -Mode $Mode -Classification $Classification -Action 'PNP_RESCAN' -PolicyDecision $decision -Result 'preview'
        return [PSCustomObject]@{
            action   = 'PNP_RESCAN'
            mode     = 'preview'
            allowed  = $true
            reason   = 'Would execute: pnputil /scan-devices'
            exitCode = 0
            stdout   = ''
            stderr   = ''
        }
    }

    Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_start' -Mode $Mode -Classification $Classification -Action 'PNP_RESCAN' -PolicyDecision $decision

    $stdout = ''
    $stderr = ''
    $exitCode = 0
    try {
        $output = & pnputil.exe /scan-devices 2>&1
        $exitCode = $LASTEXITCODE
        $stdout = ($output | Out-String).Trim()
    }
    catch {
        $exitCode = 1
        $stderr = $_.Exception.Message
    }

    $resultStatus = if ($exitCode -eq 0) { 'success' } else { 'error' }
    Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_complete' -Mode $Mode -Classification $Classification -Action 'PNP_RESCAN' -Result $resultStatus -Error $stderr

    return [PSCustomObject]@{
        action   = 'PNP_RESCAN'
        mode     = 'apply'
        allowed  = $true
        reason   = $decision.reason
        exitCode = $exitCode
        stdout   = $stdout
        stderr   = $stderr
    }
}

function Invoke-MonitorRefresh {
    [CmdletBinding()]
    param(
        [bool]$Apply = $false,
        [bool]$Force = $false,
        [string]$AuditPath = '.\nv-failsafe-audit.jsonl',
        [string]$Mode = 'Fix',
        [string]$Classification = '',
        [ValidateSet('none', 'safe', 'monitor', 'adapter')]
        [string]$FixLevel = 'monitor'
    )

    $decision = Get-RemediationPolicyDecision -Action 'MONITOR_REFRESH' -Apply:$Apply -Force:$Force -FixLevel $FixLevel
    if (-not $decision.allowed) {
        Write-AuditEvent -AuditPath $AuditPath -EventType 'policy_blocked' -Mode $Mode -Classification $Classification -Action 'MONITOR_REFRESH' -PolicyDecision $decision -Result 'blocked'
        return [PSCustomObject]@{
            action        = 'MONITOR_REFRESH'
            mode          = 'blocked'
            allowed       = $false
            reason        = $decision.reason
            refreshedCount = 0
        }
    }

    if (-not $Apply) {
        Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_preview' -Mode $Mode -Classification $Classification -Action 'MONITOR_REFRESH' -PolicyDecision $decision -Result 'preview'
        return [PSCustomObject]@{
            action         = 'MONITOR_REFRESH'
            mode           = 'preview'
            allowed        = $true
            reason         = 'Would refresh monitor/display PnP entities without disabling GPU.'
            refreshedCount = 0
        }
    }

    Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_start' -Mode $Mode -Classification $Classification -Action 'MONITOR_REFRESH' -PolicyDecision $decision

    $refreshed = 0
    $errors = [System.Collections.Generic.List[string]]::new()

    try {
        if (Get-Command -Name Get-PnpDevice -ErrorAction SilentlyContinue) {
            $targets = Get-PnpDevice -Class 'Monitor' -ErrorAction SilentlyContinue |
                Where-Object { $_.InstanceId -and $_.Class -eq 'Monitor' }

            foreach ($device in $targets) {
                try {
                    Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
                    Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
                    $refreshed++
                }
                catch {
                    $errors.Add("Failed to refresh $($device.InstanceId): $($_.Exception.Message)")
                }
            }
        }
        else {
            $errors.Add('Get-PnpDevice unavailable; monitor refresh skipped.')
        }
    }
    catch {
        $errors.Add($_.Exception.Message)
    }

    $resultStatus = if ($errors.Count -eq 0) { 'success' } else { 'error' }
    Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_complete' -Mode $Mode -Classification $Classification -Action 'MONITOR_REFRESH' -Result $resultStatus -Error ($errors -join '; ')

    return [PSCustomObject]@{
        action         = 'MONITOR_REFRESH'
        mode           = 'apply'
        allowed        = $true
        reason         = $decision.reason
        refreshedCount = $refreshed
        errors         = $errors.ToArray()
    }
}

function Invoke-NvidiaAdapterRestart {
    [CmdletBinding()]
    param(
        [bool]$Apply = $false,
        [bool]$Force = $false,
        [string]$AuditPath = '.\nv-failsafe-audit.jsonl',
        [string]$Mode = 'Fix',
        [string]$Classification = '',
        [ValidateSet('none', 'safe', 'monitor', 'adapter')]
        [string]$FixLevel = 'adapter'
    )

    $decision = Get-RemediationPolicyDecision -Action 'ADAPTER_RESTART' -Apply:$Apply -Force:$Force -FixLevel $FixLevel
    if (-not $decision.allowed) {
        Write-AuditEvent -AuditPath $AuditPath -EventType 'policy_blocked' -Mode $Mode -Classification $Classification -Action 'ADAPTER_RESTART' -PolicyDecision $decision -Result 'blocked'
        return [PSCustomObject]@{
            action       = 'ADAPTER_RESTART'
            mode         = 'blocked'
            allowed      = $false
            reason       = $decision.reason
            warning      = 'High-risk operation blocked. May cause temporary loss of display output.'
            adapters     = @()
            restartedCount = 0
        }
    }

    $nvidiaAdapters = @()
    if (Get-Command -Name Get-PnpDevice -ErrorAction SilentlyContinue) {
        $nvidiaAdapters = Get-PnpDevice -Class 'Display' -ErrorAction SilentlyContinue |
            Where-Object { $_.InstanceId -match 'VEN_10DE' -or $_.FriendlyName -match 'NVIDIA' }
    }

    if (-not $Apply) {
        Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_preview' -Mode $Mode -Classification $Classification -Action 'ADAPTER_RESTART' -PolicyDecision $decision -Result 'preview'
        return [PSCustomObject]@{
            action         = 'ADAPTER_RESTART'
            mode           = 'preview'
            allowed        = $true
            reason         = 'Would disable/enable NVIDIA display adapters only. HIGH RISK: may blank display briefly.'
            warning        = 'Requires -Apply and -Force by design.'
            adapters       = @($nvidiaAdapters | ForEach-Object { $_.InstanceId })
            restartedCount = 0
        }
    }

    Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_start' -Mode $Mode -Classification $Classification -Action 'ADAPTER_RESTART' -PolicyDecision $decision -Result 'warning'

    $restarted = 0
    $errors = [System.Collections.Generic.List[string]]::new()
    foreach ($adapter in $nvidiaAdapters) {
        try {
            Disable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false -ErrorAction Stop
            Start-Sleep -Seconds 2
            Enable-PnpDevice -InstanceId $adapter.InstanceId -Confirm:$false -ErrorAction Stop
            $restarted++
        }
        catch {
            $errors.Add("Adapter restart failed for $($adapter.InstanceId): $($_.Exception.Message)")
        }
    }

    $resultStatus = if ($errors.Count -eq 0 -and $restarted -gt 0) { 'success' } elseif ($restarted -gt 0) { 'partial' } else { 'error' }
    Write-AuditEvent -AuditPath $AuditPath -EventType 'remediation_complete' -Mode $Mode -Classification $Classification -Action 'ADAPTER_RESTART' -Result $resultStatus -Error ($errors -join '; ')

    return [PSCustomObject]@{
        action         = 'ADAPTER_RESTART'
        mode           = 'apply'
        allowed        = $true
        reason         = $decision.reason
        warning        = 'NVIDIA adapter restart completed; verify display output immediately.'
        adapters       = @($nvidiaAdapters | ForEach-Object { $_.InstanceId })
        restartedCount = $restarted
        errors         = $errors.ToArray()
    }
}

function Invoke-RemediationPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [bool]$Apply = $false,
        [bool]$Force = $false,
        [string]$AuditPath = '.\nv-failsafe-audit.jsonl',
        [string]$Mode = 'Fix',
        [string]$Classification = '',
        [ValidateSet('none', 'safe', 'monitor', 'adapter')]
        [string]$FixLevel = 'none'
    )

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($item in $Plan) {
        switch ($item.action) {
            'DISPLAY_REFRESH_HINT' {
                $results.Add((Invoke-SafeDisplayRefresh -Apply:$Apply -AuditPath $AuditPath -Mode $Mode -Classification $Classification))
            }
            'EXPLORER_RESTART' {
                if ($item.allowed -and $Apply) {
                    $results.Add((Invoke-SafeDisplayRefresh -Apply:$true -AuditPath $AuditPath -Mode $Mode -Classification $Classification))
                }
            }
            'PNP_RESCAN' {
                $results.Add((Invoke-PnpRescan -Apply:$Apply -Force:$Force -AuditPath $AuditPath -Mode $Mode -Classification $Classification -FixLevel $FixLevel))
            }
            'MONITOR_REFRESH' {
                $results.Add((Invoke-MonitorRefresh -Apply:$Apply -Force:$Force -AuditPath $AuditPath -Mode $Mode -Classification $Classification -FixLevel $FixLevel))
            }
            'ADAPTER_RESTART' {
                $results.Add((Invoke-NvidiaAdapterRestart -Apply:$Apply -Force:$Force -AuditPath $AuditPath -Mode $Mode -Classification $Classification -FixLevel $FixLevel))
            }
            'DRIVER_REINSTALL_GUIDANCE' {
                $results.Add([PSCustomObject]@{
                    action   = 'DRIVER_REINSTALL_GUIDANCE'
                    mode     = 'guidance'
                    messages = @(
                        'Recommended next step: perform a clean NVIDIA driver reinstall from NVIDIA official packages.',
                        'This toolkit does not uninstall or reinstall drivers automatically.'
                    )
                })
            }
            'DDU_LAST_RESORT_GUIDANCE' {
                $results.Add([PSCustomObject]@{
                    action   = 'DDU_LAST_RESORT_GUIDANCE'
                    mode     = 'guidance'
                    messages = @(
                        'DDU is a last-resort manual procedure only.',
                        'This toolkit never runs DDU or destructive driver removal.'
                    )
                })
            }
            default {
                $unhandled = $item.action
                throw "Unhandled remediation action: $unhandled"
            }
        }
    }

    return $results.ToArray()
}
