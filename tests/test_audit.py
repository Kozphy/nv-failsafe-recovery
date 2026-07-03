import uuid
from pathlib import Path

from nv_failsafe_recovery.audit import audit_log_is_append_only, read_audit_events, write_audit_event


def test_appends_events_without_overwriting(tmp_path: Path):
    audit_path = tmp_path / f"audit-{uuid.uuid4()}.jsonl"
    write_audit_event(
        str(audit_path),
        "test_event",
        mode="Detect",
        result="started",
        execution_mode="preview",
    )
    write_audit_event(
        str(audit_path),
        "test_event",
        mode="Detect",
        result="success",
        execution_mode="preview",
        apply_used=False,
        force_used=False,
        fix_level="safe",
    )

    events = read_audit_events(str(audit_path))
    assert len(events) == 2
    assert events[1]["applyUsed"] is False
    assert events[1]["fixLevel"] == "safe"


def test_reports_append_only_audit_log_as_valid(tmp_path: Path):
    audit_path = tmp_path / f"audit-{uuid.uuid4()}.jsonl"
    write_audit_event(str(audit_path), "test_event", mode="Detect", result="started")
    write_audit_event(str(audit_path), "test_event", mode="Detect", result="success")
    assert audit_log_is_append_only(str(audit_path), minimum_event_count=2)
