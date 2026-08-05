# Reconnaissance / Mapping Notes

## Login & Authentication
- Login fields (Plain text) -> Test for SQL Injection (A03)
- "Forgot password" function -> Requires only email
- **CRITICAL (Token Generation):** The reset token is not cryptographically secure or random; it is literally the MD5 hash of the user's email address.
- Google OAuth is available as an option
- Session cookies are missing the `HttpOnly` flag
- Session Fixation: Cookie is not rotated after login
- Passwords are partially only MD5 hashed ("predictable")
- JWT token uses HS256, secret is extremely weak ("42network" / "memorable")

## Routes, Endpoints & Vulnerabilities
- Unprotected routes (A05): `/staff`
- Test API on port `4942`
- PocketBase on port `8090`
- `PATCH /api/profile`
- Check file uploads (Whitelist was completely removed according to dev logs)
- `/internal/config` (Access is allegedly restricted to localhost only)
- **IDOR / Broken Access Control (A01):** "Private notes" on user profiles are exposed to unauthorized users/guests (Revealed Flag #1).
- **Local File Inclusion (LFI) / Path Traversal:** "Creative filenames" in the resources section lead to odd behavior.
- **XXE (XML External Entities):** XML parser uses standard library (`stdlib xml.etree`), secure `defusedxml` was disabled. Forum confirms XML import lacks sanitization.

## Configuration & Misc (A05 via F12)
- Easter egg / JS keylogger found (Konami Code): Reveals that the user `jdoe` has not changed their default password.
- Frontend (`console_eggs.js`) exposes `window.jwtDecode` function: Allows decoding of JWTs directly in the browser console and reveals the exact payload structure needed for future token manipulation (Privilege Escalation).
- **Headers:** Response headers on the site leak additional, unintended information.

## Profiles & Targets
- **jdoe (The Soft Target):** Uses a short, dictionary-based password related to the word "rock" and is explicitly linked to "the most famous list out there `(rockyou.txt)`"
- **benjamin:** `benjamin@student.42.tech` (Role: STUDENT)
- **dorian:** `dorian@student.42.tech` (Role: STUDENT)
- **thanos:** `thanos@student.42.tech` (Role: STUDENT)
- **anne-sophie:** `anne-sophie@student.42.tech` (Role: STUDENT)
- **emilie:** `emilie@42.tech` (Role: CADET)
- **wil:** `wil@42network.fr` (Role: STAFF)
- **sophie:** `sophie@42.tech` (Role: GOD)

## Probable Entry Points (Initial Access)
1. **Direct Login (jdoe):** Since the password is known to be weak and related to "rock", a manual login attempt or a short dictionary attack on `jdoe` using `rockyou.txt` is a primary entry point.
2. **Account Takeover (ATO) via Reset:** Because the reset token is simply `MD5(email)`, we can bypass the email requirement entirely. We can calculate the MD5 hash of any targeted email and use it to instantly change their password via the reset URL.

##


## Authenticated Surface - Role: STUDENT (Logged in as `jdoe`)
- **Access Level:** The sidebar now displays "Access Level: Student".
- **New Endpoints:** 
    - `/settings`: Allows updating "Personal info", uploading an "Avatar" image (File Upload Vulnerability testing ground), and changing the password.
    - `/agenda`: Features an "Import XML agenda" function.
- **XXE Vulnerability Confirmed (A05:2021):** The `/agenda` endpoint accepts XML file uploads. The UI explicitly states "External entities are supported", confirming the use of the unsafe `stdlib xml.etree` parser found earlier via F12. This is a direct vector for Local File Inclusion (LFI) or Server-Side Request Forgery (SSRF) via XXE.