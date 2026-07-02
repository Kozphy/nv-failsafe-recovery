#Requires -Version 5.1

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'src\Utilities.ps1')
. (Join-Path $repoRoot 'src\Audit.ps1')

$auditPath = Join-Path $env:TEMP "nv-failsafe-audit-test-$([guid]::NewGuid().ToString()).jsonl"

Describe 'Audit log append behavior' {
    It 'appends events without overwriting prior entries' {
        Write-AuditEvent -AuditPath $auditPath -EventType 'test_event' -Mode 'Detect' -Result 'started' -ExecutionMode 'preview'
        Write-AuditEvent -AuditPath $auditPath -EventType 'test_event' -Mode 'Detect' -Result 'success' -ExecutionMode 'preview' -ApplyUsed:$false -ForceUsed:$false -FixLevel 'safe'

        $events = Read-AuditEvents -AuditPath $auditPath
        $events.Count | Should Be 2
        $events[1].applyUsed | Should Be $false
        $events[1].fixLevel | Should Be 'safe'
    }

    It 'reports append-only audit log as valid' {
        Test-AuditLogAppendOnly -AuditPath $auditPath -MinimumEventCount 2 | Should Be $true
    }
}
