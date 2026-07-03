#Requires -Version 5.1
<#
.SYNOPSIS
    Append-only JSONL audit logging for NV-Failsafe Recovery.
#>

Set-StrictMode -Version Latest

. "$PSScriptRoot\Utilities.ps1"

function Write-AuditEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AuditPath,

        [Parameter(Mandatory)]
        [string]$EventType,

        [string]$Mode = '',
        [string]$Classification = '',
        [string]$Action = '',
        [object]$PolicyDecision = $null,
        [string]$Result = '',
        [string]$Error = '',
        [ValidateSet('', 'none', 'safe', 'monitor', 'adapter')]
        [string]$FixLevel = '',
        [bool]$ApplyUsed = $false,
        [bool]$ForceUsed = $false,
        [ValidateSet('', 'preview', 'apply', 'blocked', 'guidance', 'verify')]
        [string]$ExecutionMode = ''
    )

    $directory = Split-Path -Parent $AuditPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $event = [ordered]@{
        timestamp      = (Get-Date).ToUniversalTime().ToString('o')
        eventType      = $EventType
        mode           = $Mode
        classification = $Classification
        action         = $Action
        fixLevel       = $FixLevel
        applyUsed      = $ApplyUsed
        forceUsed      = $ForceUsed
        executionMode  = $ExecutionMode
        policyDecision = ConvertTo-OrderedHashtable -InputObject $PolicyDecision
        result         = $Result
        error          = $Error
        hostname       = $env:COMPUTERNAME
        username       = $env:USERNAME
        toolkitVersion = Get-ToolkitVersion
    }

    $json = ($event | ConvertTo-Json -Depth 8 -Compress)
    $line = $json + [Environment]::NewLine
    [System.IO.File]::AppendAllText($AuditPath, $line, [System.Text.UTF8Encoding]::new($false))
}

function Read-AuditEvents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AuditPath
    )

    if (-not (Test-Path -LiteralPath $AuditPath)) {
        return @()
    }

    $events = @()
    Get-Content -LiteralPath $AuditPath -Encoding UTF8 | ForEach-Object {
        if (-not [string]::IsNullOrWhiteSpace($_)) {
            $events += $_ | ConvertFrom-Json
        }
    }
    return $events
}

function Test-AuditLogAppendOnly {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AuditPath,

        [int]$MinimumEventCount = 1
    )

    if (-not (Test-Path -LiteralPath $AuditPath)) {
        return $false
    }

    $events = Read-AuditEvents -AuditPath $AuditPath
    return ($events.Count -ge $MinimumEventCount)
}
