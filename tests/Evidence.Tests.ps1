#Requires -Version 5.1

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'src\Utilities.ps1')
. (Join-Path $repoRoot 'src\Evidence.ps1')

Describe 'Evidence object shape' {
    It 'returns structured probe results with required fields' {
        $probe = New-EvidenceProbeResult -Status 'ok' -Source 'test' -Data @{ sample = 1 }
        $probe.status | Should Be 'ok'
        $probe.source | Should Be 'test'
        $probe.PSObject.Properties.Name -contains 'errorMessage' | Should Be $true
        $probe.collectedAt | Should Not BeNullOrEmpty
    }

    It 'Get-ResolutionRisk identifies 640x480' {
        $risk = Get-ResolutionRisk -Width 640 -Height 480
        $risk.is640x480 | Should Be $true
        $risk.riskLevel | Should Be 'critical'
    }

    It 'Get-FullEvidenceBundle returns expected top-level keys' {
        $bundle = Get-FullEvidenceBundle
        $bundle.PSObject.Properties.Name -contains 'display' | Should Be $true
        $bundle.PSObject.Properties.Name -contains 'gpu' | Should Be $true
        $bundle.PSObject.Properties.Name -contains 'monitor' | Should Be $true
        $bundle.PSObject.Properties.Name -contains 'pnpDisplay' | Should Be $true
        @('ok', 'warning', 'error', 'unavailable') -contains $bundle.display.status | Should Be $true
    }
}
