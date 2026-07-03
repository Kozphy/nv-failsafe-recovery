"""CLI orchestration for NV-Failsafe Recovery."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from nv_failsafe_recovery.audit import write_audit_event
from nv_failsafe_recovery.classifier import get_nv_failsafe_classification
from nv_failsafe_recovery.evidence import get_full_evidence_bundle, test_is_administrator
from nv_failsafe_recovery.policy import get_fix_plan
from nv_failsafe_recovery.remediation import invoke_remediation_plan
from nv_failsafe_recovery.reporting import (
    compare_nv_failsafe_reports,
    new_nv_failsafe_report,
    write_human_summary,
    write_json_report,
)
from nv_failsafe_recovery.utilities import to_json_serializable


def invoke_detect_phase(
    run_mode: str,
    *,
    fix_level: str = "none",
    apply: bool = False,
    force: bool = False,
) -> dict[str, Any]:
    evidence = get_full_evidence_bundle()
    classification = get_nv_failsafe_classification(evidence)
    is_admin = test_is_administrator()

    effective_fix_level = fix_level
    if run_mode in ("Fix", "Doctor") and fix_level == "none":
        effective_fix_level = "safe"

    policy_plan = None
    if run_mode in ("Fix", "Doctor", "Verify"):
        policy_plan = get_fix_plan(
            effective_fix_level,
            apply=apply,
            force=force,
            is_administrator=is_admin,
            classification=classification,
        )

    return new_nv_failsafe_report(
        evidence,
        classification,
        mode=run_mode,
        policy_plan=policy_plan,
    )


def write_session_audit_event(
    audit_path: str,
    mode: str,
    fix_level: str,
    apply: bool,
    force: bool,
    event_type: str,
    result: str,
    error_message: str = "",
) -> None:
    write_audit_event(
        audit_path,
        event_type,
        mode=mode,
        result=result,
        error=error_message,
        fix_level=fix_level or "none",
        apply_used=apply,
        force_used=force,
    )


def run_mode_handler(
    mode: str,
    *,
    fix_level: str = "none",
    apply: bool = False,
    force: bool = False,
    output_path: str = "./nv-failsafe-report.json",
    audit_path: str = "./nv-failsafe-audit.jsonl",
    baseline_report_path: str = "",
    json_output: bool = False,
    quiet: bool = False,
) -> int:
    write_session_audit_event(
        audit_path, mode, fix_level, apply, force, "session_start", "started"
    )

    try:
        if mode == "detect":
            report = invoke_detect_phase("Detect", fix_level=fix_level, apply=apply, force=force)
            if json_output:
                print(json.dumps(to_json_serializable(report), indent=2))
            else:
                write_human_summary(report, quiet=quiet)

        elif mode == "report":
            report = invoke_detect_phase("Report", fix_level=fix_level, apply=apply, force=force)
            write_json_report(report, output_path)
            if not quiet:
                print(f"Report written to {output_path}")
                write_human_summary(report, quiet=False)

        elif mode == "doctor":
            report = invoke_detect_phase("Doctor", fix_level=fix_level, apply=apply, force=force)
            if not quiet:
                print("=== NV-Failsafe Recovery Doctor ===")
                write_human_summary(report, quiet=False)
                print()
                print("Likely cause (evidence-based):")
                explanation = (report.get("classification") or {}).get("explanation")
                if explanation:
                    print(f"  {explanation}")
                for item in (report.get("classification") or {}).get("evidence") or []:
                    print(f"  - {item}")
                print()
                print("Manual next steps:")
                for step in (report.get("classification") or {}).get("manualSteps") or []:
                    print(f"  - {step}")
                print()
                print("Automated next steps:")
                for step in (report.get("classification") or {}).get("automatedSteps") or []:
                    print(f"  - {step}")

            if apply:
                effective_fix_level = "safe" if fix_level == "none" else fix_level
                results = invoke_remediation_plan(
                    report.get("policyPlan") or [],
                    apply=True,
                    force=force,
                    audit_path=audit_path,
                    mode="Doctor",
                    classification=(report.get("classification") or {}).get("classification", ""),
                    fix_level=effective_fix_level,
                )
                report["remediationResults"] = results
            elif not quiet:
                print()
                print("Doctor mode did not change system state (no --apply).")

            if json_output:
                print(json.dumps(to_json_serializable(report), indent=2))

        elif mode == "fix":
            before = invoke_detect_phase("Fix", fix_level=fix_level, apply=apply, force=force)
            effective_fix_level = "safe" if fix_level == "none" else fix_level
            before["policyPlan"] = get_fix_plan(
                effective_fix_level,
                apply=apply,
                force=force,
                is_administrator=test_is_administrator(),
                classification=before.get("classification"),
            )

            if not apply:
                if not quiet:
                    print("=== Fix Preview (no system changes) ===")
                    write_human_summary(before, quiet=False)
                write_audit_event(
                    audit_path,
                    "fix_preview",
                    mode="Fix",
                    classification=(before.get("classification") or {}).get("classification", ""),
                    result="preview",
                    fix_level=effective_fix_level,
                    apply_used=False,
                    force_used=force,
                    execution_mode="preview",
                )
                report = before
            else:
                results = invoke_remediation_plan(
                    before.get("policyPlan") or [],
                    apply=True,
                    force=force,
                    audit_path=audit_path,
                    mode="Fix",
                    classification=(before.get("classification") or {}).get("classification", ""),
                    fix_level=effective_fix_level,
                )
                after = invoke_detect_phase("Verify", fix_level=fix_level, apply=apply, force=force)
                verification = compare_nv_failsafe_reports(before, after)
                after["verification"] = verification
                after["remediationResults"] = results
                report = after

                if not quiet:
                    print("=== Fix Applied - Verification Summary ===")
                    print(
                        f"Resolution changed: {verification['resolutionChanged']} "
                        f"({verification['resolutionBefore']} -> {verification['resolutionAfter']})"
                    )
                    print(
                        f"Classification changed: {verification['classificationChanged']} "
                        f"({verification['classificationBefore']} -> {verification['classificationAfter']})"
                    )
                    print(f"Improved: {verification['improved']}")

            if json_output:
                print(json.dumps(to_json_serializable(report), indent=2))
            elif apply and not quiet:
                write_human_summary(report, quiet=False)

        elif mode == "verify":
            current = invoke_detect_phase("Verify", fix_level=fix_level, apply=apply, force=force)
            baseline_path = baseline_report_path or output_path
            path = Path(baseline_path)
            if not path.exists():
                raise FileNotFoundError(f"Baseline report not found: {baseline_path}")

            baseline = json.loads(path.read_text(encoding="utf-8"))
            comparison = compare_nv_failsafe_reports(baseline, current)
            current["verification"] = comparison

            if not quiet:
                print("=== Verify Comparison ===")
                print(json.dumps(comparison, indent=2))
                write_human_summary(current, quiet=False)

            if json_output:
                print(json.dumps(to_json_serializable(current), indent=2))

        else:
            raise ValueError(f"Unhandled mode: {mode}")

        write_session_audit_event(
            audit_path, mode, fix_level, apply, force, "session_complete", "success"
        )
        return 0
    except Exception as exc:  # noqa: BLE001
        write_session_audit_event(
            audit_path, mode, fix_level, apply, force, "session_error", "error", str(exc)
        )
        raise
