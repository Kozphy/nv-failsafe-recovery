# Classification Model

Classifications are **suspicion labels**, not diagnoses.

## Primary classifications

| Value | Meaning | Typical evidence |
|-------|---------|------------------|
| `NORMAL_DISPLAY_STATE` | No NV-Failsafe indicators | Normal resolution, stable monitors |
| `NV_FAILSAFE_SUSPECTED` | NVIDIA + 640x480 fallback pattern | 640x480 + NVIDIA adapter |
| `LOW_RESOLUTION_ONLY` | Low resolution without NVIDIA pattern | 640x480, no NVIDIA |
| `INSUFFICIENT_DATA` | Too many probe failures | Multiple `error`/`unavailable` probes |
| `ADMIN_REQUIRED` | Tag: elevated actions needed | Non-admin + remediation suggested |

## Secondary tags

| Tag | Meaning |
|-----|---------|
| `MONITOR_EDID_HANDSHAKE_SUSPECTED` | Generic/missing/unstable monitor entities |
| `NVIDIA_DRIVER_FALLBACK_SUSPECTED` | Non-OK GPU status or fallback-like video mode |
| `SLEEP_WAKE_DISPLAY_INIT_SUSPECTED` | Recent boot + display symptoms |
| `MONITOR_PNP_DRIFT_SUSPECTED` | PnP entity status drift |
| `ACTION_BLOCKED_BY_POLICY` | Used in policy/audit contexts |

## Rules (simplified)

1. **640x480 + NVIDIA** → `NV_FAILSAFE_SUSPECTED` (confidence ~0.82)
2. **640x480 + no NVIDIA** → `LOW_RESOLUTION_ONLY`
3. **Generic/missing monitors** → add handshake tag
4. **GPU status != OK** or fallback video mode → add driver fallback tag
5. **>=2 critical probe failures** → `INSUFFICIENT_DATA`
6. **Hardware failure** is not inferred unless stronger evidence exists (Code 43, crashes, artifacts, repeated adapter errors)

## Confidence

Confidence is heuristic and explainable:

- Starts from baseline (~0.35–0.55)
- Increases with corroborating probes
- Capped at 0.95
- Never presented as certainty

## Output contract

```json
{
  "classification": "NV_FAILSAFE_SUSPECTED",
  "confidence": 0.82,
  "evidence": [],
  "counterEvidence": [],
  "recommendedNextStep": "",
  "manualSteps": [],
  "automatedSteps": [],
  "riskNotes": [],
  "tags": []
}
```

Every `evidence[]` entry should be traceable to a probe in the report.
