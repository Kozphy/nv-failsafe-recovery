"""Policy-gated remediation actions."""

from __future__ import annotations

import subprocess
import time
from typing import Any

from nv_failsafe_recovery.audit import write_audit_event
from nv_failsafe_recovery.evidence import is_windows
from nv_failsafe_recovery.policy import get_remediation_policy_decision


def _run_powershell_pnp_toggle(instance_id: str, enable: bool) -> None:
    """Fallback shim: PowerShell PnP cmdlets when native Python bindings are unavailable."""
    cmdlet = "Enable-PnpDevice" if enable else "Disable-PnpDevice"
    command = f"{cmdlet} -InstanceId '{instance_id}' -Confirm:$false -ErrorAction Stop"
    completed = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", command],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise RuntimeError(detail or f"{cmdlet} failed for {instance_id}")


def invoke_safe_display_refresh(
    *,
    apply: bool = False,
    audit_path: str = "./nv-failsafe-audit.jsonl",
    mode: str = "Fix",
    classification: str = "",
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "action": "DISPLAY_REFRESH_HINT",
        "mode": "apply" if apply else "preview",
        "messages": [
            "Recommended manual step: press Win+Ctrl+Shift+B to reset the graphics subsystem.",
            "This is a low-risk user action and does not require administrator privileges.",
        ],
        "explorerRestarted": False,
        "exitCode": 0,
    }

    write_audit_event(
        audit_path,
        "remediation_preview",
        mode=mode,
        classification=classification,
        action="DISPLAY_REFRESH_HINT",
        result="preview",
        policy_decision={"allowed": True},
    )

    if apply:
        explorer_decision = get_remediation_policy_decision(
            "EXPLORER_RESTART", apply=True, fix_level="safe"
        )
        if explorer_decision["allowed"] and is_windows():
            try:
                write_audit_event(
                    audit_path,
                    "remediation_start",
                    mode=mode,
                    classification=classification,
                    action="EXPLORER_RESTART",
                    policy_decision=explorer_decision,
                )
                subprocess.run(
                    ["taskkill", "/IM", "explorer.exe", "/F"],
                    capture_output=True,
                    check=False,
                )
                subprocess.Popen(["explorer.exe"])  # noqa: S603
                result["explorerRestarted"] = True
                result["messages"].append(
                    "Explorer was restarted as part of safe display refresh."
                )
                write_audit_event(
                    audit_path,
                    "remediation_complete",
                    mode=mode,
                    classification=classification,
                    action="EXPLORER_RESTART",
                    result="success",
                )
            except Exception as exc:  # noqa: BLE001
                result["exitCode"] = 1
                result["messages"].append(f"Explorer restart failed: {exc}")
                write_audit_event(
                    audit_path,
                    "remediation_error",
                    mode=mode,
                    classification=classification,
                    action="EXPLORER_RESTART",
                    result="error",
                    error=str(exc),
                )
        else:
            result["messages"].append(
                "Explorer restart blocked by policy; manual Win+Ctrl+Shift+B remains recommended."
            )

    return result


def invoke_pnp_rescan(
    *,
    apply: bool = False,
    force: bool = False,
    audit_path: str = "./nv-failsafe-audit.jsonl",
    mode: str = "Fix",
    classification: str = "",
    fix_level: str = "monitor",
) -> dict[str, Any]:
    decision = get_remediation_policy_decision(
        "PNP_RESCAN", apply=apply, force=force, fix_level=fix_level
    )
    if not decision["allowed"]:
        write_audit_event(
            audit_path,
            "policy_blocked",
            mode=mode,
            classification=classification,
            action="PNP_RESCAN",
            policy_decision=decision,
            result="blocked",
        )
        return {
            "action": "PNP_RESCAN",
            "mode": "blocked",
            "allowed": False,
            "reason": decision["reason"],
            "exitCode": 0,
            "stdout": "",
            "stderr": "",
        }

    if not apply:
        write_audit_event(
            audit_path,
            "remediation_preview",
            mode=mode,
            classification=classification,
            action="PNP_RESCAN",
            policy_decision=decision,
            result="preview",
        )
        return {
            "action": "PNP_RESCAN",
            "mode": "preview",
            "allowed": True,
            "reason": "Would execute: pnputil /scan-devices",
            "exitCode": 0,
            "stdout": "",
            "stderr": "",
        }

    write_audit_event(
        audit_path,
        "remediation_start",
        mode=mode,
        classification=classification,
        action="PNP_RESCAN",
        policy_decision=decision,
    )

    stdout = ""
    stderr = ""
    exit_code = 0
    try:
        completed = subprocess.run(
            ["pnputil.exe", "/scan-devices"],
            capture_output=True,
            text=True,
            check=False,
        )
        exit_code = completed.returncode
        stdout = (completed.stdout or completed.stderr or "").strip()
        if completed.returncode != 0:
            stderr = (completed.stderr or "").strip()
    except Exception as exc:  # noqa: BLE001
        exit_code = 1
        stderr = str(exc)

    result_status = "success" if exit_code == 0 else "error"
    write_audit_event(
        audit_path,
        "remediation_complete",
        mode=mode,
        classification=classification,
        action="PNP_RESCAN",
        result=result_status,
        error=stderr,
    )

    return {
        "action": "PNP_RESCAN",
        "mode": "apply",
        "allowed": True,
        "reason": decision["reason"],
        "exitCode": exit_code,
        "stdout": stdout,
        "stderr": stderr,
    }


