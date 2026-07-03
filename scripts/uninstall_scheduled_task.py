#!/usr/bin/env python3
"""Uninstall logon scheduled task for NV-Failsafe monitoring."""

from __future__ import annotations

import argparse
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="Uninstall report-only logon scheduled task.")
    parser.add_argument("--task-name", default="NvFailsafeRecovery-ReportOnLogon")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if sys.platform != "win32":
        print("Scheduled task removal requires Windows.", file=sys.stderr)
        return 2

    command = ["schtasks", "/Delete", "/TN", args.task_name, "/F"]
    if args.dry_run:
        print(" ".join(command))
        return 0

    completed = subprocess.run(command, capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        print(completed.stderr or completed.stdout, file=sys.stderr)
        return completed.returncode

    print(f"Scheduled task '{args.task_name}' removed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
