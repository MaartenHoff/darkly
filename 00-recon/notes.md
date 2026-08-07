# Reconnaissance

Basic mapping of the attack surface before touching any breach. The mandatory
part explicitly requires this step.

> Reproduce the whole map in one command: [`./recon.sh`](recon.sh)
> (fingerprint + metafiles + page content + route inventory + PocketBase probe).

> **Note on ordering:** the WSTG `INFO-0x` IDs are catalog labels, not an execution
> order. Recon here was **iterative** — the entry-point map (INFO-06) and the page-
> content review (INFO-05) fed each other: the route list drove the per-page comment
> sweep, and comments then revealed new routes (`/projects/download`,
> `/api/docs-internal`, `/api/profile`, `/api/telemetry/heartbeat`) that were folded
> back into the inventory. Findings are filed under their WSTG ID after the fact.

## Target

- URL (host NAT): `http://localhost:4942`
- URL (VM IP): `http://<vm-ip>:4942`

## Server / stack — WSTG-INFO-02 (Fingerprint Web Server)

**Finding:** the server discloses its exact type and version through both
response headers and error-page behaviour → enables version-specific CVE lookup.

**Fingerprint**
- Web server: `uvicorn/0.24.0` (ASGI), Python `3.11`
- Framework: `FastAPI 0.104` (on Starlette) — proven **behaviorally** (not just by
  header) via the Pydantic `422` body on `POST /newsletter`. The array-of-objects
  `detail` is FastAPI's default Pydantic-validation response; Starlette produces it
  only if Pydantic is hand-wired in, which no default Starlette app does
- Validation lib: `Pydantic 2.13` — leaked in the 422 `url` field
- Backend: PocketBase at `http://localhost:8090` (leaked via `x-pocketbase`)

**Reproduction:** [`./recon.sh`](recon.sh) → `### INFO-02` section
(banner grab + `/newsletter` 422 probe).

**Evidence**
- `server: uvicorn/0.24.0 Linux` (appears twice) + `x-powered-by: Python/3.11 FastAPI/0.104`
- Custom debug headers on *every* response incl. errors:
  `x-pocketbase: http://localhost:8090`, `x-42-internal: campus=paris`
- `POST /newsletter` (empty body) → `422`
  `{"detail":[{"type":"missing","loc":["body","email"],... ,"url":"https://errors.pydantic.dev/2.13/v/missing"}]}`
  — array-of-objects `detail` = **FastAPI** (Pydantic validation); the `url` leaks
  **Pydantic 2.13**. Header-independent proof.
- Source comment corroborates: *"remove debug headers before v1.4"*

**Impact:** precise stack + versions let an attacker search for known CVEs and
tailor payloads; `x-pocketbase` reveals the backend to target next.

**Remediation:** strip/obscure `Server` and `X-Powered-By`, remove the custom
`x-*` headers, keep the stack patched, front with a hardened reverse proxy.

**Verdict:** WSTG-INFO-02 = Fail (see [coverage matrix](wstg-coverage.md)).

## Endpoints & parameters

Route inventory (auto-docs disabled → built by hand from sitemap.xml, robots.txt,
homepage nav/links; observed `curl` codes).

