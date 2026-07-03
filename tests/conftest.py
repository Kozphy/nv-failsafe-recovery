"""Pytest configuration and shared fixtures."""

from __future__ import annotations

from typing import Any

import pytest

from nv_failsafe_recovery.evidence import get_resolution_risk
from nv_failsafe_recovery.utilities import new_evidence_probe_result, utc_now_iso


def new_mock_probe(data: Any, status: str = "ok") -> dict[str, Any]:
    return new_evidence_probe_result(status, "mock", data)


def new_mock_evidence(
    *,
    is_640x480: bool = False,
    nvidia_present: bool = True,
    monitor_count: int = 1,
    generic_count: int = 0,
    has_nv_failsafe_name: bool = False,
    gpu_status: str = "OK",
    video_mode: str = "1920 x 1080 x 32 True Color",
    pnp_disabled: int = 0,
    pnp_unknown: int = 0,
    display_status: str = "ok",
    gpu_probe_status: str = "ok",
    monitor_probe_status: str = "ok",
    pnp_probe_status: str = "ok",
) -> dict[str, Any]:
    width = 640 if is_640x480 else 1920
    height = 480 if is_640x480 else 1080

    return {
        "schemaVersion": "1.1.0",
        "collectedAt": utc_now_iso(),
        "collectionStatus": "ok",
        "system": {
            "hostname": "TESTHOST",
            "username": "testuser",
            "timestamp": utc_now_iso(),
            "runtimeVersion": "3.11.0",
            "powershellVersion": "3.11.0",
            "toolkitVersion": "2.0.0",
            "operatingSystem": new_mock_probe(
                {
                    "caption": "Microsoft Windows 11",
                    "version": "10.0.26200",
                    "buildNumber": "26200",
                    "lastBootUpTime": utc_now_iso(),
                }
            ),
            "adminStatus": new_mock_probe({"isAdministrator": False}),
        },
        "display": new_mock_probe(
            {
                "activeResolution": get_resolution_risk(width, height),
                "currentVideoMode": {"name": video_mode, "status": "OK"},
                "controllerCount": 1,
            },
            status=display_status,
        ),
        "gpu": new_mock_probe(
            {
                "nvidiaAdapterPresent": nvidia_present,
                "nvidiaAdapterCount": 1 if nvidia_present else 0,
                "adapters": [
                    {
                        "name": "NVIDIA GeForce RTX 4070" if nvidia_present else "Intel UHD Graphics",
                        "status": gpu_status,
                        "pnpDeviceId": "PCI\\VEN_10DE&DEV_2786"
                        if nvidia_present
                        else "PCI\\VEN_8086",
                        "driverVersion": "31.0.15.4601",
                        "isNvidia": nvidia_present,
                    }
                ],
            },
            status=gpu_probe_status,
        ),
        "monitor": new_mock_probe(
            {
                "monitorCount": monitor_count,
                "genericCount": generic_count,
                "hasNvFailsafeName": has_nv_failsafe_name,
                "monitors": [
                    {
                        "name": (
                            "NV-Failsafe"
                            if has_nv_failsafe_name
                            else ("Generic PnP Monitor" if generic_count > 0 else "DELL U2723QE")
                        ),
                        "status": "OK",
                        "isGeneric": generic_count > 0 or has_nv_failsafe_name,
                    }
                ],
            },
            status=monitor_probe_status,
        ),
        "pnpDisplay": new_mock_probe(
            {
                "disabledCount": pnp_disabled,
                "unknownCount": pnp_unknown,
                "entityCount": monitor_count,
                "entities": [],
            },
            status=pnp_probe_status,
        ),
    }


@pytest.fixture
def mock_evidence() -> dict[str, Any]:
    return new_mock_evidence()
