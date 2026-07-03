import json
from pathlib import Path

import pytest

from nv_failsafe_recovery.classifier import get_nv_failsafe_classification
from nv_failsafe_recovery.evidence import get_full_evidence_bundle, get_resolution_risk, is_windows
from nv_failsafe_recovery.reporting import (
    compare_nv_failsafe_reports,
    new_nv_failsafe_report,
    validate_nv_failsafe_report_shape,
)
from nv_failsafe_recovery.utilities import new_evidence_probe_result
from tests.conftest import new_mock_evidence


def test_probe_result_has_required_fields():
    probe = new_evidence_probe_result("ok", "test", {"sample": 1})
    assert probe["status"] == "ok"
    assert probe["source"] == "test"
    assert "errorMessage" in probe
    assert probe["collectedAt"]


def test_resolution_risk_identifies_640x480():
    risk = get_resolution_risk(640, 480)
    assert risk["is640x480"] is True
    assert risk["riskLevel"] == "critical"


@pytest.mark.skipif(not is_windows(), reason="WMI evidence requires Windows")
def test_full_evidence_bundle_top_level_keys():
    bundle = get_full_evidence_bundle()
    for key in ("display", "gpu", "monitor", "pnpDisplay"):
        assert key in bundle
    assert bundle["display"]["status"] in ("ok", "warning", "error", "unavailable")


def test_report_includes_structured_report_fields():
    evidence = new_mock_evidence()
    classification = get_nv_failsafe_classification(evidence)
    report = new_nv_failsafe_report(evidence, classification, mode="Report")
    assert validate_nv_failsafe_report_shape(report)
    assert report["report"]["gpu_adapters"] is not None
    assert report["report"]["suspected_tags"] is not None
    assert report["report"]["explanation"]


def test_verify_treats_no_issue_as_improved_from_nv_failsafe():
    before = {
        "summary": {
            "activeDisplayResolution": "640x480",
            "is640x480": True,
            "classification": "NV_FAILSAFE_SUSPECTED",
            "monitorCount": 1,
            "gpuStatus": "OK",
            "confidence": 0.82,
        }
    }
    after = {
        "summary": {
            "activeDisplayResolution": "1920x1080",
            "is640x480": False,
            "classification": "NO_ISSUE_DETECTED",
            "monitorCount": 1,
            "gpuStatus": "OK",
            "confidence": 0.8,
        }
    }
    comparison = compare_nv_failsafe_reports(before, after)
    assert comparison["improved"] is True


def test_example_report_shape_matches_schema():
    sample_path = Path(__file__).resolve().parents[1] / "examples" / "nv-failsafe-report.sample.json"
    sample = json.loads(sample_path.read_text(encoding="utf-8"))
    assert sample["schemaVersion"] == "1.1.0"
    report_block = sample["report"]
    for field in (
        "timestamp",
        "hostname",
        "current_resolution",
        "suspected_tags",
        "evidence_items",
        "confidence_level",
        "explanation",
        "safety_warnings",
    ):
        assert field in report_block
