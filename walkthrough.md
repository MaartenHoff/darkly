# Walkthrough:

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

## Next Step??
- Phishing
- XXE via (`/agenda`)
- file upload (`/profile/me/settings`)
- sql injection (`/newsletter`)
- md5(email) token forgery
- mapping with new access
- Pocketbase /_/