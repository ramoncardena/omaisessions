# omAiSessions

Every coding-agent conversation on this computer, in one Omarchy bar panel.

Claude Code, Codex, Grok, Cursor and OpenCode keep their history per folder: to resume a
conversation you have to remember where you started it and launch the agent
there. omAiSessions lists them all, from every folder, newest first. Pick one
and it opens a terminal in that conversation's folder with the agent already
resuming it.

## Features

- One tab per agent (Claude Code, Codex, Grok, Cursor, OpenCode), plus **All** and
  **Running** tabs
- Sessions that are open right now are marked, and the bar icon lights up
  while any agent is running. Picking a running session switches to its
  window instead of opening a second copy (two copies writing one session
  would corrupt it)
- Titles from the agent's own naming (`/rename`, AI titles, Codex thread
  names, Grok, Cursor and OpenCode titles), falling back to your first prompt
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
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` (or `$CODEX_HOME`) | `codex resume <id>` | a `codex` window, matched to the sessions `codex app-server` holds locks for |
| Grok | `~/.grok/sessions/<folder>/<id>/summary.json` (or `$GROK_HOME`) | `grok --resume <id>` | `~/.grok/active_sessions.json` |
| Cursor | `~/.cursor/chats/<md5 of folder>/<id>/store.db` (or `$CURSOR_CONFIG_DIR`) | `cursor-agent --resume <id>` | process with the store open |
| OpenCode | `~/.local/share/opencode/opencode.db` (or `$XDG_DATA_HOME`) | `opencode --session <id>` | `opencode --session <id>`, or the newest session in its folder |

Cursor names each chat's directory after an md5 of its folder, so the folder
is recovered by matching that hash: against paths inside the chat, then the
folders other agents know about, then your home directory a few levels deep.
OpenCode keeps every session in one SQLite database, which also holds its
login tokens; only the session, message and part tables are read.

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

## Privacy and security

Omarchy plugins run unsandboxed, as you, inside the shell. This is
everything omAiSessions touches, so you can check it before enabling it.

**Reads**
- The agents' history folders listed above. Only the session list, titles,
  first prompts and folders are extracted. OpenCode's database also holds its
  login tokens; only its `session`, `message` and `part` tables are queried,
  read-only.
- `/proc`, to tell which sessions are running: each process's command line,
  working folder, start time and open file paths. For `codex` processes only,
  the environment is read to find `CODEX_HOME` (it can hold API keys; only
  `CODEX_HOME` and `HOME` are used, and nothing from it is kept or shown).
- Your home folder's directory names, up to three levels deep, only to match
  a Cursor chat to its folder.

**Writes**
- `~/.cache/omaisessions/index.json` (mode `600`): the extracted titles and
  first prompts, so a refresh doesn't re-read unchanged files. Nothing else is
  written, and agent history is never modified.

**Runs**
- Your terminal via `xdg-terminal-exec` (through `uwsm-app` when present),
  with the agent's own resume command, when you pick a session.
- `hyprctl`, to find and focus a running session's window.

Every command is an argument list, never a shell string. Session ids must
match a strict pattern before they reach a command line, a session opens in
the folder its own history records, and titles are shown as plain text.
There is no network access.

**Dependencies:** `python3` (standard library only), `xdg-terminal-exec`,
`hyprctl`; all ship with Omarchy.

**Removing** the plugin leaves its cache behind; delete it with
`rm -r ~/.cache/omaisessions`.

## IPC

```bash
omarchy-shell io.github.ramoncardena.omaisessions toggle   # open | close | refresh
```

## License

MIT
