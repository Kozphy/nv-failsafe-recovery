"""Policy gates for remediation actions."""

from __future__ import annotations

from typing import Any

ACTION_CATALOG: dict[str, dict[str, Any]] = {
    "DISPLAY_REFRESH_HINT": {
        "riskLevel": "low",
        "requiresAdmin": False,
        "requiresApply": False,
        "requiresForce": False,
        "manualOnly": False,
        "fixLevels": ["safe", "monitor", "adapter"],
    },
    "EXPLORER_RESTART": {
        "riskLevel": "low",
        "requiresAdmin": False,
        "requiresApply": True,
        "requiresForce": False,
        "manualOnly": False,
        "fixLevels": ["safe", "monitor", "adapter"],
    },
    "PNP_RESCAN": {
        "riskLevel": "medium",
        "requiresAdmin": True,
        "requiresApply": True,
        "requiresForce": False,
        "manualOnly": False,
        "fixLevels": ["monitor", "adapter"],
    },
    "MONITOR_REFRESH": {
        "riskLevel": "medium",
        "requiresAdmin": True,
        "requiresApply": True,
        "requiresForce": False,
        "manualOnly": False,
        "fixLevels": ["monitor", "adapter"],
    },
    "ADAPTER_RESTART": {
        "riskLevel": "high",
        "requiresAdmin": True,
        "requiresApply": True,
        "requiresForce": True,
        "manualOnly": False,
        "fixLevels": ["adapter"],
    },
    "DRIVER_REINSTALL_GUIDANCE": {
        "riskLevel": "guidance",
        "requiresAdmin": False,
        "requiresApply": False,
        "requiresForce": False,
        "manualOnly": True,
        "fixLevels": ["safe", "monitor", "adapter"],
    },
    "DDU_LAST_RESORT_GUIDANCE": {
        "riskLevel": "guidance",
        "requiresAdmin": False,
        "requiresApply": False,
        "requiresForce": False,
        "manualOnly": True,
        "fixLevels": ["safe", "monitor", "adapter"],
    },
}

FIX_LEVEL_ACTIONS: dict[str, list[str]] = {
    "safe": [
        "DISPLAY_REFRESH_HINT",
        "EXPLORER_RESTART",
        "DRIVER_REINSTALL_GUIDANCE",
        "DDU_LAST_RESORT_GUIDANCE",
    ],
    "monitor": [
        "DISPLAY_REFRESH_HINT",
        "EXPLORER_RESTART",
        "PNP_RESCAN",
        "MONITOR_REFRESH",
        "DRIVER_REINSTALL_GUIDANCE",
        "DDU_LAST_RESORT_GUIDANCE",
    ],
    "adapter": [
        "DISPLAY_REFRESH_HINT",
        "EXPLORER_RESTART",
        "PNP_RESCAN",
        "MONITOR_REFRESH",
        "ADAPTER_RESTART",
        "DRIVER_REINSTALL_GUIDANCE",
        "DDU_LAST_RESORT_GUIDANCE",
    ],
    "none": ["DISPLAY_REFRESH_HINT", "DRIVER_REINSTALL_GUIDANCE"],
}


def get_action_catalog() -> dict[str, dict[str, Any]]:
    return ACTION_CATALOG


def get_remediation_policy_decision(
    action: str,
    *,
    apply: bool = False,
    force: bool = False,
    is_administrator: bool = False,
    fix_level: str = "none",
) -> dict[str, Any]:
    if action not in ACTION_CATALOG:
        return {
            "action": action,
            "allowed": False,
            "reason": "Unknown action.",
            "requiredFlags": [],
            "riskLevel": "unknown",
            "manualOnly": False,
            "executionMode": "blocked",
        }

    meta = ACTION_CATALOG[action]
    required_flags: list[str] = []
    reasons: list[str] = []

    if fix_level == "none" and "safe" not in meta["fixLevels"] and "GUIDANCE" not in action:
        if action != "DISPLAY_REFRESH_HINT":
            reasons.append(f"FixLevel '{fix_level}' does not authorize this action.")

    if fix_level != "none" and fix_level not in meta["fixLevels"] and "GUIDANCE" not in action:
        reasons.append(f"Action not included in FixLevel '{fix_level}'.")

    if meta["requiresAdmin"] and not is_administrator:
        required_flags.append("Administrator")
        reasons.append("Requires administrator privileges.")

    if meta["requiresApply"] and not apply:
        required_flags.append("Apply")
        reasons.append("Requires --apply flag.")

    if meta["requiresForce"] and not force:
        required_flags.append("Force")
        reasons.append("Requires --force flag.")

    if action in ("DDU_LAST_RESORT_GUIDANCE", "DRIVER_REINSTALL_GUIDANCE"):
        return {
            "action": action,
            "allowed": True,
            "reason": "Manual-only escalation; toolkit provides guidance only.",
            "requiredFlags": [],
            "riskLevel": meta["riskLevel"],
            "manualOnly": True,
            "executionMode": "manual_only",
        }

    allowed = len(reasons) == 0
    reason = "Action permitted by policy." if allowed else " ".join(reasons)

    if meta["manualOnly"]:
        execution_mode = "manual_only"
    elif meta["requiresApply"] and not apply:
        execution_mode = "preview"
    elif apply and allowed:
        execution_mode = "apply"
    else:
        execution_mode = "preview"

    return {
        "action": action,
        "allowed": allowed,
        "reason": reason,
        "requiredFlags": required_flags,
        "riskLevel": meta["riskLevel"],
        "manualOnly": bool(meta["manualOnly"]),
        "executionMode": execution_mode,
    }


def action_is_allowed(
    action: str,
    *,
    apply: bool = False,
    force: bool = False,
    is_administrator: bool = False,
    fix_level: str = "none",
) -> bool:
    decision = get_remediation_policy_decision(
        action,
        apply=apply,
        force=force,
        is_administrator=is_administrator,
        fix_level=fix_level,
    )
    return bool(decision["allowed"])


def get_fix_plan(
    fix_level: str = "none",
    *,
    apply: bool = False,
    force: bool = False,
    is_administrator: bool = False,
    classification: Any = None,  # noqa: ARG001 — parity with PowerShell signature
) -> list[dict[str, Any]]:
    actions = FIX_LEVEL_ACTIONS.get(fix_level, FIX_LEVEL_ACTIONS["none"])
    plan: list[dict[str, Any]] = []
    for action in actions:
        decision = get_remediation_policy_decision(
            action,
            apply=apply,
            force=force,
            is_administrator=is_administrator,
            fix_level=fix_level,
        )
        if decision["manualOnly"]:
            execution_mode = "manual_only"
        elif apply and decision["allowed"]:
            execution_mode = "apply"
        else:
            execution_mode = "preview"
        plan.append(
            {
                "action": action,
                "allowed": decision["allowed"],
                "reason": decision["reason"],
                "requiredFlags": decision["requiredFlags"],
                "riskLevel": decision["riskLevel"],
                "manualOnly": decision["manualOnly"],
                "executionMode": execution_mode,
            }
        )
    return plan