def _list_pnp_devices(device_class: str) -> list[dict[str, str]]:
    import json

    script = (
        f"Get-PnpDevice -Class {device_class} -ErrorAction SilentlyContinue | "
        "Select-Object FriendlyName,InstanceId,Class | ConvertTo-Json -Compress"
    )
    completed = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", script],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0 or not completed.stdout.strip():
        return []
    payload = json.loads(completed.stdout)
    if isinstance(payload, dict):
        return [payload]
    return list(payload)


def invoke_monitor_refresh(
    *,
    apply: bool = False,
    force: bool = False,
    audit_path: str = "./nv-failsafe-audit.jsonl",
    mode: str = "Fix",
    classification: str = "",
    fix_level: str = "monitor",
) -> dict[str, Any]:
    decision = get_remediation_policy_decision(
        "MONITOR_REFRESH", apply=apply, force=force, fix_level=fix_level
    )
    if not decision["allowed"]:
        write_audit_event(
            audit_path,
            "policy_blocked",
            mode=mode,
            classification=classification,
            action="MONITOR_REFRESH",
            policy_decision=decision,
            result="blocked",
        )
        return {
            "action": "MONITOR_REFRESH",
            "mode": "blocked",
            "allowed": False,
            "reason": decision["reason"],
            "refreshedCount": 0,
        }

    if not apply:
        write_audit_event(
            audit_path,
            "remediation_preview",
            mode=mode,
            classification=classification,
            action="MONITOR_REFRESH",
            policy_decision=decision,
            result="preview",
        )
        return {
            "action": "MONITOR_REFRESH",
            "mode": "preview",
            "allowed": True,
            "reason": "Would refresh monitor/display PnP entities without disabling GPU.",
            "refreshedCount": 0,
        }

    write_audit_event(
        audit_path,
        "remediation_start",
        mode=mode,
        classification=classification,
        action="MONITOR_REFRESH",
        policy_decision=decision,
    )

    refreshed = 0
    errors: list[str] = []
    try:
        targets = [
            device
            for device in _list_pnp_devices("Monitor")
            if device.get("InstanceId") and device.get("Class") == "Monitor"
        ]
        for device in targets:
            instance_id = device["InstanceId"]
            try:
                _run_powershell_pnp_toggle(instance_id, enable=False)
                _run_powershell_pnp_toggle(instance_id, enable=True)
                refreshed += 1
            except Exception as exc:  # noqa: BLE001
                errors.append(f"Failed to refresh {instance_id}: {exc}")
    except Exception as exc:  # noqa: BLE001
        errors.append(str(exc))

    result_status = "success" if not errors else "error"
    write_audit_event(
        audit_path,
        "remediation_complete",
        mode=mode,
        classification=classification,
        action="MONITOR_REFRESH",
        result=result_status,
        error="; ".join(errors),
    )

    return {
        "action": "MONITOR_REFRESH",
        "mode": "apply",
        "allowed": True,
        "reason": decision["reason"],
        "refreshedCount": refreshed,
        "errors": errors,
    }


