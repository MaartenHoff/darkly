# Stored XSS → Moderation-Bot Cookie Exfiltration

Three small bugs chain into a full takeover of the forum's moderation bot — with no attacker server needed.

## Where
- `POST /forum/new` — stores `content` with no HTML-escaping.
- `GET /forum/<id>` — renders that `content` raw (the listing page strips tags for its preview; the post page doesn't).
- `GET|POST /api/collect?c=` — an unauthenticated debug endpoint that logs whatever you send and replays the whole log on a plain `GET`.

## How it works
Three separate issues, none interesting alone:

1. **Forum content isn't escaped** — post a `<script>` and anyone who opens that thread runs it. (A dev comment even jokes it "worked" for a subscriber.)
2. **The session cookie isn't `HttpOnly`** (open ticket `#4201`) — so `document.cookie` is readable by injected script.
3. **`/api/collect?c=` is a leftover debug sink** — logs anything you send and hands it back on `GET`, no auth either way.

Chained: post a script that reads `document.cookie` and sends it to `/api/collect?c=…`, then just ask that endpoint what it collected — no attacker server, no listener.

Who runs the script: a **moderation bot** (real headless-Chrome, confirmed by user-agent) opens every new thread within seconds using its own logged-in session — and that session carries a cookie named `flag`.

**Discovery:** we didn't guess `/api/collect` — the app discloses it *and* the bot in dev comments on forum **thread** pages (`/forum/<id>`), found by viewing a thread's source. (`recon.sh`'s INFO-05 sweep only covers listing pages, so this one takes opening a thread.) Two comments there spell it out: *"left `/api/collect` up from when I was debugging the bot — it logs whatever you throw at `?c=` and hands it all back on GET"* and *"the moderation bot opens every thread with a live session… and a `flag` cookie that isn't httpOnly."* Verified black-box (`curl "/api/collect?c=hello"`, then `GET /api/collect` echoed it back, unauthenticated) before relying on it — it never appeared in any wordlist.

## Exploitation (`./exploit.sh`)
1. **Log in** as `jdoe` (any account — not privilege-specific).
2. **Post a thread** with content:
   ```html
   <script>fetch("/api/collect?c="+encodeURIComponent(document.cookie))</script>
   ```
3. **Wait** — the bot opens new threads on its own (~15s in testing).
4. **Read the loot** — `GET /api/collect` returns the captured cookies. The bot's entry gives it away (HeadlessChrome UA, `from: 127.0.0.1`) and its cookie header holds a session JWT (`login: moderator`) plus the flag:

```
FLAG{xss_st0r3d_1s_n0t_4_f34tur3_w1l}
```

## Impact
- **Full session takeover of the bot's account** — its JWT is captured whole and replayable as a `session` cookie (same payoff as [`jwt_forgery/`](../jwt_forgery/), stolen instead of forged).
- **No attacker infrastructure** — the exfil sink is the app's own endpoint; you only need to know `/api/collect` exists.
- **Genuinely stored** — the payload fires for *every* future visitor to that thread, not just the bot.

## Remediation
1. **HTML-escape all user content** before rendering (or allow-list sanitize if rich text is required).
2. **Set `HttpOnly`/`Secure`/`SameSite` on the session cookie** — this alone stops the theft even with the XSS present.
3. **Remove `/api/collect`** (or require auth and stop echoing data back).
4. **Add a `Content-Security-Policy`** limiting `script-src`/`connect-src`.

## References
WSTG-INPV-02 · OWASP A03:2021. Related: [`jwt_forgery/`](../jwt_forgery/) (what a stolen session token gets you); missing `HttpOnly` = ticket `#4201`. A separate reflected-XSS sink lives on `/newsletter` — see [`newsletter_reflected_xss/`](../newsletter_reflected_xss/).
