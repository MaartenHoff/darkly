## Broken Access Control — PocketBase Admin API

### How it works
PocketBase runs on port `:8090` alongside the main app. The leaked credentials from `xxe_ssrf/` (admin email + password) allow direct authentication against PocketBase's admin API at `/api/admins/auth-with-password`. The returned token gives unrestricted read access to every collection — bypassing the app's access controls entirely.

### Impact
Complete database compromise: all user credentials (password hashes, recovery codes), all application data, full admin access.

### How it could have been avoided
1. **Network-segment PocketBase** — do not expose `:8090` to the app server; use a private network or Unix socket.
2. **Rotate leaked credentials** immediately.
3. **Use PocketBase's admin API sparingly** — prefer app-level access controls over direct database admin access.
