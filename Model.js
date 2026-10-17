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

// Sessions for one tab ("all", "running", "projects" with the open project,
// or an agent id), narrowed by a free-text query on the title or the folder.
function filter(sessions, tab, query, limit, project) {
  var q = String(query || "").trim().toLowerCase()
  var result = []
  for (var i = 0; i < sessions.length && result.length < limit; i++) {
    var s = sessions[i]
    if (tab === "projects") { if (s.project !== project) continue }
    else if (tab === "running" ? !s.running : tab !== "all" && s.agent !== tab) continue
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

// Folders to start a new session in, narrowed by the query. A query that is
// a path (~/x or /x) not in the list is offered too, after the folders it
// matches; the helper checks that it exists.
function folderChoices(folders, query, home) {
  var q = String(query || "").trim()
  var lower = q.toLowerCase()
  var result = []
  var asPath = q.charAt(0) === "~" ? String(home || "") + q.slice(1) : q
  var typed = q.charAt(0) === "/" || q === "~" || q.indexOf("~/") === 0
  var exact = asPath.replace(/\/+$/, "") || "/"   // the folder the path names
  for (var i = 0; i < folders.length; i++) {
    var f = folders[i]
    if (lower !== "" && !typed && f.path.toLowerCase().indexOf(lower) < 0 && shortPath(f.path, home).toLowerCase().indexOf(lower) < 0) continue
    if (typed && f.path !== exact && f.path.indexOf(asPath) !== 0) continue
    result.push(f)
  }
  // The folder the path names comes first; other known folders under it
  // follow, and a folder you've never used is offered after them.
  var named = -1
  for (var j = 0; j < result.length; j++) if (result[j].path === exact) named = j
  if (named > 0) result.unshift(result.splice(named, 1)[0])
  if (typed && named < 0) result.push({ path: exact, typed: true })
  return result
}

// Projects narrowed by a query on their name or path.
function filterProjects(projects, query, home) {
  var q = String(query || "").trim().toLowerCase()
  return projects.filter(function(p) {
    return q === "" || String(p.name).toLowerCase().indexOf(q) >= 0 || shortPath(p.path, home).toLowerCase().indexOf(q) >= 0
  })
}

// "omAiSessions", or "Home" for the home folder itself.
function projectName(p, home) {
  return p.path === home ? "Home" : p.name
}

// Agent names, most recently used first: "Claude, Codex".
function agentList(ids) {
  return (ids || []).map(agentShortName).join(", ")
}
