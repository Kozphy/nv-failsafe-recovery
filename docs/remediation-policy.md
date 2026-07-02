# Remediation Policy

## Actions

| Action | Risk | Admin | -Apply | -Force | FixLevels | Escalation |
|--------|------|-------|--------|--------|-----------|------------|
| `DISPLAY_REFRESH_HINT` | low | no | no | no | safe, monitor, adapter | automated preview |
| `EXPLORER_RESTART` | low | no | yes | no | safe, monitor, adapter | automated apply |
| `PNP_RESCAN` | medium | yes | yes | no | monitor, adapter | automated apply |
| `MONITOR_REFRESH` | medium | yes | yes | no | monitor, adapter | automated apply |
| `ADAPTER_RESTART` | high | yes | yes | yes | adapter | automated apply |
| `DRIVER_REINSTALL_GUIDANCE` | guidance | no | no | no | all | **manual-only** |
| `DDU_LAST_RESORT_GUIDANCE` | guidance | no | no | no | all | **manual-only** |

## Manual-only escalation

These are never executed by the toolkit:

- NVIDIA driver reinstall
- DDU usage
- Custom resolution forcing
- Hardware replacement decisions

## Policy decision object

```json
{
  "action": "ADAPTER_RESTART",
  "allowed": false,
  "reason": "Requires -Force flag.",
  "requiredFlags": ["Force"],
  "riskLevel": "high",
  "manualOnly": false,
  "executionMode": "preview"
}
```

`executionMode` values: `preview`, `apply`, `blocked`, `manual_only`.

## Audit requirements

Every preview/apply/blocked action logs:

- `action`, `timestamp`, `mode`, `fixLevel`
- `applyUsed`, `forceUsed`, `executionMode`
- `policyDecision`, `result`, `error`

Audit logs are append-only.
