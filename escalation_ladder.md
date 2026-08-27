# Escalation Ladder — Requirement Analysis

Analysis of whether this project satisfies the **privilege-escalation ladder** required by
the Darkly evaluation scale. All claims below were **verified live against the VM**
(`:4942` app, `:8090` PocketBase) — not inferred from notes.

## The requirement (from the scale)

The mandatory core is *"a full privilege escalation until the student becomes the
administrator of the web application (**4 flags, one per privilege level reached**)"*, graded
as four rungs:

| Rung | Scale wording |
|------|----------------|
| Flag 1 | Gain your **first authenticated access** and recover the flag it yields. |
| Flag 2 | **Raise your privileges one level further** and recover the flag it yields. |
| Flag 3 | **Raise your privileges one level further** and recover the flag it yields. |
| Flag 4 (administrator) | Reach **full administrator** and recover the flag it yields. |

Each rung also needs a breach explanation + a prevention method. "Recover the flag it
yields" means the flag becomes recoverable **once you reach that level** — it does *not*
require the escalation request itself to return the flag (an **indirect** flag is fine). The
real requirement is **one distinct flag per level, each via a distinct method**.

## Verified facts about the VM

### 1. There are 4 role tiers, but only 2 role-gated flags, and they overlap

Role enum (from `/api/users`): `student` → `cadet` (`emilie`) → `staff` (`wil`) → `god`
(`sophie`). What each tier can actually read:

| Tier (account) | `/api/grades` | `/staff/dashboard` | `/admin` |
|---|---|---|---|
| student (`jdoe`) | `FLAG{md5...}` | 403 | 403 |
| cadet (`emilie`) | — | `FLAG{just_p4tch...}` | 403 |
| staff (`wil`) | — | `FLAG{just_p4tch...}` | `FLAG{md5...}` |
| god (`sophie`) | — | `FLAG{just_p4tch...}` | `FLAG{md5...}` |

- `FLAG{just_p4tch...}` is gated at **cadet+** — cadet, staff, and god all read the *same*
  one via `/staff/dashboard`.
- The `/admin` flag is `FLAG{md5...}` — the **identical string** students already get from
  `/api/grades`. `/admin` has no sub-pages (all 404).
- **staff and god are indistinguishable by flags.** There is **no staff-only or god-only
  flag** anywhere in the app.

**Consequence:** a strict "distinct flag per role tier" ladder is **impossible** on this VM —
4 tiers, but only 2 role-gated flags, shared across tiers, and the admin flag duplicates the
student flag.

### 2. `moderator` is a student

`/api/users` shows `moderator@42network.fr` = `role: student`, `level: 0`. The stored-XSS
bot-session theft therefore steals a **student** session — no privilege gain. It is **not** a
staff rung.

### 3. There is no `level`-based auto-promotion

`PATCH /api/profile {"level": N}` for N ∈ {41, 42, 43, 100} never changes the role (stays
`student`). The recon note claiming "auto-promotes to staff when level ≥ 42" is **false**.

### 4. The `role` PATCH caps at cadet

`PATCH /api/profile {"role":"cadet"}` → `200`. `{"role":"staff"}` and `{"role":"god"}` →
`403 {"error":"role not assignable"}`. So mass assignment reaches **cadet only**.

### 5. JWT forgery works by `sub` impersonation, not the `role` claim

The server **ignores the token's `role` claim** and reads the role from the DB by `sub`:

- forged `sub=sophie` + `role=student` → `/admin` **200** (role claim ignored, DB role used)
- forged `sub=jdoe` + `role=god` → `/admin` **403** (DB says jdoe is a student)

The real bug is **session/identity forgery via the leaked HMAC secret** (`42network`): sign a
token for *any* `sub` and the server grants that user's real privileges. Impact is unchanged
(full god); the mechanism is identity spoofing, not "trusts the role claim."

### 6. PocketBase superuser is a distinct tier *above* app-god

Who can read the `internal_audit` collection (where its flag lives):

| Who | `internal_audit` |
|---|---|
| unauthenticated | 403 |
| student PB record token (`jdoe`) | 403 "Only admins can perform this action" |
| app-god (forged `sophie` session on `:4942`) | no route — `/api/audit`, `/admin/audit`… all 404 |
| **PB superuser** (`admin@42network.local`) | **200 → flag** |

App-god cannot touch PocketBase collections at all. **Only the PB superuser tier** reads
`internal_audit`, so it is the true "full administrator of the platform" — a legitimate top
rung with a **tier-exclusive** flag.

