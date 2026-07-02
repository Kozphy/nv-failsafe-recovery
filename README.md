# nv-failsafe-recovery

Evidence-first NVIDIA NV-Failsafe / 640×480 recovery toolkit for Windows display fallback, HDMI/DisplayPort EDID handshake failure, monitor detection drift, and NVIDIA driver fallback states.

[![PowerShell CI](https://github.com/Kozphy/nv-failsafe-recovery/actions/workflows/powershell-ci.yml/badge.svg)](https://github.com/Kozphy/nv-failsafe-recovery/actions/workflows/powershell-ci.yml)

## Problem overview

Windows sometimes detects an NVIDIA display as:

```text
NV-Failsafe
640×480
generic/fallback monitor
limited resolution list
```

In practice, the desktop may look like a low-resolution VGA-style fallback even though the system has a modern NVIDIA GPU and monitor attached.

### What NV-Failsafe / 640×480 usually means

Evidence often indicates the system could not establish a stable monitor configuration and fell back to a safe mode. This is **suspected fallback behavior**, not proof of GPU failure.

### Why HDMI / EDID handshake failure can cause this

Monitors expose capabilities via EDID during link training on HDMI/DisplayPort. If hot-plug detect (HPD) or EDID negotiation fails, Windows may cache a generic monitor profile and constrain available resolutions.

### Why unplug/replug HDMI can fix it

Re-seating the cable repeats HPD + EDID negotiation. If the issue is transient handshake or port/cable instability, the monitor may be re-detected correctly.

## Mission

Build a safe, auditable, evidence-first Windows toolkit that:

```text
Observe → Classify → Recommend → Preview → Apply → Audit → Verify
```

The toolkit never claims certainty without evidence.

## Safety model (summary)

- Preview-only by default
- No changes without `-Apply`
- Adapter restart requires `-Apply` **and** `-Force`
- Never uninstalls NVIDIA drivers
- Never runs DDU
- Never forces custom resolution
- Append-only audit logging

See [docs/safety-model.md](docs/safety-model.md).

## Installation

```powershell
git clone https://github.com/Kozphy/nv-failsafe-recovery.git
cd nv-failsafe-recovery
```

No external PowerShell modules required.

## Quick start

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Detect
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Report -OutputPath .\report.json
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Doctor
```

## CLI examples

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel safe
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel safe -Apply
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel monitor -Apply
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel adapter -Apply -Force
```

## Common scenarios

| Scenario | Likely hypothesis | First steps |
|----------|-------------------|-------------|
| 640×480 after sleep/wake | sleep/wake init race | Win+Ctrl+Shift+B, disable Fast Startup |
| NV-Failsafe after cable bump | EDID/HPD handshake | Reseat cable, try another port |
| Generic monitor every boot | PnP/monitor drift | Report on boot, monitor rescan |
| NVIDIA status not OK | driver fallback suspected | Safe fix, driver reinstall guidance |

## Decision tree (short)

```text
Report → review classification/evidence
  → manual low-risk steps
  → Fix preview
  → Fix apply (minimum FixLevel)
  → Verify
  → escalate to manual driver reinstall
  → DDU only as last resort (manual)
```

Full tree: [docs/decision-tree.md](docs/decision-tree.md)

## Troubleshooting table

| Symptom | Classification tag | Recommended next step |
|---------|-------------------|------------------------|
| 640×480 + NVIDIA | `NV_FAILSAFE_SUSPECTED` | Win+Ctrl+Shift+B, cable reseat |
| Generic monitor name | `MONITOR_EDID_HANDSHAKE_SUSPECTED` | Try other cable/port |
| GPU status not OK | `NVIDIA_DRIVER_FALLBACK_SUSPECTED` | Driver reinstall guidance |
| Probe failures | `INSUFFICIENT_DATA` | Re-run Report elevated |

Playbook: [docs/troubleshooting-playbook.md](docs/troubleshooting-playbook.md)

## Scheduled reporting (optional)

Install logon Report-only task:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Install-ScheduledTask.ps1
```

Output path:

```text
%LOCALAPPDATA%\NvFailsafeRecovery\nv-failsafe-report.json
```

Uninstall:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Uninstall-ScheduledTask.ps1
```

## What this project does **not** do

- Uninstall or reinstall NVIDIA drivers automatically
- Run DDU
- Force custom resolutions
- Edit the registry by default
- Kill arbitrary processes
- Claim guaranteed fixes
- Prove hardware failure from resolution alone

## Repository layout

```text
scripts/   CLI entrypoints
src/       Evidence, classifier, policy, remediation, audit, reporting
tests/     Pester tests
docs/      Architecture, safety, runbooks
examples/  Sample JSON reports and audit logs
```

## Documentation

- [Architecture](docs/architecture.md)
- [Evidence schema](docs/evidence-schema.md)
- [Classification model](docs/classification-model.md)
- [Remediation policy](docs/remediation-policy.md)
- [Runbook](docs/runbook.md)
- [FAQ](docs/faq.md)

## GitHub publish

```bash
git init
git add .
git commit -m "Initial NV-Failsafe recovery toolkit"
gh repo create nv-failsafe-recovery --public --source=. --remote=origin --push
```

## License

MIT — see [LICENSE](LICENSE).
