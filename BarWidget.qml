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
// caches by file mtime), so each instance refreshes on its own, every few
// seconds, to keep what's running (and what needs you) current. The helper
// makes sure only one of them sends a given notification.
BarWidget {
  id: root
  moduleName: "io.github.ramoncardena.omaisessions"

  readonly property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("bin/omaisessions")).replace(/^file:\/\//, ""))

  readonly property int maxSessions: Math.max(20, Number(setting("maxSessions", 200)) || 200)
  readonly property int refreshSeconds: Math.max(2, Math.min(300, Number(setting("refreshSeconds", 5)) || 5))
  readonly property bool notifyNeedsYou: setting("notifyNeedsYou", true) !== false

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
  readonly property int needsYouCount: sessions.filter(function(s) { return s.running && s.state === "waiting" }).length
  readonly property string summary: !loaded ? "LOADING"
    : sessions.length === 0 ? "NO SESSIONS"
    : sessions.length + (sessions.length === 1 ? " SESSION" : " SESSIONS")
      + (runningCount > 0 ? " · " + runningCount + " RUNNING" : "")
      + (needsYouCount > 0 ? " · " + needsYouCount + (needsYouCount === 1 ? " NEEDS YOU" : " NEED YOU") : "")

  function parse(text) {
    try { return JSON.parse(String(text || "")) } catch (e) { return null }
  }

  function refresh() {
    now = Date.now()
    if (listProc.running) return
    listProc.command = notifyNeedsYou ? [helperPath, "list", "--notify"] : [helperPath, "list"]
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

  // Writes this widget's settings into the bar config (shell.json); they come
  // back through `settings`, so every monitor's instance picks them up.
  function saveSettings(changes) {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") {
      errorMessage = "Settings can't be saved from here"
      return false
    }
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    for (var change in changes) entry[change] = changes[change]
    if (!root.bar.shell.updateEntryInline(root.moduleName, entry)) {
      errorMessage = "Could not save settings to shell.json"
      return false
    }
    errorMessage = ""
    return true
  }

  Component.onCompleted: Qt.callLater(refresh)

  Timer {
    interval: root.refreshSeconds * 1000
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
    // The plugin's own mark (SessionIcon.qml), in the bar's color.
    iconComponent: Component {
      SessionIcon {
        color: button.active && button.useActiveColor ? button.activeColor : button.foreground
      }
    }
    tooltipText: !root.loaded ? "AI sessions"
      : root.needsYouCount > 0 ? "AI sessions: " + root.needsYouCount + (root.needsYouCount === 1 ? " needs you" : " need you")
      : root.runningCount > 0 ? "AI sessions: " + root.runningCount + " running"
      : "AI sessions: " + root.sessions.length
    // Accent while agents run; the bar's urgent color while one needs you.
    active: root.runningCount > 0
    activeColor: root.needsYouCount > 0 ? (root.bar ? root.bar.urgent : Color.urgent) : Color.accent
    onPressed: function(mouseButton) { root.toggle() }
  }
}
