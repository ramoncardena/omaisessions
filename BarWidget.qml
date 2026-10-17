import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// omAiSessions bar widget: owns the session list and the helper processes,
// draws the bar icon, and hosts Panel.qml. Reading agent history and
// launching terminals happens in bin/omaisessions, which prints one JSON
// object per command.
//
// The bar mounts one instance per monitor. Listing is cheap (the helper
// caches by file mtime), so each instance refreshes on its own: often while
// the panel is open, rarely otherwise, to keep the running state current.
BarWidget {
  id: root
  moduleName: "io.github.ramoncardena.omaisessions"

  readonly property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("bin/omaisessions")).replace(/^file:\/\//, ""))

  readonly property int maxSessions: Math.max(20, Number(setting("maxSessions", 200)) || 200)

  property var agents: []
  property var sessions: []
  property string home: ""
  property bool loaded: false
  property string statusMessage: ""
  property string errorMessage: ""
  property double now: Date.now()
  property string opening: ""       // session id being launched
  property string listKey: ""       // last list as JSON, to skip no-op updates

  readonly property bool busy: listProc.running || openProc.running
  readonly property int runningCount: sessions.filter(function(s) { return s.running }).length
  readonly property string summary: !loaded ? "LOADING"
    : sessions.length === 0 ? "NO SESSIONS"
    : sessions.length + (sessions.length === 1 ? " SESSION" : " SESSIONS")
      + (runningCount > 0 ? " · " + runningCount + " RUNNING" : "")

  function parse(text) {
    try { return JSON.parse(String(text || "")) } catch (e) { return null }
  }

  function refresh() {
    now = Date.now()
    if (listProc.running) return
    listProc.command = [helperPath, "list"]
    listProc.running = true
  }

  function openSession(session) {
    if (!session || openProc.running) return
    errorMessage = ""
    statusMessage = (session.running ? "Switching to " : "Resuming ") + session.title + "…"
    opening = session.id
    openProc.command = [helperPath, "open", session.agent, session.id, session.cwd]
    openProc.running = true
  }

  Component.onCompleted: Qt.callLater(refresh)

  Timer {
    interval: root.opened ? 5000 : 60000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: listProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var result = root.parse(text)
        if (result && result.ok) {
          // Unchanged lists are dropped, so the periodic refresh doesn't
          // rebuild the panel's list under the cursor.
          var key = JSON.stringify([result.agents, result.sessions])
          if (key !== root.listKey) {
            root.listKey = key
            root.agents = result.agents || []
            root.sessions = result.sessions || []
          }
          root.home = result.home || ""
          root.errorMessage = ""
        } else {
          root.errorMessage = result && result.error ? result.error : "Could not read agent sessions"
        }
        root.loaded = true
      }
    }
  }

  Process {
    id: openProc
    stdout: StdioCollector { id: openOut; waitForEnd: true }
    onExited: function(exitCode) {
      var result = root.parse(openOut.text)
      root.opening = ""
      root.statusMessage = ""
      if (exitCode === 0 && result && result.ok) {
        root.close()
      } else {
        root.errorMessage = result && result.error ? result.error : "Could not resume (exit " + exitCode + ")"
      }
    }
  }

  // ------------------------------------------------------- panel contract
  // Shape required by shell.summon/hide/toggle routing and the bar's popout
  // coordinator (see the built-in clock): open/close/opened on this root.

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // omarchy-shell io.github.ramoncardena.omaisessions <method>, e.g. bind a
  // key to `toggle`.
  IpcHandler {
    target: root.moduleName

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  // ---------------------------------------------------------------- bar icon

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰚩"
    tooltipText: !root.loaded ? "AI sessions"
      : root.runningCount > 0 ? "AI sessions: " + root.runningCount + " running"
      : "AI sessions: " + root.sessions.length
    active: root.runningCount > 0
    onPressed: function(mouseButton) { root.toggle() }
  }
}
