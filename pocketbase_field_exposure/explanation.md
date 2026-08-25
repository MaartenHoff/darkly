# PocketBase Field-Level Exposure

> Status: ☒ exploited ☒ explained
> Flag: `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` (from benjamin's `recovery_code`)
> WSTG: `WSTG-APIT-*` (API Testing) · precise category: OWASP API `API3:2023`
> — see [`00-recon/wstg-coverage.md`](../00-recon/wstg-coverage.md)

**In short:** the website (`:4942`) is just a thin skin over a PocketBase
database (`:8090`). If you talk to PocketBase directly instead of clicking
through the website, logging into your own account hands back your *entire*
database row — including two fields the website never shows anyone. One of
those fields is this challenge's flag.

## Where

- `POST /api/collections/users/auth-with-password` on PocketBase directly (`:8090`), skipping the app entirely
- Also works via `GET /api/collections/users/records/:id` with an auth token

## How it works

The website shows you a few fields about yourself: your username, role, a
note. Behind the scenes, when you log in, the website is just forwarding
your email/password to PocketBase and getting back a full database record —
it just chooses to *display* only a few of those fields. PocketBase itself
imposes no such filter: ask it directly, and it hands back every column.

Two columns exist that the website never shows you:

- **`pw_hint`** — turns out to be `MD5(your current password)`, recalculated
  every time your password changes. Harmless: to read it you already need
  your live password, and it just tells you back a hash of that same
  password — nothing new.
- **`recovery_code`** — this is where the flag lives, for the account `benjamin`.

No forging is needed to trigger this — jdoe's real, already-known password
(from the Phase 2 brute-force) shows the exact same thing. The reset-token
and JWT breaches aren't the cause here; they were just convenient ways to
get valid login credentials for a *specific* target account.

**Why this isn't the classic IDOR bug:** IDOR means seeing *someone else's*
data by guessing their ID. We tested that directly — logged in as benjamin,
asking PocketBase for jdoe's record returns `404`. That door is locked
properly. What's actually broken is different: you're allowed into your
*own* record, but a couple of fields inside it were only ever meant for the
server's internal use, and nobody bothered to hide them from the owner
either. It's less "wrong door" and more "right door, but there's a filing
cabinet in there that should have stayed in the back office."

## Exploitation (step by step)

Run `./exploit.sh`:

1. Log into PocketBase directly (`:8090`) as `jdoe`, using his real password. No forging.
2. Look at the full JSON response — `pw_hint` and `recovery_code` are just sitting there.
3. Do the same for `benjamin` (whose password we control via `reset_token_forgery`) — his `recovery_code` is the flag:

```
FLAG{r3s3t_t0k3n_w4s_just_md5_lol}
```

## Impact

- **No one else's data is exposed** — only your own account's hidden fields. There's no privacy breach between users.
- **`pw_hint`** — not exploitable. It only ever repeats back a hash of a password you already had to know to log in.
- **`recovery_code`** — a genuine internal field leaking, and here it's literally the flag. Being honest about how serious this would be outside of a CTF: seeing an unused field about your *own* account is a fairly minor issue on its own — it only becomes a real problem if that field's value is useful somewhere else (a real recovery code that could unlock something), which we can't confirm this app ever does.

The lesson either way: any field on a table that a client can log into will eventually be readable by that client, whether or not the frontend meant to show it. Server-only data needs to live somewhere a client login can never reach, not just somewhere the frontend chooses not to display.

## Remediation

1. Don't expose the database's own API to the public internet — keep PocketBase internal, reachable only by the app server.
2. Use PocketBase's field-level rules to strip internal-only columns from API responses.
3. Put server-only data in a separate collection the client can never query, not alongside data the client logs into.
4. Don't build a "hint" out of an unsalted hash of the real password — use bcrypt/argon2 for storage, and a random one-time token for recovery.

## References

- WSTG: `WSTG-APIT-*` (API Testing) — not `ATHZ-04`/IDOR, since cross-user access is correctly blocked
- OWASP API Security Top 10: `API3:2023` (Broken Object Property Level Authorization)
- Other: [`reset_token_forgery/`](../reset_token_forgery/), [`jwt_forgery/`](../jwt_forgery/) (surfaced the PocketBase URL)
