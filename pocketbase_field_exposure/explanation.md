# PocketBase Field-Level Exposure

The website (`:4942`) is a thin skin over a PocketBase database (`:8090`). Authenticating to PocketBase directly — `POST /api/collections/users/auth-with-password` — returns your **entire** row, including columns the app never shows:

- **`pw_hint`** = `MD5(your password)` — harmless (you already know the password).
- **`recovery_code`** — empty on your own account.

**No flag of its own.** On your own account there's nothing to capture. The flag only appears on `benjamin`, and only because `reset_token_forgery` took over his account first: his `recovery_code` holds `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` — that breach's flag (the value names it), surfaced *through* this disclosure. Field exposure is the mechanism, not the source.

Not IDOR: asking for *another* user's record is correctly blocked (`404`). The bug is that server-internal fields in your *own* record were never hidden from the owner.

## Remediation
- Keep PocketBase internal (reachable only by the app server), not public.
- Use PocketBase field-level rules to strip internal columns from responses.
- Don't store server-only data alongside data the client logs into; don't build a "hint" from an unsalted password hash.

## References
WSTG-APIT-* · OWASP API `API3:2023` (Broken Object Property Level Authorization) — not IDOR. Flag belongs to [`reset_token_forgery/`](../reset_token_forgery/).
