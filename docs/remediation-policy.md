# Remediation Policy

## Actions

| Action | Risk | Admin | -Apply | -Force | FixLevels |
|--------|------|-------|--------|--------|-----------|
| `DISPLAY_REFRESH_HINT` | low | no | no | no | safe, monitor, adapter |
| `EXPLORER_RESTART` | low | no | yes | no | safe, monitor, adapter |
| `PNP_RESCAN` | medium | yes | yes | no | monitor, adapter |
| `MONITOR_REFRESH` | medium | yes | yes | no | monitor, adapter |
| `ADAPTER_RESTART` | high | yes | yes | yes | adapter |
| `DRIVER_REINSTALL_GUIDANCE` | guidance | no | no | no | all |
| `DDU_LAST_RESORT_GUIDANCE` | guidance | no | no | no | all |

## Fix levels

| FixLevel | Intended use |
|----------|--------------|
| `none` | Detect/report only |
| `safe` | Hints + optional Explorer restart |
| `monitor` | Adds PnP/monitor refresh |
| `adapter` | Adds NVIDIA adapter restart (high risk) |

## Policy decision object

```json
{
  "action": "ADAPTER_RESTART",
  "allowed": false,
  "reason": "Requires administrator, -Apply, and -Force.",
  "requiredFlags": ["Apply", "Force"],
  "riskLevel": "high"
}
```

## Explicit non-actions

The toolkit **never** automates:

- Driver uninstall/reinstall
- DDU
- Custom resolution forcing
- Registry edits (default)
- Arbitrary process termination

## Audit requirements

Every apply action writes:

1. `remediation_start` (or `policy_blocked`)
2. `remediation_complete` / `remediation_error`

Audit path defaults to `.\nv-failsafe-audit.jsonl` and is append-only.
