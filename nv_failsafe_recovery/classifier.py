"""Evidence-based classification for NV-Failsafe display states."""

from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any

from nv_failsafe_recovery.utilities import string_contains_any


def get_evidence_value(probe: dict[str, Any] | None, selector: Any) -> Any:
    if probe is None or probe.get("status") in ("error", "unavailable"):
        return None
    data = probe.get("data")
    if data is None:
        return None
    if callable(selector):
        return selector(data)
    return None


def evidence_incomplete(evidence: dict[str, Any]) -> bool:
    critical = [
        evidence.get("display"),
        evidence.get("gpu"),
        evidence.get("monitor"),
        evidence.get("pnpDisplay"),
    ]
    missing = [
        probe
        for probe in critical
        if probe is None or probe.get("status") in ("error", "unavailable")
    ]
    return len(missing) >= 2


def get_classification_explanation(classification: str, tags: list[str]) -> str:
    if classification == "NV_FAILSAFE_SUSPECTED":
        return (
            "Evidence indicates a suspected NVIDIA NV-Failsafe / 640x480 fallback pattern. "
            "This is a hypothesis based on resolution and adapter evidence, not proof of hardware failure."
        )
    if classification == "LOW_RESOLUTION_FALLBACK":
        return (
            "Evidence indicates a low-resolution fallback state. Root cause may be handshake, "
            "driver, or non-NVIDIA display path issues."
        )
    if classification == "INSUFFICIENT_DATA":
        return (
            "Insufficient probe data was collected to support a higher-confidence classification. "
            "Re-run Report mode, preferably elevated, to improve evidence quality."
        )
    if classification == "NO_ISSUE_DETECTED":
        if "MONITOR_EDID_HANDSHAKE_SUSPECTED" in tags or "GENERIC_MONITOR_PROFILE_SUSPECTED" in tags:
            return (
                "No active NV-Failsafe fallback is detected, but secondary tags suggest monitor "
                "detection or EDID handshake drift may still be present."
            )
        return "Current evidence does not indicate an active NV-Failsafe / 640x480 fallback state."
    return "Classification derived from available local evidence only."


