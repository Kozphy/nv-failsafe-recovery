#Requires -Version 5.1

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'Classifier rules' {
    It 'classifies NVIDIA + 640x480 as NV_FAILSAFE_SUSPECTED' {
        $evidence = New-MockEvidence -Is640x480 $true -NvidiaPresent $true
        $result = Get-NvFailsafeClassification -Evidence $evidence
        $result.classification | Should -Be 'NV_FAILSAFE_SUSPECTED'
        $result.confidence | Should -BeGreaterThan 0.7
        $result.explanation | Should -Not -BeNullOrEmpty
    }

    It 'classifies non-NVIDIA + 640x480 as LOW_RESOLUTION_FALLBACK' {
        $evidence = New-MockEvidence -Is640x480 $true -NvidiaPresent $false
        $result = Get-NvFailsafeClassification -Evidence $evidence
        $result.classification | Should -Be 'LOW_RESOLUTION_FALLBACK'
    }

    It 'flags generic monitor profile suspicion' {
        $evidence = New-MockEvidence -GenericCount 1
        $result = Get-NvFailsafeClassification -Evidence $evidence
        $result.tags | Should -Contain 'GENERIC_MONITOR_PROFILE_SUSPECTED'
    }

    It 'flags generic profile separately from handshake on low resolution' {
        $evidence = New-MockEvidence -Is640x480 $true -GenericCount 1
        $result = Get-NvFailsafeClassification -Evidence $evidence
        $result.tags | Should -Not -Contain 'MONITOR_EDID_HANDSHAKE_SUSPECTED'
        $result.tags | Should -Contain 'GENERIC_MONITOR_PROFILE_SUSPECTED'
    }

    It 'classifies healthy resolution as NO_ISSUE_DETECTED' {
        $evidence = New-MockEvidence
        $result = Get-NvFailsafeClassification -Evidence $evidence
        $result.classification | Should -Be 'NO_ISSUE_DETECTED'
    }

    It 'returns INSUFFICIENT_DATA when multiple probes fail' {
        $evidence = New-MockEvidence -DisplayStatus 'error' -GpuProbeStatus 'unavailable' -MonitorProbeStatus 'error' -PnpProbeStatus 'unavailable'
        $result = Get-NvFailsafeClassification -Evidence $evidence
        $result.classification | Should -Be 'INSUFFICIENT_DATA'
    }
}
