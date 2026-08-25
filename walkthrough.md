# Walkthrough

## Phase 1: Unauthenticated Recon & IDOR
* **Recon:** Identified public endpoints (`/login`, `/forum`, `/newsletter`, `/staff`), user roles, and emails.
* **Breach (IDOR):** Accessed `wil`'s profile directly (`/profile/k1asdfeditojrb4`) to read a private note without authentication.
* **Flag:** `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}`

---

## Phase 2: Initial Access (Account Takeover)
* **Recon:** Forum OSINT and a JS keylogger (`/static/js/console_eggs.js`) revealed `jdoe` uses an unchanged default password from `rockyou.txt`.
* **Breach (Brute Force):** Missing rate limiting on `/login` allowed a quick dictionary attack.
* **Credentials:** `jdoe@student.42.tech` / `abc123` (Access Level: STUDENT).

---

## Phase 3: Post-Exploitation & Forced Browsing
* **New Surface:** Gained ability to add comments/create posts in `/forum`. Identified `/profile/me/settings` (file uploads missing whitelists) and `/agenda` (XML import confirming an XXE vulnerability). Access to `/admin` still restricted (`{"detail":"Insufficient privileges"}`).
* **Breach (Forced Browsing):** An HTML comment leaked the hidden `/api/docs-internal` route. Accessed it using `jdoe`'s valid JWT to leak internal API structure and parameters.

---

## Phase 4: Data Exfiltration
* **Breach (Insecure API):** Used the leaked API docs to query `GET /api/grades?student=z4p1cnx47mfy50f` (jdoe's ID).
* **Flag:** `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` *(Note: The flag text confirms the MD5 email hash password reset vulnerability found during recon).*

---

## Phase 5: Privilege Escalation
* **Breach (Mass Assignment):** The leaked API docs revealed that the `role` field is writable via `PATCH /api/profile`. Sent a JSON payload (`{"role": "staff"}`) to vertically elevate account privileges.
* **Result:** Successfully bypassed role-based access controls, unlocking the previously restricted `/staff/dashboard`.
* **Flag:** `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}`

---

## Phase 6: Unrestricted File Upload
* **Recon:** Developer logs previously noted the upload whitelist was completely removed.
* **Breach (File Upload):** Uploaded an arbitrary file payload to the `/upload/avatar` endpoint. The server accepted the file without extension or MIME-type validation.
* **Result:** The application confirmed the unrestricted upload and returned the flag URL-encoded within the `Location` redirect header.
* **Flag:** `FLAG{unr3str1ct3d_upl0ad_g0_brrr}`

---

## Phase 7: Session Forgery (Full God-Role Takeover)
* **Recon:** Homepage HTML deploy-log comment leaked the JWT signing secret history (`jwt secret was "42". wil changed it to "42network".`). Sophie's PocketBase id (`enplwhu8jfo56oi`, role `god`) already known from recon (`mapping.md`).
* **Breach (JWT Forgery):** Session cookies are unencrypted HS256 JWTs (`header.payload.signature`) — knowing the secret lets anyone sign an arbitrary payload. Forged `{"sub":"enplwhu8jfo56oi","login":"sophie","role":"god","exp":...}` and signed it with `42network` via `openssl dgst -sha256 -hmac`.
* **Result:** Forged cookie passed signature verification — `GET /admin` returned `200` as `sophie`/`god`, bypassing role checks entirely (no PATCH/mass-assignment needed).
* **Flag:** `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` *(same flag as Phase 4 — the admin panel's submissions table exposes the identical value via a second, independent vulnerability.)*

---

## Phase 8: XXE → SSRF → Internal Config
* **Recon:** `/agenda` has an XML import feature (`POST /agenda/import`). HTML source confirms Python's stdlib `xml.etree` is used (no `defusedxml`).
* **Breach (XXE/SSRF):** Uploaded an XML file with an external entity pointing to `http://localhost:4942/internal/config`. The server-side parser resolved the entity, performing an SSRF request from localhost — bypassing the IP restriction on `/internal/config` (returns 403 externally).
* **Result:** The JSON response leaked the JWT secret, PocketBase admin credentials, and a flag.
* **Flag:** `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}`

---

## Phase 9: Reset Token Forgery
* **Recon:** The `/reset-password` endpoint generates a recovery link where the token is simply `md5(email)`. Confirmed via benjamin's forum post and PocketBase's `recovery_code` field exposed through API field exposure.
* **Breach (Reset Token):** Computed `md5("benjamin@student.42.tech")` and used the resulting hash as a valid reset token to take over any account.
* **Flag:** `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}`

---

## Phase 10: PocketBase Admin Database Dump
* **Recon:** `/_/` (PocketBase admin UI) is accessible on port 8090. Admin credentials leaked in `/internal/config` via XXE (Phase 8). The `x-pocketbase` header on every response confirms the backend.
* **Breach (PB Admin Dump):** Authenticated to PocketBase admin API (`POST /api/admins/auth-with-password`) with leaked credentials. Enumerated all collections (`users`, `internal_config`, `internal_audit`, `grades`, `posts`, `comments`, `projects`, `newsletter`, `agenda_imports`). The `internal_audit` collection contains the flag.
* **Flag:** `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}`

---

## Phase 11: PocketBase Field Exposure
* **Recon:** PB API returns all user fields to any authenticated user, including `recovery_code`, `pw_hint`, and `private_note`.
* **Breach (Field Exposure):** Queried `GET /api/users` as `jdoe` (student role) — all user records returned with sensitive fields visible. Confirms the MD5 reset token vulnerability and leaks other users' password hints.
* **Flag:** `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` *(same as Phase 9, independently confirmed via API field exposure)*

---

## Phase 12: Stored XSS → Cookie Exfiltration
* **Recon:** `/forum` supports HTML in posts ("HTML is supported and goes straight into the database"). Developer comment confirms the moderation bot opens every thread with a live session — and the session cookie is not HttpOnly.
* **Breach (Stored XSS):** Created a forum post containing `<script>fetch(...)</script>` that steals the session cookie via `document.cookie`. When the moderation bot visits the thread, the payload fires and exfiltrates the cookie to an external endpoint.
* **Flag:** `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}`

---

## Phase 13: Path Traversal / Arbitrary File Download
* **Recon (header breadcrumb):** `/backup` returns `403`, but its response headers leak `x-backup-exclude: data/private_notes.txt` — naming a sensitive file kept out of the webroot ("check the response headers" hint).
* **Breach (Path Traversal):** `GET /projects/download?file=` joins the parameter onto an internal base dir without sanitisation. `?file=../private_notes.txt` escapes it and returns the excluded ops note. The base's name isn't observable black-box, but it provably sits one level inside `data/` (both `../private_notes.txt` and `../../data/private_notes.txt` return the same file). (Containment allows anything under `<app>/data`, so source/`/etc`/`pb_data` still return `403` — only this file is reachable.)
* **Flag:** `FLAG{d0t_d0t_sl4sh_4ll_th3_w4y_d0wn}`
