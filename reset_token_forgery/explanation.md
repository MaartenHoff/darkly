# MD5(email) Reset-Token Forgery

## Where
`POST /reset-password/confirm` — params `email`, `token`, `new_password`; the `token` is validated against `GET /reset-password?email=&token=`.

## How it works
The reset token is just **`MD5(email)`** — no key, no randomness. Anyone who knows a target's email can compute a valid token offline and set a new password, with no inbox access and no rate-limited guessing. Staff/`god` accounts are exempted server-side ("use 42 SSO"); every regular student is vulnerable.

## Exploitation (`./exploit.sh`)
1. **Forge** — `md5(target_email)`.
2. **Reset** — `POST /reset-password/confirm` with `email`, the forged `token`, and a chosen `new_password`.
3. **Log in** as the target to confirm takeover.

Verified against `benjamin@student.42.tech`: `md5(…) = f1640a02…b3ba` → `302 /login?success=Password+updated` → login issued a genuine server-signed JWT (`{"login":"benjamin","role":"student",…}`). Against `wil` (staff) it was blocked (`error=Staff+and+god+accounts+use+42+SSO`) — confirmed real, since the attempted password still failed to log in, so wil's password was untouched.

**Full sweep:**

| Account | Result |
|---|---|
| benjamin / dorian / thanos @student | takeover OK — `recovery_code` = `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` |
| anne-sophie @student | takeover OK — `recovery_code` empty |
| jdoe, emilie (cadet) · wil (staff) · sophie (god) | SSO-blocked |

The flag is shared across benjamin/dorian/thanos (no per-account flag). Its value is read from `recovery_code` via PocketBase's direct read (the field-exposure bug) — the reset flow only sets the password, it never displays that field. See [`pocketbase_field_exposure/`](../pocketbase_field_exposure/).

## Impact
Silent, full account takeover of any non-staff/god user from just their email — and emails are guessable (`firstname@student.42.tech`). The attacker can lock out the owner and hold the identity indefinitely. Staff/god are protected only by an SSO carve-out in this one code path, not by any fix to the token itself.

## Remediation
1. Generate tokens with a CSPRNG (32+ random bytes), never derived from user data.
2. Make them single-use and short-lived.
3. Deliver the token only via the registered email, never in a guessable URL.
4. Rate-limit and log reset attempts.

## References
WSTG-ATHN-09 · OWASP A07:2021. Discovery: [`attempts/insecure_password_reset/`](../attempts/insecure_password_reset/); SQLi ruled out on this endpoint: [`attempts/sql_injection/`](../attempts/sql_injection/).
