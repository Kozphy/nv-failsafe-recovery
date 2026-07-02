# Runbook

Incident-style response for NV-Failsafe / 640x480 display fallback.

## 1. Capture report

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Report -OutputPath .\incident-report.json
```

Store report + audit log in ticket.

## 2. Identify classification

Review:

- `summary.classification`
- `summary.confidence`
- `classification.evidence[]`

## 3. Try manual low-risk recovery

1. Win+Ctrl+Shift+B
2. Power-cycle monitor
3. Reseat HDMI/DisplayPort cable
4. Try alternate port/cable

## 4. Run safe fix preview

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel safe
```

## 5. Run safe fix apply

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel safe -Apply
```

## 6. Run monitor rescan (admin)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel monitor -Apply
```

## 7. Escalate to driver reinstall guidance

Follow `DRIVER_REINSTALL_GUIDANCE` messages in Doctor/Fix output. Perform manual clean reinstall from NVIDIA.

## 8. DDU only as last resort

Manual procedure only. Toolkit emits guidance via `DDU_LAST_RESORT_GUIDANCE` and never executes it.

## 9. Verify

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Verify -BaselineReportPath .\incident-report.json
```

## Optional: logon monitoring

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Install-ScheduledTask.ps1
```

This installs **Report-only** collection at user logon.
