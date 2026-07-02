# nv-failsafe-recovery

Evidence-first Windows toolkit for NVIDIA **NV-Failsafe**, **640×480** fallback, HDMI/DisplayPort EDID handshake failure, generic monitor drift, and driver fallback states.

[![PowerShell CI](https://github.com/Kozphy/nv-failsafe-recovery/actions/workflows/powershell-ci.yml/badge.svg)](https://github.com/Kozphy/nv-failsafe-recovery/actions/workflows/powershell-ci.yml)
[![Release](https://img.shields.io/github/v/release/Kozphy/nv-failsafe-recovery?label=release)](https://github.com/Kozphy/nv-failsafe-recovery/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Disclaimer:** This toolkit reports *suspected* states from local evidence. It does not prove hardware failure, does not guarantee fixes, and is not a substitute for vendor support or formal incident response.

## Mission

```text
Observe → Classify → Recommend → Preview → Apply → Audit → Verify
```

Built for endpoint reliability, Windows support engineering, and audit-friendly operations — not one-click “fix my GPU” automation.

## Problem overview

Windows may present:

```text
NV-Failsafe
640×480
Generic PnP Monitor
limited resolution list
```

Evidence often indicates handshake, monitor detection, or driver fallback issues — **before** assuming hardware failure.

## Safety model

| Rule | Behavior |
|------|----------|
| Preview-first | No mutations without `-Apply` |
| Adapter restart | Requires `-Apply` **and** `-Force` |
| Driver reinstall / DDU | Manual-only guidance |
| Audit | Append-only JSONL |
| Claims | Evidence-based language only |

Details: [docs/safety-model.md](docs/safety-model.md)

## Quick start

```powershell
git clone https://github.com/Kozphy/nv-failsafe-recovery.git
cd nv-failsafe-recovery
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Detect
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Report -OutputPath .\report.json
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Doctor
```

## CLI examples

```powershell
# Preview safe fixes
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel safe

# Apply safe fixes
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel safe -Apply

# Admin: monitor/PnP refresh
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel monitor -Apply

# High risk: NVIDIA adapter restart
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel adapter -Apply -Force

# Verify against baseline report
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Verify -BaselineReportPath .\report.json
```

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

## Troubleshooting

| Symptom | Tag | First step |
|---------|-----|------------|
| 640×480 + NVIDIA | `NV_FAILSAFE_SUSPECTED` | Win+Ctrl+Shift+B, reseat cable |
| Generic monitor | `GENERIC_MONITOR_PROFILE_SUSPECTED` | Check EDID/cable/port |
| GPU status not OK | `NVIDIA_DRIVER_FALLBACK_SUSPECTED` | Manual driver reinstall guidance |
| Probe failures | `INSUFFICIENT_DATA` | Re-run Report elevated |

Playbook: [docs/troubleshooting-playbook.md](docs/troubleshooting-playbook.md) · Runbook: [docs/runbook.md](docs/runbook.md)

## Scheduled reporting

Report-only at logon (never auto-fixes):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Install-ScheduledTask.ps1
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
scripts/   CLI entrypoints
src/       Evidence, classifier, policy, remediation, audit, reporting
tests/     Pester tests
docs/      Architecture, safety, runbooks, release process
examples/  Sample reports, audit logs, doctor output
.github/   CI and release workflows
```

## Documentation

- [Architecture](docs/architecture.md)
- [Evidence schema](docs/evidence-schema.md) (v1.1.0)
- [Classification model](docs/classification-model.md)
- [Remediation policy](docs/remediation-policy.md)
- [Release process](docs/release-process.md)
- [FAQ](docs/faq.md)

## Releases

Tag-driven CD via [`.github/workflows/release.yml`](.github/workflows/release.yml):

```bash
# Update ModuleVersion in psd1/NvFailsafeRecovery.psd1, then:
git commit -am "Release v1.1.0"
git tag v1.1.0
git push origin main --tags
```

See [docs/release-process.md](docs/release-process.md).

## Local validation

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-SmokeTest.ps1
Invoke-Pester -Path .\tests
```

## License

MIT — see [LICENSE](LICENSE).
