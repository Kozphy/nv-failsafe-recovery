#Requires -Version 5.1

BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'Audit log append behavior' {
    BeforeAll {
        $script:AuditTestPath = Join-Path $env:TEMP "nv-failsafe-audit-test-$([guid]::NewGuid().ToString()).jsonl"
    }

    It 'appends events without overwriting prior entries' {
        Write-AuditEvent -AuditPath $script:AuditTestPath -EventType 'test_event' -Mode 'Detect' -Result 'started' -ExecutionMode 'preview'
        Write-AuditEvent -AuditPath $script:AuditTestPath -EventType 'test_event' -Mode 'Detect' -Result 'success' -ExecutionMode 'preview' -ApplyUsed:$false -ForceUsed:$false -FixLevel 'safe'

        $events = Read-AuditEvents -AuditPath $script:AuditTestPath
        $events.Count | Should -Be 2
        $events[1].applyUsed | Should -Be $false
        $events[1].fixLevel | Should -Be 'safe'
    }

    It 'reports append-only audit log as valid' {
        Test-AuditLogAppendOnly -AuditPath $script:AuditTestPath -MinimumEventCount 2 | Should -Be $true
    }
}
