# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## Reporting a vulnerability

Please do **not** open public issues for exploitable security problems.

Report privately to the repository maintainer with:

- Description and impact
- Reproduction steps
- Suggested mitigation (if any)

## Scope notes

This toolkit intentionally performs high-impact local operations when explicitly requested (`-Apply`, `-Force`, admin). Security focus areas:

- Preventing accidental execution of high-risk actions
- Avoiding destructive driver operations
- Preserving audit integrity
- Preventing misleading certainty in classifications

## Safe usage

- Run Detect/Report without elevation when possible
- Treat audit logs as sensitive operational data
- Review Fix previews before applying
