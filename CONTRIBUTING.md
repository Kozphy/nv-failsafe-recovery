# Contributing

Thank you for helping improve NV-Failsafe Recovery.

## Principles

1. Evidence-first language (suspected/likely/insufficient data)
2. Preview-first remediation
3. No destructive driver automation
4. Every risky action must pass policy gates
5. Auditability for apply operations

## Development setup

```powershell
git clone https://github.com/Kozphy/nv-failsafe-recovery.git
cd nv-failsafe-recovery
powershell -ExecutionPolicy Bypass -File .\scripts\Invoke-SmokeTest.ps1
```

Optional Pester:

```powershell
Install-Module Pester -Scope CurrentUser -Force
Invoke-Pester -Path .\tests
```

## Pull request expectations

- Update docs when changing classification/policy behavior
- Add/adjust tests for rule changes
- Include safety impact notes in PR template
- Keep PowerShell 5.1 compatibility unless justified

## Code style

- Imports at top of file (no inline imports)
- Structured probe objects with `status/source/errorMessage`
- Exhaustive switch handling for enums where applicable

## Security issues

Please report security concerns privately per `SECURITY.md`.
