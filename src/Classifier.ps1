#Requires -Version 5.1
<#
.SYNOPSIS
    Evidence-based classification for NV-Failsafe display states.
#>

Set-StrictMode -Version Latest

. "$PSScriptRoot\Utilities.ps1"

function Get-EvidenceValue {
    param(
        [object]$Probe,
        [scriptblock]$Selector
    )

    if ($null -eq $Probe -or $Probe.status -eq 'error' -or $Probe.status -eq 'unavailable') {
        return $null
    }
    return & $Selector $Probe.data
}

function Test-EvidenceIncomplete {
    param([object]$Evidence)

    $criticalProbes = @($Evidence.display, $Evidence.gpu, $Evidence.monitor, $Evidence.pnpDisplay)
    $missing = @($criticalProbes | Where-Object { $null -eq $_ -or $_.status -in @('error', 'unavailable') })
    return $missing.Count -ge 2
}

function Get-ClassificationExplanation {
    param(
        [string]$Classification,
        [string[]]$Tags
    )

    switch ($Classification) {
        'NV_FAILSAFE_SUSPECTED' {
            return 'Evidence indicates a suspected NVIDIA NV-Failsafe / 640x480 fallback pattern. This is a hypothesis based on resolution and adapter evidence, not proof of hardware failure.'
        }
        'LOW_RESOLUTION_FALLBACK' {
            return 'Evidence indicates a low-resolution fallback state. Root cause may be handshake, driver, or non-NVIDIA display path issues.'
        }
        'INSUFFICIENT_DATA' {
            return 'Insufficient probe data was collected to support a higher-confidence classification. Re-run Report mode, preferably elevated, to improve evidence quality.'
        }
        'NO_ISSUE_DETECTED' {
            if ($Tags -contains 'MONITOR_EDID_HANDSHAKE_SUSPECTED' -or $Tags -contains 'GENERIC_MONITOR_PROFILE_SUSPECTED') {
                return 'No active NV-Failsafe fallback is detected, but secondary tags suggest monitor detection or EDID handshake drift may still be present.'
            }
            return 'Current evidence does not indicate an active NV-Failsafe / 640x480 fallback state.'
        }
        default {
            return 'Classification derived from available local evidence only.'
        }
    }
}

