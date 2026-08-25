# Path Traversal / Arbitrary File Download

> Flag: `FLAG{d0t_d0t_sl4sh_4ll_th3_w4y_d0wn}` · WSTG-ATHZ-01 · CWE-22

## Where
`GET /projects/download?file=` (any authenticated session) joins `file=` onto an
internal base dir without normalising, so `../` walks out. A partial guard keeps
the resolved path under `<app>/data` (so `/etc/passwd`, source, `pb_data/data.db`
all `403`), but the one secret inside that root is readable:

```
GET /projects/download?file=../private_notes.txt   →  200, file contents
```

## Finding the target
Two unknowns, recovered separately:
- **Name** — `/backup` returns `403` but leaks a header
  `x-backup-exclude: data/private_notes.txt` (the forum's "check the response
  headers" hint). Gives the filename + that it lives in `data/`; not the depth.
- **Depth** — by trial: `?file=private_notes.txt` → `404`; `?file=../private_notes.txt`
  → `200`. One `../` climbs the base into `data/`. (`../../data/private_notes.txt`
  hits the same file, confirming the base sits one level inside `data/`.) The
  base's own name is never observed and never needed.

## Exploitation (`./exploit.sh`, curl-only)
1. `POST /login` as `jdoe@student.42.tech` / `abc123` (any session works).
2. `GET /backup` → header leaks `x-backup-exclude: data/private_notes.txt`.
3. `GET /projects/download?file=../private_notes.txt` → returns the ops note.
4. Grab `recovery_flag=FLAG{d0t_d0t_sl4sh_4ll_th3_w4y_d0wn}` from the body.

## Impact
Authenticated low-priv file read outside the download dir. With a weaker root or
a symlink, the same bug reaches source, config, or the PocketBase DB.

## Remediation
`realpath(join(base, file))` and reject anything not under the intended base
(not merely `<app>/data`); or take only `basename(file)`; or allow-list by
name/id. Don't store secrets under a served root or name them in headers.

## References
CWE-22, CWE-200 · OWASP A01/A05 · [`00-recon/notes.md`](../00-recon/notes.md)
