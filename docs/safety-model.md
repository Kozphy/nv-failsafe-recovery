# Safety Model

This toolkit is designed for endpoint reliability teams, not “one-click fix” automation.

## Core guarantees

| Rule | Implementation |
|------|----------------|
| Preview-only by default | Fix/Doctor without `-Apply` |
| No destructive actions without explicit flags | Policy module gates |
| Adapter restart is high risk | Requires `-Apply`, `-Force`, admin |
| Never uninstall NVIDIA drivers | Guidance only |
| Never run DDU | Guidance only |
| Never force custom resolution | Not implemented |
| Never edit registry by default | Not implemented |
| Never kill arbitrary processes | Explorer restart only, gated |
| Never hide failures | Probe `error` status + audit errors |
| Append-only audit log | `Write-AuditEvent` |

## Language model

The toolkit uses careful language by design:

- **suspected** / **likely** / **evidence indicates**
- **insufficient data** when probes fail
- **recommended next step** instead of guarantees

It avoids:

- “your GPU is broken”
- “driver is definitely corrupted”
- “this will fix it”

## Detection is not proof

A `NV_FAILSAFE_SUSPECTED` classification means the collected evidence aligns with a known fallback pattern. It does not prove root cause.

## Classification is not accusation

Tags like `MONITOR_EDID_HANDSHAKE_SUSPECTED` identify plausible hypotheses ranked by evidence, starting with handshake/detection issues before hardware failure.

## Recommendation is not execution authority

Doctor mode suggestions are operational guidance. Only policy-allowed actions run in Fix mode, and only with `-Apply`.

## Risk tiers

| Tier | Examples |
|------|----------|
| Low | Display refresh hint, Explorer restart |
| Medium | PnP rescan, monitor refresh |
| High | NVIDIA adapter disable/enable |
| Guidance | Driver reinstall, DDU last resort |

## Operational guidance

1. Always run **Detect** or **Report** first.
2. Review JSON + human summary.
3. Try manual low-risk steps (Win+Ctrl+Shift+B, cable reseat).
4. Preview Fix mode.
5. Apply only the minimum FixLevel required.
