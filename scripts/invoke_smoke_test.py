#!/usr/bin/env python3
"""Lightweight smoke validation for NV-Failsafe Recovery toolkit."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    failures: list[str] = []

    required_files = [
        "README.md",
        "nv_failsafe_recovery/cli.py",
        "nv_failsafe_recovery/evidence.py",
        "nv_failsafe_recovery/classifier.py",
        "nv_failsafe_recovery/policy.py",
        "nv_failsafe_recovery/remediation.py",
        "nv_failsafe_recovery/reporting.py",
        "nv_failsafe_recovery/audit.py",
        "nv_failsafe_recovery/utilities.py",
        "pyproject.toml",
    ]

    for relative in required_files:
        path = REPO_ROOT / relative
        if not path.exists():
            failures.append(f"Missing required file: {relative}")

    if sys.platform == "win32":
        completed = subprocess.run(
            [sys.executable, "-m", "nv_failsafe_recovery", "--mode", "detect", "--quiet"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        if completed.returncode != 0:
            failures.append(f"Detect mode failed: {completed.stderr.strip() or completed.stdout}")
        output = completed.stdout + completed.stderr
        forbidden = ("Disable-PnpDevice", "pnputil /scan-devices", "taskkill /IM explorer")
        for phrase in forbidden:
            if phrase.lower() in output.lower():
                failures.append(f"Detect mode appears to execute remediation: {phrase}")

    if failures:
        print("SMOKE TEST FAILED")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("SMOKE TEST PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
