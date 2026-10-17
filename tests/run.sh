#!/bin/bash

# Tests for bin/omaisessions against fixture histories in a temp dir.
# Never touches real agent history: HOME, CLAUDE_CONFIG_DIR, CODEX_HOME and
# XDG_CACHE_HOME all point into the temp dir, and the terminal is stubbed.

set -uo pipefail

HELPER="$(cd "$(dirname "$0")/.." && pwd)/bin/omaisessions"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

export HOME="$T/home" XDG_CACHE_HOME="$T/cache"
export CLAUDE_CONFIG_DIR="$HOME/.claude" CODEX_HOME="$HOME/.codex" GROK_HOME="$HOME/.grok" CURSOR_CONFIG_DIR="$HOME/.cursor"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$HOME/Projects/app" "$HOME/Projects/my-app" "$T/stub"

# Stub terminal and agents: record the command line, launch nothing.
cat >"$T/stub/xdg-terminal-exec" <<STUB
#!/bin/bash
printf '%s\n' "\$PWD" "\$@" >"$T/launched"
STUB
for a in claude codex grok cursor-agent opencode; do printf '#!/bin/bash\n' >"$T/stub/$a"; done
# Notifications go to files, never to the desktop: /usr/bin has Omarchy's
# real sender, so every way of sending one is stubbed.
for a in omarchy-notification-send notify-send; do
  printf '#!/bin/bash\nprintf "%%s\\n" "$@" >>"%s/notified-%s"\n' "$T" "$a" >"$T/stub/$a"
done
printf '#!/bin/bash\n' >"$T/stub/omarchy-shell"
chmod +x "$T/stub/"*
export PATH="$T/stub:/usr/bin"

pass=0 failed=0
check() {
  local name="$1"
  shift
  if "$@"; then pass=$((pass + 1)); else failed=$((failed + 1)); echo "FAIL: $name"; fi
}
list() { "$HELPER" list; }
field() { list | jq -r --arg id "$1" ".sessions[] | select(.id == \$id) | .$2"; }

# ---- Claude fixtures. The project folder name is lossy (my-app vs my/app),
# so the real path must come from the cwd field inside the file.
C="$CLAUDE_CONFIG_DIR/projects/-home-x-Projects-my-app"
mkdir -p "$C/aaaaaaaa-0000-0000-0000-000000000001/subagents"
cat >"$C/aaaaaaaa-0000-0000-0000-000000000001.jsonl" <<JSON
{"type":"mode","sessionId":"aaaaaaaa-0000-0000-0000-000000000001"}
{"type":"user","cwd":"$HOME/Projects/my-app","gitBranch":"main","message":{"role":"user","content":"<command-name>/clear</command-name>"}}
{"type":"user","cwd":"$HOME/Projects/my-app","isMeta":true,"message":{"role":"user","content":"meta text"}}
{"type":"user","cwd":"$HOME/Projects/my-app","message":{"role":"user","content":[{"type":"text","text":"Fix the   login\nbug please"}]}}
{"type":"ai-title","aiTitle":"Old title"}
{"type":"ai-title","aiTitle":"Login bug fix"}
JSON
echo '{"type":"user","cwd":"/x","message":{"content":"sub"}}' >"$C/aaaaaaaa-0000-0000-0000-000000000001/subagents/agent-1.jsonl"
# Only a /clear: nothing to resume.
cat >"$C/aaaaaaaa-0000-0000-0000-000000000002.jsonl" <<JSON
{"type":"user","cwd":"$HOME/Projects/my-app","message":{"role":"user","content":"<command-name>/clear</command-name>"}}
JSON
# No title yet, detached HEAD, folder since deleted.
cat >"$C/aaaaaaaa-0000-0000-0000-000000000003.jsonl" <<JSON
{"type":"user","cwd":"$HOME/gone","gitBranch":"HEAD","message":{"role":"user","content":"Write a very long prompt $(printf 'x%.0s' {1..200})"}}
JSON
# A /rename beats the AI title.
cat >"$C/aaaaaaaa-0000-0000-0000-000000000004.jsonl" <<JSON
{"type":"user","cwd":"$HOME/Projects/app","message":{"role":"user","content":"hello"}}
{"type":"ai-title","aiTitle":"Greeting"}
{"type":"custom-title","customTitle":"My named session"}
JSON
touch -d '3 hours ago' "$C/aaaaaaaa-0000-0000-0000-000000000003.jsonl"

# ---- Codex fixtures.
X="$CODEX_HOME/sessions/2026/10/12"
mkdir -p "$X"
cat >"$X/rollout-2026-10-12T10-00-00-bbbbbbbb-0000-0000-0000-000000000001.jsonl" <<JSON
{"type":"session_meta","payload":{"id":"bbbbbbbb-0000-0000-0000-000000000001","cwd":"$HOME/Projects/app","source":"cli","git":{"branch":"dev"}}}
{"type":"response_item","payload":{"type":"message","role":"developer","content":[{"type":"input_text","text":"instructions"}]}}
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>x</environment_context>"}]}}
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Add dark mode"}]}}
JSON
cat >"$X/rollout-2026-10-12T11-00-00-bbbbbbbb-0000-0000-0000-000000000002.jsonl" <<JSON
{"type":"session_meta","payload":{"id":"bbbbbbbb-0000-0000-0000-000000000002","cwd":"$HOME/Projects/app","source":"exec"}}
{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"batch job"}]}}
JSON
cat >"$CODEX_HOME/session_index.jsonl" <<JSON
{"id":"bbbbbbbb-0000-0000-0000-000000000001","thread_name":"First name"}
{"id":"bbbbbbbb-0000-0000-0000-000000000001","thread_name":"Dark mode toggle"}
JSON

