from nv_failsafe_recovery.policy import get_fix_plan, get_remediation_policy_decision


def test_blocks_adapter_restart_without_force():
    decision = get_remediation_policy_decision(
        "ADAPTER_RESTART",
        apply=True,
        force=False,
        is_administrator=True,
        fix_level="adapter",
    )
    assert decision["allowed"] is False
    assert "Force" in decision["requiredFlags"]


def test_blocks_pnp_rescan_without_admin():
    decision = get_remediation_policy_decision(
        "PNP_RESCAN",
        apply=True,
        force=False,
        is_administrator=False,
        fix_level="monitor",
    )
    assert decision["allowed"] is False
    assert "Administrator" in decision["requiredFlags"]


def test_allows_display_refresh_hint_without_apply():
    decision = get_remediation_policy_decision(
        "DISPLAY_REFRESH_HINT", apply=False, fix_level="safe"
    )
    assert decision["allowed"] is True


def test_blocks_explorer_restart_without_apply():
    decision = get_remediation_policy_decision(
        "EXPLORER_RESTART", apply=False, fix_level="safe"
    )
    assert decision["allowed"] is False
    assert "Apply" in decision["requiredFlags"]


def test_allows_adapter_restart_with_apply_force_and_admin():
    decision = get_remediation_policy_decision(
        "ADAPTER_RESTART",
        apply=True,
        force=True,
        is_administrator=True,
        fix_level="adapter",
    )
    assert decision["allowed"] is True


def test_marks_driver_reinstall_guidance_as_manual_only():
    decision = get_remediation_policy_decision(
        "DRIVER_REINSTALL_GUIDANCE", apply=False, fix_level="safe"
    )
    assert decision["allowed"] is True
    assert decision["manualOnly"] is True
    assert decision["executionMode"] == "manual_only"


def test_fix_plan_defaults_to_preview_when_apply_false():
    plan = get_fix_plan("monitor", apply=False, is_administrator=True)
    pnp = next(item for item in plan if item["action"] == "PNP_RESCAN")
    assert pnp["executionMode"] == "preview"
