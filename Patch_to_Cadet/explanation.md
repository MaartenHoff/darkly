## Mass Assignment / Privilege Escalation

### How it works
The internal API documentation (`/api/docs-internal`) revealed that the `users` collection has `role` listed under `writable_fields`, and explicitly stated: `note: "role writable via PATCH /api/profile"`. 

This is a textbook Mass Assignment vulnerability. The backend framework automatically binds client-provided data (JSON payload) to the internal user model without filtering protected fields like `role`. By sending a `PATCH` request to `/api/profile` with the payload `{"role": "cadet"}`, the backend blindly updates the database entry for the authenticated user (`jdoe`). 

Upon navigating to the previously restricted `/staff/dashboard`, the application now recognizes the session as having "Cadet+" privileges, granting access to the dashboard and revealing the internal staff flag.

### Impact
An attacker can vertically escalate their privileges from a standard user (`student`) to higher-level role `cadet`. This completely bypasses the intended Role-Based Access Control (RBAC) and can lead to full administrative compromise of the application.

### How it could have been avoided
1. **Explicit Field Whitelisting:** The backend data transfer objects (DTOs) or models used for updates must strictly define which fields are allowed to be modified by the user (e.g., `first_name`, `last_name`, `avatar`). 
2. **Protect Sensitive Fields:** Fields dictating access control, permissions, or roles must explicitly be removed or ignored in user-facing update endpoints. Role modifications should only be handled by dedicated endpoints restricted to high-privilege administrators.