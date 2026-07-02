# Decision Tree

```text
Start: unexpected 640x480 / NV-Failsafe / generic monitor
│
├─ Collect Report
│   └─ classification + confidence + evidence[]
│
├─ If unplug/replug HDMI/DP fixes it
│   └─ likely EDID / handshake / cable / port issue
│       └─ recommended: cable/port swap, monitor refresh
│
├─ If occurs after sleep/wake
│   └─ likely sleep/wake display initialization issue
│       └─ recommended: Win+Ctrl+Shift+B, disable Fast Startup
│
├─ If occurs every boot
│   └─ likely persistent monitor detection or driver fallback
│       └─ recommended: scheduled Report, monitor rescan, driver reinstall guidance
│
├─ If NVIDIA adapter missing or status not OK
│   └─ likely driver fallback (not proven hardware failure)
│       └─ recommended: safe fix, driver reinstall guidance
│
└─ If Code 43, black screen, artifacts, crashes, repeated adapter errors
    └─ escalate hardware/driver deep investigation
        └─ toolkit provides evidence only; no destructive automation
```

## Confidence interpretation

| Confidence | Operator interpretation |
|------------|-------------------------|
| < 0.5 | Weak signal — gather more evidence |
| 0.5 – 0.75 | Plausible hypothesis — try low-risk steps |
| > 0.75 | Strong suspicion — proceed with policy-gated fixes |

Always pair confidence with `evidence[]` review.
