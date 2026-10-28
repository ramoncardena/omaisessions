# Changelog

## 0.5.2

- Needs-you notifications are generic only ("An agent needs you"): titles,
  folders, wait reasons and prompts never appear on a subprocess command line;
  several new waits in one refresh share one toast. Details stay in the panel.

## 0.5.1

- Cursor: `$CURSOR_CONFIG_DIR` is respected alone (defaults are only used when
  it is unset); tests isolate `$XDG_CONFIG_HOME` so real chats can't leak in
- README: a short **Why this one** section for the Projects view, conversation
  search, needs-you bar, and safe resume

## 0.5.0

- Settings: a value already at its bound (`→` at 300 s, `←` at 20 sessions)
  no longer reports a failed save
- The bar icon toggles the panel on left click only
- Footer hints wrap instead of being cut off
- `omarchy-shell io.github.ramoncardena.omaisessions refresh` refreshes every
  monitor's widget, not just one
- A Cursor chat whose folder can't be found is remembered for an hour, so the
  home folder isn't walked again on every refresh
- Preview and README screenshots, taken from demo histories; the README
  documents removal and every tool the plugin runs
- Search inside conversations: after a pause in typing, sessions whose
  messages (yours or the agent's) have every word follow the title matches,
  with the words around the match; phrase matches rank first
- Open a project's folder in the file manager: Open folder in its heading,
  or `o` in Projects
- Projects tab: sessions grouped by git repository (a subfolder or a
  worktree counts as its repository) or by folder, with their agents and
  what's running or needs you; open one to see its sessions, `n` to start a
  new session there
- New layout: Sessions and Projects views, and agent chips on their own
  line (they wrap instead of overflowing). The Running tab is gone: running
  sessions are pinned at the top of Sessions under Active, needs-you first
- Lists take the room left in the panel, so a long one scrolls instead of
  running off the bottom; inside a project, the heading or the Projects
  button goes back to the list
- README: a keybinding to toggle the panel (`SUPER + A`)
- New session view (`n` or +): every folder an agent has worked in, last used
  first, or a path you type; starts an installed agent there, by default the
  one you used in that folder last
- Bar icon drawn at the font icons' size and line weight: it filled the
  whole 16 px canvas and sat 2 px past the other icons at top and bottom

## 0.4.0

- Running sessions show what they're doing: working, needs you (with the
  reason) or your turn, and for how long. Read from Claude Code's session
  status, Codex's turn events, Grok's events (including permission
  requests) and OpenCode's latest message
- The Running tab lists what needs you first; opening the panel while an
  agent needs you lands on it
- Bar icon: accent while agents run, urgent while one needs you
- Desktop notification when an agent starts waiting on you, once per wait
  across every monitor's widget; clicking it opens the panel on that
  session. Sent with Omarchy's notification sender, so a title the agent's
  model wrote can never be read as an option or a click-command hint
- Settings page in the panel (`s`): refresh interval (default 5 s, was 60 s
  while closed), notifications, sessions shown

## 0.3.0

- Security review: a session opens only in the folder its own history
  records, a window address must be hex before it reaches Hyprland's Lua
  dispatch, and the README documents everything the plugin reads, writes
  and runs
- Deep security review: one malformed history file or registry no longer
  breaks the whole list; running detection only considers your own
  processes; session ids are matched exactly (no trailing newline); folders
  with control characters are never handed to the terminal
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
