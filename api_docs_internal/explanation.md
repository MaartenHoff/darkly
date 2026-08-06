## Broken Access Control / Information Exposure (Forced Browsing)

### How it works
Inspecting the HTML source code of the application reveals a hidden comment left by a developer:
`<!-- sophie: /api/docs-internal still accessible without staff check — TODO fix in v1.4 -->`

This comment exposes a hidden endpoint (`/api/docs-internal`). While the endpoint is not linked anywhere in the UI, it can be accessed by any authenticated user, regardless of their role. 

The internal documentation (returned as JSON) discloses the structure of the API, including the fact that the `flag` field is readable via `GET /api/grades?student={id}`.

To exploit this programmatically:
1. Authenticate as `jdoe` (obtain a valid session cookie).
2. Access `/api/docs-internal` with the cookie to retrieve the API layout.
3. Use the leaked information to call `/api/grades?student=<user_id>` (the user’s own ID can be found in `/api/profile`) and extract the flag.

*(Note on Token Inspection: The JWT payload can be decoded locally via `echo "<payload>" | base64 -d` or `atob()` in the console. This reveals the assigned `"role":"student"`, proving that staff privileges are not being enforced at the endpoint).*

### Impact
Sensitive internal documentation and endpoints are exposed to low-privileged users. This Information Exposure can map out the backend architecture for attackers, providing them with further attack vectors and internal API logic.

### How it could have been avoided
1. **Remove Debug Comments:** Never expose internal paths, developer notes, or "TODOs" in the production frontend HTML.
2. **Enforce Role-Based Access Control (RBAC):** The backend must explicitly verify the user's role contained within the verified JWT. If the role is not `staff` or `admin`, the server must reject the request with a `403 Forbidden` status.