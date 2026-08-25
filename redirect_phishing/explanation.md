# Open Redirect → Phishing (Credential Harvest)

`GET /redirect?next=<url>` echoes `next` straight into the `Location:` header — no allow-list, no scheme check, no relative-only rule — and answers `307`. The site uses this redirector for its own links (footer, "Continue with Google"), so `…/redirect?next=…` looks first-party.

```
GET /redirect?next=https://evil.example/login  →  307, Location: https://evil.example/login
```

Any value passes verbatim: external URLs, scheme-relative `//evil.example`, even `javascript:alert(1)`.

**Why it's dangerous:** the link's *host* is the real site, so the URL bar looks safe until the attacker's cloned login page renders. And `307` (unlike `302`) replays the request **method + body**, so a form posted through the chain forwards its raw credentials to the attacker.

**No flag** — a bonus, flag-less vulnerability (probed exhaustively; always the bare echo). Live proof in `./exploit.sh`.

## Remediation
- Allow-list destinations, or accept only same-site paths starting with `/` (reject `//`).
- Reject non-http(s) schemes; or sign `next` (HMAC) if open redirects are required.

## References
WSTG-CLNT-04 · OWASP A01:2021 · CWE-601. Recon: [`00-recon/notes.md`](../00-recon/notes.md).
