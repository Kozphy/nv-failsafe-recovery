# Release Process

This project uses tag-driven continuous delivery via [`.github/workflows/release.yml`](../.github/workflows/release.yml).

## Versioning

1. Update `version` in `pyproject.toml` (toolkit version, currently **2.0.0**).
2. Update `TOOLKIT_VERSION` in `nv_failsafe_recovery/version.py` to match.
3. Report schema is versioned separately via `REPORT_SCHEMA_VERSION` (currently **1.1.0**).

Legacy PowerShell v1.1.0 remains under `legacy/powershell/psd1/` for archival reference only.

## Cut a release

```bash
git add pyproject.toml nv_failsafe_recovery/version.py
git commit -m "Release v2.0.0"
git tag v2.0.0
git push origin main
git push origin v2.0.0
```

## Release pipeline

On tag push (`v*`):

1. Verify tag matches `pyproject.toml` version
2. Install Python package and dev dependencies
3. Run smoke test and pytest
4. Package release zip (Python package + docs + legacy sources)
5. Generate SHA256 checksum
6. Publish GitHub Release artifact

## Pre-release checklist

- [ ] Python CI green on `main`
- [ ] `python scripts/invoke_smoke_test.py` passes locally
- [ ] `pytest` passes locally on Windows
- [ ] README and docs reflect any behavior changes
- [ ] No local incident reports committed

## Consumer install

1. Download release zip from GitHub Releases.
2. Verify SHA256 checksum.
3. Extract and install:

```powershell
pip install -e .
python -m nv_failsafe_recovery --mode detect
```

## Safety reminder

Releases must preserve preview-first semantics. Never ship builds that auto-apply adapter restart or driver removal.
