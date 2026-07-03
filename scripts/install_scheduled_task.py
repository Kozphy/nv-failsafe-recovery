#!/usr/bin/env python3
"""Install logon scheduled task for Report-only NV-Failsafe monitoring."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Install report-only logon scheduled task.")
    parser.add_argument("--task-name", default="NvFailsafeRecovery-ReportOnLogon")
    parser.add_argument("--output-directory", default="")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if sys.platform != "win32":
        print("Scheduled task installation requires Windows.", file=sys.stderr)
        return 2

    output_directory = args.output_directory or str(
        Path(os.environ.get("LOCALAPPDATA", ".")) / "NvFailsafeRecovery"
    )
    Path(output_directory).mkdir(parents=True, exist_ok=True)

    report_path = str(Path(output_directory) / "nv-failsafe-report.json")
    audit_path = str(Path(output_directory) / "nv-failsafe-audit.jsonl")
    python_exe = sys.executable
    arguments = (
        f'-m nv_failsafe_recovery --mode report --output-path "{report_path}" '
        f'--audit-path "{audit_path}" --quiet'
    )

    command = [
        "schtasks",
        "/Create",
        "/TN",
        args.task_name,
        "/TR",
        f'"{python_exe}" {arguments}',
        "/SC",
        "ONLOGON",
        "/RL",
        "LIMITED",
        "/F",
    ]

    if args.dry_run:
        print(" ".join(command))
        return 0

    completed = subprocess.run(command, capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        print(completed.stderr or completed.stdout, file=sys.stderr)
        return completed.returncode

    print(f"Scheduled task '{args.task_name}' installed.")
    print(f"Report output: {report_path}")
    print("This task runs Report mode only and never runs Fix automatically.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
