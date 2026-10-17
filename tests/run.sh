#!/bin/bash

# Tests for bin/omaisessions against fixture histories in a temp dir.
# Never touches real agent history: HOME, CLAUDE_CONFIG_DIR, CODEX_HOME and
# XDG_CACHE_HOME all point into the temp dir, and the terminal is stubbed.

set -uo pipefail

HELPER="$(cd "$(dirname "$0")/.." && pwd)/bin/omaisessions"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

export HOME="$T/home" XDG_CACHE_HOME="$T/cache"
export CLAUDE_CONFIG_DIR="$HOME/.claude" CODEX_HOME="$HOME/.codex"
mkdir -p "$HOME/Projects/app" "$HOME/Projects/my-app" "$T/stub"

# Stub terminal and agents: record the command line, launch nothing.
cat >"$T/stub/xdg-terminal-exec" <<STUB
#!/bin/bash
printf '%s\n' "\$PWD" "\$@" >"$T/launched"
STUB
printf '#!/bin/bash\n' >"$T/stub/claude"; printf '#!/bin/bash\n' >"$T/stub/codex"
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

out=$(list)
check "list succeeds" test "$(jq -r .ok <<<"$out")" = true
check "finds resumable sessions only" test "$(jq '.sessions | length' <<<"$out")" = 4
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
check "sorted newest first" test "$(jq -r '.sessions[-1].id' <<<"$out")" = aaaaaaaa-0000-0000-0000-000000000003
check "agent counts" test "$(jq -c '[.agents[] | [.id, .count, .installed]]' <<<"$out")" = '[["claude",3,true],["codex",1,true]]'
check "limit" test "$("$HELPER" list --limit 2 | jq '.sessions | length')" = 2

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

# No history at all.
check "empty home lists nothing" test "$(HOME="$T/empty" CLAUDE_CONFIG_DIR="$T/empty/.claude" CODEX_HOME="$T/empty/.codex" "$HELPER" list | jq '.sessions | length')" = 0

# Opening.
out=$("$HELPER" open claude aaaaaaaa-0000-0000-0000-000000000001 "$HOME/Projects/my-app")
sleep 0.3
check "open succeeds" test "$(jq -r .ok <<<"$out")" = true
check "terminal starts in the session folder" test "$(sed -n 1p "$T/launched")" = "$HOME/Projects/my-app"
check "claude resume command" test "$(tail -n +2 "$T/launched" | tr '\n' ' ')" = "--app-id=org.omarchy.agent --dir=$HOME/Projects/my-app -e claude --resume aaaaaaaa-0000-0000-0000-000000000001 "
rm -f "$T/launched"
"$HELPER" open codex bbbbbbbb-0000-0000-0000-000000000001 "$HOME/Projects/app" >/dev/null; sleep 0.3
check "codex resume command" test "$(tail -n 4 "$T/launched" | tr '\n' ' ')" = "-e codex resume bbbbbbbb-0000-0000-0000-000000000001 "
check "open rejects a missing folder" bash -c "! '$HELPER' open claude aaaaaaaa-0000-0000-0000-000000000003 '$HOME/gone' >/dev/null"
check "open rejects relative folders" bash -c "! '$HELPER' open claude aaaaaaaa-0000-0000-0000-000000000001 Projects >/dev/null"
check "open rejects option-like ids" bash -c "! '$HELPER' open claude --dangerously-skip-permissions '$HOME' >/dev/null"
check "open rejects unknown agents" bash -c "! '$HELPER' open rm aaaaaaaa-0000-0000-0000-000000000001 '$HOME' >/dev/null"
check "open reports a missing agent" bash -c "PATH='$T/nostub:/usr/bin' '$HELPER' open claude aaaaaaaa-0000-0000-0000-000000000001 '$HOME' | jq -e '.error | test(\"not installed\")' >/dev/null"
check "unknown command fails" bash -c "! '$HELPER' frobnicate >/dev/null"

echo
echo "$pass passed, $failed failed"
(( failed == 0 ))