# ---- Grok fixtures: sessions/<url-encoded cwd>/<id>/summary.json.
G="$GROK_HOME/sessions/$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$HOME/Projects/app")"
mkdir -p "$G/cccccccc-0000-0000-0000-000000000001" "$G/cccccccc-0000-0000-0000-000000000002" "$G/cccccccc-0000-0000-0000-000000000003/subagents/x"
cat >"$G/cccccccc-0000-0000-0000-000000000001/summary.json" <<JSON
{"info":{"id":"cccccccc-0000-0000-0000-000000000001","cwd":"$HOME/Projects/app"},"generated_title":"Grok titled","num_chat_messages":4,"last_active_at":"2026-10-13T05:56:14.431001912Z"}
JSON
cat >"$G/cccccccc-0000-0000-0000-000000000002/summary.json" <<JSON
{"info":{"id":"cccccccc-0000-0000-0000-000000000002","cwd":"$HOME/Projects/app"},"session_summary":"","num_chat_messages":3}
JSON
cat >"$G/cccccccc-0000-0000-0000-000000000002/chat_history.jsonl" <<JSON
{"type":"system","content":"You are Grok"}
{"type":"user","content":[{"type":"text","text":"<user_info>Workspace Path: /x</user_info>"}]}
{"type":"user","content":[{"type":"text","text":"<user_query>\nTidy the README\n</user_query>"}]}
JSON
# Opened, never prompted: nothing to resume.
cat >"$G/cccccccc-0000-0000-0000-000000000003/summary.json" <<JSON
{"info":{"id":"cccccccc-0000-0000-0000-000000000003","cwd":"$HOME/Projects/app"},"num_chat_messages":0}
JSON
echo '{"info":{"id":"sub","cwd":"/x"},"generated_title":"sub"}' >"$G/cccccccc-0000-0000-0000-000000000003/subagents/x/summary.json"

# ---- Cursor fixtures: chats/<md5 of folder>/<id>/store.db, metadata as
# hex-encoded JSON under meta key "0".
mkdir -p "$HOME/Projects/deep/one"
python3 - "$CURSOR_CONFIG_DIR/chats" "$HOME" <<'PY'
import hashlib, json, os, sqlite3, sys
chats, home = sys.argv[1], sys.argv[2]
def chat(folder, cid, meta, blobs):
    d = os.path.join(chats, hashlib.md5(folder.encode()).hexdigest(), cid)
    os.makedirs(d)
    db = sqlite3.connect(os.path.join(d, "store.db"))
    db.executescript("CREATE TABLE blobs (id TEXT PRIMARY KEY, data BLOB); CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);")
    db.execute("INSERT INTO meta VALUES ('0', ?)", (json.dumps(meta).encode().hex(),))
    for i, b in enumerate(blobs):
        db.execute("INSERT INTO blobs VALUES (?, ?)", (str(i), b))
    db.commit(); db.close()
app = home + "/Projects/app"
# Folder named in a blob; untitled, so the typed query is the title.
chat(app, "dddddddd-0000-0000-0000-000000000001", {"agentId": "x", "name": "New Agent"}, [
    b"\x0a\x10binary\x00junk",
    json.dumps({"role": "user", "content": "<user_info>Workspace Path: " + app + "</user_info>\n<user_query>Refactor the parser</user_query>"}, separators=(",", ":")).encode()])
# No path in any blob: found through another agent's folder.
chat(home + "/Projects/my-app", "dddddddd-0000-0000-0000-000000000002", {"name": "Named chat"}, [b"\x00\x01"])
# Only the home walk can find this one.
chat(home + "/Projects/deep/one", "dddddddd-0000-0000-0000-000000000003", {"name": "Deep chat"}, [])
# Never prompted and untitled: skipped.
chat(app, "dddddddd-0000-0000-0000-000000000004", {"name": "New Agent"}, [])
PY

# ---- OpenCode fixtures: one database for every session, in the shape of
# opencode 1.19 (session, message and part rows; data is JSON).
OC="$XDG_DATA_HOME/opencode/opencode.db"; mkdir -p "$(dirname "$OC")"
python3 - "$OC" "$HOME" <<'PY'
import json, sqlite3, sys, time
db = sqlite3.connect(sys.argv[1]); home = sys.argv[2]
db.executescript("""
CREATE TABLE session (id TEXT PRIMARY KEY, project_id TEXT, parent_id TEXT, directory TEXT, title TEXT,
  time_created INTEGER, time_updated INTEGER, time_archived INTEGER);
CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT);
CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT);
CREATE TABLE credential (id TEXT PRIMARY KEY, value TEXT);
INSERT INTO credential VALUES ('c', 'SECRET-TOKEN');
""")
now = int(time.time() * 1000)
n = 0
def session(sid, title, parts, parent=None, archived=None, cwd=home + "/Projects/app"):
    global n
    db.execute("INSERT INTO session VALUES (?,?,?,?,?,?,?,?)", (sid, "p", parent, cwd, title, now - 9000, now - 5000, archived))
    for role, part in parts:
        n += 1
        db.execute("INSERT INTO message VALUES (?,?,?,?,?)", ("msg%d" % n, sid, n, n, json.dumps({"role": role})))
        db.execute("INSERT INTO part VALUES (?,?,?,?,?,?)", ("prt%d" % n, "msg%d" % n, sid, n, n, json.dumps(part)))
session("ses_titled0000000001", "Add an OpenCode tab", [("user", {"type": "text", "text": "add opencode"}), ("assistant", {"type": "text", "text": "ok"})])
# Still on the placeholder title: the first typed prompt, past a synthetic part.
session("ses_untitled00000002", "New session - 2026-10-17T10:00:00.000Z",
        [("user", {"type": "text", "text": "Injected", "synthetic": True}), ("user", {"type": "text", "text": "Write the README"})],
        cwd=home + "/Projects/my-app")
