#Requires -Version 5.1
<#
.SYNOPSIS
    Report generation and comparison for NV-Failsafe Recovery.
#>

Set-StrictMode -Version Latest

. "$PSScriptRoot\Utilities.ps1"

function Get-ReportActionLists {
    param(
        [object]$PolicyPlan,
        [object]$RemediationResults
    )

    $preview = [System.Collections.Generic.List[string]]::new()
    $applied = [System.Collections.Generic.List[string]]::new()
    $recommended = [System.Collections.Generic.List[string]]::new()

    if ($PolicyPlan) {
        foreach ($item in $PolicyPlan) {
            if ($item.manualOnly) {
                $recommended.Add("$($item.action) (manual-only)")
            }
            elseif ($item.executionMode -eq 'preview' -and $item.allowed) {
                $preview.Add($item.action)
            }
            elseif ($item.executionMode -eq 'apply') {
                $preview.Add($item.action)
            }
            elseif (-not $item.allowed) {
                $recommended.Add("$($item.action) (blocked: $($item.reason))")
            }
        }
    }

    if ($RemediationResults) {
        foreach ($result in $RemediationResults) {
            if ($result.mode -in @('apply', 'guidance') -and $result.action) {
                $applied.Add($result.action)
            }
        }
    }

    return [PSCustomObject]@{
        previewActions      = $preview.ToArray()
        appliedActions      = $applied.ToArray()
        recommendedActions  = $recommended.ToArray()
    }
}

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

    $gpuAdapters = @()
    $nvidiaPresent = $false
    $gpuName = $null
    $gpuStatus = $null
    $driverVersion = $null
    $pnpDeviceId = $null

    if ($Evidence.gpu.status -eq 'ok') {
        $nvidiaPresent = [bool]$Evidence.gpu.data.nvidiaAdapterPresent
        $gpuAdapters = @($Evidence.gpu.data.adapters)
        $primary = $gpuAdapters | Select-Object -First 1
        if ($primary) {
            $gpuName = $primary.name
            $gpuStatus = $primary.status
            $driverVersion = $primary.driverVersion
            $pnpDeviceId = $primary.pnpDeviceId
        }
    }

    $monitorDevices = @()
    $monitorNames = @()
    $monitorPnPStatus = @()
    if ($Evidence.monitor.status -eq 'ok') {
        $monitorDevices = @($Evidence.monitor.data.monitors)
        $monitorNames = @($monitorDevices | ForEach-Object { $_.name })
        $monitorPnPStatus = @($monitorDevices | ForEach-Object { $_.status })
    }

    $displayAdapters = @()
    if ($Evidence.pnpDisplay.status -eq 'ok') {
        $displayAdapters = @($Evidence.pnpDisplay.data.entities)
    }

    $isAdmin = $false
    if ($Evidence.system.adminStatus.status -eq 'ok') {
        $isAdmin = [bool]$Evidence.system.adminStatus.data.isAdministrator
    }

    $osInfo = $null
    if ($Evidence.system.operatingSystem.status -eq 'ok') {
        $osInfo = $Evidence.system.operatingSystem.data
    }

    $safetyNotes = [System.Collections.Generic.List[string]]::new()
    $safetyNotes.Add('Classification is evidence-based suspicion, not proof.')
    $safetyNotes.Add('Remediation defaults to preview-only without -Apply.')
    $safetyNotes.Add('Adapter restart requires -Apply and -Force and may blank the display.')
    foreach ($note in $Classification.riskNotes) {
        $safetyNotes.Add($note)
    }

    $actionLists = Get-ReportActionLists -PolicyPlan $PolicyPlan -RemediationResults $RemediationResults

    $structuredReport = [ordered]@{
        timestamp            = $Evidence.system.timestamp
        hostname             = $Evidence.system.hostname
        os                   = $osInfo
        gpu_adapters         = $gpuAdapters
        display_adapters     = $displayAdapters
        monitor_devices      = $monitorDevices
        current_resolution   = if ($resolution) { $resolution.resolutionString } else { $null }
        suspected_tags       = $Classification.tags
        evidence_items       = $Classification.evidence
        confidence_level     = $Classification.confidence
        explanation          = $Classification.explanation
        recommended_actions  = $actionLists.recommendedActions
        preview_actions      = $actionLists.previewActions
        applied_actions      = $actionLists.appliedActions
        safety_warnings      = $safetyNotes.ToArray()
        verification_result  = $Verification
    }

    return [PSCustomObject]@{
        schemaVersion      = Get-ReportSchemaVersion
        generatedAt        = (Get-Date).ToUniversalTime().ToString('o')
        mode               = $Mode
        hostname           = $Evidence.system.hostname
        username           = $Evidence.system.username
        report             = $structuredReport
        summary            = [ordered]@{
            timestamp                 = $Evidence.system.timestamp
            osVersion                 = if ($osInfo) { $osInfo.version } else { $null }
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
            explanation               = $Classification.explanation
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
        'NO_ISSUE_DETECTED' { Add-SummaryLine -Prefix 'OK' -Message 'No active NV-Failsafe indicators in current evidence.' }
        'NORMAL_DISPLAY_STATE' { Add-SummaryLine -Prefix 'OK' -Message 'No active NV-Failsafe indicators in current evidence.' }
        'INSUFFICIENT_DATA' { Add-SummaryLine -Prefix 'WARN' -Message 'Insufficient data for high-confidence classification.' }
        default { Add-SummaryLine -Prefix 'INFO' -Message "Classification: $($s.classification) (confidence $($s.confidence))." }
    }

    if ($s.explanation) {
        Add-SummaryLine -Prefix 'INFO' -Message $s.explanation
    }

    Add-SummaryLine -Prefix 'INFO' -Message "Recommended next step: $($s.recommendedNextStep)"

    if ($Report.policyPlan) {
        foreach ($item in $Report.policyPlan) {
            if ($item.executionMode -eq 'manual_only') {
                Add-SummaryLine -Prefix 'MANUAL' -Message "$($item.action): manual-only escalation."
            }
            elseif ($item.executionMode -eq 'preview' -and $item.allowed) {
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

function Test-ReportBlockHasProperty {
    param(
        [object]$Block,
        [string]$Name
    )

    if ($null -eq $Block) { return $false }
    if ($Block -is [System.Collections.IDictionary]) {
        return $Block.Contains($Name)
    }
    return ($Block.PSObject.Properties.Name -contains $Name)
}

function Test-NvFailsafeReportShape {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Report
    )

    $required = @('schemaVersion', 'generatedAt', 'mode', 'hostname', 'report', 'summary', 'classification')
    foreach ($name in $required) {
        if (-not ($Report.PSObject.Properties.Name -contains $name)) {
            return $false
        }
    }

    $reportRequired = @(
        'timestamp', 'hostname', 'current_resolution', 'suspected_tags',
        'evidence_items', 'confidence_level', 'explanation', 'safety_warnings'
    )
    foreach ($name in $reportRequired) {
        if (-not (Test-ReportBlockHasProperty -Block $Report.report -Name $name)) {
            return $false
        }
    }

    return $true
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

    $resolvedClassifications = @('NO_ISSUE_DETECTED', 'NORMAL_DISPLAY_STATE')

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
            ($before.classification -eq 'NV_FAILSAFE_SUSPECTED' -and ($after.classification -in $resolvedClassifications))
        )
    }
}