| Path | Code | Params | Notes / source |
|------|------|--------|----------------|
| `/` | 200 | — | homepage |
| `/projects` | 200 | — | sitemap |
| `/forum` | 200 | — | sitemap / nav |
| `/newsletter` | 200 | — | sitemap / nav |
| `/agenda` | 302 | — | nav; redirects (auth?) |
| `/login` | 200 | — | login form (SQLi lead) |
| `/logout` | 302→`/login` | — | session present |
| `/redirect` | 307 | `next=` | **open redirect** — reflects any URL, no allow-list |
| `/admin` | 302→`/login` | — | robots; auth-gated |
| `/staff` | 200 | — | robots; **public** (should it be?) |
| `/backup` | 403 | — | robots; exists, forbidden |
| `/internal` | 404 | — | robots (parent 404) |
| `/internal/config` | 403 | — | "localhost only" per comment |
| `/api/grades` | 302→`/login` | `id`? | robots; IDOR target |
| `/projects/download` | 302→`/login` | `file=` | **arbitrary file download / path traversal** (comment) |
| `/api/docs-internal` | 302→`/login` | — | internal API docs ("no staff check" per comment) |
| `/api/profile` | 405 `[PATCH]` | PATCH `role` | **mass assignment / privesc** (comment); needs auth |
| `/api/telemetry/heartbeat` | 405 `[POST]` | JSON `ts/page/ua` | from `console_eggs.js`; black-box, no auth |
| `/reset-password` | 200 | — | **password reset** (wordlist); token = `MD5(email)` per team recon |
| `/profile/upload` | 302→`/login` | file | **file upload** (wordlist); "whitelist removed" per team recon |
| `/api/users` | 302→`/login` | — | users API (wordlist); IDOR / user-enum target |
| `/static/js/console_eggs.js` | 200 | — | `_k42` blob = console egg (π digits) |
| `/static/css/main.css` | 200 | — | asset |
| `/register`, `/signup` | 404 | — | no reg route (auth via `/login` + PocketBase) |

_Discovery: passive (sitemap/robots/nav/JS/comments) + an own curl wordlist sweep
(`/tmp/sweep.sh`) for unlinked routes. **Full completion pending post-auth** — read
`/api/docs-internal` (authoritative route list) or source via `/projects/download`._

_Session cookie: JWT named `session`, **not HttpOnly** (JS-readable per console_eggs.js)._

_PocketBase (`:8090`): `/api/health` 200, `/_/` admin UI 200, `/api/collections` 401._

## Metafiles — WSTG-INFO-03 (Review Webserver Metafiles)

**Finding:** `robots.txt` and `sitemap.xml` disclose sensitive/hidden paths,
handing an attacker a map of admin and internal endpoints. `robots.txt` is only
advisory crawl guidance — it provides no access control for the paths it lists.

**Reproduction:** [`./recon.sh`](recon.sh) → `### INFO-03` section
(`robots.txt` + `sitemap.xml`).

**Evidence**
- `robots.txt` `Disallow`: `/admin`, `/staff`, `/internal`, `/backup`,
  `/api/grades`, `/_/`, `/static/uploads/`
- `sitemap.xml` `<loc>`: `/`, `/projects`, `/forum`, `/newsletter`

**Full category coverage** (all six WSTG-INFO-03 metafile types checked):
- robots.txt → leaks (above); no `Sitemap:` directive inside it
- sitemap.xml → leaks (above); no `sitemap_index.xml` / `.gz` / `.txt` variants
- META tags → only `charset` + `viewport`; no `robots` meta, no `X-Robots-Tag`
  header, no generator/`og:`/`twitter:` leakage
- security.txt → absent (404 at `/` and `/.well-known/`)
- humans.txt → absent (404)
- other `.well-known/` URIs → all absent (404)

**Impact:** `robots.txt` advertises exactly the paths meant to stay hidden —
`/admin`, `/backup`, `/internal`, `/api/grades` (grades API → IDOR target), `/_/`
(PocketBase admin UI), `/static/uploads/`. An attacker reads it first and gets a
free target list; crawlers can ignore `Disallow`, so it enforces nothing. Directly
seeds forced-browsing (INFO-06) and the IDOR/authz work.

**Remediation:** don't enumerate sensitive paths in `robots.txt` — it's not a
security control. Protect those endpoints with real server-side authorization; if
they must be kept out of search indexes, use auth plus an `X-Robots-Tag: noindex`
response header rather than listing them publicly.

**Verdict:** WSTG-INFO-03 = Fail (see [coverage matrix](wstg-coverage.md)).

## Page content — WSTG-INFO-05 (Review Web Page Content)

