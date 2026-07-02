# Classification Model

Classifications are **suspicion labels**, not diagnoses. Schema version **1.1.0**.

## Primary classifications

| Value | Meaning | Typical evidence |
|-------|---------|------------------|
| `NO_ISSUE_DETECTED` | No active NV-Failsafe fallback | Normal resolution, stable monitors |
| `NV_FAILSAFE_SUSPECTED` | NVIDIA + 640x480 fallback pattern | 640x480 + NVIDIA adapter |
| `LOW_RESOLUTION_FALLBACK` | Low resolution without NV-Failsafe pattern | 640x480 or low res, no NVIDIA |
| `INSUFFICIENT_DATA` | Too many probe failures | Multiple `error`/`unavailable` probes |

## Secondary tags (`suspected_tags`)

| Tag | Meaning |
|-----|---------|
| `MONITOR_EDID_HANDSHAKE_SUSPECTED` | NV-Failsafe name, missing monitors, unstable PnP |
| `GENERIC_MONITOR_PROFILE_SUSPECTED` | Generic/non-specific monitor names |
| `NVIDIA_DRIVER_FALLBACK_SUSPECTED` | Non-OK GPU status or fallback-like video mode |

## Required classifier output

Each result includes:

- `classification` — primary label
- `confidence` — bounded heuristic 0..1
- `evidence` — supporting strings
- `counterEvidence` — contradicting strings
- `explanation` — human-readable hypothesis summary
- `recommendedNextStep` — next operational step
- `manualSteps` / `automatedSteps`
- `riskNotes`
- `tags` — all suspected tags

## Rules (simplified)

1. **640x480 + NVIDIA** → `NV_FAILSAFE_SUSPECTED`
2. **640x480 + no NVIDIA** → `LOW_RESOLUTION_FALLBACK`
3. **Generic monitor names** → `GENERIC_MONITOR_PROFILE_SUSPECTED`
4. **Handshake indicators** → `MONITOR_EDID_HANDSHAKE_SUSPECTED`
5. **GPU status != OK** → `NVIDIA_DRIVER_FALLBACK_SUSPECTED`
6. **>=2 critical probe failures** → `INSUFFICIENT_DATA`
7. **Hardware failure** is not inferred from resolution alone

## Legacy mapping

| Legacy | Current |
|--------|---------|
| `NORMAL_DISPLAY_STATE` | `NO_ISSUE_DETECTED` |
| `LOW_RESOLUTION_ONLY` | `LOW_RESOLUTION_FALLBACK` |
