## XML External Entities (XXE) → Server-Side Request Forgery (SSRF)

### How it works
The agenda page (`/agenda`) has an XML import feature (`POST /agenda/import`) that accepts uploaded `.xml` files. HTML comments on the page confirm the parser uses Python's stdlib `xml.etree.ElementTree` instead of the safer `defusedxml` library.

The parser resolves `http://` SYSTEM entities server-side. By uploading an XML file that declares `<!ENTITY xxe SYSTEM "http://localhost:4942/internal/config">`, the server fetches the URL and embeds the response in the rendered page.

`/internal/config` is blocked externally (returns 403, "localhost only"), but the XXE parser runs on localhost itself — so the request succeeds and leaks the full JSON config, including PocketBase admin credentials and the JWT signing secret.

### Impact
Exposes all server-side secrets: admin credentials, JWT signing secret, and internal configuration. This enables full database compromise when chained with direct PocketBase access (see `pb_admin_dump/`).

### How it could have been avoided
1. **Replace `xml.etree` with `defusedxml`** — blocks XXE by default.
2. **Remove `/internal/config`** — never serve secrets over HTTP, even on localhost.
3. **Rotate leaked credentials** immediately after discovery.
