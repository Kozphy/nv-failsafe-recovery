"""Report generation and comparison."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from nv_failsafe_recovery.utilities import get_report_schema_version, to_json_serializable, utc_now_iso


def get_report_action_lists(
    policy_plan: list[dict[str, Any]] | None,
    remediation_results: list[dict[str, Any]] | None,
) -> dict[str, list[str]]:
    preview: list[str] = []
    applied: list[str] = []
    recommended: list[str] = []

    if policy_plan:
        for item in policy_plan:
            if item.get("manualOnly"):
                recommended.append(f"{item['action']} (manual-only)")
            elif item.get("executionMode") == "preview" and item.get("allowed"):
                preview.append(item["action"])
            elif item.get("executionMode") == "apply":
                preview.append(item["action"])
            elif not item.get("allowed"):
                recommended.append(f"{item['action']} (blocked: {item.get('reason', '')})")

    if remediation_results:
        for result in remediation_results:
            if result.get("mode") in ("apply", "guidance") and result.get("action"):
                applied.append(result["action"])

    return {
        "previewActions": preview,
        "appliedActions": applied,
        "recommendedActions": recommended,
    }


def new_nv_failsafe_report(
    evidence: dict[str, Any],
    classification: dict[str, Any],
    *,
    mode: str = "Detect",
    policy_plan: list[dict[str, Any]] | None = None,
    remediation_results: list[dict[str, Any]] | None = None,
    verification: dict[str, Any] | None = None,
) -> dict[str, Any]:
    resolution = None
    display = evidence.get("display") or {}
    if display.get("status") == "ok":
        resolution = (display.get("data") or {}).get("activeResolution")

    gpu_adapters: list[Any] = []
    nvidia_present = False
    gpu_name = None
    gpu_status = None
    driver_version = None
    pnp_device_id = None

    gpu = evidence.get("gpu") or {}
    if gpu.get("status") == "ok":
        gpu_data = gpu.get("data") or {}
        nvidia_present = bool(gpu_data.get("nvidiaAdapterPresent"))
        gpu_adapters = list(gpu_data.get("adapters") or [])
        if gpu_adapters:
            primary = gpu_adapters[0]
            gpu_name = primary.get("name")
            gpu_status = primary.get("status")
            driver_version = primary.get("driverVersion")
            pnp_device_id = primary.get("pnpDeviceId")

    monitor_devices: list[Any] = []
    monitor_names: list[str] = []
    monitor_pnp_status: list[str] = []
    monitor = evidence.get("monitor") or {}
    if monitor.get("status") == "ok":
        monitor_data = monitor.get("data") or {}
        monitor_devices = list(monitor_data.get("monitors") or [])
        monitor_names = [m.get("name", "") for m in monitor_devices]
        monitor_pnp_status = [m.get("status", "") for m in monitor_devices]

    display_adapters: list[Any] = []
    pnp_display = evidence.get("pnpDisplay") or {}
    if pnp_display.get("status") == "ok":
        display_adapters = list((pnp_display.get("data") or {}).get("entities") or [])

    is_admin = False
    system = evidence.get("system") or {}
    admin_status = system.get("adminStatus") or {}
    if admin_status.get("status") == "ok":
        is_admin = bool((admin_status.get("data") or {}).get("isAdministrator"))

    os_info = None
    operating_system = system.get("operatingSystem") or {}
    if operating_system.get("status") == "ok":
        os_info = operating_system.get("data")

    safety_notes = [
        "Classification is evidence-based suspicion, not proof.",
        "Remediation defaults to preview-only without --apply.",
        "Adapter restart requires --apply and --force and may blank the display.",
    ]
    safety_notes.extend(classification.get("riskNotes") or [])

    action_lists = get_report_action_lists(policy_plan, remediation_results)

    structured_report = {
        "timestamp": system.get("timestamp"),
        "hostname": system.get("hostname"),
        "os": os_info,
        "gpu_adapters": gpu_adapters,
        "display_adapters": display_adapters,
        "monitor_devices": monitor_devices,
        "current_resolution": resolution.get("resolutionString") if resolution else None,
        "suspected_tags": classification.get("tags"),
        "evidence_items": classification.get("evidence"),
        "confidence_level": classification.get("confidence"),
        "explanation": classification.get("explanation"),
        "recommended_actions": action_lists["recommendedActions"],
        "preview_actions": action_lists["previewActions"],
        "applied_actions": action_lists["appliedActions"],
        "safety_warnings": safety_notes,
        "verification_result": verification,
    }

    runtime_version = system.get("runtimeVersion") or system.get("powershellVersion")

    return {
        "schemaVersion": get_report_schema_version(),
        "generatedAt": utc_now_iso(),
        "mode": mode,
        "hostname": system.get("hostname"),
        "username": system.get("username"),
        "report": structured_report,
        "summary": {
            "timestamp": system.get("timestamp"),
            "osVersion": os_info.get("version") if os_info else None,
            "powershellVersion": runtime_version,
            "runtimeVersion": runtime_version,
            "adminStatus": is_admin,
            "activeDisplayResolution": resolution.get("resolutionString") if resolution else None,
            "is640x480": resolution.get("is640x480") if resolution else False,
            "isSuspiciouslyLow": resolution.get("isSuspiciouslyLow") if resolution else False,
            "nvidiaAdapterPresent": nvidia_present,
            "gpuName": gpu_name,
            "gpuStatus": gpu_status,
            "driverVersion": driver_version,
            "pnpDeviceId": pnp_device_id,
            "currentVideoMode": (
                (display.get("data") or {}).get("currentVideoMode", {}).get("name")
                if display.get("status") == "ok"
                else None
            ),
            "monitorCount": (
                (monitor.get("data") or {}).get("monitorCount")
                if monitor.get("status") == "ok"
                else None
            ),
            "monitorNames": monitor_names,
            "monitorPnPStatus": monitor_pnp_status,
            "classification": classification.get("classification"),
            "confidence": classification.get("confidence"),
            "explanation": classification.get("explanation"),
            "recommendedNextStep": classification.get("recommendedNextStep"),
            "safetyNotes": safety_notes,
        },
        "evidence": evidence,
        "classification": classification,
        "policyPlan": policy_plan,
        "remediationResults": remediation_results,
        "verification": verification,
    }


def write_human_summary(report: dict[str, Any], *, quiet: bool = False) -> list[str]:
    lines: list[str] = []
    summary = report.get("summary") or {}

    def add_line(prefix: str, message: str) -> None:
        lines.append(f"[{prefix}] {message}")

    if summary.get("nvidiaAdapterPresent"):
        add_line("OK", f"NVIDIA adapter detected: {summary.get('gpuName')}")
    else:
        add_line("WARN", "NVIDIA adapter not detected in current evidence.")

    if summary.get("is640x480"):
        add_line("WARN", "Current resolution is 640x480.")
    elif summary.get("isSuspiciouslyLow"):
        add_line("WARN", f"Current resolution {summary.get('activeDisplayResolution')} is suspiciously low.")
    else:
        add_line("OK", f"Current resolution: {summary.get('activeDisplayResolution')}")

    classification = summary.get("classification")
    if classification == "NV_FAILSAFE_SUSPECTED":
        add_line("WARN", "NV-Failsafe suspected based on available evidence.")
    elif classification in ("NO_ISSUE_DETECTED", "NORMAL_DISPLAY_STATE"):
        add_line("OK", "No active NV-Failsafe indicators in current evidence.")
    elif classification == "INSUFFICIENT_DATA":
        add_line("WARN", "Insufficient data for high-confidence classification.")
    else:
        add_line(
            "INFO",
            f"Classification: {classification} (confidence {summary.get('confidence')}).",
        )

    if summary.get("explanation"):
        add_line("INFO", summary["explanation"])

    add_line("INFO", f"Recommended next step: {summary.get('recommendedNextStep')}")

    for item in report.get("policyPlan") or []:
        if item.get("executionMode") == "manual_only":
            add_line("MANUAL", f"{item['action']}: manual-only escalation.")
        elif item.get("executionMode") == "preview" and item.get("allowed"):
            add_line("PREVIEW", f"Would run action: {item['action']}")
        elif not item.get("allowed"):
            add_line("BLOCKED", f"{item['action']}: {item.get('reason')}")

    for note in summary.get("safetyNotes") or []:
        add_line("SAFETY", note)

    if not quiet:
        for line in lines:
            print(line)

    return lines


def write_json_report(report: dict[str, Any], output_path: str) -> None:
    path = Path(output_path)
    if path.parent and str(path.parent) not in (".", ""):
        path.parent.mkdir(parents=True, exist_ok=True)
    payload = to_json_serializable(report)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def report_block_has_property(block: Any, name: str) -> bool:
    if block is None:
        return False
    if isinstance(block, dict):
        return name in block
    return hasattr(block, name)


def validate_nv_failsafe_report_shape(report: dict[str, Any]) -> bool:
    required = [
        "schemaVersion",
        "generatedAt",
        "mode",
        "hostname",
        "report",
        "summary",
        "classification",
    ]
    if not all(key in report for key in required):
        return False

    report_required = [
        "timestamp",
        "hostname",
        "current_resolution",
        "suspected_tags",
        "evidence_items",
        "confidence_level",
        "explanation",
        "safety_warnings",
    ]
    block = report.get("report") or {}
    return all(report_block_has_property(block, name) for name in report_required)


def compare_nv_failsafe_reports(
    before_report: dict[str, Any],
    after_report: dict[str, Any],
) -> dict[str, Any]:
    before = before_report.get("summary") or {}
    after = after_report.get("summary") or {}
    resolved = {"NO_ISSUE_DETECTED", "NORMAL_DISPLAY_STATE"}

    return {
        "comparedAt": utc_now_iso(),
        "resolutionChanged": before.get("activeDisplayResolution")
        != after.get("activeDisplayResolution"),
        "resolutionBefore": before.get("activeDisplayResolution"),
        "resolutionAfter": after.get("activeDisplayResolution"),
        "nvFailsafeSuspectedBefore": before.get("classification") == "NV_FAILSAFE_SUSPECTED",
        "nvFailsafeSuspectedAfter": after.get("classification") == "NV_FAILSAFE_SUSPECTED",
        "monitorCountChanged": before.get("monitorCount") != after.get("monitorCount"),
        "monitorCountBefore": before.get("monitorCount"),
        "monitorCountAfter": after.get("monitorCount"),
        "nvidiaAdapterStatusChanged": before.get("gpuStatus") != after.get("gpuStatus"),
        "nvidiaAdapterStatusBefore": before.get("gpuStatus"),
        "nvidiaAdapterStatusAfter": after.get("gpuStatus"),
        "classificationChanged": before.get("classification") != after.get("classification"),
        "classificationBefore": before.get("classification"),
        "classificationAfter": after.get("classification"),
        "confidenceBefore": before.get("confidence"),
        "confidenceAfter": after.get("confidence"),
        "improved": (
            (before.get("is640x480") and not after.get("is640x480"))
            or (
                before.get("classification") == "NV_FAILSAFE_SUSPECTED"
                and after.get("classification") in resolved
            )
        ),
    }
