"""Append-only JSONL audit logging."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

from nv_failsafe_recovery.utilities import get_toolkit_version, to_json_serializable, utc_now_iso


def write_audit_event(
    audit_path: str,
    event_type: str,
    *,
    mode: str = "",
    classification: str = "",
    action: str = "",
    policy_decision: Any = None,
    result: str = "",
    error: str = "",
    fix_level: str = "",
    apply_used: bool = False,
    force_used: bool = False,
    execution_mode: str = "",
) -> None:
    directory = Path(audit_path).parent
    if str(directory) and str(directory) != ".":
        directory.mkdir(parents=True, exist_ok=True)

    event = {
        "timestamp": utc_now_iso(),
        "eventType": event_type,
        "mode": mode,
        "classification": classification,
        "action": action,
        "fixLevel": fix_level,
        "applyUsed": apply_used,
        "forceUsed": force_used,
        "executionMode": execution_mode,
        "policyDecision": to_json_serializable(policy_decision),
        "result": result,
        "error": error,
        "hostname": os.environ.get("COMPUTERNAME", ""),
        "username": os.environ.get("USERNAME", ""),
        "toolkitVersion": get_toolkit_version(),
    }

    line = json.dumps(event, separators=(",", ":")) + os.linesep
    with open(audit_path, "a", encoding="utf-8", newline="") as handle:
        handle.write(line)


def read_audit_events(audit_path: str) -> list[dict[str, Any]]:
    path = Path(audit_path)
    if not path.exists():
        return []

    events: list[dict[str, Any]] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        if raw_line.strip():
            events.append(json.loads(raw_line))
    return events


def audit_log_is_append_only(audit_path: str, minimum_event_count: int = 1) -> bool:
    if not Path(audit_path).exists():
        return False
    return len(read_audit_events(audit_path)) >= minimum_event_count
