# nv-failsafe-recovery

Evidence-first Windows toolkit for NVIDIA **NV-Failsafe**, **640×480** fallback, HDMI/DisplayPort EDID handshake failure, generic monitor drift, and driver fallback states.

[![Python CI](https://github.com/Kozphy/nv-failsafe-recovery/actions/workflows/python-ci.yml/badge.svg)](https://github.com/Kozphy/nv-failsafe-recovery/actions/workflows/python-ci.yml)
[![Release](https://img.shields.io/github/v/release/Kozphy/nv-failsafe-recovery?label=release)](https://github.com/Kozphy/nv-failsafe-recovery/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Disclaimer:** This toolkit reports *suspected* states from local evidence. It does not prove hardware failure, does not guarantee fixes, and is not a substitute for vendor support or formal incident response.

**Version 2.0.0** is the Python implementation. PowerShell v1.1.0 is preserved under [`legacy/powershell/`](legacy/powershell/). See [Migration guide](docs/migration-powershell-to-python.md).

## Mission

```text
Observe → Classify → Recommend → Preview → Apply → Audit → Verify
```

Built for endpoint reliability, Windows support engineering, and audit-friendly operations — not one-click “fix my GPU” automation.

## Requirements

- Windows 10/11
- Python **3.11+**
- Administrator elevation for monitor/PnP remediation actions only

## Quick start

```powershell
git clone https://github.com/Kozphy/nv-failsafe-recovery.git
cd nv-failsafe-recovery
pip install -e ".[dev]"
python -m nv_failsafe_recovery --mode detect
```

```powershell
python -m nv_failsafe_recovery --mode report --output-path .\report.json
python -m nv_failsafe_recovery --mode doctor
```

## CLI examples

```powershell
# Preview safe fixes
python -m nv_failsafe_recovery --mode fix --fix-level safe

# Apply safe fixes
python -m nv_failsafe_recovery --mode fix --fix-level safe --apply

# Admin: monitor/PnP refresh
python -m nv_failsafe_recovery --mode fix --fix-level monitor --apply

# High risk: NVIDIA adapter restart
python -m nv_failsafe_recovery --mode fix --fix-level adapter --apply --force

# Verify against baseline report
python -m nv_failsafe_recovery --mode verify --baseline-report-path .\report.json
```

## Safety model

| Rule | Behavior |
|------|----------|
| Preview-first | No mutations without `--apply` |
| Adapter restart | Requires `--apply` **and** `--force` |
| Driver reinstall / DDU | Manual-only guidance |
| Audit | Append-only JSONL |
| Claims | Evidence-based language only |

Details: [docs/safety-model.md](docs/safety-model.md)

## Classification tags (summary)

| Tag | Meaning |
|-----|---------|
| `NV_FAILSAFE_SUSPECTED` | 640×480 + NVIDIA pattern |
| `LOW_RESOLUTION_FALLBACK` | Low resolution without NV-Failsafe pattern |
| `GENERIC_MONITOR_PROFILE_SUSPECTED` | Generic monitor names |
| `MONITOR_EDID_HANDSHAKE_SUSPECTED` | Handshake / PnP instability |
| `NVIDIA_DRIVER_FALLBACK_SUSPECTED` | Driver fallback indicators |
| `NO_ISSUE_DETECTED` | No active fallback detected |
| `INSUFFICIENT_DATA` | Probe collection incomplete |

## Scheduled reporting

Report-only at logon (never auto-fixes):

```powershell
python scripts/install_scheduled_task.py
```

Output: `%LOCALAPPDATA%\NvFailsafeRecovery\nv-failsafe-report.json`

## What this project does **not** do

- Uninstall/reinstall NVIDIA drivers automatically
- Run DDU or force custom resolutions
- Edit registry by default
- Kill arbitrary processes
- Claim guaranteed fixes or hardware verdicts from resolution alone

## Repository layout

```text
nv_failsafe_recovery/   Python package (CLI, evidence, policy, remediation)
scripts/                Smoke test and scheduled-task helpers
tests/                  pytest suite
docs/                   Architecture, safety, runbooks, migration
examples/               Sample reports, audit logs, doctor output
legacy/powershell/      PowerShell v1.1.0 sources (archived)
.github/                CI and release workflows
```

## Documentation

- [Architecture](docs/architecture.md)
- [Migration: PowerShell → Python](docs/migration-powershell-to-python.md)
- [Evidence schema](docs/evidence-schema.md) (v1.1.0)
- [Classification model](docs/classification-model.md)
- [Remediation policy](docs/remediation-policy.md)
- [Release process](docs/release-process.md)
- [FAQ](docs/faq.md)

## Releases

Tag-driven CD via [`.github/workflows/release.yml`](.github/workflows/release.yml):

```bash
# Update version in pyproject.toml, then:
git commit -am "Release v2.0.0"
git tag v2.0.0
git push origin main --tags
```

See [docs/release-process.md](docs/release-process.md).

## Local validation

```powershell
pip install -e ".[dev]"
python scripts/invoke_smoke_test.py
pytest
```

## License

MIT — see [LICENSE](LICENSE).
