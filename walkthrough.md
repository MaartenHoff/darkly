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
* **New Surface:** `/profile/me/settings` (file uploads missing whitelists) and `/agenda` (XML import confirming an XXE vulnerability).
* **Breach (Forced Browsing):** An HTML comment leaked the hidden `/api/docs-internal` route. Accessed it using `jdoe`'s valid JWT to leak the internal API structure.

---

## Phase 4: Data Exfiltration
* **Breach (Insecure API):** Used the leaked API docs to query `GET /api/grades?student=z4p1cnx47mfy50f` (jdoe's ID).
* **Flag:** `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` *(Note: The flag text confirms the MD5 email hash password reset vulnerability found during recon).*

---

## Phase 5: Privilege Escalation (Pending)
* **Vector (Mass Assignment):** The leaked API docs explicitly state `"role writable via PATCH /api/profile"`. 
* **Next Step:** Use this endpoint to patch the account's role from `student` to `staff`.