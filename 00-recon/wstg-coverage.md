# WSTG Coverage Matrix — Darkly

Triage of the app against the [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
(v4.2). Every relevant test is tracked to a verdict; tech/feature-absent tests
are grouped as N/A with a reason. Each **Fail** links to its breach folder, and
each breach's `explanation.md` cites its WSTG ID back.

**Verdicts:** `Open` = still to test · `Pass` = tested, not vulnerable ·
`Fail` = vulnerable (→ breach folder) · `Done` = recon task completed ·
`N/A` = precondition absent.

Target: FastAPI (`uvicorn`, `:4942`) + PocketBase (`:8090`), plain HTTP over NAT.

---

## In scope — tested / to test

| WSTG ID | Test | Verdict | Evidence / reason | Breach |
|---------|------|---------|-------------------|--------|
| INFO-02 | Fingerprint web server | Fail | leaks `uvicorn/0.24.0`, `FastAPI 0.104`, `x-powered-by`, `x-pocketbase`, `x-42-internal`; comment: "remove debug headers before v1.4" | [recon notes](notes.md#server--stack--wstg-info-02-fingerprint-web-server) |
| INFO-03 | Review webserver metafiles | Fail | `robots.txt` discloses `/admin /staff /internal /backup /api/grades /_/ /static/uploads/`; `sitemap.xml` adds `/projects /forum /newsletter` | [recon notes](notes.md#metafiles--wstg-info-03-review-webserver-metafiles) |
| INFO-05 | Review webpage content | Fail | per-page HTML comments leak a full roadmap (file-download, XSS, `role` mass-assign, JWT/SSRF, hidden endpoints); JS confirms session JWT not HttpOnly | [recon notes](notes.md#page-content--wstg-info-05-review-web-page-content) |
| INFO-06 | Identify entry points | Done | route inventory built ([notes](notes.md#endpoints--parameters)); nav adds `/agenda`, `/redirect`; no `/register` path found | — |
| CLNT-04 | Open redirect | Fail | `/redirect?next=` reflects arbitrary URL into `307 Location`, no allow-list (verified external + internal) | [redirect_phishing](../redirect_phishing/explanation.md) (no flag) |
| CONF-04 | Backup & unreferenced files | Fail | `/backup` → 403 body, but response headers leak backup config: `x-backup-dest: localhost:/opt/pocketbase/pb_data`, `x-backup-exclude: data/private_notes.txt` (names the traversal target) | [arbitrary_file_download](../arbitrary_file_download/explanation.md) (chained) |
| CONF-05 | Enumerate admin interfaces | Open | PocketBase admin `/_/` (200); `/admin` → 302 login; `/api/docs-internal` (302, "no staff check") | — |
| CONF-06 | Test HTTP methods | Open | verb-probe key routes (`OPTIONS`, `Allow`) | — |
| CONF-07 | HSTS | Open | plain HTTP, likely missing — confirm & note | — |
| IDNT-02 | User registration process | Open | test mass-assignment (`role`,`verified`,`isAdmin`); `PATCH /api/profile` accepts `role` (comment) | — |
| IDNT-04 | Account enumeration | Open | login/reset error-message differences | — |
| ATHN-02 | Default credentials | Open | try common/default app creds | — |
| ATHN-03 | Weak lockout mechanism | Open | login form — check rate-limit/brute-force | — |
| ATHN-04 | Bypass authentication schema | Open | forced browsing; `/internal/config` localhost gate | — |
| ATHN-09 | Weak password change/reset | Open | inspect reset flow + token | — |
| ATHZ-01 | Directory traversal / file include | Fail | **`/projects/download?file=../private_notes.txt`** escapes the base dir (unsanitised path join; base provably sits one level inside `data/` — `../private_notes.txt` and `../../data/private_notes.txt` hit the same file; base name not observable black-box); target file named by `/backup`'s leaked `x-backup-exclude` header | [arbitrary_file_download](../arbitrary_file_download/explanation.md) |
| ATHZ-02 | Bypass authorization schema | Open | `/staff` (200 public), `/backup`, `/api/grades` | — |
| ATHZ-03 | Privilege escalation | Open | **core of the 4-flag admin chain**; `PATCH /api/profile` `role` field (comment) | — |
| ATHZ-04 | Insecure Direct Object References | Open | `/api/grades?id=`, PocketBase records | — |
| SESS-02 | Cookie attributes | Open | session cookie `session` = JWT, **not HttpOnly** (JS reads it in `console_eggs.js`) + comment #4201 | — |
| SESS-05 | CSRF | Open | state-changing forms — check tokens | — |
| SESS-10 | JSON Web Tokens | Open | session is a JWT (`session` cookie); JWT config at `/internal/config`; decode/tamper `alg`/claims | — |
| INPV-01 | Reflected XSS | Open | `/newsletter` "echoes your email straight back… unescaped" (comment) | — |
| INPV-02 | Stored XSS | Open | `/forum` "HTML supported… goes straight into the DB" (comment) | — |
| INPV-05 | SQL Injection | Open | login form — comment: "we fixed it. probably" | — |
| INPV-07 | XML Injection (XXE) | Open | comment: `xml.etree`→`defusedxml`; find XML sink | — |
| INPV-12 | Command injection | Open | any endpoint shelling out | — |
| INPV-19 | Server-Side Request Forgery | Open | `/internal/config` "localhost only" | — |
| ERRH-01 | Improper error handling | Pass | 404 is a clean custom page, no stack traces (re-check on 500) | — |
| BUSL-* | Business logic | Open | e.g. tampering `/api/grades`, workflow bypass | — |
| CLNT-* | Client-side (DOM-XSS, clickjacking) | Open | no `X-Frame-Options`; check DOM sinks | — |
| APIT-* | API testing | Open | FastAPI REST + PocketBase API surface | — |

## Not applicable (grouped, with reason)

- **INPV-06 / 08 / 09 / 10** (LDAP / SSI / XPath / IMAP-SMTP injection) — no such
  backend or feature in the stack.
- **INPV-05.1–05.5** (Oracle / MySQL / MSSQL / MS-Access / PostgreSQL variants) —
  PocketBase uses SQLite; only the generic + SQLite angle applies.
- **CONF-08 / 10 / 11** (RIA cross-domain, subdomain takeover, cloud storage) —
  not present.
- **CRYP-01 / 03** (weak TLS, padding oracle) — plain HTTP over NAT, no HTTPS
  layer to test (worth noting as a config weakness, not a crypto test).
- **ATHN-10 / SESS-03 alt-channel** — no secondary auth channel.

---

## Progress

Mandatory target: **6 flags · 10 vulnerabilities** documented (each = one `Fail`
above with a breach folder). Bonus: **10 flags · 15 vulnerabilities**.

- **Unique flags captured: 9** — `1d0r`, `md5`, `just_p4tch`, `unr3str1ct3d_upl0ad`,
  `d3fus3dxml`, `r3s3t_t0k3n`, `th3_und3rsc0r3`, `xss_st0r3d`, **`d0t_d0t_sl4sh` (NEW —
  ATHZ-01 path traversal)**. DB holds exactly 5 (all found via PB admin); the rest are
  app-emitted / file-based.
- Fails confirmed: INFO-02/03/05 (info-disclosure), CLNT-04 (open redirect), CONF-04
  (`/backup` header leak), ATHZ-01 (path traversal) + every flag-bearing breach folder.
- Verified dead / flag-less (probed live): INPV-05 login SQLi (parameterized — no
  error/bypass), INPV-01 newsletter reflected XSS (confirmed vuln, no victim/bot →
  no flag), INPV-12 command injection (no shell sink), `/api/telemetry/heartbeat`
  (fixed response, decoy).
