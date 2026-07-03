from tests.conftest import new_mock_evidence
from nv_failsafe_recovery.classifier import get_nv_failsafe_classification


def test_classifies_nvidia_640x480_as_nv_failsafe_suspected():
    evidence = new_mock_evidence(is_640x480=True, nvidia_present=True)
    result = get_nv_failsafe_classification(evidence)
    assert result["classification"] == "NV_FAILSAFE_SUSPECTED"
    assert result["confidence"] > 0.7
    assert result["explanation"]


def test_classifies_non_nvidia_640x480_as_low_resolution_fallback():
    evidence = new_mock_evidence(is_640x480=True, nvidia_present=False)
    result = get_nv_failsafe_classification(evidence)
    assert result["classification"] == "LOW_RESOLUTION_FALLBACK"


def test_flags_generic_monitor_profile_suspicion():
    evidence = new_mock_evidence(generic_count=1)
    result = get_nv_failsafe_classification(evidence)
    assert "GENERIC_MONITOR_PROFILE_SUSPECTED" in result["tags"]


def test_flags_generic_separately_from_handshake_on_low_resolution():
    evidence = new_mock_evidence(is_640x480=True, generic_count=1)
    result = get_nv_failsafe_classification(evidence)
    assert "MONITOR_EDID_HANDSHAKE_SUSPECTED" not in result["tags"]
    assert "GENERIC_MONITOR_PROFILE_SUSPECTED" in result["tags"]


def test_classifies_healthy_resolution_as_no_issue_detected():
    evidence = new_mock_evidence()
    result = get_nv_failsafe_classification(evidence)
    assert result["classification"] == "NO_ISSUE_DETECTED"


def test_returns_insufficient_data_when_multiple_probes_fail():
    evidence = new_mock_evidence(
        display_status="error",
        gpu_probe_status="unavailable",
        monitor_probe_status="error",
        pnp_probe_status="unavailable",
    )
    result = get_nv_failsafe_classification(evidence)
    assert result["classification"] == "INSUFFICIENT_DATA"
