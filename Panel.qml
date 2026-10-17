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
    agents: [], sessions: [], home: "", loaded: false, busy: false, opening: "",
    statusMessage: "", errorMessage: "", now: 0, summary: "", maxSessions: 200
  })

  readonly property color foreground: root.barForeground
  readonly property color dim: Qt.darker(root.foreground, 1.4)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  property string tab: "all"
  property int cursorIndex: 0

  // "All" plus one tab per agent that has sessions on this computer.
  readonly property var tabs: {
    var list = [{ value: "all", label: "All" }]
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

  onTabChanged: cursorIndex = 0
  onVisibleSessionsChanged: cursorIndex = Math.min(cursorIndex, Math.max(0, visibleSessions.length - 1))
  onCursorIndexChanged: sessionList.positionViewAtIndex(cursorIndex, ListView.Contain)

  onOpenedChanged: {
    if (opened) {
      if (root.hostWidget) root.hostWidget.refresh()
      if (root.hostWidget) root.hostWidget.errorMessage = ""
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
      blocked: searchField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveTab(dx)
        else root.moveCursor(dy)
      }
      onActivateRequested: root.activate()
      onTextKey: function(text) {
        if (text === "/") searchFocusTimer.restart()
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
            Text {
              text: "󰚩"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
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

        ButtonGroup {
          visible: root.tabs.length > 1
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
          visible: root.host.loaded && root.visibleSessions.length === 0
          width: parent.width
          text: searchField.text.trim() !== "" ? "No sessions match \"" + searchField.text.trim() + "\"."
            : "No sessions yet. Start Claude Code or Codex in any folder and they show up here."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        ListView {
          id: sessionList
          width: parent.width
          height: Math.min(contentHeight, Style.space(440))
          visible: root.visibleSessions.length > 0
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

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "↑↓ select · ←→ agent · Enter resume · / search"
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

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: root.host.opening === row.session.id ? "Resuming…" : row.session.title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: (root.tab === "all" ? Model.agentShortName(row.session.agent) + " · " : "")
          + Model.shortPath(row.session.cwd, root.host.home)
          + (row.session.branch ? " (" + row.session.branch + ")" : "")
          + (row.missing ? " · folder missing" : "")
          + " · " + Model.relativeTime(row.session.updated, root.host.now)
        color: row.missing ? Color.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideMiddle
      }
    }
  }
}
