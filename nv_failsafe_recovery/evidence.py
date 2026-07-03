"""Evidence collection for NV-Failsafe Recovery (Windows WMI)."""

from __future__ import annotations

import os
import platform
import subprocess
import sys
from typing import Any

from nv_failsafe_recovery.utilities import (
    get_toolkit_version,
    invoke_safe_command,
    new_evidence_probe_result,
    string_contains_any,
    utc_now_iso,
)


def is_windows() -> bool:
    return sys.platform == "win32"


def test_is_administrator() -> bool:
    if not is_windows():
        return False
    try:
        import ctypes

        return bool(ctypes.windll.shell32.IsUserAnAdmin())  # type: ignore[attr-defined]
    except Exception:  # noqa: BLE001
        return False


def get_resolution_risk(width: int, height: int) -> dict[str, Any]:
    is_640x480 = width == 640 and height == 480
    is_suspiciously_low = width <= 800 and height <= 600
    if is_640x480:
        risk_level = "critical"
    elif is_suspiciously_low:
        risk_level = "elevated"
    else:
        risk_level = "normal"
    return {
        "width": width,
        "height": height,
        "is640x480": is_640x480,
        "isSuspiciouslyLow": is_suspiciously_low,
        "riskLevel": risk_level,
        "resolutionString": f"{width}x{height}",
    }


def _query_wmi(class_name: str) -> list[dict[str, Any]]:
    if not is_windows():
        raise RuntimeError("WMI is only available on Windows.")

    try:
        import wmi  # type: ignore[import-untyped]
    except ImportError as exc:
        raise RuntimeError("WMI package is not installed.") from exc

    connection = wmi.WMI()
    klass = getattr(connection, class_name)
    rows: list[dict[str, Any]] = []
    for item in klass():
        rows.append({key: getattr(item, key, None) for key in item.properties.keys()})
    return rows


def get_system_evidence() -> dict[str, Any]:
    def collect_os() -> dict[str, Any]:
        rows = _query_wmi("Win32_OperatingSystem")
        if not rows:
            raise RuntimeError("Win32_OperatingSystem returned no rows.")
        os_row = rows[0]
        last_boot = os_row.get("LastBootUpTime")
        if hasattr(last_boot, "isoformat"):
            last_boot = last_boot.isoformat()
        return {
            "caption": os_row.get("Caption"),
            "version": os_row.get("Version"),
            "buildNumber": os_row.get("BuildNumber"),
            "osArchitecture": os_row.get("OSArchitecture"),
            "lastBootUpTime": last_boot,
        }

    os_probe = invoke_safe_command("Win32_OperatingSystem", collect_os)
    admin_probe = new_evidence_probe_result(
        "ok",
        "SecurityPrincipal",
        {"isAdministrator": test_is_administrator()},
    )

    return {
        "hostname": os.environ.get("COMPUTERNAME", platform.node()),
        "username": os.environ.get("USERNAME", ""),
        "timestamp": utc_now_iso(),
        "runtimeVersion": platform.python_version(),
        "powershellVersion": platform.python_version(),
        "toolkitVersion": get_toolkit_version(),
        "operatingSystem": os_probe,
        "adminStatus": admin_probe,
    }


def get_display_evidence() -> dict[str, Any]:
    def collect() -> dict[str, Any]:
        controllers = _query_wmi("Win32_VideoController")
        active = None
        for controller in controllers:
            if controller.get("CurrentHorizontalResolution") and controller.get(
                "CurrentVerticalResolution"
            ):
                active = controller
                break
        if active is None and controllers:
            active = controllers[0]
        if active is None:
            raise RuntimeError("No video controllers found.")

        width = int(active.get("CurrentHorizontalResolution") or 0)
        height = int(active.get("CurrentVerticalResolution") or 0)
        adapter_ram = active.get("AdapterRAM")
        driver_date = active.get("DriverDate")
        if hasattr(driver_date, "isoformat"):
            driver_date = driver_date.isoformat()

        return {
            "activeResolution": get_resolution_risk(width, height),
            "currentVideoMode": {
                "name": active.get("VideoModeDescription"),
                "adapterRamMB": round(adapter_ram / (1024 * 1024), 2) if adapter_ram else None,
                "driverDate": driver_date,
                "driverVersion": active.get("DriverVersion"),
                "videoProcessor": active.get("VideoProcessor"),
                "status": active.get("Status"),
            },
            "controllerCount": len(controllers),
        }

    return invoke_safe_command("Win32_VideoController.Display", collect)


def get_gpu_evidence() -> dict[str, Any]:
    def collect() -> dict[str, Any]:
        controllers = _query_wmi("Win32_VideoController")
        adapters: list[dict[str, Any]] = []
        nvidia_count = 0
        for gpu in controllers:
            name = str(gpu.get("Name") or "")
            pnp_id = str(gpu.get("PNPDeviceID") or "")
            is_nvidia = "NVIDIA" in name.upper() or "VEN_10DE" in pnp_id.upper()
            if is_nvidia:
                nvidia_count += 1
            adapter_ram = gpu.get("AdapterRAM")
            adapters.append(
                {
                    "name": name,
                    "status": gpu.get("Status"),
                    "pnpDeviceId": pnp_id,
                    "driverVersion": gpu.get("DriverVersion"),
                    "isNvidia": is_nvidia,
                    "availability": gpu.get("Availability"),
                    "adapterRamMB": round(adapter_ram / (1024 * 1024), 2) if adapter_ram else None,
                }
            )
        return {
            "adapters": adapters,
            "nvidiaAdapterCount": nvidia_count,
            "nvidiaAdapterPresent": nvidia_count > 0,
            "primaryGpuName": adapters[0]["name"] if adapters else None,
        }

    return invoke_safe_command("Win32_VideoController.GPU", collect)


