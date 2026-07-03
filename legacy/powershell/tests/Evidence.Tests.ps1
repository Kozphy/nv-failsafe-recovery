#Requires -Version 5.1

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'Evidence object shape' {
    It 'returns structured probe results with required fields' {
        $probe = New-EvidenceProbeResult -Status 'ok' -Source 'test' -Data @{ sample = 1 }
        $probe.status | Should -Be 'ok'
        $probe.source | Should -Be 'test'
        $probe.PSObject.Properties.Name | Should -Contain 'errorMessage'
        $probe.collectedAt | Should -Not -BeNullOrEmpty
    }

    It 'Get-ResolutionRisk identifies 640x480' {
        $risk = Get-ResolutionRisk -Width 640 -Height 480
        $risk.is640x480 | Should -Be $true
        $risk.riskLevel | Should -Be 'critical'
    }

    It 'Get-FullEvidenceBundle returns expected top-level keys' {
        $bundle = Get-FullEvidenceBundle
        $bundle.PSObject.Properties.Name | Should -Contain 'display'
        $bundle.PSObject.Properties.Name | Should -Contain 'gpu'
        $bundle.PSObject.Properties.Name | Should -Contain 'monitor'
        $bundle.PSObject.Properties.Name | Should -Contain 'pnpDisplay'
        @('ok', 'warning', 'error', 'unavailable') | Should -Contain $bundle.display.status
    }
}