function Get-NvFailsafeClassification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Evidence
    )

    $evidenceItems = [System.Collections.Generic.List[string]]::new()
    $counterEvidence = [System.Collections.Generic.List[string]]::new()
    $manualSteps = [System.Collections.Generic.List[string]]::new()
    $automatedSteps = [System.Collections.Generic.List[string]]::new()
    $riskNotes = [System.Collections.Generic.List[string]]::new()
    $tags = [System.Collections.Generic.List[string]]::new()

    $confidence = 0.35
    $classification = 'INSUFFICIENT_DATA'
    $recommendedNextStep = 'Collect additional display evidence and re-run Detect mode.'

    if (Test-EvidenceIncomplete -Evidence $Evidence) {
        $evidenceItems.Add('Multiple critical probes failed or were unavailable.')
        $manualSteps.Add('Re-run Report mode from an elevated PowerShell session if PnP data is missing.')
        $tagArray = @('INSUFFICIENT_DATA')
        return [PSCustomObject]@{
            classification      = 'INSUFFICIENT_DATA'
            confidence          = 0.25
            evidence            = $evidenceItems.ToArray()
            counterEvidence     = $counterEvidence.ToArray()
            explanation         = (Get-ClassificationExplanation -Classification 'INSUFFICIENT_DATA' -Tags $tagArray)
            recommendedNextStep = $recommendedNextStep
            manualSteps         = $manualSteps.ToArray()
            automatedSteps      = $automatedSteps.ToArray()
            riskNotes           = @('Classification confidence is limited due to incomplete evidence collection.')
            tags                = $tagArray
        }
    }

    $resolution = Get-EvidenceValue -Probe $Evidence.display -Selector { param($d) $d.activeResolution }
    $nvidiaPresent = Get-EvidenceValue -Probe $Evidence.gpu -Selector { param($d) $d.nvidiaAdapterPresent }
    $gpuStatus = Get-EvidenceValue -Probe $Evidence.gpu -Selector { param($d) ($d.adapters | Select-Object -First 1).status }
    $videoMode = Get-EvidenceValue -Probe $Evidence.display -Selector { param($d) $d.currentVideoMode.name }
    $monitorCount = Get-EvidenceValue -Probe $Evidence.monitor -Selector { param($d) $d.monitorCount }
    $genericCount = Get-EvidenceValue -Probe $Evidence.monitor -Selector { param($d) $d.genericCount }
    $hasNvFailsafeName = Get-EvidenceValue -Probe $Evidence.monitor -Selector { param($d) $d.hasNvFailsafeName }
    $pnpDisabled = Get-EvidenceValue -Probe $Evidence.pnpDisplay -Selector { param($d) $d.disabledCount }
    $pnpUnknown = Get-EvidenceValue -Probe $Evidence.pnpDisplay -Selector { param($d) $d.unknownCount }
    $isAdmin = $false
    if ($Evidence.system.adminStatus.status -eq 'ok') {
        $isAdmin = [bool]$Evidence.system.adminStatus.data.isAdministrator
    }

    if ($resolution -and $resolution.is640x480) {
        if ($nvidiaPresent) {
            $classification = 'NV_FAILSAFE_SUSPECTED'
            $confidence = 0.82
            $evidenceItems.Add('Active resolution is exactly 640x480 with NVIDIA adapter present.')
            $recommendedNextStep = 'Try Win+Ctrl+Shift+B, then power-cycle monitor and replug HDMI/DisplayPort before automated fixes.'
            $manualSteps.Add('Press Win+Ctrl+Shift+B to reset the graphics driver.')
            $manualSteps.Add('Power-cycle the monitor and replug the display cable.')
            $automatedSteps.Add('Run Fix mode with -FixLevel safe (preview first).')
            $tags.Add('NV_FAILSAFE_SUSPECTED')
        }
        else {
            $classification = 'LOW_RESOLUTION_FALLBACK'
            $confidence = 0.55
            $evidenceItems.Add('Active resolution is 640x480 but no NVIDIA adapter was detected.')
            $counterEvidence.Add('NV-Failsafe classification requires NVIDIA adapter evidence.')
            $recommendedNextStep = 'Verify GPU detection and display cable path; NVIDIA-specific recovery may not apply.'
            $tags.Add('LOW_RESOLUTION_FALLBACK')
        }
    }
    elseif ($resolution -and $resolution.isSuspiciouslyLow) {
        $classification = 'LOW_RESOLUTION_FALLBACK'
        $confidence = 0.48
        $evidenceItems.Add("Resolution $($resolution.resolutionString) is suspiciously low.")
        $recommendedNextStep = 'Verify monitor EDID handshake and Windows display settings.'
        $tags.Add('LOW_RESOLUTION_FALLBACK')
    }
    else {
        $classification = 'NO_ISSUE_DETECTED'
        $confidence = 0.72
        $evidenceItems.Add('Active resolution does not indicate NV-Failsafe fallback.')
        $recommendedNextStep = 'No active NV-Failsafe indicators detected; monitor for recurrence after sleep/wake.'
        $tags.Add('NO_ISSUE_DETECTED')
    }

    if ($genericCount -gt 0) {
        $tags.Add('GENERIC_MONITOR_PROFILE_SUSPECTED')
        $confidence = [math]::Min(0.95, $confidence + 0.05)
        $evidenceItems.Add('One or more monitors appear generic or non-specific.')
        $manualSteps.Add('Verify the monitor is detected with its correct model name in Display Settings.')
    }

    $monitorHandshakeSuspected = $false
    if ($hasNvFailsafeName) {
        $monitorHandshakeSuspected = $true
        $evidenceItems.Add('Monitor name evidence indicates NV-Failsafe.')
    }
    if ($pnpUnknown -gt 0 -or $pnpDisabled -gt 0) {
        $monitorHandshakeSuspected = $true
        $evidenceItems.Add('PnP display entities report unknown or non-OK status.')
    }
    if ($null -ne $monitorCount -and $monitorCount -eq 0) {
        $monitorHandshakeSuspected = $true
        $evidenceItems.Add('No monitor devices were enumerated.')
    }

    if ($monitorHandshakeSuspected) {
        $tags.Add('MONITOR_EDID_HANDSHAKE_SUSPECTED')
        $confidence = [math]::Min(0.95, $confidence + 0.08)
        $manualSteps.Add('Try another HDMI/DisplayPort cable or GPU output port.')
        $automatedSteps.Add('Consider Fix mode -FixLevel monitor with -Apply if handshake suspicion persists.')
        if ($classification -eq 'NO_ISSUE_DETECTED') {
            $recommendedNextStep = 'Evidence indicates possible EDID/handshake issue despite acceptable resolution.'
        }
    }

    $driverFallbackSuspected = $false
    if ($gpuStatus -and $gpuStatus -ne 'OK') {
        $driverFallbackSuspected = $true
        $evidenceItems.Add("NVIDIA adapter status is '$gpuStatus', not OK.")
    }
    if ($videoMode -and ($videoMode -match '640\s*x\s*480|Failsafe|Standard VGA')) {
        $driverFallbackSuspected = $true
        $evidenceItems.Add("Current video mode '$videoMode' appears fallback-like.")
    }

    if ($driverFallbackSuspected) {
        $tags.Add('NVIDIA_DRIVER_FALLBACK_SUSPECTED')
        $confidence = [math]::Min(0.95, $confidence + 0.07)
        $riskNotes.Add('Driver fallback is suspected, not proven; hardware failure requires stronger evidence.')
        $automatedSteps.Add('Escalate to driver reinstall guidance before adapter restart.')
    }

    $lastBoot = Get-EvidenceValue -Probe $Evidence.system.operatingSystem -Selector { param($d) $d.lastBootUpTime }
    if ($lastBoot) {
        $bootAge = (Get-Date).ToUniversalTime() - [datetime]::Parse($lastBoot)
        if ($bootAge.TotalMinutes -lt 15 -and $classification -ne 'NO_ISSUE_DETECTED') {
            $evidenceItems.Add('Recent boot timing suggests possible post-sleep/wake display initialization race.')
            $manualSteps.Add('If issue appeared after sleep, test with Fast Startup disabled.')
        }
    }

    if (($pnpDisabled -gt 0 -or $pnpUnknown -gt 0) -and $classification -ne 'NO_ISSUE_DETECTED') {
        $evidenceItems.Add('Display PnP state drift is suspected based on entity status.')
        $automatedSteps.Add('PnP rescan may help if policy allows (-Apply, admin).')
    }

    if (-not $isAdmin -and $classification -ne 'NO_ISSUE_DETECTED') {
        $riskNotes.Add('Some remediation actions require administrator privileges.')
    }

    if ($tags.Count -eq 0) {
        $tags.Add($classification)
    }

    $tagArray = $tags.ToArray()

    return [PSCustomObject]@{
        classification      = $classification
        confidence          = [math]::Round([math]::Max(0.0, [math]::Min(1.0, $confidence)), 2)
        evidence            = $evidenceItems.ToArray()
        counterEvidence     = $counterEvidence.ToArray()
        explanation         = (Get-ClassificationExplanation -Classification $classification -Tags $tagArray)
        recommendedNextStep = $recommendedNextStep
        manualSteps         = $manualSteps.ToArray()
        automatedSteps      = $automatedSteps.ToArray()
        riskNotes           = $riskNotes.ToArray()
        tags                = $tagArray
    }
}
