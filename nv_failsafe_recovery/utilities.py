"""Shared utilities for NV-Failsafe Recovery."""

from __future__ import annotations

import re
from collections.abc import Callable, Mapping, Sequence
from datetime import datetime, timezone
from typing import Any, TypeVar

from packaging.version import parse as parse_version

from nv_failsafe_recovery.version import REPORT_SCHEMA_VERSION, TOOLKIT_VERSION

T = TypeVar("T")


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def new_evidence_probe_result(
    status: str,
    source: str,
    data: Any = None,
    error_message: str = "",
) -> dict[str, Any]:
    return {
        "status": status,
        "source": source,
        "data": data,
        "errorMessage": error_message,
        "collectedAt": utc_now_iso(),
    }


def invoke_safe_command(
    source: str,
    fn: Callable[[], T],
    unavailable_message: str = "Command unavailable on this system.",
) -> dict[str, Any]:
    try:
        data = fn()
        return new_evidence_probe_result("ok", source, data)
    except Exception as exc:  # noqa: BLE001 — probe failures must not abort collection
        message = str(exc)
        lowered = message.lower()
        if "not found" in lowered or "no module named" in lowered:
            return new_evidence_probe_result(
                "unavailable", source, error_message=unavailable_message
            )
        return new_evidence_probe_result("error", source, error_message=message)


def to_json_serializable(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, Mapping):
        return {str(k): to_json_serializable(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [to_json_serializable(item) for item in value]
    if hasattr(value, "__dict__") and not isinstance(value, (str, int, float, bool)):
        return to_json_serializable(vars(value))
    return value


def string_contains_any(value: str | None, patterns: Sequence[str]) -> bool:
    if not value or not value.strip():
        return False
    for pattern in patterns:
        if re.search(pattern, value, re.IGNORECASE):
            return True
    return False


def version_meets_minimum(version: str, minimum: str) -> bool:
    return parse_version(version) >= parse_version(minimum)


def get_toolkit_version() -> str:
    return TOOLKIT_VERSION


def get_report_schema_version() -> str:
    return REPORT_SCHEMA_VERSION


def convert_to_legacy_classification(classification: str) -> str:
    if classification == "NO_ISSUE_DETECTED":
        return "NORMAL_DISPLAY_STATE"
    if classification == "LOW_RESOLUTION_FALLBACK":
        return "LOW_RESOLUTION_ONLY"
    return classification