session("ses_child00000000003", "Child task", [("user", {"type": "text", "text": "sub"})], parent="ses_titled0000000001")
session("ses_archived00000004", "Archived", [("user", {"type": "text", "text": "old"})], archived=now)
session("ses_empty00000000005", "New session - 2026-10-17T11:00:00.000Z", [])
db.commit(); db.close()
PY

out=$(list)
check "list succeeds" test "$(jq -r .ok <<<"$out")" = true
check "finds resumable sessions only" test "$(jq '.sessions | length' <<<"$out")" = 11
check "skips subagent transcripts" test -z "$(jq -r '.sessions[] | select(.cwd == "/x") | .id' <<<"$out")"
check "skips cleared-only claude sessions" test -z "$(field aaaaaaaa-0000-0000-0000-000000000002 id)"
check "skips codex exec runs" test -z "$(field bbbbbbbb-0000-0000-0000-000000000002 id)"
check "claude cwd comes from the file" test "$(field aaaaaaaa-0000-0000-0000-000000000001 cwd)" = "$HOME/Projects/my-app"
check "latest ai-title wins" test "$(field aaaaaaaa-0000-0000-0000-000000000001 title)" = "Login bug fix"
check "custom title beats ai-title" test "$(field aaaaaaaa-0000-0000-0000-000000000004 title)" = "My named session"
check "first prompt is the fallback title" bash -c "[[ '$(field aaaaaaaa-0000-0000-0000-000000000003 title)' == 'Write a very long prompt x'* ]]"
check "long titles are cut" test "$(field aaaaaaaa-0000-0000-0000-000000000003 title | wc -m)" -le 121
check "claude branch kept" test "$(field aaaaaaaa-0000-0000-0000-000000000001 branch)" = main
check "detached HEAD shows no branch" test -z "$(field aaaaaaaa-0000-0000-0000-000000000003 branch)"
check "missing folder flagged" test "$(field aaaaaaaa-0000-0000-0000-000000000003 exists)" = false
check "existing folder flagged" test "$(field aaaaaaaa-0000-0000-0000-000000000001 exists)" = true
check "codex title from session index" test "$(field bbbbbbbb-0000-0000-0000-000000000001 title)" = "Dark mode toggle"
check "codex branch from git meta" test "$(field bbbbbbbb-0000-0000-0000-000000000001 branch)" = dev
check "sorted newest first" test "$(jq -r '.sessions[-1].id' <<<"$out")" = cccccccc-0000-0000-0000-000000000001
check "agent counts" test "$(jq -c '[.agents[] | [.id, .count, .installed]]' <<<"$out")" = '[["claude",3,true],["codex",1,true],["grok",2,true],["cursor",3,true],["opencode",2,true]]'
check "opencode title" test "$(field ses_titled0000000001 title)" = "Add an OpenCode tab"
check "opencode folder" test "$(field ses_titled0000000001 cwd)" = "$HOME/Projects/app"
check "opencode placeholder title falls back to the prompt" test "$(field ses_untitled00000002 title)" = "Write the README"
check "opencode skips subagent, archived and empty sessions" test -z "$(jq -r '.sessions[] | select(.id == "ses_child00000000003" or .id == "ses_archived00000004" or .id == "ses_empty00000000005") | .id' <<<"$out")"
check "opencode credentials never leave the database" bash -c "! grep -q SECRET-TOKEN <<<'$out' && ! grep -q SECRET-TOKEN '$XDG_CACHE_HOME/omaisessions/index.json'"
check "limit" test "$("$HELPER" list --limit 2 | jq '.sessions | length')" = 2

check "grok title from summary" test "$(field cccccccc-0000-0000-0000-000000000001 title)" = "Grok titled"
check "grok time from summary" test "$(field cccccccc-0000-0000-0000-000000000001 updated)" = "$(date -d 2026-10-13T05:56:14Z +%s)"
check "grok falls back to the user query" test "$(field cccccccc-0000-0000-0000-000000000002 title)" = "Tidy the README"
check "grok skips unprompted sessions" test -z "$(field cccccccc-0000-0000-0000-000000000003 id)"
check "grok skips subagents" test -z "$(field sub id)"
check "cursor folder from a blob" test "$(field dddddddd-0000-0000-0000-000000000001 cwd)" = "$HOME/Projects/app"
check "cursor title from the user query" test "$(field dddddddd-0000-0000-0000-000000000001 title)" = "Refactor the parser"
check "cursor folder from another agent" test "$(field dddddddd-0000-0000-0000-000000000002 cwd)" = "$HOME/Projects/my-app"
check "cursor name from metadata" test "$(field dddddddd-0000-0000-0000-000000000002 title)" = "Named chat"
check "cursor folder from the home walk" test "$(field dddddddd-0000-0000-0000-000000000003 cwd)" = "$HOME/Projects/deep/one"
check "cursor skips untitled empty chats" test -z "$(field dddddddd-0000-0000-0000-000000000004 id)"
check "cursor folders are cached" test "$(jq '.paths | length' "$XDG_CACHE_HOME/omaisessions/index.json")" -ge 1
check "nothing running yet" test "$(list | jq '[.sessions[] | select(.running)] | length')" = 0

