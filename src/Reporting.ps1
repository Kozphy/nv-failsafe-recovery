#Requires -Version 5.1
<#
.SYNOPSIS
    Report generation and comparison for NV-Failsafe Recovery.
#>

Set-StrictMode -Version Latest

. "$PSScriptRoot\Utilities.ps1"

function New-NvFailsafeReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Evidence,

        [Parameter(Mandatory)]
        [object]$Classification,

        [string]$Mode = 'Detect',
        [object]$PolicyPlan = $null,
        [object]$RemediationResults = $null,
        [object]$Verification = $null
    )

    $resolution = $null
    if ($Evidence.display.status -eq 'ok' -and $Evidence.display.data.activeResolution) {
        $resolution = $Evidence.display.data.activeResolution
    }

    $nvidiaPresent = $false
    $gpuName = $null
    $gpuStatus = $null
    $driverVersion = $null
    $pnpDeviceId = $null

    if ($Evidence.gpu.status -eq 'ok') {
        $nvidiaPresent = [bool]$Evidence.gpu.data.nvidiaAdapterPresent
        $primary = $Evidence.gpu.data.adapters | Select-Object -First 1
        if ($primary) {
            $gpuName = $primary.name
            $gpuStatus = $primary.status
            $driverVersion = $primary.driverVersion
            $pnpDeviceId = $primary.pnpDeviceId
        }
    }

    $monitorNames = @()
    $monitorPnPStatus = @()
    if ($Evidence.monitor.status -eq 'ok') {
        $monitorNames = @($Evidence.monitor.data.monitors | ForEach-Object { $_.name })
        $monitorPnPStatus = @($Evidence.monitor.data.monitors | ForEach-Object { $_.status })
    }

    $isAdmin = $false
    if ($Evidence.system.adminStatus.status -eq 'ok') {
        $isAdmin = [bool]$Evidence.system.adminStatus.data.isAdministrator
    }

    $safetyNotes = [System.Collections.Generic.List[string]]::new()
    $safetyNotes.Add('Classification is evidence-based suspicion, not proof.')
    $safetyNotes.Add('Remediation defaults to preview-only without -Apply.')
    $safetyNotes.Add('Adapter restart requires -Apply and -Force and may blank the display.')
    foreach ($note in $Classification.riskNotes) {
        $safetyNotes.Add($note)
    }

    return [PSCustomObject]@{
        schemaVersion = '1.0.0'
        generatedAt   = (Get-Date).ToUniversalTime().ToString('o')
        mode          = $Mode
        hostname      = $Evidence.system.hostname
        username      = $Evidence.system.username
        summary       = [ordered]@{
            timestamp                 = $Evidence.system.timestamp
            osVersion                 = if ($Evidence.system.operatingSystem.status -eq 'ok') { $Evidence.system.operatingSystem.data.version } else { $null }
            powershellVersion         = $Evidence.system.powershellVersion
            adminStatus               = $isAdmin
            activeDisplayResolution   = if ($resolution) { $resolution.resolutionString } else { $null }
            is640x480                 = if ($resolution) { $resolution.is640x480 } else { $false }
            isSuspiciouslyLow         = if ($resolution) { $resolution.isSuspiciouslyLow } else { $false }
            nvidiaAdapterPresent      = $nvidiaPresent
            gpuName                   = $gpuName
            gpuStatus                 = $gpuStatus
            driverVersion             = $driverVersion
            pnpDeviceId               = $pnpDeviceId
            currentVideoMode          = if ($Evidence.display.status -eq 'ok') { $Evidence.display.data.currentVideoMode.name } else { $null }
            monitorCount              = if ($Evidence.monitor.status -eq 'ok') { $Evidence.monitor.data.monitorCount } else { $null }
            monitorNames              = $monitorNames
            monitorPnPStatus          = $monitorPnPStatus
            classification            = $Classification.classification
            confidence                = $Classification.confidence
            recommendedNextStep       = $Classification.recommendedNextStep
            safetyNotes               = $safetyNotes.ToArray()
        }
        evidence           = $Evidence
        classification     = $Classification
        policyPlan         = $PolicyPlan
        remediationResults = $RemediationResults
        verification       = $Verification
    }
}

