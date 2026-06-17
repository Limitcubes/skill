# Claude Limit Cubes — Skill

Mint **Claude Limit Cubes** NFTs by spending your Claude Code usage.
Every 10% of your 5‑hour window burned in Claude Code unlocks one cube
(max 10 per wallet, 2222 total). The skill reads your real usage via
`claude -p` — you never type a number by hand.

> Site: https://limitcubes.com

---

## Requirements — read this first

The skill needs the **Claude Code CLI** installed, with the `claude` command
available in your terminal's PATH. The skill reads your real usage by running
`claude -p`, so a working `claude` binary is **required** — there is no way
around it.

**This is required even if you normally use the VS Code / JetBrains extension,
the web app, or another interface.** Those do not always put `claude` on your
terminal PATH, and the skill calls it from a shell. Install the desktop / CLI
build so the command exists.

Verify it works before installing the skill:

```bash
claude --version      # should print a version, e.g. 2.1.x
claude -p "hi"        # should respond — confirms the CLI runs
```

If `claude` is "command not found" or the binary fails to launch, install (or
reinstall) Claude Code from https://claude.com/claude-code and re-open your
terminal, then check `claude --version` again. Don't continue until both
commands above work.

---

## Install

Open a terminal (not the Claude chat) and run the one line for your OS — it
downloads the skill into Claude Code.

**macOS / Linux:**

```bash
mkdir -p ~/.claude/skills/limitcubes && curl -fsSL https://raw.githubusercontent.com/Limitcubes/skill/main/skills/limitcubes/SKILL.md -o ~/.claude/skills/limitcubes/SKILL.md
```

**Windows (PowerShell):**

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills\limitcubes" | Out-Null; Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Limitcubes/skill/main/skills/limitcubes/SKILL.md" -OutFile "$env:USERPROFILE\.claude\skills\limitcubes\SKILL.md"
```

Then **restart Claude Code** and run `/limitcubes start 0xYourWallet`.

Run this in a real terminal, not the Claude chat — Claude Code blocks writing
downloaded files into its skills folder from inside the chat. Requires the
`claude` CLI on your PATH (see Requirements above) — it reads usage via
`claude -p`. No extra runtime, only `claude` and `curl`.

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
