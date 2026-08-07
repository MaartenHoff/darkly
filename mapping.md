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
## Stack Fingerprint (WSTG-INFO-02)

| Component   | Version              | How confirmed                                       |
|-------------|----------------------|-----------------------------------------------------|
| Web server  | uvicorn 0.24.0 (ASGI)| `Server` header + malformed-request behaviour       |
| Framework   | FastAPI 0.104 (Starlette) | 422 Pydantic body on `POST /newsletter` (header-independent) |
| Runtime     | Python 3.11          | `x-powered-by` header                               |
| Validation  | Pydantic 2.13        | leaked in the 422 error `url` field                 |
| Backend     | PocketBase (:8090)   | `x-pocketbase` header + `/api/health`               |

Debug headers on every response: `x-powered-by`, `x-pocketbase`, `x-42-internal: campus=paris`.
**Impact:** exact versions → targeted CVE lookup; `x-pocketbase` discloses the backend.
**Fix:** strip `Server`/`X-Powered-By`/`x-*` headers, keep the stack patched, front with a reverse proxy.

**Reproduce:** run `00-recon/recon.sh` (fingerprint + metafiles + page content + routes + PocketBase).

## Page content & JS (WSTG-INFO-05) — detail

Per-page HTML comments (each a lead):
- `/projects`: `/projects/download` "serves any file" → path traversal; references `faq_darkly.pdf`
- `/forum`: "HTML supported… goes straight into the DB" → stored XSS
- `/newsletter`: "echoes email back… unescaped… `<script>` worked" → reflected + stored XSS
- `/staff`: `/api/docs-internal` (no staff check); `PATCH /api/profile` accepts `role`; JWT config at `/internal/config`

`console_eggs.js`:
- session is a **JWT**, read via `document.cookie` → confirms cookie is **not HttpOnly**
- endpoint `/api/telemetry/heartbeat` (POST, black-box, no auth)
- `_k42` / `flags:[3,1,4,1,5,9,2,6]` = digits of π → decorative **red herring**, no secret

Source maps: none (404). Redirect bodies: no content leak (Starlette `{"detail":"Found"}`).
