# Reflected XSS — Newsletter "Subscribed" Banner

> Status: ☒ exploited ☒ explained
> Flag: _none observed_ (probed; no banner/flag issued by this endpoint)
> WSTG: `WSTG-INPV-01` (Reflected Cross-Site Scripting) — see [`00-recon/wstg-coverage.md`](../00-recon/wstg-coverage.md)

## Where

- Endpoint: `POST /newsletter` — **form-encoded** (`email=...`), *not* JSON
  (JSON body returns Pydantic `422`; form/multipart return `302`)
- Sink: `GET /newsletter?email=<raw>&msg=subscribed` renders the success banner:
  `<div class="alert alert-success">You're now subscribed with: <b>RAW EMAIL</b></div>`

## How it works

1. The POST handler stores the email verbatim in the backend `newsletter`
   collection and 302-redirects to `/newsletter?email=<raw>&msg=subscribed`.
2. The GET handler echoes the `email` query parameter straight into the HTML
   success banner with **zero escaping**.
3. Any markup in the URL therefore executes in the victim's browser:

```
/newsletter?email=%3Cscript%3Ealert(1)%3C/script%3Ex@darkly.test&msg=subscribed
→ You're now subscribed with: <script>alert(1)</script>x@darkly.test
```

The app's own dev comments acknowledge it:

```html
<!-- wil: the "subscribed with: ___" banner echoes your email straight back. sophie: unescaped?? wil: define "unescaped". -->
<!-- emilie: someone subscribed with a <script> tag last week. wil: bold of them. it worked. -->
```

## Exploitation

Run `./exploit.sh` — it walks the flow (subscribe → comment evidence → crafted
URL → raw `<script>` in the served HTML) and prints the confirmation line.

## Impact

- One-click account actions under the victim's session: the session cookie is
  **not HttpOnly** (ticket #4201), so `document.cookie` theft works here too —
  same primitive as [`stored_xss_bot_exfil/`](../stored_xss_bot_exfil/) but
  delivered by link instead of storage.
- Delivery requires a crafted link (reflected, not stored), which lowers severity
  vs. the forum variant; the trusted-host open redirect
  ([`redirect_phishing/`](../redirect_phishing/)) chains directly into it:
  `/redirect?next=<newsletter XSS URL>` launders the link through the real host.
- Injection is also persisted raw into the backend (dev comment shows a
  `' OR 1=1--@evil.com` subscription), so the value may resurface wherever
  subscriber data is later rendered.

## Remediation

1. HTML-escape the echoed parameter (or drop the echo entirely).
2. Validate the email server-side (format allow-list) before storing.
3. Set `HttpOnly`/`SameSite` on the session cookie so reflected payload cannot
   read it.
4. Add a CSP (`script-src 'self'`) as defense-in-depth.

## References

- WSTG: `WSTG-INPV-01`
- OWASP Top 10: A03:2021 (Injection)
- Other: confirmed live during the flag hunt on 2026-08-23 (build 1.3.7-prod);
  related sinks: [`stored_xss_bot_exfil/`](../stored_xss_bot_exfil/),
  cookie flags ticket #4201.
