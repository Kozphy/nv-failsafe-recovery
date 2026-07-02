# Threat Model

## Assets

- Display output availability (user productivity)
- Local audit/report artifacts (incident evidence)
- Operator trust in automation safety

## Threats

| Threat | Impact | Mitigation |
|--------|--------|------------|
| Accidentally disabling active display adapter | Loss of video output | Adapter restart requires `-Apply` + `-Force` + admin; NVIDIA-only targeting |
| Misclassifying hardware failure | Wrong escalation | Evidence-tagged classifications; no hardware verdict by default |
| Destructive driver changes | System instability | No uninstall/DDU automation |
| Overconfident automation | Unsafe operator action | Preview-first; careful language |
| Running as admin without understanding | High-risk apply | Policy reasons + audit trail |
| Tampered audit log | Lost accountability | Append-only default; operator controls path |
| Probe failures hidden | False negatives | Per-probe `status` + `INSUFFICIENT_DATA` |

## Out of scope

- Remote execution hardening (toolkit is local CLI)
- Kernel-mode driver analysis
- EDID binary parsing (future enhancement)

## Recommended deployment

- Standard users: Detect/Report/Doctor without `-Apply`
- Helpdesk elevated: Fix `-FixLevel monitor` with audit path to secured folder
- Adapter restart: senior operator only, with physical access / KVM
