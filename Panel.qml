import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The omAiSessions popup. BarWidget.qml owns all state and helper processes
// and injects itself as `hostWidget`; this file is only the view plus
// view-local state (tab, search, keyboard cursor).
Panel {
  id: root
  moduleName: "io.github.ramoncardena.omaisessions"
  ipcTarget: moduleName
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot, not this nested panel, so
  // popout coordination and panel switching go through the host.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // Until BarWidget.qml injects itself, bind against an inert stand-in.
  readonly property var host: hostWidget || ({
    agents: [], sessions: [], home: "", loaded: false, busy: false, opening: "", runningCount: 0,
    needsYouCount: 0, statusMessage: "", errorMessage: "", now: 0, summary: "", maxSessions: 200,
    refreshSeconds: 5, notifyNeedsYou: true
  })

  readonly property color foreground: root.barForeground
  readonly property color dim: Qt.darker(root.foreground, 1.4)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  property string tab: "all"
  property int cursorIndex: 0

  // The settings page replaces the list; one row per setting.
  property bool showSettings: false
  property int settingsCursor: 0
  readonly property int settingsCount: 3

  function save(changes) {
    if (root.hostWidget) root.hostWidget.saveSettings(changes)
  }

  // ←→ on the selected setting: seconds by 1, sessions by 20, toggle flips.
  function adjustSetting(dx) {
    if (settingsCursor === 0) save({ refreshSeconds: Math.max(2, Math.min(300, root.host.refreshSeconds + dx)) })
    else if (settingsCursor === 1) save({ notifyNeedsYou: !root.host.notifyNeedsYou })
    else save({ maxSessions: Math.max(20, Math.min(2000, root.host.maxSessions + dx * 20)) })
  }

  // "All", "Running" while anything runs, and one tab per agent that has
  // sessions on this computer.
  readonly property var tabs: {
    var list = [{ value: "all", label: "All" }]
    if (root.host.runningCount > 0) list.push({ value: "running", label: "Running " + root.host.runningCount })
    for (var i = 0; i < root.host.agents.length; i++) {
      var a = root.host.agents[i]
      if (a.count > 0) list.push({ value: a.id, label: a.name })
    }
    return list
  }

  readonly property var visibleSessions: Model.filter(root.host.sessions, root.tab, searchField.text, root.host.maxSessions)

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function moveTab(dx) {
    var i = 0
    for (var k = 0; k < tabs.length; k++) if (tabs[k].value === tab) i = k
    tab = tabs[Math.max(0, Math.min(tabs.length - 1, i + dx))].value
  }

  function moveCursor(dy) {
    if (visibleSessions.length === 0) return
    cursorIndex = Math.max(0, Math.min(visibleSessions.length - 1, cursorIndex + dy))
  }

  function activate() {
    if (showSettings) {
      if (settingsCursor === 1) adjustSetting(1)
      return
    }
    if (visibleSessions.length && root.hostWidget) root.hostWidget.openSession(visibleSessions[cursorIndex])
  }

  // "/" opens the search a beat later: input methods such as fcitx5 deliver
  // the typed character separately from the key press, so focusing at once
  // lets the slash land in the field.
  Timer {
    id: searchFocusTimer
    interval: 120
    onTriggered: searchField.forceActiveFocus()
  }

  function endSearch(clear) {
    if (clear) searchField.text = ""
    keyCatcher.forceActiveFocus()
  }

  // The selected session, by identity: a refresh can reorder the list (a
  // running session moves up as it works), and the cursor follows it.
  property string selectedKey: ""
  function keyOf(s) { return s ? s.agent + "/" + s.id : "" }

  onTabChanged: cursorIndex = 0
  // The Running tab disappears when the last session ends.
  onTabsChanged: if (!tabs.some(function(t) { return t.value === root.tab })) tab = "all"
  onVisibleSessionsChanged: {
    var found = -1
    for (var i = 0; i < visibleSessions.length && found < 0; i++)
      if (keyOf(visibleSessions[i]) === selectedKey) found = i
    cursorIndex = found >= 0 ? found : Math.min(cursorIndex, Math.max(0, visibleSessions.length - 1))
    selectedKey = keyOf(visibleSessions[cursorIndex])
    // A new model resets the scroll position; bring the cursor back into view.
    Qt.callLater(function() { sessionList.positionViewAtIndex(root.cursorIndex, ListView.Contain) })
  }
  onCursorIndexChanged: {
    selectedKey = keyOf(visibleSessions[cursorIndex])
    sessionList.positionViewAtIndex(cursorIndex, ListView.Contain)
  }

  onOpenedChanged: {
    if (opened) {
      if (root.hostWidget) root.hostWidget.refresh()
      if (root.hostWidget) root.hostWidget.errorMessage = ""
      showSettings = false
      // An agent waiting on you is why you opened this: start on it, so
      // Enter switches straight to its window.
      if (root.host.needsYouCount > 0) tab = "running"
      cursorIndex = 0
      sessionList.positionViewAtBeginning()
    } else {
      searchField.text = ""
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus || refreshField.field.activeFocus || maxField.field.activeFocus
      onCloseRequested: {
        if (root.showSettings) root.showSettings = false
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (root.showSettings) {
          if (dx !== 0) root.adjustSetting(dx)
          else root.settingsCursor = Math.max(0, Math.min(root.settingsCount - 1, root.settingsCursor + dy))
        }
        else if (dx !== 0) root.moveTab(dx)
        else root.moveCursor(dy)
      }
      onActivateRequested: root.activate()
      onTextKey: function(text) {
        if (text === "s") { root.showSettings = !root.showSettings; root.settingsCursor = 0 }
        else if (root.showSettings) return
        else if (text === "/") searchFocusTimer.restart()
        else if (text === "r" && root.hostWidget) root.hostWidget.refresh()
        else if (text >= "1" && text <= "9" && Number(text) <= root.tabs.length) root.tab = root.tabs[Number(text) - 1].value
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          title: "AI Sessions"
          meta: root.host.summary
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            SessionIcon {
              size: Style.font.display
              color: root.foreground
            }
          }
          trailingControl: Component {
            Row {
              spacing: Style.space(4)
              PanelActionButton {
                iconText: "󰒓"
                tooltipText: root.showSettings ? "Back to sessions (s)" : "Settings (s)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: { root.showSettings = !root.showSettings; root.settingsCursor = 0 }
              }
              PanelActionButton {
                iconText: "󰑐"
                tooltipText: "Refresh (r)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !root.host.busy
                onClicked: if (root.hostWidget) root.hostWidget.refresh()
              }
            }
          }
        }

        ButtonGroup {
          visible: root.tabs.length > 1 && !root.showSettings
          options: root.tabs
          value: root.tab
          focusable: false
          foreground: root.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.bodySmall
          onChanged: function(value) { root.tab = value }
        }

        TextField {
          id: searchField
          visible: !root.showSettings
          width: parent.width
          placeholderText: "Search titles and folders (/)"
          foreground: root.foreground
          font.family: root.fontFamily
          onAccepted: { root.endSearch(false); root.activate() }
          Keys.onEscapePressed: function(event) { root.endSearch(true); event.accepted = true }
          Keys.onDownPressed: function(event) { root.endSearch(false); event.accepted = true }
        }

        Text {
          visible: text !== ""
          width: parent.width
          textFormat: Text.PlainText
          text: root.host.errorMessage !== "" ? root.host.errorMessage : root.host.statusMessage
          color: root.host.errorMessage !== "" ? Color.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          visible: root.host.loaded && root.visibleSessions.length === 0 && !root.showSettings
          width: parent.width
          textFormat: Text.PlainText
          text: searchField.text.trim() !== "" ? "No sessions match \"" + searchField.text.trim() + "\"."
            : "No sessions yet. Start Claude Code, Codex, Grok, Cursor or OpenCode in any folder and they show up here."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        ListView {
          id: sessionList
          width: parent.width
          height: Math.min(contentHeight, Style.space(440))
          visible: root.visibleSessions.length > 0 && !root.showSettings
          clip: true
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds
          model: root.visibleSessions
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          delegate: SessionRow {
            required property var modelData
            required property int index
            width: sessionList.width
            session: modelData
            rowIndex: index
          }
        }

        Column {
          visible: root.showSettings
          width: parent.width
          spacing: Style.space(8)

          NumberField {
            id: refreshField
            label: "Refresh every (seconds)"
            from: 2
            to: 300
            value: root.host.refreshSeconds
            hasCursor: root.settingsCursor === 0
            foreground: root.foreground
            fontFamily: root.fontFamily
            onModified: function(value) { root.save({ refreshSeconds: value }) }
            onHovered: function(on) { if (on) root.settingsCursor = 0 }
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: "How fast the bar icon notices an agent that needs you. Each refresh takes a fraction of a second."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
          Toggle {
            width: parent.width
            label: "Notify when an agent needs you"
            description: "A desktop notification when a session is blocked on a prompt (Claude Code and Grok report it; Codex and OpenCode approval prompts aren't visible)."
            checked: root.host.notifyNeedsYou
            hasCursor: root.settingsCursor === 1
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.save({ notifyNeedsYou: !root.host.notifyNeedsYou })
            onHovered: function(on) { if (on) root.settingsCursor = 1 }
          }
          NumberField {
            id: maxField
            label: "Sessions to show"
            from: 20
            to: 2000
            stepSize: 20
            value: root.host.maxSessions
            hasCursor: root.settingsCursor === 2
            foreground: root.foreground
            fontFamily: root.fontFamily
            onModified: function(value) { root.save({ maxSessions: value }) }
            onHovered: function(on) { if (on) root.settingsCursor = 2 }
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.showSettings ? "↑↓ select · ←→ change · Enter toggle · s or Esc back"
            : "↑↓ select · ←→ tab · Enter resume or switch · / search · s settings"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  component SessionRow: CursorSurface {
    id: row
    property var session: ({})
    property int rowIndex: 0
    readonly property bool missing: session.exists === false
    readonly property bool waiting: session.running === true && session.state === "waiting"

    hasCursor: root.cursorIndex === rowIndex
    foreground: root.foreground
    opacity: missing ? 0.55 : 1
    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) root.cursorIndex = row.rowIndex
      onClicked: if (root.hostWidget) root.hostWidget.openSession(row.session)
    }

    ColumnLayout {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(1)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)
        Text {
          visible: row.session.running === true
          textFormat: Text.PlainText
          text: "●"
          color: row.waiting ? Color.urgent : row.session.state === "idle" ? root.foreground : Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          Layout.alignment: Qt.AlignVCenter
        }
        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: root.host.opening === row.session.id ? (row.session.running ? "Switching…" : "Resuming…") : row.session.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: (root.tab === "all" || root.tab === "running" ? Model.agentShortName(row.session.agent) + " · " : "")
          + Model.shortPath(row.session.cwd, root.host.home)
          + (row.session.branch ? " (" + row.session.branch + ")" : "")
          + (row.missing ? " · folder missing" : "")
          + " · " + (row.session.running ? Model.stateLabel(row.session, root.host.now) : Model.relativeTime(row.session.updated, root.host.now))
        color: row.missing || row.waiting ? Color.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideMiddle
      }
    }
  }
}
