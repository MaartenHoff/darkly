# JWT Forgery / Signature Bypass

> Status: ☐ not started ☐ exploited ☒ explained
> Flag: `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` (shared with grades API — no dedicated flag)
> WSTG: `WSTG-SESS-01` (Session Management Scheme Bypass) — see [`00-recon/wstg-coverage.md`](../00-recon/wstg-coverage.md)

## Where

- Endpoint: `POST /login` sets a `session` cookie containing a JWT
- Input: the JWT payload (`sub`, `login`, `role`, `exp`)
- Leak: JWT secret hardcoded in an HTML comment (deploy log)

## How it works

The app signs its session cookies with HS256 JWTs. The signature is
`HMAC-SHA256(header.payload, secret)`. If an attacker knows the secret, they can
sign **any** payload they want — the server has no way to tell a forged token
from a real one.

Two things went wrong:

1. **Secret leaked** in the page source (`v1.2.0 — sophie — ... jwt secret was "42". wil changed it to "42network".`).
2. **No server-side role check** — the server trusts the `role` claim inside the
   token instead of looking the real role up from the database.

## Exploitation (step by step)

Run `./exploit.sh`:

1. **Forge the token** — build `header` + `payload` claiming Sophie's identity
   (`sub: enplwhu8jfo56oi`, `login: sophie`, `role: god`), sign with the leaked
   secret `42network`.
2. **Send it** as the `session` cookie to `/admin`.
3. **Read the admin panel** — the server trusts `role: god` and serves the
   admin page.

The recovered flag (shared with the grades endpoint):

```
FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}
```

## Impact

Full account impersonation (Sophie, a `god`-privileged admin) and total bypass
of role-based access control. An attacker with the secret can forge tokens for
**any** user, read the admin panel, and perform any god-privileged action.

## Remediation

1. **Keep the secret server-side** — never in client code, HTML comments, or
   source control. Use an environment variable.
2. **Rotate secrets** — if a secret leaks, invalidate all tokens (short `exp`,
   blacklist, key rotation).
3. **Verify roles from the DB** — don't trust the token's `role` claim; fetch
   the user's actual role from the database on every authorization check.
4. Use a stronger secret (the 9-byte `42network` is below the 32-byte HMAC
   minimum).

## References

- WSTG: `WSTG-SESS-01` (Session Management Scheme Bypass)
- OWASP Top 10: A02 (Broken Authentication)
- Other: [jwt.io](https://jwt.io), RFC 7519
