# snip-skill

> Use [snip](https://github.com/edouard-claude/snip) (LLM token optimizer) without breaking your AI coding agent.
> Escape protocol, safe config, filter-by-filter danger analysis with real before/after examples.

## The Problem

snip saves 60-90% tokens by filtering verbose CLI output. Works with Claude Code,
OpenCode, Cursor, Copilot, and more.

**But filters work silently.** An aggressive filter can strip critical information
your agent needs — and you won't know what was lost. One wrong filter turns a
debugging session into a guessing game.

## This Repo

`SKILL.md` is a complete guide that teaches you:

- **The Escape Protocol** — 4 ways to bail out when output looks wrong
- **The Safe Zone** — 70+ filters you can trust (test runners, linters, build tools)
- **The Danger Zone** — 24 filters to disable, each with real before/after examples
  showing exactly what gets lost
- **Full Config** — drop-in `config/config.toml` with everything annotated

## Quick Install

```bash
# One command — installs snip + skill + safe config + OpenCode plugin
curl -fsSL https://raw.githubusercontent.com/EnRaiha/snip-skill/main/install.sh | sh
```

## Manual Install

```bash
# 1. Install snip
curl -fsSL https://raw.githubusercontent.com/edouard-claude/snip/master/install.sh | sh

# 2. Install the skill
mkdir -p ~/.claude/skills/snip
cp SKILL.md ~/.claude/skills/snip/SKILL.md

# 3. Install the safe config
mkdir -p ~/.config/snip
cp config/config.toml ~/.config/snip/config.toml

# 4. Add OpenCode plugin (optional)
# Add "opencode-snip@latest" to your opencode.json plugin list
```

## Escape Protocol

```
Output looks wrong?   → snip proxy <command>         (instant bypass)
See what snip hid?    → ls ~/.local/share/snip/tee/   (raw output saved)
Disable a filter?     → edit ~/.config/snip/config.toml
Everything broken?    → remove plugin, restart session
```

## Filter Safety at a Glance

| Status | Category | Count |
|--------|----------|-------|
| ✅ Safe | Test runners, linters, build tools, package managers, git (except diff/show) | 70+ |
| 🛑 Disabled | curl, systemctl, git-diff, git-show, find, grep, jq, psql, and 16 more | 24 |

Every disabled filter has an explanation in SKILL.md with a real example of what gets lost.

## Files

```
snip-skill/
├── SKILL.md              # The full teaching guide (~680 lines)
├── README.md             # This file
├── LICENSE               # MIT
├── install.sh            # One-command installer
└── config/
    └── config.toml       # Drop-in safe config
```

## Credits

- **[edouard-claude/snip](https://github.com/edouard-claude/snip)** — original [snip](https://github.com/edouard-claude/snip) CLI proxy and 126 YAML filters. Inspired by [rtk](https://github.com/rtk-ai/rtk).
- **[VincentHardouin/opencode-snip](https://github.com/VincentHardouin/opencode-snip)** — OpenCode plugin that auto-prefixes `bash` tool calls with `snip`.

## License

MIT — matching [snip](https://github.com/edouard-claude/snip)'s license.