function Write-HumanSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Report,

        [switch]$Quiet
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $s = $Report.summary

    function Add-SummaryLine {
        param([string]$Prefix, [string]$Message)
        $lines.Add("[$Prefix] $Message")
    }

    if ($s.nvidiaAdapterPresent) {
        Add-SummaryLine -Prefix 'OK' -Message "NVIDIA adapter detected: $($s.gpuName)"
    }
    else {
        Add-SummaryLine -Prefix 'WARN' -Message 'NVIDIA adapter not detected in current evidence.'
    }

    if ($s.is640x480) {
        Add-SummaryLine -Prefix 'WARN' -Message 'Current resolution is 640x480.'
    }
    elseif ($s.isSuspiciouslyLow) {
        Add-SummaryLine -Prefix 'WARN' -Message "Current resolution $($s.activeDisplayResolution) is suspiciously low."
    }
    else {
        Add-SummaryLine -Prefix 'OK' -Message "Current resolution: $($s.activeDisplayResolution)"
    }

    switch ($s.classification) {
        'NV_FAILSAFE_SUSPECTED' { Add-SummaryLine -Prefix 'WARN' -Message 'NV-Failsafe suspected based on available evidence.' }
        'NORMAL_DISPLAY_STATE' { Add-SummaryLine -Prefix 'OK' -Message 'No NV-Failsafe indicators in current evidence.' }
        'INSUFFICIENT_DATA' { Add-SummaryLine -Prefix 'WARN' -Message 'Insufficient data for high-confidence classification.' }
        default { Add-SummaryLine -Prefix 'INFO' -Message "Classification: $($s.classification) (confidence $($s.confidence))." }
    }

    Add-SummaryLine -Prefix 'INFO' -Message "Recommended next step: $($s.recommendedNextStep)"

    if ($Report.policyPlan) {
        foreach ($item in $Report.policyPlan) {
            if ($item.executionMode -eq 'preview' -and $item.allowed) {
                Add-SummaryLine -Prefix 'PREVIEW' -Message "Would run action: $($item.action)"
            }
            elseif (-not $item.allowed) {
                Add-SummaryLine -Prefix 'BLOCKED' -Message "$($item.action): $($item.reason)"
            }
        }
    }

    foreach ($note in $s.safetyNotes) {
        Add-SummaryLine -Prefix 'SAFETY' -Message $note
    }

    if (-not $Quiet) {
        $lines | ForEach-Object { Write-Output $_ }
    }

    return $lines.ToArray()
}

function Write-JsonReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Report,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $directory = Split-Path -Parent $OutputPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $ordered = ConvertTo-OrderedHashtable -InputObject $Report
    $json = $ordered | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
}

function Compare-NvFailsafeReports {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$BeforeReport,

        [Parameter(Mandatory)]
        [object]$AfterReport
    )

    $before = $BeforeReport.summary
    $after = $AfterReport.summary

    return [PSCustomObject]@{
        comparedAt = (Get-Date).ToUniversalTime().ToString('o')
        resolutionChanged = ($before.activeDisplayResolution -ne $after.activeDisplayResolution)
        resolutionBefore = $before.activeDisplayResolution
        resolutionAfter = $after.activeDisplayResolution
        nvFailsafeSuspectedBefore = ($before.classification -eq 'NV_FAILSAFE_SUSPECTED')
        nvFailsafeSuspectedAfter = ($after.classification -eq 'NV_FAILSAFE_SUSPECTED')
        monitorCountChanged = ($before.monitorCount -ne $after.monitorCount)
        monitorCountBefore = $before.monitorCount
        monitorCountAfter = $after.monitorCount
        nvidiaAdapterStatusChanged = ($before.gpuStatus -ne $after.gpuStatus)
        nvidiaAdapterStatusBefore = $before.gpuStatus
        nvidiaAdapterStatusAfter = $after.gpuStatus
        classificationChanged = ($before.classification -ne $after.classification)
        classificationBefore = $before.classification
        classificationAfter = $after.classification
        confidenceBefore = $before.confidence
        confidenceAfter = $after.confidence
        improved = (
            ($before.is640x480 -and -not $after.is640x480) -or
            ($before.classification -eq 'NV_FAILSAFE_SUSPECTED' -and $after.classification -eq 'NORMAL_DISPLAY_STATE')
        )
    }
}
