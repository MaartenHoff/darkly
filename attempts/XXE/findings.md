# XXE — Findings

## Agenda XML Import (`POST /agenda/import`)

The parser is **stdlib `xml.etree.ElementTree`** — evidence:

- HTML comment on `/agenda`:
  `<!-- TODO: replace stdlib xml.etree with defusedxml — emilie reported issue -->`
- Deployment log in same page:
  `v1.3.4 — wil — "disabled defusedxml temporarily" (that was 6 months ago)`
- `mapping.md:53`: `XML Parser: Uses standard library (stdlib xml.etree).`
- VM runs **Python 3.11** per `x-powered-by: Python/3.11 FastAPI/0.104` header.

It resolves internal DTD entities but **rejects SYSTEM entities** (raises `ParseError` caught by the app, returns empty).

| Feature | Works? | Evidence |
|---------|--------|----------|
| `<!ENTITY name "value">` | ✅ | `&test;` → `"internal_works"` in title |
| `<!ENTITY name SYSTEM "file://...">` | ❌ | returns empty `<td>`, no error |
| `<!ENTITY name SYSTEM "http://...">` | ❌ | same — empty |
| `<xi:include href="file://...">` | ❌ | no content |
| Nested entities | ✅ | `&a;` → `"hello"`, `&b;` → `"hello_world"` |
| Predefined XML entities | ✅ | `&amp;` → `&` |

**Root cause:** `xml.etree.ElementTree` resolves internal DTD entities but rejects external SYSTEM entities (raises `ParseError`). The app catches the error and returns partial data (empty title, date still works).

## Other XML sinks (unconfirmed)

The `HANDOFF.md` says the actual XXE-vulnerable endpoint is **not yet located**. Possible candidates:
- `/upload/avatar` — file upload, whitelist removed
- `/forum` — HTML post content
- `/newsletter` — email subscription

## Tried file paths (all empty)

`/flag`, `/flag.txt`, `/etc/hostname`, `/etc/passwd`, `/proc/self/cmdline`, `/proc/1/cmdline`, `/app/flag`, `/home/flag`, `/root/flag`, `/tmp/flag`, `php://filter/...`, `expect://id`