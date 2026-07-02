#Requires -Version 5.1

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'src\Utilities.ps1')
. (Join-Path $repoRoot 'src\Evidence.ps1')
. (Join-Path $repoRoot 'src\Policy.ps1')
. (Join-Path $repoRoot 'src\Audit.ps1')
. (Join-Path $repoRoot 'src\Remediation.ps1')

$testAuditPath = Join-Path $env:TEMP 'nv-failsafe-remediation-test-audit.jsonl'
if (Test-Path -LiteralPath $testAuditPath) {
    Remove-Item -LiteralPath $testAuditPath -Force
}

Describe 'Remediation preview behavior' {
    It 'adapter restart is blocked without Apply and Force' {
        $result = Invoke-NvidiaAdapterRestart -Apply:$false -Force:$false -AuditPath $testAuditPath -FixLevel 'adapter'
        $result.mode | Should Be 'blocked'
        $result.allowed | Should Be $false
    }

    It 'adapter restart blocked without Force even with Apply' {
        $result = Invoke-NvidiaAdapterRestart -Apply:$true -Force:$false -AuditPath $testAuditPath -FixLevel 'adapter'
        $result.allowed | Should Be $false
        $result.mode | Should Be 'blocked'
    }

    It 'PnP rescan preview does not execute pnputil without Apply' {
        $result = Invoke-PnpRescan -Apply:$false -AuditPath $testAuditPath -FixLevel 'monitor'
        @('preview', 'blocked') -contains $result.mode | Should Be $true
        $result.stdout | Should Be ''
    }

    It 'safe display refresh preview does not restart explorer' {
        $result = Invoke-SafeDisplayRefresh -Apply:$false -AuditPath $testAuditPath
        $result.explorerRestarted | Should Be $false
        $result.mode | Should Be 'preview'
    }
}

Describe 'Fix mode policy integration' {
    It 'fix plan defaults to preview when Apply is false' {
        $plan = Get-FixPlan -FixLevel 'monitor' -Apply:$false -IsAdministrator $true
        ($plan | Where-Object { $_.action -eq 'PNP_RESCAN' }).executionMode | Should Be 'preview'
    }
}
