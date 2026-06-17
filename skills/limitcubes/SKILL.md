---
name: limitcubes
description: Earn the right to mint a Limit Cubes NFT by using Claude Code. Use when the user types /limitcubes or asks to start, check, or claim a Limit Cubes mint. Reads only your usage percentage via `claude -p` and sends just that one number to the mint backend. Never reads any Claude config file, auth tokens, API keys, or conversation content.
---

# limitcubes

You operate the **Claude Limit Cubes** proof-of-usage mint: a user earns the
right to mint an NFT by spending Claude Code usage. The unit is a **credit** ≈
10% of a Pro 5-hour window; each credit = 1 cube (max 10 per wallet, 2222 total).
Read the user's **real** usage — never invent or accept a hand-typed number.

## Privacy & safety — read this first

This skill is deliberately minimal. It does the following and nothing else:

- **Reads:** only the usage *percentage* reported by `claude -p` (just the
  number). That's the single piece of local information it needs.
- **Sends to the backend:** that usage number, the plan label the user tells
  you, and a timestamp. Nothing else leaves the machine.
- **Never reads** any Claude config file (`~/.claude.json`, `cc-accounts/`,
  settings), authentication tokens, API keys, or any conversation/message
  content. It does not touch protected files at all.
- **Never signs** anything locally and never moves funds — the backend returns
  an EIP-712 signature and the *website* performs the on-chain mint, which the
  user confirms in their own wallet.

If any step would require reading a token, a config file, or message content,
**don't do it** — stop and tell the user instead.

Everything runs with Bash (`claude -p`, `curl`, the browser opener).

## Endpoints
- Base URL: `https://limitcubes.com`. API at `<base>/api`.
- Site URL: `https://limitcubes.com`.

## Commands
- `/limitcubes start <wallet>` — snapshot the baseline
- `/limitcubes status` — show progress
- `/limitcubes claim` — request a mint authorization and open the mint page

## Prerequisite — the `claude` CLI must work

This skill reads usage by running `claude -p`, so a working Claude Code CLI is
required. **Before the first command**, verify it:
```bash
claude --version
```
If that fails (`command not found`, or "not a valid application"), stop and tell
the user: they must install/reinstall Claude Code from
https://claude.com/claude-code so the `claude` command is on their PATH — even
if they normally use the VS Code/JetBrains extension or the web app (those do
not always expose `claude` to the terminal). Do not try to fake or skip the
usage reading.

## Step 0 — determine the plan (do this first, every command)

The plan is decided **automatically — never ask the user, never let them pick**
(a user-chosen plan is plan-faking). Rule:

1. If the `ANTHROPIC_API_KEY` environment variable is set → plan = **api**
   (checking an env var reads no file and can't be faked into a multiplier).
2. Otherwise → plan = **pro**. Always. Every Claude Code subscription (Pro,
   Max 5×, Max 20×) earns at the Pro rate: 10% of the 5-hour window = 1 cube.
   There is no plan multiplier and no plan question.

Do **not** read `~/.claude.json`, `~/.claude/cc-accounts/`, or any settings file,
and do **not** ask the user which plan they are on. The skill sends only the
usage number, `plan` (always `pro`, or `api`), and a timestamp.

## Reading the spend

**Subscription (pro)** — get the 5-hour session percentage in one shot. Pass
`/usage` as the **argument** to `claude -p` (NOT piped via stdin — piping makes
Claude treat it as a prompt instead of running the command). Extract the number
directly, don't print or "interpret" the output:

```bash
PCT=$(claude -p "/usage" 2>/dev/null | grep -i "Current session" | sed -E 's/.*[^0-9]([0-9]+)% used.*/\1/' | head -1)
```

`PCT` is now the integer percentage (e.g. `48`). If it's empty, the CLI isn't
working — see the Prerequisite section; do not guess a value.

**API** — there is no usage window, so estimate dollars spent from the
**numeric token counters** in the local usage logs. Read **only** the
`.message.usage.*` token *counts* (integers) — never the message text, prompts,
or responses. Multiply by model prices (USD per 1M tokens):

| model contains | input $/M | output $/M |
|---|---|---|
| `opus`   | 15 | 75 |
| `sonnet` | 3  | 15 |
| `haiku`  | 0.80 | 4 |

Pull just the integer fields (`input_tokens`, `output_tokens`,
`cache_read_input_tokens`, `cache_creation_input_tokens`; cache-read ≈ 0.1×
input price, cache-write ≈ 1.25× input price) with a `jq` selector that extracts
**only those numbers** and discards everything else. A rough blended total is
fine. Call it `USD`. Do not print or transmit anything but the final dollar
figure.

## Snapshot to send

Subscription: `{"plan":"pro","fivehour_used_pct":PCT,"captured_at":TS,"source":"claude_subprocess"}`
API: `{"plan":"api","usd_used":USD,"captured_at":TS,"source":"claude_subprocess"}`

where `TS` = `date +%s`. `source` must always be `claude_subprocess` (a live
`claude -p` reading) — the backend rejects anything else, so never hand-type or
guess a number.

## Sending POST requests (do it this way — avoids shell escaping)

Inline JSON in a shell argument breaks easily, **especially in Windows
PowerShell** (it mangles quotes/braces and `curl.exe` returns 400). To avoid all
of that: **write the JSON body to a temp file and send the file**. One reliable
form per platform — pick the user's shell:

- **macOS / Linux (bash/zsh):**
  ```bash
  printf '%s' '<JSON BODY>' > /tmp/lc_body.json
  curl -s -X POST "$BASE/api/session/start" -H "Content-Type: application/json" --data @/tmp/lc_body.json
  ```
- **Windows (PowerShell):** write the file, then use `Invoke-RestMethod` (do NOT
  hand-escape JSON into a `curl.exe` argument):
  ```powershell
  '<JSON BODY>' | Set-Content -Path "$env:TEMP\lc_body.json" -Encoding utf8 -NoNewline
  Invoke-RestMethod -Method Post -Uri "$BASE/api/session/start" -ContentType "application/json" -InFile "$env:TEMP\lc_body.json"
  ```

Use this same file-based approach for **every** POST below (`start`, `claim`,
the PoW retry). Don't retry with different inline-escaping tricks — go straight
to the temp-file form. Replace `start` with `claim` in the URL as needed.

## start &lt;wallet&gt;
1. Validate wallet `^0x[0-9a-fA-F]{40}$` (else stop and ask). Lowercase it.
2. Determine the plan (Step 0), read the spend, build the snapshot.
3. POST it using the **file-based form** above (write
   `{"wallet":"<wallet>","usageSnapshot":<snapshot>}` to the temp file, then
   send it to `"$BASE/api/session/start"`). Do not inline the JSON.
4. On `ok:true`, persist wallet + plan:
   ```bash
   mkdir -p ~/.claude/skills/limitcubes
   printf '{"wallet":"%s","plan":"%s"}' "<wallet>" "<plan>" > ~/.claude/skills/limitcubes/state.json
   ```
   Tell the user the baseline is saved and how cubes accrue:
   - subscription: every +10% of the 5-hour session → +1 cube
   - api: every $`usdPerCube` (from the response) spent → +1 cube
5. On `ok:false`, report `error`.

## status
1. Read wallet+plan from `~/.claude/skills/limitcubes/state.json` (else ask to run start).
2. `curl -s "$BASE/api/session/<wallet>/status"`.
3. Read the current spend (same method as the plan), report progress and how
   many cubes are unlocked.

## claim
1. Read wallet+plan from state (else ask to run start).
2. Read spend, build the snapshot (same `plan` as start — must match).
3. POST the claim **without** a `pow` field first, using the file-based form
   (write `{"wallet":"<wallet>","usageSnapshot":<snapshot>}` to the temp file,
   send it to `"$BASE/api/session/claim"`). Do not inline the JSON.
4. **Proof-of-work.** If the response is `{"needPow":true,"challenge":"<C>","difficulty":<D>}`,
   solve it: find any `nonce` such that `sha256("<C>:<nonce>")` (hex) starts with
   `<D>` zeros. Then re-POST the same body **plus** `"pow":{"challenge":"<C>","nonce":"<found>"}`.
   This runs in the background and takes ~1–2 s — do it silently, don't ask the user.
   ```bash
   C="<challenge>"; D=<difficulty>; PFX=$(printf '0%.0s' $(seq 1 $D))
   n=0; while :; do
     h=$(printf '%s:%s' "$C" "$n" | shasum -a 256 | cut -c1-$D)
     [ "$h" = "$PFX" ] && break
     n=$((n+1))
   done
   # now $n is the nonce; re-POST with "pow":{"challenge":"$C","nonce":"$n"}
   ```
   (If `shasum` truncation differs on the platform, compare the full hash prefix
   instead. Any language/loop is fine — the rule is just "hash starts with D zeros".)
5. On `ok:true`: open the mint page —
   `open` (macOS) / `xdg-open` (Linux) / `start` (Windows) on `"$SITE/?wallet=<wallet>"`.
   Tell the user: authorization for `additionalQuantity` cube(s) signed; connect
   the wallet in the browser and confirm.
6. On `ok:false`, explain `error`:
   - `pow_required` / `pow_expired` / `pow_invalid` — solve (or re-request) the
     proof-of-work and retry (see step 4); `pow_expired` means get a fresh challenge
   - `session_too_short` — wait ~5 min between start and claim
   - `baseline_expired` — run start again
   - `suspicious_growth` — spend grew too fast for the elapsed time
   - `below_step` — not enough spent yet (see `deltaPercent` / `deltaUsd`)
   - `plan_mismatch` — plan changed since start; run start again
   - `max_per_wallet_reached` — wallet already owns the 10-cube cap
   - `sold_out` — the 2222 collection is gone

## Rules
- Never fabricate usage — read the real number from `claude -p`.
- Never read any Claude config file (`~/.claude.json`, `cc-accounts/`, settings)
  or any auth token / API key. Determine the plan from `ANTHROPIC_API_KEY`,
  saved state, or by asking the user — never by reading a protected file.
- Send only: the usage number, the plan label, and a timestamp.
- Always lowercase the wallet. Keep `plan` identical between start and claim.
- Never sign anything locally and never move funds — the backend returns the
  EIP-712 signature; the website performs the on-chain mint, confirmed by the
  user in their own wallet.