**Finding:** developer HTML comments (different on each page) and frontend JS leak
a near-complete roadmap of the app's weaknesses, plus confirm the session JWT is
JavaScript-readable.

**Reproduction:** [`./recon.sh`](recon.sh) → `### INFO-05` section (per-page
comments + external JS list); `console_eggs.js` reviewed by hand.

**Evidence — comment breadcrumbs (per page), each a lead:**
- `/projects`: **`/projects/download` serves any file you ask for** (arbitrary file
  download / path traversal); references `faq_darkly.pdf`
- `/forum`: **"HTML supported… content goes straight into the DB"** → stored XSS
- `/newsletter`: **"echoes your email straight back… unescaped… `<script>`… it
  worked"** → reflected + stored XSS
- `/staff`: **`/api/docs-internal`** ("accessible without staff check");
  **`PATCH /api/profile` accepts a `role` field** (mass assignment / privesc);
  JWT config lives at `/internal/config`; "removed hardcoded creds — see git history"
- global (all pages): remove debug headers (v1.4); **session cookie not HttpOnly**
  (#4201); `xml.etree`→`defusedxml` (XXE); `/internal/config` localhost-only

**Evidence — JavaScript (`/static/js/console_eggs.js`):**
- Session cookie is a **JWT named `session`**, read via `document.cookie` and
  `jwtDecode()` → **confirms it is NOT HttpOnly** (behavioral proof of #4201)
- Endpoint `/api/telemetry/heartbeat`
- The `_k42` / `flags:[3,1,4,1,5,9,2,6]` blob is a decorative console egg (digits of
  π) — reviewed, **no secret leaked**

**Other INFO-05 categories:**
- Source maps → none (`console_eggs.js.map`, `main.css.map` = 404)
- Redirect bodies → only Starlette's `{"detail":"Found"}` status phrase, no content
  leak (negative)
- Generated files → `faq_darkly.pdf` served via `/projects/download` (auth-gated);
  inspect its metadata (`exiftool`/`pdfinfo`) once authenticated

**Impact:** the comments alone hand an attacker the whole target list — file
download/traversal, stored/reflected XSS, `role` mass-assignment privesc, JWT/SSRF,
hidden endpoints — turning discovery into a checklist. The JS confirms the session
JWT is stealable via XSS (not HttpOnly).

**Remediation:** strip all developer comments from production HTML; do not ship
internal notes, endpoint names, or file references to clients; remove debug JS; set
the session cookie `HttpOnly`/`Secure`/`SameSite`.

**Verdict:** WSTG-INFO-05 = Fail (see [coverage matrix](wstg-coverage.md)).

## Forms & inputs (candidate injection points)

- **Login** (`POST /login`, `identity`+`password`) → SQLi lead (INPV-05)
- **Newsletter** (`POST /newsletter`, JSON `email` — Pydantic) → reflected/stored XSS
- **Forum** (HTML→DB per comment) → stored XSS (INPV-02)
- **`/projects/download`** (`?file=`) → path traversal / arbitrary file download
- **`PATCH /api/profile`** (`role` field) → mass assignment / privesc
- **`/redirect`** (`?next=`) → open redirect (already confirmed)
- **`/api/grades`** (`id`?) → IDOR

## Cookies

| Name | Value | Looks like | Idea |
|------|-------|-----------|------|
| `session` | (set on login) | **JWT** (dot-separated, decoded by `jwtDecode()` in JS) | not HttpOnly → XSS theft (SESS-02); tamper `alg`/claims (SESS-10) |

## Flag / breach map (fill in as you go)

One row per breach you actually find. Create its folder with
`cp -r _template <breach-name>`.

| # | Breach folder | Vuln class | Flag? | Done |
|---|---------------|-----------|-------|------|
|   |               |           | ☐ | ☐ |
|   |               |           | ☐ | ☐ |
|   |               |           | ☐ | ☐ |
