#Requires -Version 5.1

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:RemediationAuditPath = Join-Path $env:TEMP "nv-failsafe-remediation-test-$([guid]::NewGuid().ToString()).jsonl"
}

Describe 'Remediation preview behavior' {
    It 'adapter restart is blocked without Apply and Force' {
        $result = Invoke-NvidiaAdapterRestart -Apply:$false -Force:$false -AuditPath $script:RemediationAuditPath -FixLevel 'adapter'
        $result.mode | Should -Be 'blocked'
        $result.allowed | Should -Be $false
    }

    It 'adapter restart blocked without Force even with Apply' {
        $result = Invoke-NvidiaAdapterRestart -Apply:$true -Force:$false -AuditPath $script:RemediationAuditPath -FixLevel 'adapter'
        $result.allowed | Should -Be $false
        $result.mode | Should -Be 'blocked'
    }

    It 'PnP rescan preview does not execute pnputil without Apply' {
        $result = Invoke-PnpRescan -Apply:$false -AuditPath $script:RemediationAuditPath -FixLevel 'monitor'
        @('preview', 'blocked') | Should -Contain $result.mode
        $result.stdout | Should -Be ''
    }

    It 'safe display refresh preview does not restart explorer' {
        $result = Invoke-SafeDisplayRefresh -Apply:$false -AuditPath $script:RemediationAuditPath
        $result.explorerRestarted | Should -Be $false
        $result.mode | Should -Be 'preview'
    }
}

Describe 'Fix mode policy integration' {
    It 'fix plan defaults to preview when Apply is false' {
        $plan = Get-FixPlan -FixLevel 'monitor' -Apply:$false -IsAdministrator $true
        ($plan | Where-Object { $_.action -eq 'PNP_RESCAN' }).executionMode | Should -Be 'preview'
    }
}
