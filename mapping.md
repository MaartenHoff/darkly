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