#Requires -Version 5.1

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'Policy gates' {
    It 'blocks adapter restart without Force' {
        $decision = Get-RemediationPolicyDecision -Action 'ADAPTER_RESTART' -Apply:$true -Force:$false -IsAdministrator $true -FixLevel 'adapter'
        $decision.allowed | Should -Be $false
        $decision.requiredFlags | Should -Contain 'Force'
    }

    It 'blocks PnP rescan without admin' {
        $decision = Get-RemediationPolicyDecision -Action 'PNP_RESCAN' -Apply:$true -Force:$false -IsAdministrator $false -FixLevel 'monitor'
        $decision.allowed | Should -Be $false
        $decision.requiredFlags | Should -Contain 'Administrator'
    }

    It 'allows display refresh hint without Apply' {
        $decision = Get-RemediationPolicyDecision -Action 'DISPLAY_REFRESH_HINT' -Apply:$false -FixLevel 'safe'
        $decision.allowed | Should -Be $true
    }

    It 'blocks explorer restart without Apply' {
        $decision = Get-RemediationPolicyDecision -Action 'EXPLORER_RESTART' -Apply:$false -FixLevel 'safe'
        $decision.allowed | Should -Be $false
        $decision.requiredFlags | Should -Contain 'Apply'
    }

    It 'allows adapter restart only with Apply, Force, and admin' {
        $decision = Get-RemediationPolicyDecision -Action 'ADAPTER_RESTART' -Apply:$true -Force:$true -IsAdministrator $true -FixLevel 'adapter'
        $decision.allowed | Should -Be $true
    }

    It 'marks driver reinstall guidance as manual-only' {
        $decision = Get-RemediationPolicyDecision -Action 'DRIVER_REINSTALL_GUIDANCE' -Apply:$false -FixLevel 'safe'
        $decision.allowed | Should -Be $true
        $decision.manualOnly | Should -Be $true
        $decision.executionMode | Should -Be 'manual_only'
    }
}
