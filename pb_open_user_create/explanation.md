# Open PocketBase User-Create Rule → Self-Made God Account

## Where

- Endpoint: `POST http://localhost:8090/api/collections/users/records`
  — PocketBase's own records API, bypassing the web app entirely
- Precondition: any valid PocketBase *record* auth token (every student account
  gets one at login; the backend is exposed off-box per the `x-pocketbase` header)

## How it works

1. The app enforces role discipline only in its own handler:
   `PATCH /api/profile {"role":"staff"|"god"}` → `403 {"error":"role not assignable"}`.
2. PocketBase itself has no such rule: the `users` collection **create rule**
   accepts inserts from any authenticated record user and does not strip the
   `role` column. `POST /api/collections/users/records` with `"role":"god"`
   stores a god account verbatim.
3. Logging into the *app* with that account mints a genuine HS256 session JWT
   with `role:"god"` (the app reads the role from the DB), so every god-tier page
   opens: `/admin`, `/staff/dashboard`, …

Verified live (build 1.3.7-prod): account `evilcreate2@test.local`
(record id `p1ob4go8ydzo7ja`) created by student benjamin's token, `role:"god"`
stored, app login succeeded, `/admin` → 200.

## Exploitation

Run `./exploit.sh` — it walks the chain: student login → PB token → create
god account → app login as it → `/admin` 200.

## Impact

- Complete vertical privilege escalation from *any* low-privileged account,
  without touching the leaked JWT secret or the PB superuser credentials —
  a third independent path to administrator.
- Silently scales: an attacker can mint unlimited god/staff accounts, surviving
  password rotations of the real staff.
- Chained with the exposed `:8090` (header-leaked) this needs nothing but one
  ordinary student credential.

## Remediation

1. Set the `users` collection **create rule** so only the app server (or nobody)
   can insert records — e.g. deny client creates entirely (`null` rule) and
   provision users server-side.
2. Strip/ignore privileged columns on create via PocketBase field validation;
   never trust client-supplied `role`.
3. Network-isolate `:8090` so the records API isn't reachable off-box.

## References

- OWASP API Security Top 10: API6:2023; WSTG-ATHZ-02 (BFLA)
- Other: complements [`Patch_to_Cadet/`](../Patch_to_Cadet/) (app-side mass
  assignment) and [`pb_admin_dump/`](../pb_admin_dump/) (superuser compromise) —
  together three distinct escalation paths to the same tier.
