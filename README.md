# Claude Limit Cubes — Skill

Mint **Claude Limit Cubes** NFTs by spending your Claude Code usage.
Every 10% of your 5‑hour window burned in Claude Code unlocks one cube
(max 10 per wallet, 2222 total). The skill reads your real usage via
`claude -p` — you never type a number by hand.

> Site: https://limitcubes.io · Network: Ethereum (Sepolia for testing)

---

## Install

### Option A — Claude Code plugin (recommended)

In Claude Code:

```
/plugin marketplace add Limitcubes/skill
/plugin install limitcubes@limitcubes
```

This is the trusted path — Claude Code installs it as a managed plugin,
so it is **not** blocked by the security classifier.

### Option B — manual (normal terminal, not Claude Code)

```bash
git clone https://github.com/Limitcubes/skill.git ~/limitcubes-skill
bash ~/limitcubes-skill/install.sh
```

The installer copies `SKILL.md` into `~/.claude/skills/limitcubes/`.
Run it in a **normal terminal** — installing skills from inside Claude
Code triggers its prompt‑injection guard.

**No runtime to install** — the skill uses `claude` and `curl`, which you
already have.

---

## Usage

In Claude Code:

```
/limitcubes start 0xYourWallet
# ...work normally so your 5-hour usage grows, wait ≥5 min...
/limitcubes status
/limitcubes claim
```

`claim` opens the mint page in your browser — connect your wallet and
confirm the transaction.

### Pointing at a different backend

By default the skill talks to `https://limitcubes.io`. Override for local
dev or a custom deployment:

```bash
export SKILL_BACKEND_URL=http://localhost:3000
export SKILL_SITE_URL=http://localhost:5173
```

---

## How it works

1. `start` snapshots your current 5‑hour usage as a baseline.
2. You work in Claude Code normally; usage grows.
3. `claim` sends the new usage; the backend verifies the delta, signs an
   EIP‑712 mint authorization, and opens the mint page.
4. You mint on‑chain. The signature is single‑use and expires in 10 min.

Your usage number comes from Anthropic via `claude -p`, not from you —
it can't be faked without tampering with the Claude binary.

## Security

The skill is just instructions ([`skills/limitcubes/SKILL.md`](skills/limitcubes/SKILL.md)) —
inspect it before installing. It only:

- runs `claude -p` to read your usage percentage,
- POSTs `{wallet, usageSnapshot}` to the backend with `curl`,
- opens the mint URL in your browser.

No keys, no wallet access, no telemetry, no third‑party runtime.

## License

MIT