# ---- Running sessions, simulated by stand-in processes named after the
# agents (exec -a) that hold the session files open like the real ones do.
pids=()
# Stand-ins never inherit stdout, so piping this script never waits on them.
spawn() { "$@" >/dev/null 2>&1 & pids+=($!); }
# Children too: a stand-in shell's sleep would outlive it.
stop() { for p in "${pids[@]}"; do pkill -P "$p"; kill "$p"; done 2>/dev/null; pids=(); sleep 0.2; }
trap 'stop; rm -rf "$T"' EXIT
start_of() { awk '{print $22}' "/proc/$1/stat"; }
mkdir -p "$CLAUDE_CONFIG_DIR/sessions"
spawn bash -c 'exec -a claude sleep 300'; cp=$!
spawn bash -c "exec 3<'$X/rollout-2026-10-12T10-00-00-bbbbbbbb-0000-0000-0000-000000000001.jsonl'; exec -a codex sleep 300"
spawn bash -c "exec 3<'$(dirname "$(ls "$CURSOR_CONFIG_DIR"/chats/*/dddddddd-0000-0000-0000-000000000003/store.db)")/store.db'; exec -a cursor-agent sleep 300"
spawn bash -c 'exec -a grok sleep 300'; gp=$!
sleep 0.3
echo "{\"pid\":$cp,\"sessionId\":\"aaaaaaaa-0000-0000-0000-000000000001\",\"cwd\":\"$HOME/Projects/my-app\",\"procStart\":\"$(start_of $cp)\"}" >"$CLAUDE_CONFIG_DIR/sessions/$cp.json"
echo '{"pid":999999,"sessionId":"aaaaaaaa-0000-0000-0000-000000000004","procStart":"1"}' >"$CLAUDE_CONFIG_DIR/sessions/999999.json"
echo "{\"pid\":$cp,\"sessionId\":\"aaaaaaaa-0000-0000-0000-000000000003\",\"procStart\":\"1\"}" >"$CLAUDE_CONFIG_DIR/sessions/recycled.json"
echo "[{\"session_id\":\"cccccccc-0000-0000-0000-000000000002\",\"pid\":$gp,\"pid_start\":$(start_of $gp)}]" >"$GROK_HOME/active_sessions.json"
out=$(list)
run() { jq -r --arg id "$1" '.sessions[] | select(.id == $id) | .running' <<<"$out"; }
check "claude running from its registry" test "$(run aaaaaaaa-0000-0000-0000-000000000001)" = true
check "claude registry pid matches" test "$(jq -r '.sessions[] | select(.id == "aaaaaaaa-0000-0000-0000-000000000001") | .pid' <<<"$out")" = "$cp"
check "dead registry entry is not running" test "$(run aaaaaaaa-0000-0000-0000-000000000004)" = false
check "recycled pid is not running" test "$(run aaaaaaaa-0000-0000-0000-000000000003)" = false
check "grok running from active_sessions" test "$(run cccccccc-0000-0000-0000-000000000002)" = true
check "codex running from its open rollout" test "$(run bbbbbbbb-0000-0000-0000-000000000001)" = true
check "cursor running from its open store" test "$(run dddddddd-0000-0000-0000-000000000003)" = true
check "others are not running" test "$(jq '[.sessions[] | select(.running)] | length' <<<"$out")" = 4
check "agent running counts" test "$(jq -c '[.agents[] | .running]' <<<"$out")" = '[1,1,1,1,0]'

# Codex named on its command line (`codex resume <id>`), no open file.
stop
spawn bash -c 'exec -a codex python3 -c "import time; time.sleep(300)" resume bbbbbbbb-0000-0000-0000-000000000001'
sleep 0.3
check "codex running from its argv" test "$(field bbbbbbbb-0000-0000-0000-000000000001 running)" = true
stop
# A fresh codex in a folder: the session there written since it started.
spawn bash -c "cd '$HOME/Projects/app' && exec -a codex sleep 300"
sleep 1.2; touch "$X/rollout-2026-10-12T10-00-00-bbbbbbbb-0000-0000-0000-000000000001.jsonl"
check "codex running from its folder" test "$(field bbbbbbbb-0000-0000-0000-000000000001 running)" = true

stop
# A shell whose script merely mentions an agent is not that agent.
spawn bash -c "cd '$HOME/Projects/deep/one' && sleep 300; : cursor-agent /x/cursor-agent/1/index.js codex"
sleep 1.2; touch "$(ls "$CURSOR_CONFIG_DIR"/chats/*/dddddddd-0000-0000-0000-000000000003/store.db)"
check "decoy shell is not an agent" test "$(field dddddddd-0000-0000-0000-000000000003 running)" = false
spawn bash -c "cd '$HOME/Projects/deep/one' && exec -a cursor-agent sleep 300"
sleep 1.2; touch "$(ls "$CURSOR_CONFIG_DIR"/chats/*/dddddddd-0000-0000-0000-000000000003/store.db)"
check "cursor running from its folder" test "$(field dddddddd-0000-0000-0000-000000000003 running)" = true
stop

# OpenCode: every process holds the shared database open, which says
# nothing about its session; --session on the command line or the folder does.
spawn bash -c "cd / && exec 3<'$OC' && exec -a opencode sleep 300"
sleep 0.3
check "opencode open database is not a session" test "$(list | jq '[.sessions[] | select(.agent == "opencode" and .running)] | length')" = 0
spawn bash -c 'exec -a opencode python3 -c "import time; time.sleep(300)" --session ses_untitled00000002'
sleep 0.3
check "opencode running from --session" test "$(field ses_untitled00000002 running)" = true
spawn bash -c "cd '$HOME/Projects/app' && exec -a opencode sleep 300"
sleep 1.2; python3 -c "import sqlite3,sys,time; d=sqlite3.connect(sys.argv[1]); d.execute('UPDATE session SET time_updated=? WHERE id=?', (int(time.time()*1000), 'ses_titled0000000001')); d.commit()" "$OC"
check "opencode running from its folder" test "$(field ses_titled0000000001 running)" = true
spawn bash -c 'cd / && exec -a codex python3 -c "import time; time.sleep(300)" resume bbbbbbbb-0000-0000-0000-000000000001'
sleep 0.3

