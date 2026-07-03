# PowerShell v1.1.0 (archived)

This directory preserves the original PowerShell implementation for reference and rollback.

**Primary implementation:** Python v2.0.0 in `nv_failsafe_recovery/` at the repository root.

## Run (legacy)

```powershell
powershell -ExecutionPolicy Bypass -File .\legacy\powershell\scripts\NvFailsafeRecovery.ps1 -Mode Detect
```

## Tests (legacy)

```powershell
Invoke-Pester -Path .\legacy\powershell\tests
```

See [docs/migration-powershell-to-python.md](../../docs/migration-powershell-to-python.md).