def get_nv_failsafe_classification(evidence: dict[str, Any]) -> dict[str, Any]:
    evidence_items: list[str] = []
    counter_evidence: list[str] = []
    manual_steps: list[str] = []
    automated_steps: list[str] = []
    risk_notes: list[str] = []
    tags: list[str] = []

    confidence = 0.35
    classification = "INSUFFICIENT_DATA"
    recommended_next_step = "Collect additional display evidence and re-run Detect mode."

    if evidence_incomplete(evidence):
        evidence_items.append("Multiple critical probes failed or were unavailable.")
        manual_steps.append(
            "Re-run Report mode from an elevated session if PnP data is missing."
        )
        tag_array = ["INSUFFICIENT_DATA"]
        return {
            "classification": "INSUFFICIENT_DATA",
            "confidence": 0.25,
            "evidence": evidence_items,
            "counterEvidence": counter_evidence,
            "explanation": get_classification_explanation("INSUFFICIENT_DATA", tag_array),
            "recommendedNextStep": recommended_next_step,
            "manualSteps": manual_steps,
            "automatedSteps": automated_steps,
            "riskNotes": ["Classification confidence is limited due to incomplete evidence collection."],
            "tags": tag_array,
        }

    resolution = get_evidence_value(evidence.get("display"), lambda d: d.get("activeResolution"))
    nvidia_present = get_evidence_value(evidence.get("gpu"), lambda d: d.get("nvidiaAdapterPresent"))
    gpu_status = get_evidence_value(
        evidence.get("gpu"),
        lambda d: (d.get("adapters") or [{}])[0].get("status") if d.get("adapters") else None,
    )
    video_mode = get_evidence_value(
        evidence.get("display"), lambda d: (d.get("currentVideoMode") or {}).get("name")
    )
    monitor_count = get_evidence_value(evidence.get("monitor"), lambda d: d.get("monitorCount"))
    generic_count = get_evidence_value(evidence.get("monitor"), lambda d: d.get("genericCount"))
    has_nv_failsafe_name = get_evidence_value(
        evidence.get("monitor"), lambda d: d.get("hasNvFailsafeName")
    )
    pnp_disabled = get_evidence_value(evidence.get("pnpDisplay"), lambda d: d.get("disabledCount"))
    pnp_unknown = get_evidence_value(evidence.get("pnpDisplay"), lambda d: d.get("unknownCount"))

    is_admin = False
    admin_status = (evidence.get("system") or {}).get("adminStatus") or {}
    if admin_status.get("status") == "ok":
        is_admin = bool((admin_status.get("data") or {}).get("isAdministrator"))

    if resolution and resolution.get("is640x480"):
        if nvidia_present:
            classification = "NV_FAILSAFE_SUSPECTED"
            confidence = 0.82
            evidence_items.append("Active resolution is exactly 640x480 with NVIDIA adapter present.")
            recommended_next_step = (
                "Try Win+Ctrl+Shift+B, then power-cycle monitor and replug HDMI/DisplayPort "
                "before automated fixes."
            )
            manual_steps.append("Press Win+Ctrl+Shift+B to reset the graphics driver.")
            manual_steps.append("Power-cycle the monitor and replug the display cable.")
            automated_steps.append("Run Fix mode with --fix-level safe (preview first).")
            tags.append("NV_FAILSAFE_SUSPECTED")
        else:
            classification = "LOW_RESOLUTION_FALLBACK"
            confidence = 0.55
            evidence_items.append("Active resolution is 640x480 but no NVIDIA adapter was detected.")
            counter_evidence.append("NV-Failsafe classification requires NVIDIA adapter evidence.")
            recommended_next_step = (
                "Verify GPU detection and display cable path; NVIDIA-specific recovery may not apply."
            )
            tags.append("LOW_RESOLUTION_FALLBACK")
    elif resolution and resolution.get("isSuspiciouslyLow"):
        classification = "LOW_RESOLUTION_FALLBACK"
        confidence = 0.48
        evidence_items.append(f"Resolution {resolution.get('resolutionString')} is suspiciously low.")
        recommended_next_step = "Verify monitor EDID handshake and Windows display settings."
        tags.append("LOW_RESOLUTION_FALLBACK")
    else:
        classification = "NO_ISSUE_DETECTED"
        confidence = 0.72
        evidence_items.append("Active resolution does not indicate NV-Failsafe fallback.")
        recommended_next_step = "No active NV-Failsafe indicators detected; monitor for recurrence after sleep/wake."
        tags.append("NO_ISSUE_DETECTED")

    if generic_count and generic_count > 0:
        tags.append("GENERIC_MONITOR_PROFILE_SUSPECTED")
        confidence = min(0.95, confidence + 0.05)
        evidence_items.append("One or more monitors appear generic or non-specific.")
        manual_steps.append("Verify the monitor is detected with its correct model name in Display Settings.")

    monitor_handshake_suspected = False
    if has_nv_failsafe_name:
        monitor_handshake_suspected = True
        evidence_items.append("Monitor name evidence indicates NV-Failsafe.")
    if (pnp_unknown or 0) > 0 or (pnp_disabled or 0) > 0:
        monitor_handshake_suspected = True
        evidence_items.append("PnP display entities report unknown or non-OK status.")
    if monitor_count is not None and monitor_count == 0:
        monitor_handshake_suspected = True
        evidence_items.append("No monitor devices were enumerated.")

    if monitor_handshake_suspected:
        tags.append("MONITOR_EDID_HANDSHAKE_SUSPECTED")
        confidence = min(0.95, confidence + 0.08)
        manual_steps.append("Try another HDMI/DisplayPort cable or GPU output port.")
        automated_steps.append(
            "Consider Fix mode --fix-level monitor --apply if handshake suspicion persists."
        )
        if classification == "NO_ISSUE_DETECTED":
            recommended_next_step = (
                "Evidence indicates possible EDID/handshake issue despite acceptable resolution."
            )

    driver_fallback_suspected = False
    if gpu_status and gpu_status != "OK":
        driver_fallback_suspected = True
        evidence_items.append(f"NVIDIA adapter status is '{gpu_status}', not OK.")
    if video_mode and re_search_fallback_mode(video_mode):
        driver_fallback_suspected = True
        evidence_items.append(f"Current video mode '{video_mode}' appears fallback-like.")

    if driver_fallback_suspected:
        tags.append("NVIDIA_DRIVER_FALLBACK_SUSPECTED")
        confidence = min(0.95, confidence + 0.07)
        risk_notes.append(
            "Driver fallback is suspected, not proven; hardware failure requires stronger evidence."
        )
        automated_steps.append("Escalate to driver reinstall guidance before adapter restart.")

    last_boot = get_evidence_value(
        (evidence.get("system") or {}).get("operatingSystem"),
        lambda d: d.get("lastBootUpTime"),
    )
    if last_boot:
        try:
            boot_time = datetime.fromisoformat(last_boot.replace("Z", "+00:00"))
            boot_age = datetime.now(timezone.utc) - boot_time
            if boot_age.total_seconds() < 15 * 60 and classification != "NO_ISSUE_DETECTED":
                evidence_items.append(
                    "Recent boot timing suggests possible post-sleep/wake display initialization race."
                )
                manual_steps.append("If issue appeared after sleep, test with Fast Startup disabled.")
        except ValueError:
            pass

    if (
        ((pnp_disabled or 0) > 0 or (pnp_unknown or 0) > 0)
        and classification != "NO_ISSUE_DETECTED"
    ):
        evidence_items.append("Display PnP state drift is suspected based on entity status.")
        automated_steps.append("PnP rescan may help if policy allows (--apply, admin).")

    if not is_admin and classification != "NO_ISSUE_DETECTED":
        risk_notes.append("Some remediation actions require administrator privileges.")

    if not tags:
        tags.append(classification)

    return {
        "classification": classification,
        "confidence": round(max(0.0, min(1.0, confidence)), 2),
        "evidence": evidence_items,
        "counterEvidence": counter_evidence,
        "explanation": get_classification_explanation(classification, tags),
        "recommendedNextStep": recommended_next_step,
        "manualSteps": manual_steps,
        "automatedSteps": automated_steps,
        "riskNotes": risk_notes,
        "tags": tags,
    }


def re_search_fallback_mode(video_mode: str) -> bool:
    return bool(re.search(r"640\s*x\s*480|Failsafe|Standard VGA", video_mode, re.IGNORECASE))