# Opening a running session focuses its window instead of a second copy.
cat >"$T/stub/hyprctl" <<STUB
#!/bin/bash
if [[ \$1 == clients ]]; then echo '[{"pid":$$,"address":"0xfeed"}]'; else echo "\$*" >>"$T/focused"; echo ok; fi
STUB
chmod +x "$T/stub/hyprctl"; rm -f "$T/launched"
out=$("$HELPER" open codex bbbbbbbb-0000-0000-0000-000000000001 "$HOME/Projects/app")
check "running session is focused" test "$(jq -r .focused <<<"$out")" = true
check "focus targets the terminal window" grep -q 'address:0xfeed' "$T/focused"
check "no second copy is launched" test ! -e "$T/launched"
# A window address that isn't hex never reaches the Lua dispatch.
cat >"$T/stub/hyprctl" <<STUB
#!/bin/bash
if [[ \$1 == clients ]]; then echo '[{"pid":$$,"address":"0x1\\" }) os.exit() --"}]'; else echo "\$*" >>"$T/focused-bad"; echo ok; fi
STUB
out=$("$HELPER" open codex bbbbbbbb-0000-0000-0000-000000000001 "$HOME/Projects/app")
check "odd window addresses are not dispatched" test ! -e "$T/focused-bad"
check "odd window address reads as no window" jq -e '.error | test("window can.t be found")' <<<"$out"
printf '#!/bin/bash\necho "[]"\n' >"$T/stub/hyprctl"
check "running without a window explains" bash -c "'$HELPER' open codex bbbbbbbb-0000-0000-0000-000000000001 '$HOME/Projects/app' | jq -e '.error | test(\"Already running\")' >/dev/null"
stop

