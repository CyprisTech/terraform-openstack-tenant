# Architecture decision records

An architecture decision record (ADR) captures one significant design decision: its context, the decision itself and its consequences. Until the first release, ADRs are revised in place. Once an implementation has been released, an ADR is no longer edited: a later decision supersedes it with a new ADR.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-module-design.md) | Module design | Accepted (`v0.1.0`) |
| [0002](0002-output-contract.md) | Output contract of the tenant composite | Accepted (`v0.1.0`, recorded later) |
| [0003](0003-floating-ips-per-port.md) | Several floating IPs on one port | Accepted (`v0.1.2`, recorded later) |

## Writing an ADR

1. Copy [template.md](template.md) to `NNNN-short-title.md` with the next number.
2. Open a pull request with status *Proposed*.
3. Once merged, the status becomes *Accepted*. Add it to the table above.
