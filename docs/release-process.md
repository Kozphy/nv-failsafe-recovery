# Release Process

This project uses tag-driven continuous delivery via [`.github/workflows/release.yml`](../.github/workflows/release.yml).

## Versioning

1. Update `ModuleVersion` in `psd1/NvFailsafeRecovery.psd1`.
2. Ensure `Get-ToolkitVersion` in `src/Utilities.ps1` matches.
3. Report schema is versioned separately via `Get-ReportSchemaVersion` (currently `1.1.0`).

## Cut a release

```bash
git add psd1/NvFailsafeRecovery.psd1 src/Utilities.ps1
git commit -m "Release v1.1.0"
git tag v1.1.0
git push origin main
git push origin v1.1.0
```

## Release pipeline

On tag push (`v*`):

1. Verify tag matches `ModuleVersion`
2. Parse all PowerShell scripts
3. Install Pester and run full test suite
4. Package release zip
5. Generate SHA256 checksum
6. Publish GitHub Release artifact

## Pre-release checklist

- [ ] CI green on `main`
- [ ] `Invoke-SmokeTest.ps1` passes locally
- [ ] `Invoke-Pester -Path ./tests` passes locally
- [ ] README and docs reflect any behavior changes
- [ ] No local incident reports committed

## Consumer install

Download the release zip from GitHub Releases, extract, and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Detect
```

Verify checksum before use in regulated environments.

## What releases do not include

- Automatic Fix mode deployment
- Driver uninstall packages
- DDU or registry mutation tooling

Releases are read-only diagnostic/recovery scripts intended for controlled endpoint use.
