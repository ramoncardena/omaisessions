# Changelog

## 0.3.0

- New icon: a robot head whose antenna is a return arrow
  (`assets/icon.svg`), so it no longer looks like the built-in Agents widget
- OpenCode sessions, read from its database (`opencode.db`); resume with
  `opencode --session <id>`
- Codex: a new window in a folder whose closed session the app-server still
  holds is paired with the session it opened, not the old one; windows of
  another `CODEX_HOME` are never paired with these sessions

## 0.2.1

- Detect running sessions of current Codex (0.162+), which runs them in a
  `codex app-server` daemon; they showed as not running before. The daemon
  keeps closed sessions loaded, so a session counts as running only while a
  Codex window is attached
- List running sessions that have no prompt yet as "New session" (Claude,
  Codex, Grok), so they can be switched to
- Explain when a session ended before its first prompt instead of trying to
  resume it

## 0.2.0

- Grok and Cursor CLI sessions, each with its own tab
- Running sessions: marked in the list, a **Running** tab, and a lit bar icon
  while any agent runs. Picking a running session focuses its window instead
  of resuming it a second time.
- The list refreshes every few seconds while the panel is open, keeping the
  cursor on the same session when the order changes

## 0.1.0

- Claude Code and Codex sessions from every folder, newest first, with search
- Resume in a terminal opened in the session's folder
