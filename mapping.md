# Reconnaissance

## Endpoints
| Path | Code | Params | Notes / source |
|------|------|--------|----------------|
| `/` | 200 | — | — |
| `/projects` | 200 | — | — |
| `/forum` | 200 | — | entry to /profile/... + info |
| `/newsletter` | 200 | — | sql injection? |
| `/agenda` | 302 | — | needs login |
| `/login` | 200 | — | sql injection? |
| `/reset-password` | 200 | — | sql injection? |
| `/logout` | 302→`/login` | — | needs login |
| `/redirect` | 307 | `next=` | phishing? |
| `/admin` | 302→`/login` | — | needs login |
| `/staff` | 200 | — | info |
| `/backup` | 403 | — | access denied |
| `/internal` | 404 | — | page not found |
| `/internal/config` | 403 | — | forbidden |
| `/api/grades` | 302→`/login` | — | needs login |
| `/projects/download` | 302→`/login` | — | needs login |
| `/api/docs-internal` | 302→`/login` | — | needs login |
| `/api/profile` | ? | PATCH `role` | Method Not Allowed |
| `/api/users` | 302→`/login` | — | needs login |
| `/api/telemetry/heartbeat` | ? | — | Method Not Allowed |
| `/static/js/console_eggs.js` | 200 | — | info |
| `/static/css/main.css` | 200 | — | — |
| `/register` | 404 | — | page not found |
| `/signup` | 404 | — | page not found |

## Profiles & Targets
- **jdoe (The Soft Target):** Uses a short, dictionary-based password  and is explicitly linked to "the most famous list out there `(rockyou.txt)`"
- **benjamin:** `benjamin@student.42.tech` (Role: STUDENT)
- **dorian:** `dorian@student.42.tech` (Role: STUDENT)
- **thanos:** `thanos@student.42.tech` (Role: STUDENT)
- **anne-sophie:** `anne-sophie@student.42.tech` (Role: STUDENT)
- **emilie:** `emilie@42.tech` (Role: CADET)
- **wil:** `wil@42network.fr` (Role: STAFF)
- **sophie:** `sophie@42.tech` (Role: GOD)

## Entrypoints & Vulnerabilities
* **jdoe Profile:** Has a weak password, possible rate-limiting missing so brute force with rockyou.txt could work.
* **Private Notes from Profiles are open:** wil's profile (IDOR / Broken Access Control).
* **SQL Injection:** Should be attempted on login, reset-password, and newsletter.
* **Token for reset-password:** Is stored in URL and is just the email MD5 hashed.
* **JWT token:** Uses HS256, secret is extremely weak.
* **Passwords:** Are partially only MD5 hashed ("predictable").
* **Cookie:** Is not rotated after login and is missing the `HttpOnly` flag.
* **Information Exposure:** `window.jwtDecode` exposed in `console_eggs.js` reveals JWT payload structure for future privilege escalation.
* **Ports:** Test API runs on port `4942`, PocketBase on port `8090`.

## Vulnerabilities for later
* **XML Parser:** Uses standard library (`stdlib xml.etree`).
* **File Uploads:** The file whitelist was completely removed according to dev logs.
* **SSRF (Server-Side Request Forgery):** `/internal/config` throws 403 but is allegedly restricted to localhost only.
* **LFI / Path Traversal:** "Creative filenames" in the resources section lead to odd behavior.
* **Headers:** Response headers on the site leak additional, unintended information.
## What the site is built with (fingerprinting)

The site openly tells us which software and **exact versions** it runs. That's a
problem: with an exact version, an attacker can look up known bugs (CVEs) for it.

| Part            | What it runs        | Where we saw it                          |
|-----------------|---------------------|------------------------------------------|
| Web server      | uvicorn 0.24.0      | the `Server` line in the response        |
| Framework       | FastAPI 0.104       | the shape of its error pages + a header  |
| Language        | Python 3.11         | the `x-powered-by` header                |
| Input validation| Pydantic 2.13       | leaked inside an error message           |
| Database backend| PocketBase (port 8090) | the `x-powered-by`/`x-pocketbase` header |

On **every** response the site also adds these extra info headers:
`x-powered-by`, `x-pocketbase`, `x-42-internal: campus=paris`.

- **Why it's bad:** the exact versions let an attacker search for ready-made
  exploits, and `x-pocketbase` even points them straight at the database backend.
- **Fix:** remove these headers and keep the software updated.

**Reproduce:** run `00-recon/recon.sh` (fingerprint + metafiles + page content + routes + PocketBase).

## Clues hidden in the page source

Developers left **comments in the HTML** — you don't see them on the page, only in
the browser's "View Source". Each one points to a weakness:

- **`/projects`** — says `/projects/download` "serves any file you ask for."
  → we can probably download files we shouldn't (e.g. the server's own code).
- **`/forum`** — "HTML is supported and goes straight into the database."
  → we can post a `<script>` that gets saved and runs for every visitor (stored XSS).
- **`/newsletter`** — "your email is echoed back unescaped… a `<script>` worked."
  → our input runs in the browser (XSS).
- **`/staff`** — mentions three things: `/api/docs-internal` (reachable even if you're
  not staff), that `PATCH /api/profile` lets you set your own `role`, and that the
  login-token settings live at `/internal/config`.

The JavaScript file **`console_eggs.js`** also reveals:
- the login `session` cookie is a **token that JavaScript can read** — so it's *not*
  protected (missing the HttpOnly flag), meaning an XSS could steal someone's login.
- there's a hidden endpoint `/api/telemetry/heartbeat`.
- a scary-looking `_k42` block is just a **joke** — the numbers `3,1,4,1,5,9,2,6` are
  the digits of π. No secret there.

Also checked, nothing found: no leftover source-map files, and redirect pages don't
leak anything.
