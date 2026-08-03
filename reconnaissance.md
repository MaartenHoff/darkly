# Reconnaissance / Mapping Notes

## Login & Authentication
- Login fields (Plain text) -> Test for SQL Injection (A03)
- "Forgot password" function -> Requires only email
- Google OAuth is available as an option
- Session cookies are missing the `HttpOnly` flag
- Session Fixation: Cookie is not rotated after login
- Passwords are partially only MD5 hashed ("predictable")
- JWT token uses HS256, secret is extremely weak ("42network" / "memorable")

## Routes & Endpoints
- Unprotected routes (A05): `/staff`
- Test API on port `4942`
- PocketBase on port `8090`
- `PATCH /api/profile`
- Check file uploads (Whitelist was completely removed according to dev logs)
- `/internal/config` (Access is allegedly restricted to localhost only)

## Configuration & Misc (A05 via F12)
- XML parser uses standard library (`stdlib xml.etree`), secure `defusedxml` was disabled -> possible target for XML attacks
- Easter egg / JS keylogger found (Konami Code): Reveals that the user `jdoe` has not changed their default password.
- Frontend(sources - console_eggs.js) exposes `window.jwtDecode` function: Allows decoding of JWTs directly in the browser console and reveals the exact payload structure needed for future token manipulation (Privilege Escalation).

## probable entry points
- in the console it is written: "Hey, curious one. You found the console. That's already step 1" so that might just be the step 1
- or use plain text options (Login or forgot password) to try a sql injection