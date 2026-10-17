# omAiSessions

Every coding-agent conversation on this computer, in one Omarchy bar panel.

Claude Code, Codex, Grok and Cursor keep their history per folder: to resume a
conversation you have to remember where you started it and launch the agent
there. omAiSessions lists them all, from every folder, newest first. Pick one
and it opens a terminal in that conversation's folder with the agent already
resuming it.

## Features

- One tab per agent (Claude Code, Codex, Grok, Cursor), plus **All** and
  **Running** tabs
- Sessions that are open right now are marked, and the bar icon lights up
  while any agent is running. Picking a running session switches to its
  window instead of opening a second copy (two copies writing one session
  would corrupt it)
- Titles from the agent's own naming (`/rename`, AI titles, Codex thread
  names, Grok and Cursor titles), falling back to your first prompt
- Folder, git branch and last activity for each session; sessions whose folder
  was deleted are flagged
- Search across titles and folders
- Keyboard-first: works without touching the mouse

## Keys

| Key | Action |
|---|---|
| `↑` `↓` / `j` `k` | Select a session |
| `←` `→` / `h` `l`, `1`–`9` | Switch agent tab |
| `Enter` | Resume in a terminal, or switch to it if it's running |
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

| Agent | History | Resume | Running |
|---|---|---|---|
| Claude Code | `~/.claude/projects/*/<id>.jsonl` (or `$CLAUDE_CONFIG_DIR`) | `claude --resume <id>` | `~/.claude/sessions/<pid>.json` |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` (or `$CODEX_HOME`) | `codex resume <id>` | `thread-writer-locks/<id>.lock` held by `codex app-server` |
| Grok | `~/.grok/sessions/<folder>/<id>/summary.json` (or `$GROK_HOME`) | `grok --resume <id>` | `~/.grok/active_sessions.json` |
| Cursor | `~/.cursor/chats/<md5 of folder>/<id>/store.db` (or `$CURSOR_CONFIG_DIR`) | `cursor-agent --resume <id>` | process with the store open |

Cursor names each chat's directory after an md5 of its folder, so the folder
is recovered by matching that hash: against paths inside the chat, then the
folders other agents know about, then your home directory a few levels deep.
Registry entries are checked against the live process (pid and start time),
so a crashed agent never shows as running. A session you just started has no
history until its first prompt, so there is nothing to resume yet; while it
runs it is listed as "New session", so you can still switch to its window.

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
