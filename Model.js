.pragma library

// Pure presentation helpers for omAiSessions: no QML types, so BarWidget.qml
// and Panel.qml share one source of truth for how a session reads.

function plural(n, one, many) {
  return n + " " + (n === 1 ? one : many)
}

// /home/me/Projects/x -> ~/Projects/x
function shortPath(path, home) {
  var p = String(path || "")
  if (home && (p === home || p.indexOf(home + "/") === 0)) return "~" + p.slice(home.length)
  return p
}

function relativeTime(epochSec, nowMs) {
  if (!epochSec) return "never"
  var s = Math.max(0, Math.round(nowMs / 1000 - epochSec))
  if (s < 60) return "just now"
  if (s < 3600) return Math.floor(s / 60) + "m ago"
  if (s < 86400) return Math.floor(s / 3600) + "h ago"
  if (s < 86400 * 30) return Math.floor(s / 86400) + "d ago"
  return Math.floor(s / (86400 * 30)) + "mo ago"
}

// 3m, 2h, 4d: how long a running session has been in its state.
function elapsed(epochSec, nowMs) {
  if (!epochSec) return ""
  var s = Math.max(0, Math.round(nowMs / 1000 - epochSec))
  if (s < 60) return "now"
  if (s < 3600) return Math.floor(s / 60) + "m"
  if (s < 86400) return Math.floor(s / 3600) + "h"
  return Math.floor(s / 86400) + "d"
}

// What a running session is doing: "working", "needs you: permission
// prompt · 2m", "your turn · 5m". Agents that report no state say "running".
function stateLabel(s, nowMs) {
  var since = elapsed(s.stateSince, nowMs)
  switch (s.state) {
    case "waiting": return "needs you" + (s.waitingFor ? ": " + s.waitingFor : "") + (since ? " · " + since : "")
    case "idle": return "your turn" + (since ? " · " + since : "")
    case "working": return "working"
    default: return "running"
  }
}

// Order of the Running tab: what needs you first, then what's done.
function attentionRank(s) {
  return s.state === "waiting" ? 0 : s.state === "idle" ? 1 : 2
}

function agentShortName(id) {
  switch (id) {
    case "claude": return "Claude"
    case "codex": return "Codex"
    case "grok": return "Grok"
    case "cursor": return "Cursor"
    case "opencode": return "OpenCode"
    default: return String(id || "")
  }
}

// Sessions for one tab ("all", "running" or an agent id), narrowed by a
// free-text query that matches the title or the folder.
function filter(sessions, tab, query, limit) {
  var q = String(query || "").trim().toLowerCase()
  var result = []
  for (var i = 0; i < sessions.length && result.length < limit; i++) {
    var s = sessions[i]
    if (tab === "running" ? !s.running : tab !== "all" && s.agent !== tab) continue
    if (q !== "" && String(s.title).toLowerCase().indexOf(q) < 0 && String(s.cwd).toLowerCase().indexOf(q) < 0) continue
    result.push(s)
  }
  if (tab === "running") {
    // Stable: within a rank, newest first as listed.
    var ranked = result.map(function(s, i) { return { s: s, i: i } })
    ranked.sort(function(a, b) { return attentionRank(a.s) - attentionRank(b.s) || a.i - b.i })
    result = ranked.map(function(r) { return r.s })
  }
  return result
}
