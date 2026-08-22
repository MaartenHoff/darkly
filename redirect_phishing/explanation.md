# Open Redirect → Phishing (Credential Harvest)

> Status: ☒ exploited ☒ explained
> Flag: _no flag — documented vulnerability only_ (probed extensively: the endpoint never returns one)
> WSTG: `WSTG-CLNT-04` (Testing for Client-side URL Redirect) — see [`00-recon/wstg-coverage.md`](../00-recon/wstg-coverage.md)

## Where

- Endpoint: `GET /redirect`
- Parameter: `next` — arbitrary destination, echoed into the `Location:` header

The site itself uses the redirector for its own outbound links, which trains
users that `…/redirect?next=…` is a normal, first-party pattern:

- homepage + every page footer: "42.tech" and "Intra" links
  (`/redirect?next=https://42.tech`, `/redirect?next=https://code.42.tech`)
- login page: "Continue with Google" (`/redirect?next=https://accounts.google.com`)

## How it works

The handler reads the `next` query parameter and hands it straight to a
Starlette-style redirect response — no allow-list, no scheme check, not even
a restriction to relative paths:

```
GET /redirect?next=<value>   →   HTTP/1.1 307 Temporary Redirect
                                 Location: <value>
```

Verified black-box (all reflected with case preserved):

| `next=` | `Location:` |
|---|---|
| `https://evil.example/login` | same, verbatim |
| `//evil.example` | same (scheme-relative works too) |
| `Https://MiXeD.evil/x` | case untouched — zero normalization |
| `javascript:alert(1)` | passed through unfiltered |

Two edges show the value is read as a *standard parsed query param* before
being echoed (consistent with a plain `next: str` handed to
`RedirectResponse`, though the exact source line is unverifiable from
outside): the value is percent-decoded once (`%7Euser` → `~user`), and `&`
delimits parameters at the HTTP level. Neither is server-side rewriting —
whatever string arrives as `next` is what lands in `Location`.

**Why phishing works:** browsers and users trust the *host*, and the link's
host is the real site. The victim clicks `http://<trusted>:4942/redirect?next=http://attacker/login`
and is delivered to an attacker-controlled page that can be a pixel-faithful
clone of the real login screen.

**Why 307 specifically matters:** unlike `302`, a `307 Temporary Redirect`
replays the request **with its method and body intact**. A victim who
submits a form through the redirect chain forwards the raw `POST` body —
e.g. credentials — to the attacker's endpoint, not just a click.

## Exploitation (step by step)

Run `./exploit.sh` (curl-only, no background processes):

1. **Recon anchor** — fetch `/login` and list the first-party
   `/redirect?next=` links (footer + "Continue with Google"): proof the
   redirector pattern is normal on this site.
2. **Craft the link** — `http://localhost:4942/redirect?next=https://evil.example/login`.
   Raw response shown in full:
   `HTTP/1.1 307 Temporary Redirect` / `Location: https://evil.example/login`
   — the trusted host orders the browser onto an attacker URL, unfiltered.
3. **What the victim would see** — an attacker hosts at the `Location` target
   a standalone clone of the real login page (same fonts, dark theme,
   "Session expired — sign in again…" banner); its only functional difference
   is that the form posts credentials to the attacker instead of `POST /login`,
   after which it bounces the victim back to the real site so nothing looks
   broken. No infrastructure was stood up for this demo — serving the clone
   requires attacker hosting, which the vulnerability proof does not depend on.

No flag exists for this breach — the endpoint was probed exhaustively
(external/internal/scheme-relative/javascript values, empty `next`, with and
without sessions) and always returns the bare echo; no admin-panel entry or
page hint references a redirect flag either. It is documented as one of the
bonus vulnerabilities that exposes no flag.

## Impact

- **Full credential harvesting under a trusted hostname.** The URL bar shows
  the real site up to the moment the fake page renders; users have no signal
  to distrust it.
- **POST-body forwarding via 307 semantics** — any form routed through the
  redirector leaks its contents verbatim, so even non-login forms (newsletter,
  password reset) can be hijacked.
- **Filter evasion:** naive blocklists that scan for `evil` domains in URLs
  miss this shape, because the malicious host appears *after* the trusted one;
  scheme-relative (`//host`) values also defeat checks that assume a scheme
  is present.
- **Chains with existing findings:** combined with the missing `HttpOnly`
  flag (ticket #4201), a cloned page could also run script against the real
  origin's cookies; combined with the moderation bot, a planted thread could
  redirect bot traffic anywhere.

## Remediation

1. **Allow-list destinations server-side:** accept only an explicit set of
   approved absolute URLs (`42.tech`, `code.42.tech`, …) or — simpler and
   strictly safer — only same-site relative paths starting with `/` (and
   reject `//`).
2. Or **drop the redirector entirely**: footer/login links can point at their
   targets directly; an internal hop adds attack surface without adding value.
3. Reject non-http(s) schemes explicitly (`javascript:`, `data:` must never
   reach `Location:`).
4. If redirects must stay open-ended (login-return flows), sign the
   destination (HMAC token alongside `next`) so tampered values fail.

## References

- WSTG: `WSTG-CLNT-04` (Testing for Client-side URL Redirect)
- OWASP Top 10: A01:2021 (Broken Access Control); classic mapping: Unvalidated
  Redirects and Forwards (2013-A10)
- CWE-601 (URL Redirection to Untrusted Site, "Open Redirect")
- Other: recon evidence in [`00-recon/notes.md`](../00-recon/notes.md) (route
  inventory, INFO-06) and the live probe transcript in this folder's
  `exploit.sh`; related hardening ticket #4201 (cookie flags) noted in admin
  panel comments.
