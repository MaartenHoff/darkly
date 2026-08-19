# MD5(email) Reset-Token Forgery

> Status: ☒ exploited ☒ explained
> Flag: _no flag — documented vulnerability only_ (impact: full account takeover)
> WSTG: `WSTG-ATHN-09` (Testing for Weak Password Change or Reset Functionalities) — see [`00-recon/wstg-coverage.md`](../00-recon/wstg-coverage.md)

## Where

- Endpoint: `POST /reset-password/confirm` (token issued/validated against `GET /reset-password?email=&token=`)
- Parameter: `token`

## How it works

The password-reset token is not a random, single-use secret — it's simply
`MD5(email)`. MD5 has no key, so anyone who knows (or guesses) a target's
email address can compute a valid reset token entirely offline, with no need
to intercept the target's inbox and no rate-limited guessing involved.

Staff and `god`-role accounts are exempted server-side ("Staff and god
accounts use 42 SSO"), but every regular student account is vulnerable.

## Exploitation (step by step)

Run `./exploit.sh`:

1. **Forge the token** — compute `md5(target_email)` locally.
2. **Set a new password** — `POST /reset-password/confirm` with `email`, the
   forged `token`, and a `new_password` of the attacker's choosing.
3. **Log in** as the target with the new password to confirm takeover.

Verified against `benjamin@student.42.tech`:
`md5("benjamin@student.42.tech") = f1640a02eeccb971463836da7300b3ba` →
`POST /reset-password/confirm` → `302 /login?success=Password+updated` →
logging in with the new password issued a genuine, server-signed session JWT:

```
{"sub":"8l16vboi47dmand","login":"benjamin","role":"student","exp":...}
```

Tried first against `wil@42network.fr` (STAFF) — blocked:
`302 /reset-password?error=Staff+and+god+accounts+use+42+SSO`. Confirmed the
block was real (not just a misleading redirect) by attempting to log in with
the password we'd tried to set: it failed, no session was issued, proving
wil's real password was untouched.

## Impact

Full, silent account takeover of any non-staff/god user, given only their
email address (this app uses a predictable `firstname@student.42.tech`
convention, making targets easy to guess). An attacker can lock the
legitimate owner out and assume their identity indefinitely. Staff/god
accounts are currently protected only by an SSO carve-out in this one code
path — not by a structural fix to the token itself.

## Remediation

1. **Generate reset tokens with a CSPRNG** (32+ random bytes), never derived
   from public/guessable user data.
2. **Make tokens single-use and short-lived**, invalidated after first use or
   a short TTL.
3. **Never expose the token in a URL** — deliver it only via the registered
   email address.
4. **Rate-limit and log** reset attempts to detect enumeration/abuse.

## References

- WSTG: `WSTG-ATHN-09` (Testing for Weak Password Change or Reset Functionalities)
- OWASP Top 10: A07:2021 (Identification and Authentication Failures)
- Other: [`attempts/insecure_password_reset/`](../attempts/insecure_password_reset/) (original discovery notes), [`attempts/sql_injection/`](../attempts/sql_injection/) (ruled out SQLi on this same endpoint)