# Current Codex: clients attach to a `codex app-server` daemon that holds a
# lock per loaded session (before the first prompt there is no rollout at
# all) and keeps closed sessions loaded after their window is gone.
L="$CODEX_HOME/thread-writer-locks"; mkdir -p "$L" "$T/srv"
: >"$L/eeeeeeee-0000-0000-0000-000000000001.lock"; : >"$L/bbbbbbbb-0000-0000-0000-000000000001.lock"
printf 'sleep 300; :\n' >"$T/srv/app-server"
spawn bash -c "cd '$T/srv' && exec 3<'$L/eeeeeeee-0000-0000-0000-000000000001.lock' 4<'$L/bbbbbbbb-0000-0000-0000-000000000001.lock' && exec -a codex bash app-server"
srv=("${pids[@]}")
sleep 0.3
check "codex server alone is not a session" test "$(list | jq '[.sessions[] | select(.running)] | length')" = 0
spawn bash -c "cd '$HOME/Projects/app' && exec -a codex sleep 300"; c1=$!
sleep 1.1
spawn bash -c "cd '$HOME/Projects/my-app' && exec -a codex sleep 300"; c2=$!
# Locks predate the clients, except the one c2 took when it started.
touch -d '-1 hour' "$L/bbbbbbbb-0000-0000-0000-000000000001.lock"; sleep 0.1; touch "$L/eeeeeeee-0000-0000-0000-000000000001.lock"
echo "[{\"session_id\":\"cccccccc-0000-0000-0000-00000000000f\",\"pid\":$$,\"pid_start\":$(start_of $$),\"cwd\":\"$HOME/Projects/my-app\"}]" >"$GROK_HOME/active_sessions.json"
sleep 0.3
out=$(list)
new() { jq -r --arg id "$1" '.sessions[] | select(.id == $id) | [.title, .cwd, .running, .new, .pid] | join("|")' <<<"$out"; }
check "codex client on the locked session in its folder" test "$(jq -r '.sessions[] | select(.id == "bbbbbbbb-0000-0000-0000-000000000001") | [.running, .pid] | join("|")' <<<"$out")" = "true|$c1"
check "codex client on a new locked session" test "$(new eeeeeeee-0000-0000-0000-000000000001)" = "New session|$HOME/Projects/my-app|true|true|$c2"
check "grok running before its first prompt" test "$(new cccccccc-0000-0000-0000-00000000000f)" = "New session|$HOME/Projects/my-app|true|true|$$"
check "new sessions count per agent" test "$(jq -c '[.agents[] | .running]' <<<"$out")" = '[0,2,1,0,0]'
kill "$c1" "$c2"; sleep 0.2
# A new client in a folder whose closed session is still loaded: it is on
# the session it locked when it started, not the old one.
spawn bash -c "cd '$HOME/Projects/app' && exec -a codex sleep 300"; c3=$!
sleep 0.2; : >"$L/eeeeeeee-0000-0000-0000-000000000002.lock"
spawn bash -c "cd '$T/srv' && exec 3<'$L/eeeeeeee-0000-0000-0000-000000000002.lock' && exec -a codex bash app-server"
sleep 0.3; out=$(list)
check "new codex window beats an old lock in its folder" test "$(new eeeeeeee-0000-0000-0000-000000000002)" = "New session|$HOME/Projects/app|true|true|$c3"
check "old loaded session is not running" test "$(run bbbbbbbb-0000-0000-0000-000000000001)" = false
kill "$c3"; sleep 0.2
check "closed codex windows stop running" test "$(list | jq '[.sessions[] | select(.agent == "codex" and .running)] | length')" = 0
check "new session vanishes when it ends" test -z "$(field eeeeeeee-0000-0000-0000-000000000001 id)"
check "opening an ended new session explains" bash -c "'$HELPER' open codex eeeeeeee-0000-0000-0000-000000000001 '$HOME/Projects/app' | jq -e '.error | test(\"gone\")' >/dev/null"
stop
rm -f "$CLAUDE_CONFIG_DIR"/sessions/*.json "$GROK_HOME/active_sessions.json"

# ---- Whether a running session is working, waiting on you, or done.
R="$X/rollout-2026-10-12T10-00-00-bbbbbbbb-0000-0000-0000-000000000001.jsonl"
spawn bash -c 'exec -a claude sleep 300'; cp=$!
spawn bash -c 'exec -a claude sleep 300'; cp2=$!
spawn bash -c 'exec -a grok sleep 300'; gp=$!
spawn bash -c "exec 3<'$R'; exec -a codex sleep 300"
spawn bash -c 'exec -a opencode python3 -c "import time; time.sleep(300)" --session ses_titled0000000001'
sleep 0.3
reg() { echo "{\"pid\":$1,\"sessionId\":\"$2\",\"procStart\":\"$(start_of $1)\",\"status\":\"$3\",\"waitingFor\":\"$4\",\"statusUpdatedAt\":$5}" >"$CLAUDE_CONFIG_DIR/sessions/$1.json"; }
st() { list | jq -r --arg id "$1" '.sessions[] | select(.id == $id) | [.state, (.waitingFor // "")] | join("|")'; }
A1=aaaaaaaa-0000-0000-0000-000000000001
reg $cp $A1 busy "" 1792000000000
check "claude working" test "$(st $A1)" = "working|"
reg $cp $A1 waiting "permission prompt" 1792000001000
check "claude waiting, with its reason" test "$(st $A1)" = "waiting|permission prompt"
check "waiting since the status changed" test "$(list | jq -r --arg id $A1 '.sessions[] | select(.id == $id) | .stateSince')" = 1792000001
reg $cp $A1 idle "" 1792000002000
check "claude done: your turn" test "$(st $A1)" = "idle|"

B1=bbbbbbbb-0000-0000-0000-000000000001
echo '{"timestamp":"2026-10-12T10:01:00Z","type":"event_msg","payload":{"type":"task_started"}}' >>"$R"
check "codex working on a turn" test "$(st $B1)" = "working|"
echo '{"timestamp":"2026-10-12T10:02:00Z","type":"event_msg","payload":{"type":"task_complete"}}' >>"$R"
check "codex turn complete" test "$(st $B1)" = "idle|"

C2=cccccccc-0000-0000-0000-000000000002; E="$G/$C2/events.jsonl"
echo "[{\"session_id\":\"$C2\",\"pid\":$gp,\"pid_start\":$(start_of $gp)}]" >"$GROK_HOME/active_sessions.json"
echo '{"ts":"2026-10-17T10:00:00Z","type":"turn_started"}' >"$E"
check "grok working" test "$(st $C2)" = "working|"
echo '{"ts":"2026-10-17T10:00:05Z","type":"permission_requested","tool_name":"bash"}' >>"$E"
check "grok waiting on a permission" test "$(st $C2)" = "waiting|permission prompt"
echo '{"ts":"2026-10-17T10:00:09Z","type":"permission_resolved"}' >>"$E"
check "grok working again once answered" test "$(st $C2)" = "working|"
echo '{"ts":"2026-10-17T10:01:00Z","type":"turn_ended","outcome":"completed"}' >>"$E"
check "grok turn over" test "$(st $C2)" = "idle|"

check "opencode working until the reply completes" test "$(st ses_titled0000000001)" = "working|"
python3 - "$OC" <<'PY'
import json, sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("UPDATE message SET data = ? WHERE id = 'msg2'", (json.dumps({"role": "assistant", "time": {"created": 1, "completed": 2}, "finish": "stop"}),))
db.commit()
PY
check "opencode reply complete" test "$(st ses_titled0000000001)" = "idle|"

# Notifications: once per wait, never twice for parallel lists (one bar
# widget per monitor), sent with Omarchy's sender (plain D-Bus values, a
# click opens the panel), and the text is never markup or an option.
N="$T/notified-omarchy-notification-send"
nsent() { grep -cx 'Claude Code needs you' "$N" 2>/dev/null || true; }
reg $cp $A1 waiting "permission prompt" 1792000005000
"$HELPER" list >/dev/null
check "no notification without --notify" test "$(nsent)" = ""
"$HELPER" list --notify >/dev/null
check "notifies when a session starts waiting" test "$(nsent)" = 1
check "notification says why and where" grep -qxF "permission prompt · ~/Projects/my-app" "$N"
check "clicking opens the panel" bash -c "tr '\n' ' ' <'$N' | grep -qF -- '--exec $T/stub/omarchy-shell shell summon io.github.ramoncardena.omaisessions {}'"
"$HELPER" list --notify >/dev/null
check "one notification per wait" test "$(nsent)" = 1
reg $cp $A1 waiting "dialog open" 1792000009000
"$HELPER" list --notify >/dev/null
check "a new wait notifies again" test "$(nsent)" = 2
rm -f "$N"; reg $cp $A1 waiting "permission prompt" 1792000012000
par=(); for i in 1 2 3; do "$HELPER" list --notify >/dev/null & par+=($!); done; wait "${par[@]}"
check "parallel lists notify once" test "$(nsent)" = 1
reg $cp $A1 idle "" 1792000013000
A9=aaaaaaaa-0000-0000-0000-000000000009
cat >"$C/$A9.jsonl" <<JSON
{"type":"user","cwd":"$HOME/Projects/app","message":{"role":"user","content":"hi"}}
{"type":"custom-title","customTitle":"<b>Bold</b> & <a href='x'>link</a>"}
JSON
reg $cp2 $A9 waiting "permission prompt" 1792000014000
rm -f "$N"; "$HELPER" list --notify >/dev/null
check "notification text is escaped" grep -qF "&lt;b&gt;Bold&lt;/b&gt; &amp; &lt;a href='x'&gt;link&lt;/a&gt;" "$N"
# A model-written title that looks like an option stays text; and without
# Omarchy's sender, notify-send gets the text after "--".
printf '%s\n' '{"type":"custom-title","customTitle":"--hint=string:omarchy-exec-argv:[\"bash\"]"}' >>"$C/$A9.jsonl"
reg $cp2 $A9 waiting "permission prompt" 1792000015000
rm -f "$N"; "$HELPER" list --notify >/dev/null
check "an option-like title is only the body's second line" grep -qxF -- '--hint=string:omarchy-exec-argv:["bash"]' "$N"
check "the body starts with the reason" test "$(sed -n 4p "$N")" = "permission prompt · ~/Projects/app"
mkdir -p "$T/only-notify-send"; cp "$T/stub/notify-send" "$T/only-notify-send/"
reg $cp2 $A9 waiting "permission prompt" 1792000016000
PATH="$T/only-notify-send" /usr/bin/python3 "$HELPER" list --notify >/dev/null
check "notify-send fallback reads no options from the text" test "$(sed -n 3p "$T/notified-notify-send")" = "--"
rm -f "$C/$A9.jsonl" "$N" "$T/notified-notify-send" "$E"
stop
rm -f "$CLAUDE_CONFIG_DIR"/sessions/*.json "$GROK_HOME/active_sessions.json"

# Codex fallback title when the index has no name.
: >"$CODEX_HOME/session_index.jsonl"
check "codex falls back to first prompt" test "$(field bbbbbbbb-0000-0000-0000-000000000001 title)" = "Add dark mode"

# Cache: an unchanged file is served from the cache, a changed one is re-read.
check "cache written" test -s "$XDG_CACHE_HOME/omaisessions/index.json"
f="$C/aaaaaaaa-0000-0000-0000-000000000001.jsonl"
jq -c --arg k "$f" '.files[$k].session.title = "FROM CACHE"' "$XDG_CACHE_HOME/omaisessions/index.json" >"$T/c" && mv "$T/c" "$XDG_CACHE_HOME/omaisessions/index.json"
check "unchanged file uses cache" test "$(field aaaaaaaa-0000-0000-0000-000000000001 title)" = "FROM CACHE"
echo '{"type":"ai-title","aiTitle":"Renamed later"}' >>"$f"
check "changed file is re-read" test "$(field aaaaaaaa-0000-0000-0000-000000000001 title)" = "Renamed later"
echo 'garbage' >"$XDG_CACHE_HOME/omaisessions/index.json"
check "corrupt cache is ignored" test "$(list | jq -r .ok)" = true

# Broken lines never break the listing.
echo '{not json' >>"$f"
check "bad lines are skipped" test "$(field aaaaaaaa-0000-0000-0000-000000000001 title)" = "Renamed later"

# Files in shapes a reader doesn't expect (a new format, a truncated write)
# skip that session, never the whole list.
echo '["cwd"]' >"$C/aaaaaaaa-0000-0000-0000-00000000000a.jsonl"
printf '{"cwd":"/tmp","type":"user","x":%s}\n' "$(python3 -c "print('['*100000 + ']'*100000)")" >"$C/aaaaaaaa-0000-0000-0000-00000000000b.jsonl"
mkdir -p "$G/cccccccc-0000-0000-0000-00000000000a"; echo '[1]' >"$G/cccccccc-0000-0000-0000-00000000000a/summary.json"
echo '{"type":"session_meta","payload":[1]}' >"$X/rollout-2026-10-12T11-00-00-odd.jsonl"
echo '[1]' >"$CLAUDE_CONFIG_DIR/sessions/odd.json"; echo '[1, "x"]' >"$GROK_HOME/active_sessions.json"
out=$(list)
check "odd files never break the list" test "$(jq -r .ok <<<"$out")" = true
check "odd files leave the other sessions" test "$(jq -r '.sessions[] | select(.id == "aaaaaaaa-0000-0000-0000-000000000001") | .title' <<<"$out")" = "Renamed later"
rm -rf "$C/aaaaaaaa-0000-0000-0000-00000000000"[ab].jsonl "$G/cccccccc-0000-0000-0000-00000000000a" "$X/rollout-2026-10-12T11-00-00-odd.jsonl" "$CLAUDE_CONFIG_DIR/sessions/odd.json" "$GROK_HOME/active_sessions.json"

# No history at all.
check "empty home lists nothing" test "$(HOME="$T/empty" XDG_DATA_HOME="$T/empty/.local/share" CLAUDE_CONFIG_DIR="$T/empty/.claude" CODEX_HOME="$T/empty/.codex" GROK_HOME="$T/empty/.grok" CURSOR_CONFIG_DIR="$T/empty/.cursor" "$HELPER" list | jq '.sessions | length')" = 0

# Opening.
out=$("$HELPER" open claude aaaaaaaa-0000-0000-0000-000000000001 "$HOME/Projects/my-app")
sleep 0.3
check "open succeeds" test "$(jq -r .ok <<<"$out")" = true
check "terminal starts in the session folder" test "$(sed -n 1p "$T/launched")" = "$HOME/Projects/my-app"
check "claude resume command" test "$(tail -n +2 "$T/launched" | tr '\n' ' ')" = "--app-id=org.omarchy.agent --dir=$HOME/Projects/my-app -e claude --resume aaaaaaaa-0000-0000-0000-000000000001 "
rm -f "$T/launched"
"$HELPER" open codex bbbbbbbb-0000-0000-0000-000000000001 "$HOME/Projects/app" >/dev/null; sleep 0.3
check "codex resume command" test "$(tail -n 4 "$T/launched" | tr '\n' ' ')" = "-e codex resume bbbbbbbb-0000-0000-0000-000000000001 "
rm -f "$T/launched"
"$HELPER" open grok cccccccc-0000-0000-0000-000000000001 "$HOME/Projects/app" >/dev/null; sleep 0.3
check "grok resume command" test "$(tail -n 4 "$T/launched" | tr '\n' ' ')" = "-e grok --resume cccccccc-0000-0000-0000-000000000001 "
rm -f "$T/launched"
"$HELPER" open cursor dddddddd-0000-0000-0000-000000000001 "$HOME/Projects/app" >/dev/null; sleep 0.3
check "cursor resume command" test "$(tail -n 4 "$T/launched" | tr '\n' ' ')" = "-e cursor-agent --resume dddddddd-0000-0000-0000-000000000001 "
rm -f "$T/launched"
"$HELPER" open opencode ses_titled0000000001 "$HOME/Projects/app" >/dev/null; sleep 0.3
check "opencode resume command" test "$(tail -n 4 "$T/launched" | tr '\n' ' ')" = "-e opencode --session ses_titled0000000001 "
check "open rejects a missing folder" bash -c "! '$HELPER' open claude aaaaaaaa-0000-0000-0000-000000000003 '$HOME/gone' >/dev/null"
check "open uses the session's own folder" bash -c "'$HELPER' open claude aaaaaaaa-0000-0000-0000-000000000001 '$HOME/Projects/app' | jq -e '.error | test(\"not where this session\")' >/dev/null"
check "open rejects an id with a trailing newline" bash -c "! '$HELPER' open claude \$'aaaaaaaa-0000-0000-0000-000000000001\\n' '$HOME/Projects/my-app' >/dev/null"
# A folder name with a newline: xdg-terminal-exec would cut it at the newline.
odd="$HOME/Projects/odd"$'\n'"dir"; mkdir -p "$odd"
python3 -c 'import json,sys; print(json.dumps({"type":"user","cwd":sys.argv[1],"message":{"role":"user","content":"odd folder"}}, separators=(",", ":")))' "$odd" >"$C/aaaaaaaa-0000-0000-0000-00000000000c.jsonl"
out=$("$HELPER" open claude aaaaaaaa-0000-0000-0000-00000000000c "$odd")
check "open refuses folders with control characters" jq -e '.error | test("control characters")' <<<"$out"
rm -rf "$odd" "$C/aaaaaaaa-0000-0000-0000-00000000000c.jsonl"
check "open rejects relative folders" bash -c "! '$HELPER' open claude aaaaaaaa-0000-0000-0000-000000000001 Projects >/dev/null"
check "open rejects option-like ids" bash -c "! '$HELPER' open claude --dangerously-skip-permissions '$HOME' >/dev/null"
check "open rejects unknown agents" bash -c "! '$HELPER' open rm aaaaaaaa-0000-0000-0000-000000000001 '$HOME' >/dev/null"
check "open reports a missing agent" bash -c "PATH='$T/nostub:/usr/bin' '$HELPER' open claude aaaaaaaa-0000-0000-0000-000000000001 '$HOME/Projects/my-app' | jq -e '.error | test(\"not installed\")' >/dev/null"
# Starting a new session: any agent, any existing folder (known or typed).
folders=$(list | jq -c '[.folders[] | .path]')
check "folders are the session folders, last used first" test "$(jq -r '.[0]' <<<"$folders")" = "$(list | jq -r '[.sessions[] | select(.exists)][0].cwd')"
check "folders that no longer exist are left out" bash -c "! jq -e 'index(\"$HOME/gone\")' >/dev/null <<<'$folders'"
check "a folder knows the agent used there last" test "$(list | jq -r --arg p "$HOME/Projects/my-app" '.folders[] | select(.path == $p) | .lastAgent')" = "$(list | jq -r --arg p "$HOME/Projects/my-app" '[.sessions[] | select(.cwd == $p)][0].agent')"
for a in claude:claude codex:codex grok:grok cursor:cursor-agent opencode:opencode; do
  rm -f "$T/launched"
  out=$("$HELPER" new "${a%%:*}" "$HOME/Projects/app"); sleep 0.2
  check "new ${a%%:*} session starts ${a#*:} with no arguments" test "$(tail -n 2 "$T/launched" | tr '\n' ' ')" = "-e ${a#*:} "
done
check "new session opens in that folder" test "$(sed -n 1p "$T/launched")" = "$HOME/Projects/app"
rm -f "$T/launched"; mkdir -p "$HOME/brand-new"
"$HELPER" new claude "~/brand-new" >/dev/null; sleep 0.2
check "new session in a typed ~ folder" grep -qx -- "--dir=$HOME/brand-new" "$T/launched"
check "new rejects a relative folder" bash -c "'$HELPER' new claude Projects | jq -e '.error | test(\"full path\")' >/dev/null"
check "new rejects a missing folder" bash -c "! '$HELPER' new claude '$HOME/nope' >/dev/null"
check "new rejects unknown agents" bash -c "! '$HELPER' new rm '$HOME' >/dev/null"
odd="$HOME/odd"$'\n'"dir"; mkdir -p "$odd"
check "new refuses folders with control characters" jq -e '.error | test("control characters")' <<<"$("$HELPER" new claude "$odd")"
rm -rf "$odd" "$HOME/brand-new"
check "unknown command fails" bash -c "! '$HELPER' frobnicate >/dev/null"

echo
echo "$pass passed, $failed failed"
(( failed == 0 ))