def invoke_nvidia_adapter_restart(
    *,
    apply: bool = False,
    force: bool = False,
    audit_path: str = "./nv-failsafe-audit.jsonl",
    mode: str = "Fix",
    classification: str = "",
    fix_level: str = "adapter",
) -> dict[str, Any]:
    decision = get_remediation_policy_decision(
        "ADAPTER_RESTART", apply=apply, force=force, fix_level=fix_level
    )
    if not decision["allowed"]:
        write_audit_event(
            audit_path,
            "policy_blocked",
            mode=mode,
            classification=classification,
            action="ADAPTER_RESTART",
            policy_decision=decision,
            result="blocked",
        )
        return {
            "action": "ADAPTER_RESTART",
            "mode": "blocked",
            "allowed": False,
            "reason": decision["reason"],
            "warning": "High-risk operation blocked. May cause temporary loss of display output.",
            "adapters": [],
            "restartedCount": 0,
        }

    nvidia_adapters = [
        device
        for device in _list_pnp_devices("Display")
        if "VEN_10DE" in (device.get("InstanceId") or "")
        or "NVIDIA" in (device.get("FriendlyName") or "").upper()
    ]

    if not apply:
        write_audit_event(
            audit_path,
            "remediation_preview",
            mode=mode,
            classification=classification,
            action="ADAPTER_RESTART",
            policy_decision=decision,
            result="preview",
        )
        return {
            "action": "ADAPTER_RESTART",
            "mode": "preview",
            "allowed": True,
            "reason": (
                "Would disable/enable NVIDIA display adapters only. "
                "HIGH RISK: may blank display briefly."
            ),
            "warning": "Requires --apply and --force by design.",
            "adapters": [a.get("InstanceId") for a in nvidia_adapters],
            "restartedCount": 0,
        }

    write_audit_event(
        audit_path,
        "remediation_start",
        mode=mode,
        classification=classification,
        action="ADAPTER_RESTART",
        policy_decision=decision,
        result="warning",
    )

    restarted = 0
    errors: list[str] = []
    for adapter in nvidia_adapters:
        instance_id = adapter.get("InstanceId")
        if not instance_id:
            continue
        try:
            _run_powershell_pnp_toggle(instance_id, enable=False)
            time.sleep(2)
            _run_powershell_pnp_toggle(instance_id, enable=True)
            restarted += 1
        except Exception as exc:  # noqa: BLE001
            errors.append(f"Adapter restart failed for {instance_id}: {exc}")

    if not errors and restarted > 0:
        result_status = "success"
    elif restarted > 0:
        result_status = "partial"
    else:
        result_status = "error"

    write_audit_event(
        audit_path,
        "remediation_complete",
        mode=mode,
        classification=classification,
        action="ADAPTER_RESTART",
        result=result_status,
        error="; ".join(errors),
    )

    return {
        "action": "ADAPTER_RESTART",
        "mode": "apply",
        "allowed": True,
        "reason": decision["reason"],
        "warning": "NVIDIA adapter restart completed; verify display output immediately.",
        "adapters": [a.get("InstanceId") for a in nvidia_adapters],
        "restartedCount": restarted,
        "errors": errors,
    }


def invoke_remediation_plan(
    plan: list[dict[str, Any]],
    *,
    apply: bool = False,
    force: bool = False,
    audit_path: str = "./nv-failsafe-audit.jsonl",
    mode: str = "Fix",
    classification: str = "",
    fix_level: str = "none",
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for item in plan:
        action = item.get("action")
        if action == "DISPLAY_REFRESH_HINT":
            results.append(
                invoke_safe_display_refresh(
                    apply=apply,
                    audit_path=audit_path,
                    mode=mode,
                    classification=classification,
                )
            )
        elif action == "EXPLORER_RESTART":
            if item.get("allowed") and apply:
                results.append(
                    invoke_safe_display_refresh(
                        apply=True,
                        audit_path=audit_path,
                        mode=mode,
                        classification=classification,
                    )
                )
        elif action == "PNP_RESCAN":
            results.append(
                invoke_pnp_rescan(
                    apply=apply,
                    force=force,
                    audit_path=audit_path,
                    mode=mode,
                    classification=classification,
                    fix_level=fix_level,
                )
            )
        elif action == "MONITOR_REFRESH":
            results.append(
                invoke_monitor_refresh(
                    apply=apply,
                    force=force,
                    audit_path=audit_path,
                    mode=mode,
                    classification=classification,
                    fix_level=fix_level,
                )
            )
        elif action == "ADAPTER_RESTART":
            results.append(
                invoke_nvidia_adapter_restart(
                    apply=apply,
                    force=force,
                    audit_path=audit_path,
                    mode=mode,
                    classification=classification,
                    fix_level=fix_level,
                )
            )
        elif action == "DRIVER_REINSTALL_GUIDANCE":
            results.append(
                {
                    "action": "DRIVER_REINSTALL_GUIDANCE",
                    "mode": "guidance",
                    "messages": [
                        "Recommended next step: perform a clean NVIDIA driver reinstall from NVIDIA official packages.",
                        "This toolkit does not uninstall or reinstall drivers automatically.",
                    ],
                }
            )
        elif action == "DDU_LAST_RESORT_GUIDANCE":
            results.append(
                {
                    "action": "DDU_LAST_RESORT_GUIDANCE",
                    "mode": "guidance",
                    "messages": [
                        "DDU is a last-resort manual procedure only.",
                        "This toolkit never runs DDU or destructive driver removal.",
                    ],
                }
            )
        else:
            raise ValueError(f"Unhandled remediation action: {action}")
    return results
