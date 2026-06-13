---
name: limitcubes
description: Earn the right to mint a Limit Cubes NFT by using Claude Code. Use when the user types /limitcubes or asks to start, check, or claim a Limit Cubes mint. Reads only your usage percentage (via `claude -p`) and your plan tier, and sends just that one number to the mint backend. Never reads or transmits your auth tokens, messages, or conversation content.
---

# limitcubes

You operate the **Claude Limit Cubes** proof-of-usage mint: a user earns the
right to mint an NFT by spending Claude Code usage. The unit is a **credit** ≈
10% of a Pro 5-hour window; each credit = 1 cube (max 10 per wallet, 2222 total).
Read the user's **real** usage — never invent or accept a hand-typed number.

## Privacy & safety — read this first

This skill is deliberately minimal. It does the following and nothing else:

- **Reads:** the usage *percentage* reported by `claude -p` (just the number),
  and a few **non-secret** plan fields from `~/.claude.json` → `.oauthAccount`
  (the rate-limit tier and a stable account UUID).
- **Sends to the backend:** that single usage number, the plan label, a
  timestamp, and a one-way SHA-256 **hash** of the account UUID (not the UUID
  itself). Nothing else leaves the machine.
- **Never reads** authentication tokens, API keys, the `cc-accounts/` credential
  files, or any conversation/message content.
- **Never signs** anything locally and never moves funds — the backend returns
  an EIP-712 signature and the *website* performs the on-chain mint, which the
  user confirms in their own wallet.

If any step would require reading a token or message content, **don't do it** —
stop and tell the user instead.

Everything runs with Bash (`claude -p`, `jq`, `curl`, the browser opener).

## Endpoints
- Base URL: env `SKILL_BACKEND_URL` if set, else `https://limitcubes.io`. API at `<base>/api`.
- Site URL: env `SKILL_SITE_URL` if set, else `https://limitcubes.io`.

## Commands
- `/limitcubes start <wallet>` — snapshot the baseline
- `/limitcubes status` — show progress
- `/limitcubes claim` — request a mint authorization and open the mint page

## Step 0 — detect the plan (do this first, every command)

Read **only** the non-secret plan fields from `~/.claude.json` → `.oauthAccount`.
Do **not** open `~/.claude/cc-accounts/` — those files hold auth tokens and this
skill never touches them. The `.oauthAccount` object contains only the tier
label and account UUID, no credentials.

1. If `ANTHROPIC_API_KEY` is set in the environment → plan = **api**.
2. Otherwise read the rate-limit tier (just the tier string, nothing else):
   ```bash
   TIER_RAW=$(jq -r '.oauthAccount.organizationRateLimitTier // .oauthAccount.userRateLimitTier // empty' ~/.claude.json 2>/dev/null)
   ```
   Map it to a plan:
   - contains `max` and `20` → plan = **max20**
   - contains `max` and `5`  → plan = **max5**
   - contains `max` (tier unclear) → plan = **max5** (conservative)
   - otherwise → plan = **pro**

   Include `"tier_raw":"<TIER_RAW>"` in the snapshot when non-empty (the backend
   cross-checks tier vs. plan; it is just a label, not a secret).

Also compute a stable, non-secret **account fingerprint** — a one-way hash that
binds the mint to one Claude account without ever sending the UUID itself:
```bash
UUID=$(jq -r '.oauthAccount.accountUuid // empty' ~/.claude.json 2>/dev/null)
ACCOUNT_HASH=$(printf '%s' "limitcubes:$UUID" | shasum -a 256 | cut -d' ' -f1)
```
If `$UUID` is empty (e.g. pure API key, no Claude login) leave `ACCOUNT_HASH` empty and omit it.

## Reading the spend

**Subscription (pro / max5 / max20)** — run `echo "/usage" | claude -p`, take the
integer `Current session: N% used` (the 5-hour window). That is `PCT`.

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

Subscription: `{"plan":"<pro|max5|max20>","fivehour_used_pct":PCT,"tier_raw":"<TIER_RAW>","captured_at":TS,"source":"claude_subprocess"}`
API: `{"plan":"api","usd_used":USD,"captured_at":TS,"source":"claude_subprocess"}`

where `TS` = `date +%s`. Omit `tier_raw` if empty. `source` must always be
`claude_subprocess` (a live `claude -p` reading) — the backend rejects anything
else, so never hand-type or guess a number.

## start &lt;wallet&gt;
1. Validate wallet `^0x[0-9a-fA-F]{40}$` (else stop and ask). Lowercase it.
2. Detect plan + `ACCOUNT_HASH`, read spend, build the snapshot.
3. POST it (include `accountHash` when non-empty — it binds the mint to your
   Claude account, capping total cubes per account):
   ```bash
   curl -s -X POST "$BASE/api/session/start" -H "Content-Type: application/json" \
     -d '{"wallet":"<wallet>","accountHash":"<ACCOUNT_HASH>","usageSnapshot":<snapshot>}'
   ```
4. On `ok:true`, persist wallet + plan:
   ```bash
   mkdir -p ~/.claude/skills/limitcubes
   printf '{"wallet":"%s","plan":"%s"}' "<wallet>" "<plan>" > ~/.claude/skills/limitcubes/state.json
   ```
   Tell the user the baseline is saved and how cubes accrue:
   - pro: every +10% of the session → +1 cube
   - max5: every +2% → +1 cube (5× multiplier); max20: every +0.5% → +1 cube
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
3. POST the claim **without** a `pow` field first:
   ```bash
   curl -s -X POST "$BASE/api/session/claim" -H "Content-Type: application/json" \
     -d '{"wallet":"<wallet>","usageSnapshot":<snapshot>}'
   ```
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
   - `account_required` — your snapshot is missing the account hash; run start again
   - `account_cap_reached` — this Claude account already earned its 10 cubes
   - `max_per_wallet_reached` — wallet already owns the 10-cube cap
   - `sold_out` — the 2222 collection is gone

## Rules
- Never fabricate usage or plan — read the real number from `claude -p`.
- Read only the non-secret tier/UUID fields from `~/.claude.json .oauthAccount`.
  Never open `cc-accounts/`, never read tokens or API keys, never read message
  content (only numeric token counters for the API estimate).
- Send only: the usage number, plan label, timestamp, and the account-UUID hash.
- Always lowercase the wallet. Keep `plan` identical between start and claim.
- Never sign anything locally and never move funds — the backend returns the
  EIP-712 signature; the website performs the on-chain mint, confirmed by the
  user in their own wallet.
