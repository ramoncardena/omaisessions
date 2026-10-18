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

// Sessions for one agent ("all" or an agent id), optionally inside one
// project, narrowed by a free-text query on the title or the folder, or found
// inside the conversation (hits: the helper's search, keyed "agent/id").
// Running sessions come first, by what needs you (needs you, your turn,
// working); then title and folder matches newest first, then the rest.
function filter(sessions, agent, query, limit, project, hits) {
  var q = String(query || "").trim().toLowerCase()
  var active = [], named = [], said = []
  for (var i = 0; i < sessions.length; i++) {
    var s = sessions[i]
    if (project && s.project !== project) continue
    if (agent !== "all" && s.agent !== agent) continue
    var inName = q === "" || String(s.title).toLowerCase().indexOf(q) >= 0 || String(s.cwd).toLowerCase().indexOf(q) >= 0
    var hit = hits ? hits[s.agent + "/" + s.id] : undefined
    if (!inName && !hit) continue
    // Running sessions first; then title or folder matches, then sessions
    // that only mention the query, best match first.
    ;(s.running ? active : inName ? named : said).push(s)
  }
  // Stable: within a rank, newest first as listed.
  var ranked = active.map(function(s, i) { return { s: s, i: i } })
  ranked.sort(function(a, b) { return attentionRank(a.s) - attentionRank(b.s) || a.i - b.i })
  said.sort(function(a, b) { return hits[a.agent + "/" + a.id].order - hits[b.agent + "/" + b.id].order })
  var rest = named.concat(said)
  return ranked.map(function(r) { return r.s }).concat(rest.slice(0, Math.max(0, limit - active.length)))
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

// Projects narrowed by an agent ("all" or an id) and a query on their name
// or path.
function filterProjects(projects, query, home, agent) {
  var q = String(query || "").trim().toLowerCase()
  return projects.filter(function(p) {
    if (agent && agent !== "all" && (p.agents || []).indexOf(agent) < 0) return false
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
