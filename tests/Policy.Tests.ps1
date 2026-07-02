#Requires -Version 5.1

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'src\Utilities.ps1')
. (Join-Path $repoRoot 'src\Evidence.ps1')
. (Join-Path $repoRoot 'src\Policy.ps1')

Describe 'Policy gates' {
    It 'blocks adapter restart without Force' {
        $decision = Get-RemediationPolicyDecision -Action 'ADAPTER_RESTART' -Apply:$true -Force:$false -IsAdministrator $true -FixLevel 'adapter'
        $decision.allowed | Should Be $false
        $decision.requiredFlags -contains 'Force' | Should Be $true
    }

    It 'blocks PnP rescan without admin' {
        $decision = Get-RemediationPolicyDecision -Action 'PNP_RESCAN' -Apply:$true -Force:$false -IsAdministrator $false -FixLevel 'monitor'
        $decision.allowed | Should Be $false
        $decision.requiredFlags -contains 'Administrator' | Should Be $true
    }

    It 'allows display refresh hint without Apply' {
        $decision = Get-RemediationPolicyDecision -Action 'DISPLAY_REFRESH_HINT' -Apply:$false -FixLevel 'safe'
        $decision.allowed | Should Be $true
    }

    It 'blocks explorer restart without Apply' {
        $decision = Get-RemediationPolicyDecision -Action 'EXPLORER_RESTART' -Apply:$false -FixLevel 'safe'
        $decision.allowed | Should Be $false
        $decision.requiredFlags -contains 'Apply' | Should Be $true
    }

    It 'allows adapter restart only with Apply, Force, and admin' {
        $decision = Get-RemediationPolicyDecision -Action 'ADAPTER_RESTART' -Apply:$true -Force:$true -IsAdministrator $true -FixLevel 'adapter'
        $decision.allowed | Should Be $true
    }
}
