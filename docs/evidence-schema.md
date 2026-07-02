# Evidence Schema

Report schema version: `1.0.0`

## Top-level report

| Field | Type | Description |
|-------|------|-------------|
| `schemaVersion` | string | Report schema version |
| `generatedAt` | ISO-8601 | Report generation timestamp (UTC) |
| `mode` | string | CLI mode used |
| `hostname` | string | Computer name |
| `username` | string | Current user |
| `summary` | object | Human-oriented summary block |
| `evidence` | object | Full evidence bundle |
| `classification` | object | Classifier output |
| `policyPlan` | array | Optional policy decisions per action |
| `remediationResults` | array | Optional remediation execution results |
| `verification` | object | Optional before/after comparison |

## Summary block

| Field | Description |
|-------|-------------|
| `activeDisplayResolution` | e.g. `2560x1440` |
| `is640x480` | True when exactly 640x480 |
| `isSuspiciouslyLow` | True when resolution <= 800x600 |
| `nvidiaAdapterPresent` | NVIDIA adapter detected |
| `gpuName` | Primary GPU friendly name |
| `gpuStatus` | CIM status |
| `driverVersion` | Installed driver version |
| `pnpDeviceId` | Primary GPU PnP ID |
| `currentVideoMode` | Active video mode description |
| `monitorCount` | Enumerated monitors |
| `monitorNames` | Monitor friendly names |
| `monitorPnPStatus` | Monitor statuses |
| `classification` | Primary classification |
| `confidence` | 0..1 heuristic confidence |
| `recommendedNextStep` | Next operational step |
| `safetyNotes` | Safety reminders |

## Probe object (`evidence.*`)

Each probe includes:

| Field | Values | Description |
|-------|--------|-------------|
| `status` | `ok`, `warning`, `error`, `unavailable` | Probe health |
| `source` | string | Data source identifier |
| `data` | object | Structured probe payload |
| `errorMessage` | string | Error detail when applicable |
| `collectedAt` | ISO-8601 | Probe timestamp |

## Classification object

| Field | Description |
|-------|-------------|
| `classification` | Primary enum value |
| `confidence` | Bounded heuristic score |
| `evidence` | Supporting evidence strings |
| `counterEvidence` | Contradicting evidence strings |
| `recommendedNextStep` | Primary recommendation |
| `manualSteps` | Manual operator steps |
| `automatedSteps` | Toolkit step suggestions |
| `riskNotes` | Risk qualifiers |
| `tags` | Additional classification tags |

## Audit event (JSONL)

| Field | Description |
|-------|-------------|
| `timestamp` | UTC event time |
| `eventType` | e.g. `session_start`, `policy_blocked` |
| `mode` | CLI mode |
| `classification` | Classification at event time |
| `action` | Remediation action if applicable |
| `policyDecision` | Embedded policy object |
| `result` | `started`, `preview`, `success`, `blocked`, `error` |
| `error` | Error text |
| `hostname` | Computer name |
| `username` | User name |

See `examples/` for realistic samples.
