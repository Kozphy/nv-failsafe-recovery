#Requires -Version 5.1
<#
.SYNOPSIS
    Shared utilities for NV-Failsafe Recovery toolkit.
#>

Set-StrictMode -Version Latest

function New-EvidenceProbeResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ok', 'warning', 'error', 'unavailable')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Source,

        [object]$Data = $null,

        [string]$ErrorMessage = ''
    )

    [PSCustomObject]@{
        status       = $Status
        source       = $Source
        data         = $Data
        errorMessage = $ErrorMessage
        collectedAt  = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Invoke-SafeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [string]$UnavailableMessage = 'Command unavailable on this system.'
    )

    try {
        $data = & $ScriptBlock
        return New-EvidenceProbeResult -Status 'ok' -Source $Source -Data $data
    }
    catch {
        $message = $_.Exception.Message
        if ($_.FullyQualifiedErrorId -match 'CommandNotFound|NotFound') {
            return New-EvidenceProbeResult -Status 'unavailable' -Source $Source -ErrorMessage $UnavailableMessage
        }
        return New-EvidenceProbeResult -Status 'error' -Source $Source -ErrorMessage $message
    }
}

function Get-NvFailsafeModuleRoot {
    [CmdletBinding()]
    param()

    $utilitiesPath = $PSScriptRoot
    if (-not $utilitiesPath) {
        throw 'Unable to resolve module root from Utilities.ps1.'
    }
    return (Split-Path -Parent $utilitiesPath)
}

function Import-NvFailsafeModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $root = Get-NvFailsafeModuleRoot
    $path = Join-Path $root "src\$Name.ps1"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Module file not found: $path"
    }
    . $path
}

function ConvertTo-OrderedHashtable {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return $null
        }

        if ($InputObject -is [System.Collections.IDictionary]) {
            $ordered = [ordered]@{}
            foreach ($key in $InputObject.Keys) {
                $ordered[$key] = ConvertTo-OrderedHashtable -InputObject $InputObject[$key]
            }
            return $ordered
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $items = @()
            foreach ($item in $InputObject) {
                $items += ConvertTo-OrderedHashtable -InputObject $item
            }
            return $items
        }

        if ($InputObject -is [pscustomobject]) {
            $ordered = [ordered]@{}
            foreach ($prop in $InputObject.PSObject.Properties) {
                $ordered[$prop.Name] = ConvertTo-OrderedHashtable -InputObject $prop.Value
            }
            return $ordered
        }

        return $InputObject
    }
}

function Test-StringContainsAny {
    [CmdletBinding()]
    param(
        [string]$Value,
        [string[]]$Patterns
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    foreach ($pattern in $Patterns) {
        if ($Value -match $pattern) {
            return $true
        }
    }
    return $false
}

function Test-PowerShellVersionMeetsMinimum {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$MinimumVersion
    )

    return ([version]$Version -ge [version]$MinimumVersion)
}

function Get-ToolkitVersion {
    [CmdletBinding()]
    param()

    return '1.1.0'
}

function Get-ReportSchemaVersion {
    [CmdletBinding()]
    param()

    return '1.1.0'
}

function ConvertTo-LegacyClassification {
    [CmdletBinding()]
    param(
        [string]$Classification
    )

    switch ($Classification) {
        'NO_ISSUE_DETECTED' { return 'NORMAL_DISPLAY_STATE' }
        'LOW_RESOLUTION_FALLBACK' { return 'LOW_RESOLUTION_ONLY' }
        default { return $Classification }
    }
}