def get_monitor_evidence() -> dict[str, Any]:
    def collect() -> dict[str, Any]:
        monitors_raw = _query_wmi("Win32_DesktopMonitor")
        monitor_list: list[dict[str, Any]] = []
        for monitor in monitors_raw:
            name = str(monitor.get("Name") or "")
            monitor_list.append(
                {
                    "name": name,
                    "description": monitor.get("Description"),
                    "status": monitor.get("Status"),
                    "pnpDeviceId": monitor.get("PNPDeviceID"),
                    "screenWidth": monitor.get("ScreenWidth"),
                    "screenHeight": monitor.get("ScreenHeight"),
                    "isGeneric": string_contains_any(
                        name,
                        [
                            "Generic",
                            "Non-PnP",
                            "Default Monitor",
                            "NV-Failsafe",
                            r"640\s*x\s*480",
                        ],
                    ),
                }
            )
        generic_count = sum(1 for m in monitor_list if m.get("isGeneric"))
        has_nv_failsafe = any("NV-Failsafe" in (m.get("name") or "") for m in monitor_list)
        return {
            "monitors": monitor_list,
            "monitorCount": len(monitor_list),
            "genericCount": generic_count,
            "hasNvFailsafeName": has_nv_failsafe,
        }

    return invoke_safe_command("Win32_DesktopMonitor", collect)


def _collect_pnp_via_powershell() -> list[dict[str, Any]]:
    script = (
        "Get-PnpDevice -Class Monitor,Display -ErrorAction SilentlyContinue | "
        "Select-Object FriendlyName,Status,Class,InstanceId,Problem | "
        "ConvertTo-Json -Compress"
    )
    completed = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", script],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0 or not completed.stdout.strip():
        raise RuntimeError("Get-PnpDevice unavailable.")

    import json

    payload = json.loads(completed.stdout)
    if isinstance(payload, dict):
        payload = [payload]
    entities: list[dict[str, Any]] = []
    for device in payload:
        status = device.get("Status")
        problem = device.get("Problem") or 0
        entities.append(
            {
                "friendlyName": device.get("FriendlyName"),
                "status": status,
                "class": device.get("Class"),
                "instanceId": device.get("InstanceId"),
                "problem": problem,
                "isDisabled": status == "Error" or problem != 0,
                "isUnknown": status == "Unknown",
            }
        )
    return entities


def _collect_pnp_via_wmi_fallback() -> list[dict[str, Any]]:
    rows = _query_wmi("Win32_PnPEntity")
    entities: list[dict[str, Any]] = []
    for device in rows:
        pnp_class = device.get("PNPClass")
        if pnp_class not in ("Monitor", "Display"):
            continue
        status = device.get("Status")
        entities.append(
            {
                "friendlyName": device.get("Name"),
                "status": status,
                "class": pnp_class,
                "instanceId": device.get("PNPDeviceID"),
                "problem": None,
                "isDisabled": status != "OK",
                "isUnknown": status == "Unknown",
            }
        )
    return entities


def get_pnp_display_evidence() -> dict[str, Any]:
    def collect() -> dict[str, Any]:
        try:
            entities = _collect_pnp_via_powershell()
        except Exception:
            entities = _collect_pnp_via_wmi_fallback()

        disabled_count = sum(1 for e in entities if e.get("isDisabled"))
        unknown_count = sum(1 for e in entities if e.get("isUnknown"))
        unstable_count = sum(1 for e in entities if e.get("status") not in ("OK", "Unknown"))
        return {
            "entities": entities,
            "entityCount": len(entities),
            "disabledCount": disabled_count,
            "unknownCount": unknown_count,
            "unstableCount": unstable_count,
        }

    return invoke_safe_command(
        "Get-PnpDevice.Display",
        collect,
        unavailable_message="Get-PnpDevice unavailable; using Win32_PnPEntity fallback.",
    )


def get_full_evidence_bundle() -> dict[str, Any]:
    system = get_system_evidence()
    display = get_display_evidence()
    gpu = get_gpu_evidence()
    monitor = get_monitor_evidence()
    pnp = get_pnp_display_evidence()

    probe_statuses = [
        display.get("status"),
        gpu.get("status"),
        monitor.get("status"),
        pnp.get("status"),
        (system.get("operatingSystem") or {}).get("status"),
    ]
    probe_statuses = [status for status in probe_statuses if status]

    has_errors = any(status == "error" for status in probe_statuses)
    has_unavailable = any(status == "unavailable" for status in probe_statuses)

    collection_status = "ok"
    if has_errors:
        collection_status = "error"
    elif has_unavailable:
        collection_status = "warning"

    return {
        "schemaVersion": "1.1.0",
        "collectedAt": utc_now_iso(),
        "collectionStatus": collection_status,
        "system": system,
        "display": display,
        "gpu": gpu,
        "monitor": monitor,
        "pnpDisplay": pnp,
    }
