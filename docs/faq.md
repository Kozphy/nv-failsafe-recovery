# FAQ

## What is NV-Failsafe / 640x480?

Windows may fall back to a basic display mode (often **640x480**) with a generic monitor name such as **NV-Failsafe** when the GPU and monitor cannot establish a stable display configuration.

## Does this tool prove my GPU is broken?

No. The toolkit reports **suspected** states based on local evidence. Hardware failure is not inferred without stronger signals.

## Is it safe to run Detect mode?

Yes. Detect mode collects evidence only and does not change system state.

## Why preview-first?

To prevent unintended display loss or risky changes during initial triage.

## Why does adapter restart need `-Force`?

Disabling the active NVIDIA display adapter can blank the screen. This is intentional friction.

## Will this uninstall my NVIDIA driver?

Never. Driver reinstall and DDU are guidance-only.

## Can I schedule automatic fixes?

No. The scheduled task installer registers **Report mode only**.

## PowerShell 5.1 vs 7?

The toolkit targets both Windows PowerShell 5.1 and PowerShell 7 where possible.

## Where are reports stored?

Default: `.\nv-failsafe-report.json`. Scheduled task uses `%LOCALAPPDATA%\NvFailsafeRecovery\`.

## What if probes fail?

The run continues. Failed probes surface as `error`/`unavailable` and may lead to `INSUFFICIENT_DATA`.
