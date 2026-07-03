import uuid
from pathlib import Path

from nv_failsafe_recovery.remediation import (
    invoke_nvidia_adapter_restart,
    invoke_pnp_rescan,
    invoke_safe_display_refresh,
)


def test_adapter_restart_blocked_without_apply_and_force(tmp_path: Path):
    audit_path = tmp_path / f"remediation-{uuid.uuid4()}.jsonl"
    result = invoke_nvidia_adapter_restart(
        apply=False, force=False, audit_path=str(audit_path), fix_level="adapter"
    )
    assert result["mode"] == "blocked"
    assert result["allowed"] is False


def test_adapter_restart_blocked_without_force_even_with_apply(tmp_path: Path):
    audit_path = tmp_path / f"remediation-{uuid.uuid4()}.jsonl"
    result = invoke_nvidia_adapter_restart(
        apply=True, force=False, audit_path=str(audit_path), fix_level="adapter"
    )
    assert result["allowed"] is False
    assert result["mode"] == "blocked"


def test_pnp_rescan_preview_does_not_execute_pnputil(tmp_path: Path):
    audit_path = tmp_path / f"remediation-{uuid.uuid4()}.jsonl"
    result = invoke_pnp_rescan(
        apply=False, audit_path=str(audit_path), fix_level="monitor"
    )
    assert result["mode"] in ("preview", "blocked")
    assert result["stdout"] == ""


def test_safe_display_refresh_preview_does_not_restart_explorer(tmp_path: Path):
    audit_path = tmp_path / f"remediation-{uuid.uuid4()}.jsonl"
    result = invoke_safe_display_refresh(apply=False, audit_path=str(audit_path))
    assert result["explorerRestarted"] is False
    assert result["mode"] == "preview"
