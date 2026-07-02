# Evidence Schema

Report schema version: **1.1.0**

## Top-level report

| Field | Type | Description |
|-------|------|-------------|
| `schemaVersion` | string | Report schema version (`1.1.0`) |
| `generatedAt` | ISO-8601 | Report generation timestamp (UTC) |
| `mode` | string | CLI mode used |
| `hostname` | string | Computer name |
| `username` | string | Current user |
| `report` | object | Structured machine-readable summary (see below) |
| `summary` | object | Human-oriented summary block (backward compatible) |
| `evidence` | object | Full evidence bundle |
| `classification` | object | Classifier output |
| `policyPlan` | array | Optional policy decisions per action |
| `remediationResults` | array | Optional remediation execution results |
| `verification` | object | Optional before/after comparison |

## Structured `report` block (1.1.0)

| Field | Description |
|-------|-------------|
| `timestamp` | Evidence collection time |
| `hostname` | Computer name |
| `os` | OS probe data |
| `gpu_adapters` | GPU adapter objects |
| `display_adapters` | PnP display entities |
| `monitor_devices` | Monitor device objects |
| `current_resolution` | e.g. `1920x1080` |
| `suspected_tags` | Classification tags |
| `evidence_items` | Supporting evidence strings |
| `confidence_level` | 0..1 heuristic |
| `explanation` | Hypothesis summary (not proof) |
| `recommended_actions` | Policy-recommended actions |
| `preview_actions` | Actions that would run in preview |
| `applied_actions` | Actions executed in apply mode |
| `safety_warnings` | Safety reminders |
| `verification_result` | Verify comparison object |

## Probe object (`evidence.*`)

| Field | Values | Description |
|-------|--------|-------------|
| `status` | `ok`, `warning`, `error`, `unavailable` | Probe health |
| `source` | string | Data source identifier |
| `data` | object | Structured probe payload |
| `errorMessage` | string | Error detail when applicable |
| `collectedAt` | ISO-8601 | Probe timestamp |

## Audit event (JSONL)

| Field | Description |
|-------|-------------|
| `timestamp` | UTC event time |
| `eventType` | e.g. `session_start`, `policy_blocked` |
| `mode` | CLI mode |
| `classification` | Classification at event time |
| `action` | Remediation action if applicable |
| `fixLevel` | `none`, `safe`, `monitor`, `adapter` |
| `applyUsed` | Whether `-Apply` was active |
| `forceUsed` | Whether `-Force` was active |
| `executionMode` | `preview`, `apply`, `blocked`, `manual_only`, `guidance` |
| `policyDecision` | Embedded policy object |
| `result` | Event outcome |
| `error` | Error text |

See `examples/nv-failsafe-report.sample.json` and `examples/audit-log.sample.jsonl`.
