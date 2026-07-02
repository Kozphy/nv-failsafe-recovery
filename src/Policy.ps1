#Requires -Version 5.1
<#
.SYNOPSIS
    Policy gates for remediation actions.
#>

Set-StrictMode -Version Latest

. "$PSScriptRoot\Utilities.ps1"
. "$PSScriptRoot\Evidence.ps1"

$script:ActionCatalog = [ordered]@{
    DISPLAY_REFRESH_HINT      = @{
        riskLevel    = 'low'
        requiresAdmin = $false
        requiresApply = $false
        requiresForce = $false
        fixLevels     = @('safe', 'monitor', 'adapter')
    }
    EXPLORER_RESTART          = @{
        riskLevel    = 'low'
        requiresAdmin = $false
        requiresApply = $true
        requiresForce = $false
        fixLevels     = @('safe', 'monitor', 'adapter')
    }
    PNP_RESCAN                = @{
        riskLevel    = 'medium'
        requiresAdmin = $true
        requiresApply = $true
        requiresForce = $false
        fixLevels     = @('monitor', 'adapter')
    }
    MONITOR_REFRESH           = @{
        riskLevel    = 'medium'
        requiresAdmin = $true
        requiresApply = $true
        requiresForce = $false
        fixLevels     = @('monitor', 'adapter')
    }
    ADAPTER_RESTART           = @{
        riskLevel    = 'high'
        requiresAdmin = $true
        requiresApply = $true
        requiresForce = $true
        fixLevels     = @('adapter')
    }
    DRIVER_REINSTALL_GUIDANCE = @{
        riskLevel    = 'guidance'
        requiresAdmin = $false
        requiresApply = $false
        requiresForce = $false
        fixLevels     = @('safe', 'monitor', 'adapter')
    }
    DDU_LAST_RESORT_GUIDANCE  = @{
        riskLevel    = 'guidance'
        requiresAdmin = $false
        requiresApply = $false
        requiresForce = $false
        fixLevels     = @('safe', 'monitor', 'adapter')
    }
}

function Get-ActionCatalog {
    [CmdletBinding()]
    param()
    return $script:ActionCatalog
}

function Test-ActionAllowed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DISPLAY_REFRESH_HINT', 'EXPLORER_RESTART', 'PNP_RESCAN', 'MONITOR_REFRESH', 'ADAPTER_RESTART', 'DRIVER_REINSTALL_GUIDANCE', 'DDU_LAST_RESORT_GUIDANCE')]
        [string]$Action,

        [bool]$Apply = $false,
        [bool]$Force = $false,
        [bool]$IsAdministrator = (Test-IsAdministrator),
        [ValidateSet('none', 'safe', 'monitor', 'adapter')]
        [string]$FixLevel = 'none'
    )

    $decision = Get-RemediationPolicyDecision -Action $Action -Apply:$Apply -Force:$Force -IsAdministrator:$IsAdministrator -FixLevel $FixLevel
    return $decision.allowed
}

function Get-RemediationPolicyDecision {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DISPLAY_REFRESH_HINT', 'EXPLORER_RESTART', 'PNP_RESCAN', 'MONITOR_REFRESH', 'ADAPTER_RESTART', 'DRIVER_REINSTALL_GUIDANCE', 'DDU_LAST_RESORT_GUIDANCE')]
        [string]$Action,

        [bool]$Apply = $false,
        [bool]$Force = $false,
        [bool]$IsAdministrator = (Test-IsAdministrator),
        [ValidateSet('none', 'safe', 'monitor', 'adapter')]
        [string]$FixLevel = 'none'
    )

    if (-not $script:ActionCatalog.Contains($Action)) {
        return [PSCustomObject]@{
            action        = $Action
            allowed       = $false
            reason        = 'Unknown action.'
            requiredFlags = @()
            riskLevel     = 'unknown'
        }
    }

    $meta = $script:ActionCatalog[$Action]
    $requiredFlags = [System.Collections.Generic.List[string]]::new()
    $reasons = [System.Collections.Generic.List[string]]::new()

    if ($FixLevel -eq 'none' -and $meta.fixLevels -notcontains 'safe' -and $Action -notmatch 'GUIDANCE') {
        if ($Action -ne 'DISPLAY_REFRESH_HINT') {
            $reasons.Add("FixLevel '$FixLevel' does not authorize this action.")
        }
    }

    if ($FixLevel -ne 'none' -and $meta.fixLevels -notcontains $FixLevel -and $Action -notmatch 'GUIDANCE') {
        $reasons.Add("Action not included in FixLevel '$FixLevel'.")
    }

    if ($meta.requiresAdmin -and -not $IsAdministrator) {
        $requiredFlags.Add('Administrator')
        $reasons.Add('Requires administrator privileges.')
    }

    if ($meta.requiresApply -and -not $Apply) {
        $requiredFlags.Add('Apply')
        $reasons.Add('Requires -Apply flag.')
    }

    if ($meta.requiresForce -and -not $Force) {
        $requiredFlags.Add('Force')
        $reasons.Add('Requires -Force flag.')
    }

    if ($Action -eq 'DDU_LAST_RESORT_GUIDANCE') {
        $reasons.Add('Guidance only; toolkit never executes DDU.')
    }

    if ($Action -eq 'DRIVER_REINSTALL_GUIDANCE') {
        $reasons.Add('Guidance only; toolkit never uninstalls drivers.')
    }

    $allowed = ($reasons.Count -eq 0)
    $reason = if ($allowed) { 'Action permitted by policy.' } else { ($reasons -join ' ') }

    return [PSCustomObject]@{
        action        = $Action
        allowed       = $allowed
        reason        = $reason
        requiredFlags = $requiredFlags.ToArray()
        riskLevel     = $meta.riskLevel
    }
}

function Get-FixPlan {
    [CmdletBinding()]
    param(
        [ValidateSet('none', 'safe', 'monitor', 'adapter')]
        [string]$FixLevel = 'none',

        [bool]$Apply = $false,
        [bool]$Force = $false,
        [bool]$IsAdministrator = (Test-IsAdministrator),

        [object]$Classification = $null
    )

    $actions = switch ($FixLevel) {
        'safe' { @('DISPLAY_REFRESH_HINT', 'EXPLORER_RESTART', 'DRIVER_REINSTALL_GUIDANCE', 'DDU_LAST_RESORT_GUIDANCE') }
        'monitor' { @('DISPLAY_REFRESH_HINT', 'EXPLORER_RESTART', 'PNP_RESCAN', 'MONITOR_REFRESH', 'DRIVER_REINSTALL_GUIDANCE', 'DDU_LAST_RESORT_GUIDANCE') }
        'adapter' { @('DISPLAY_REFRESH_HINT', 'EXPLORER_RESTART', 'PNP_RESCAN', 'MONITOR_REFRESH', 'ADAPTER_RESTART', 'DRIVER_REINSTALL_GUIDANCE', 'DDU_LAST_RESORT_GUIDANCE') }
        default { @('DISPLAY_REFRESH_HINT', 'DRIVER_REINSTALL_GUIDANCE') }
    }

    $plan = foreach ($action in $actions) {
        $decision = Get-RemediationPolicyDecision -Action $action -Apply:$Apply -Force:$Force -IsAdministrator:$IsAdministrator -FixLevel $FixLevel
        [PSCustomObject]@{
            action         = $action
            allowed        = $decision.allowed
            reason         = $decision.reason
            requiredFlags  = $decision.requiredFlags
            riskLevel      = $decision.riskLevel
            executionMode  = if ($Apply -and $decision.allowed) { 'execute' } else { 'preview' }
        }
    }

    return $plan
}
