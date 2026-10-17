# omAiSessions

Every coding-agent conversation on this computer, in one Omarchy bar panel.

Claude Code and Codex keep their history per folder: to resume a
conversation you have to remember where you started it and launch the agent
there. omAiSessions lists them all, from every folder, newest first. Pick one
and it opens a terminal in that conversation's folder with the agent already
resuming it.

## Features

- One tab per agent (Claude Code, Codex), plus an **All** tab
- Titles from the agent's own naming (`/rename`, AI titles, Codex thread
  names), falling back to your first prompt
- Folder, git branch and last activity for each session; sessions whose folder
  was deleted are flagged
- Search across titles and folders
- Keyboard-first: works without touching the mouse

## Keys

| Key | Action |
|---|---|
| `↑` `↓` / `j` `k` | Select a session |
| `←` `→` / `h` `l`, `1`–`9` | Switch agent tab |
| `Enter` | Resume in a terminal |
| `/` | Search (Esc clears, ↓ back to the list) |
| `r` | Refresh |
| `Esc` | Close |

## Install

```bash
omarchy plugin add https://github.com/ramoncardena/omaisessions
```

For development, from a clone:

```bash
scripts/dev-sync.sh    # validate, copy into ~/.config/omarchy/plugins, enable
tests/run.sh           # helper tests against fixture histories
```

## How it works

`bin/omaisessions` (Python, standard library only) reads each agent's history
and prints JSON for the panel:

| Agent | History | Resume |
|---|---|---|
| Claude Code | `~/.claude/projects/*/<id>.jsonl` (or `$CLAUDE_CONFIG_DIR`) | `claude --resume <id>` |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` (or `$CODEX_HOME`) | `codex resume <id>` |

It only reads history; it never changes it. Results are cached in
`~/.cache/omaisessions/` by file mtime, so a refresh only re-reads files that
changed. Terminals open with the same app-id as `omarchy agent`
(`org.omarchy.agent`), so your window rules for agents apply.

These history formats are internal to each agent and can change between
versions; each agent has its own small reader, so a format change breaks only
that tab.

## IPC

```bash
omarchy-shell io.github.ramoncardena.omaisessions toggle   # open | close | refresh
```

## License

MIT