## Ground-truth flag map (from the PB superuser dump)

| Flag | Location | Lowest tier that can reach it | Tier-exclusive? |
|---|---|---|---|
| `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` | app `/staff/dashboard` | **cadet** | ✅ yes |
| `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}` | `internal_audit` collection | **PB superuser** | ✅ yes |
| `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` | `grades` collection | student (`/api/grades`); also `/admin` | no |
| `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` | `users.recovery_code` | student (reset-forge) | no |
| `FLAG{1d0r_ur_pr0f1l3_1s_m1n3}` | `users.private_note` | anon (IDOR) | no |
| `FLAG{d3fus3dxml_n3xt_spr1nt_pr0m1s3}` | `internal_config` | student (XXE→SSRF) | no |
| `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}` | bot cookie (not in DB) | student (stored XSS) | no |
| `FLAG{unr3str1ct3d_upl0ad_g0_brrr}` | app upload response (not in DB) | student (upload) | no |
| `FLAG{d0t_d0t_sl4sh_4ll_th3_w4y_d0wn}` | file on disk (not in DB) | anon/student (path traversal) | no |

9 distinct flag values. Only two are strictly privilege-tier-exclusive.

## Do we meet the requirement?

**Not** as a "distinct flag per role tier" ladder — the VM cannot support that (fact #1).
**Yes** under the correct reading — "one flag per *privilege level reached*," where each flag
is recovered as part of reaching that level (indirect flags are allowed). This gives a clean,
honest, monotonically-increasing ladder with 4 distinct flags and 4 distinct methods:

| Rung | Access gained | Method (distinct) | Flag it yields (distinct) |
|------|---------------|-------------------|---------------------------|
| 1 | anon → **student** | reset-token forgery — `md5(email)` reset, own a student account | `FLAG{r3s3t_t0k3n_w4s_just_md5_lol}` |
| 2 | student → **cadet** | mass assignment — `PATCH /api/profile {"role":"cadet"}` | `FLAG{just_p4tch_y0ur_0wn_r0l3_lol}` |
| 3 | → **app admin (god)** | session forgery — leaked HMAC secret, impersonate sophie's `sub` | `FLAG{md5_1s_4_n4m3pl4t3_n0t_4_l0ck}` (from `/admin`) |
| 4 | → **DB superuser** | XXE → leaked creds → PocketBase admin dump | `FLAG{th3_und3rsc0r3_sl4sh_kn0ws_th3_w4y}` |

### Why this mapping

- **Rung 1 uses reset-forge, not the jdoe brute-force.** Both are valid anon→student vectors,
  but brute-force yields no flag of its own (you'd have to borrow `FLAG{md5}` from grades),
  whereas reset-forge carries its **own** distinct flag. Using it here **frees `FLAG{md5}`**
  to serve as the admin-rung flag, eliminating the student/admin duplication.
- **`staff` is dropped as a separate rung** — it is flag-identical to god (fact #1), so it is
  not a useful distinct level. Rung 3 = app-admin (god), Rung 4 = the strictly-higher PB
  superuser.
- Each rung's breach explanation + prevention already exist in the per-breach folders
  (`reset_token_forgery/`, `patch_to_cadet/`, `jwt_forgery/`, `xxe_ssrf/` + `pb_admin_dump/`).

### The 2 mandatory "additional flags (your choice)" — off the ladder

Pick any 2 not used above: `FLAG{1d0r...}` (IDOR), `FLAG{unr3str1ct3d...}` (upload),
`FLAG{d3fus3dxml...}` (XXE/SSRF), `FLAG{d0t_d0t...}` (path traversal),
`FLAG{xss_st0r3d...}` (stored XSS).

## Repo corrections this analysis exposes

These are **claims in the current repo contradicted by the live VM** — to fix in the
respective files (not done here; this doc is analysis only):

1. `walkthrough.md` Phase 5 — `PATCH role=staff` does **not** work (403); the cap is
   **cadet**. Change to `role=cadet`.
2. `jwt_forgery/explanation.md` — mechanism is **`sub` impersonation + DB role lookup**, not
   "the server trusts the `role` claim." Fix the "two things went wrong" and remediation.
3. `00-recon/wstg-coverage.md` (BUSL row) — the `level:42 → staff` auto-promote is **false**;
   remove or mark disproven.
4. `stored_xss_bot_exfil/explanation.md` — the moderation bot is **student-role**, so "same
   payoff as jwt_forgery" (god) is overstated; it is a student-session theft.
