# Migration: PowerShell v1.1.0 → Python v2.0.0

## Overview

| | PowerShell v1.1.0 | Python v2.0.0 |
|---|-------------------|---------------|
| Entry | `scripts/NvFailsafeRecovery.ps1` | `python -m nv_failsafe_recovery` |
| Version file | `psd1/NvFailsafeRecovery.psd1` | `pyproject.toml` |
| Tests | Pester (`legacy/powershell/tests/`) | pytest (`tests/`) |
| Report schema | 1.1.0 | **1.1.0 (unchanged)** |

PowerShell sources are preserved under `legacy/powershell/` for reference and rollback.

## CLI flag mapping

| PowerShell | Python |
|------------|--------|
| `-Mode Detect` | `--mode detect` |
| `-Mode Report` | `--mode report` |
| `-Mode Doctor` | `--mode doctor` |
| `-Mode Fix` | `--mode fix` |
| `-Mode Verify` | `--mode verify` |
| `-FixLevel safe` | `--fix-level safe` |
| `-Apply` | `--apply` |
| `-Force` | `--force` |
| `-OutputPath` | `--output-path` |
| `-AuditPath` | `--audit-path` |
| `-BaselineReportPath` | `--baseline-report-path` |
| `-Json` | `--json` |
| `-Quiet` | `--quiet` |

## JSON compatibility

- Report files produced by Python use `schemaVersion: "1.1.0"` and the same top-level `report` block fields.
- Audit JSONL events retain `fixLevel`, `applyUsed`, `forceUsed`, and `executionMode`.
- The `summary.powershellVersion` field is retained for backward compatibility; it now contains the Python runtime version. `summary.runtimeVersion` is also set.

## Scheduled tasks

Replace PowerShell logon tasks:

```powershell
# Uninstall old task if present
powershell -File legacy/powershell/scripts/Uninstall-ScheduledTask.ps1

# Install Python report-only task
python scripts/install_scheduled_task.py
```

## Safety model

Unchanged: preview-first, `--apply` / `--force` gates, manual-only driver/DDU guidance, append-only audit.

## When to stay on PowerShell

- Endpoints without Python installed and no software deployment path
- Environments that forbid Python but allow signed PowerShell scripts

For new deployments, Python v2.0.0 is the supported primary implementation.
