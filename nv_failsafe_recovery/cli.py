"""Command-line interface for NV-Failsafe Recovery."""

from __future__ import annotations

import argparse
import sys

from nv_failsafe_recovery.evidence import is_windows
from nv_failsafe_recovery.orchestrator import run_mode_handler


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="nv-failsafe-recovery",
        description=(
            "Evidence-first detection, classification, policy-gated remediation, and audit "
            "for NVIDIA NV-Failsafe / 640x480 display fallback states on Windows."
        ),
    )
    parser.add_argument(
        "--mode",
        choices=["detect", "report", "doctor", "fix", "verify"],
        default="detect",
        help="CLI mode (default: detect)",
    )
    parser.add_argument(
        "--fix-level",
        choices=["none", "safe", "monitor", "adapter"],
        default="none",
        help="Remediation scope for Fix/Doctor modes",
    )
    parser.add_argument("--apply", action="store_true", help="Apply remediation actions")
    parser.add_argument("--force", action="store_true", help="Authorize high-risk adapter restart")
    parser.add_argument(
        "--output-path",
        default="./nv-failsafe-report.json",
        help="Report output path",
    )
    parser.add_argument(
        "--audit-path",
        default="./nv-failsafe-audit.jsonl",
        help="Append-only audit log path",
    )
    parser.add_argument(
        "--baseline-report-path",
        default="",
        help="Baseline report for verify mode",
    )
    parser.add_argument("--json", dest="json_output", action="store_true", help="Emit JSON to stdout")
    parser.add_argument("--quiet", action="store_true", help="Reduce human output")
    return parser


def main(argv: list[str] | None = None) -> int:
    if not is_windows():
        print(
            "nv-failsafe-recovery requires Windows for evidence collection and remediation.",
            file=sys.stderr,
        )
        return 2

    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        return run_mode_handler(
            args.mode,
            fix_level=args.fix_level,
            apply=args.apply,
            force=args.force,
            output_path=args.output_path,
            audit_path=args.audit_path,
            baseline_report_path=args.baseline_report_path,
            json_output=args.json_output,
            quiet=args.quiet,
        )
    except Exception as exc:  # noqa: BLE001
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
