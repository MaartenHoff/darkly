# __BREACH__

> Status: ☐ not started ☐ exploited ☐ explained
> Flag: `FLAG{...}` (or _no flag — documented vulnerability only_)
> WSTG: `WSTG-XXX-00` — see [`00-recon/wstg-coverage.md`](../00-recon/wstg-coverage.md)

## Where

Location of the breach (URL / parameter / form / cookie / header):

- Endpoint:
- Parameter / input:

## How it works

Explain the underlying flaw — what the application does wrong and why the input
you send subverts it. Enough that a reviewer with no prior context understands
the mechanism.

## Exploitation (step by step)

Mirror `exploit.sh`, but in prose. Each step: what you send, what you expect
back, and why.

1.
2.
3.

The recovered flag (if any):

```
FLAG{...}
```

## Impact

What an attacker gains (data read/modified, accounts taken over, code executed,
privilege level reached) and the realistic business consequence.

## Remediation

How the application should be fixed. Be specific: the concrete control
(parameterized queries, output encoding, server-side auth checks, allow-list
upload validation, etc.), not just "validate input".

## References

- WSTG: `WSTG-XXX-00` (test name)
- OWASP Top 10:
- Other:
