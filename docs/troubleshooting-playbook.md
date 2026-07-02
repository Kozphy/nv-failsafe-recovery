# Troubleshooting Playbook

Use this order unless incident context strongly suggests otherwise.

```text
Win + Ctrl + Shift + B
↓
Power-cycle monitor
↓
Unplug/replug HDMI or DisplayPort
↓
Try another GPU port
↓
Try another cable
↓
Run monitor rescan (toolkit Fix -FixLevel monitor -Apply, admin)
↓
Disable Fast Startup
↓
Clean reinstall NVIDIA driver (manual)
↓
Use DDU only as last resort (manual, never automated)
```

## Scenario notes

### Unplug/replug fixes it temporarily

Evidence likely indicates EDID / handshake / cable / port issue.

### Happens after sleep/wake

Evidence may indicate sleep/wake display initialization race. Test with Fast Startup disabled.

### Happens every boot

Suspect persistent monitor detection drift or driver fallback state. Collect scheduled Report artifacts across boots.

### Code 43, artifacts, crashes, repeated adapter errors

Escalate to driver or hardware investigation. This toolkit will not auto-classify hardware failure without stronger evidence.

## Toolkit commands

```powershell
# Capture evidence
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Report -OutputPath .\report.json

# Explain likely cause
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Doctor

# Preview safe fixes
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel safe

# Apply safe fixes
powershell -ExecutionPolicy Bypass -File .\scripts\NvFailsafeRecovery.ps1 -Mode Fix -FixLevel safe -Apply
```
