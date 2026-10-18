import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The omAiSessions popup. BarWidget.qml owns all state and helper processes
// and injects itself as `hostWidget`; this file is only the view plus
// view-local state (view, agent filter, search, keyboard cursor).
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
    refreshSeconds: 5, notifyNeedsYou: true, folders: [], projects: []
  })

  readonly property color foreground: root.barForeground
  readonly property color dim: Qt.darker(root.foreground, 1.4)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  // Sessions or Projects; the agent chips narrow either one.
  property string tab: "sessions"
  property string agentFilter: "all"
  property int cursorIndex: 0

  // The Projects tab lists projects; Enter opens one to list its sessions.
  property string openProject: ""
  property int projectCursor: 0
  readonly property bool listingProjects: tab === "projects" && openProject === ""
  readonly property var visibleProjects: Model.filterProjects(root.host.projects, searchField.text, root.host.home, root.agentFilter)

  function enterProject() {
    if (!visibleProjects.length) return
    openProject = visibleProjects[Math.min(projectCursor, visibleProjects.length - 1)].path
    searchField.text = ""
    cursorIndex = 0
  }
  function leaveProject() {
    openProject = ""
    searchField.text = ""
  }

  // "sessions" (the list), "new" (start a session) or "settings".
  property string view: "sessions"
  readonly property bool showSettings: view === "settings"
  readonly property bool showNew: view === "new"
  function toggleView(name) {
    view = view === name ? "sessions" : name
    settingsCursor = 0
    newCursor = 0
    agentPicked = false
    searchField.text = ""
  }

  // The settings page: one row per setting.
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

  readonly property var viewOptions: [{ value: "sessions", label: "Sessions" }, { value: "projects", label: "Projects" }]

  // "All", then each agent that has sessions on this computer.
  readonly property var agentChips: {
    var list = [{ value: "all", label: "All" }]
    for (var i = 0; i < root.host.agents.length; i++) {
      var a = root.host.agents[i]
      if (a.count > 0) list.push({ value: a.id, label: Model.agentShortName(a.id) })
    }
    return list
  }
  function cycleAgent(step) {
    var i = 0
    for (var k = 0; k < agentChips.length; k++) if (agentChips[k].value === agentFilter) i = k
    agentFilter = agentChips[(i + step + agentChips.length) % agentChips.length].value
  }

  // Active sessions (needs you, your turn, working) first, then the rest.
  readonly property var visibleSessions: Model.filter(root.host.sessions, root.agentFilter, searchField.text,
    root.host.maxSessions, root.tab === "projects" ? root.openProject : "")
  readonly property int activeShown: visibleSessions.filter(function(s) { return s.running }).length

  // ---- New session: a folder (one you've used, or a path you type) and an
  // installed agent, by default the one you used there last.
  property int newCursor: 0
  property string newAgent: ""
  property bool agentPicked: false
  readonly property var installedAgents: root.host.agents
    .filter(function(a) { return a.installed })
    .map(function(a) { return { value: a.id, label: a.name } })
  readonly property var newFolders: Model.folderChoices(root.host.folders, searchField.text, root.host.home)
  readonly property var newFolder: newFolders.length ? newFolders[Math.min(newCursor, newFolders.length - 1)] : null

  function defaultAgent() {
    if (agentPicked && installedAgents.some(function(a) { return a.value === newAgent })) return
    var last = newFolder && newFolder.lastAgent
    newAgent = installedAgents.some(function(a) { return a.value === last }) ? last
      : installedAgents.length ? installedAgents[0].value : ""
  }
  onNewFolderChanged: defaultAgent()
  onInstalledAgentsChanged: defaultAgent()

  function moveAgent(dx) {
    var i = 0
    for (var k = 0; k < installedAgents.length; k++) if (installedAgents[k].value === newAgent) i = k
    if (!installedAgents.length) return
    newAgent = installedAgents[Math.max(0, Math.min(installedAgents.length - 1, i + dx))].value
    agentPicked = true
  }

  function startNew() {
    if (!newFolder || !newAgent || !root.hostWidget) return
    var name = installedAgents.filter(function(a) { return a.value === newAgent })[0].label
    root.hostWidget.newSession(newAgent, name, newFolder.path)
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function moveTab(dx) {
    tab = dx > 0 ? "projects" : "sessions"
  }

  function moveCursor(dy) {
    if (listingProjects) {
      projectCursor = Math.max(0, Math.min(visibleProjects.length - 1, projectCursor + dy))
      return
    }
    if (visibleSessions.length === 0) return
    cursorIndex = Math.max(0, Math.min(visibleSessions.length - 1, cursorIndex + dy))
  }

  function activate() {
    if (showNew) {
      startNew()
      return
    }
    if (showSettings) {
      if (settingsCursor === 1) adjustSetting(1)
      return
    }
    if (listingProjects) {
      enterProject()
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

  onTabChanged: {
    cursorIndex = 0
    projectCursor = 0
    openProject = ""
  }
  onAgentFilterChanged: {
    cursorIndex = 0
    projectCursor = 0
  }
  // An agent's chip goes away when its last session does.
  onAgentChipsChanged: if (!agentChips.some(function(c) { return c.value === root.agentFilter })) agentFilter = "all"
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
      view = "sessions"
      openProject = ""
      // An agent waiting on you is why you opened this: it's first in the
      // sessions list, so Enter switches straight to its window.
      if (root.host.needsYouCount > 0) {
        tab = "sessions"
        agentFilter = "all"
      }
      cursorIndex = 0
      sessionList.positionViewAtBeginning()
    } else {
      searchField.text = ""
    }
  }

  // The list's height: whatever the panel has left below the header and
  // above the footer, so a long list scrolls instead of running off the card.
  readonly property real listRoom: Math.max(Style.space(120),
    panel.fittedContentHeight(100000, Style.space(620)) - panel.verticalContentInset
      - header.height - footer.height - contentColumn.spacing * 2)

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
        if (root.view !== "sessions") root.toggleView(root.view)
        else if (root.openProject !== "") root.leaveProject()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (root.showNew) {
          if (dx !== 0) root.moveAgent(dx)
          else root.newCursor = Math.max(0, Math.min(root.newFolders.length - 1, root.newCursor + dy))
        }
        else if (root.showSettings) {
          if (dx !== 0) root.adjustSetting(dx)
          else root.settingsCursor = Math.max(0, Math.min(root.settingsCount - 1, root.settingsCursor + dy))
        }
        else if (dx !== 0) root.moveTab(dx)
        else root.moveCursor(dy)
      }
      onActivateRequested: root.activate()
      onTextKey: function(text) {
        if (text === "s" && !root.showNew) root.toggleView("settings")
        else if (text === "n" && !root.showSettings) {
          // Inside a project, a new session starts there.
          var here = root.view === "sessions" ? root.openProject : ""
          root.toggleView("new")
          if (here !== "" && root.showNew) searchField.text = Model.shortPath(here, root.host.home)
        }
        else if (text === "/" && !root.showSettings) searchFocusTimer.restart()
        else if (root.view !== "sessions") return
        else if (text === "r" && root.hostWidget) root.hostWidget.refresh()
        else if (text === "a") root.cycleAgent(1)
        else if (text >= "1" && text <= "9" && Number(text) <= root.agentChips.length) root.agentFilter = root.agentChips[Number(text) - 1].value
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(10)

        // Everything above the list, so the list can take what's left.
        Column {
          id: header
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
                  iconText: "󰐕"
                  tooltipText: root.showNew ? "Back to sessions (n)" : "New session (n)"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.toggleView("new")
                }
                PanelActionButton {
                  iconText: "󰒓"
                  tooltipText: root.showSettings ? "Back to sessions (s)" : "Settings (s)"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.toggleView("settings")
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

          Text {
            visible: root.showNew
            textFormat: Text.PlainText
            text: "NEW SESSION"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }

          ButtonGroup {
            visible: root.showNew && root.installedAgents.length > 0
            options: root.installedAgents
            value: root.newAgent
            focusable: false
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onChanged: function(value) { root.newAgent = value; root.agentPicked = true }
          }

          ButtonGroup {
            visible: root.view === "sessions"
            options: root.viewOptions
            value: root.tab
            focusable: false
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            // Projects again, from inside a project, goes back to the list.
          onChanged: function(value) { if (value !== root.tab) root.tab = value; else if (root.openProject !== "") root.leaveProject() }
          }

          // Agent chips: wraps rather than overflowing, whatever is installed.
          Flow {
            visible: root.view === "sessions" && root.agentChips.length > 2
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: root.agentChips
              Chip {
                required property var modelData
                label: modelData.label
                selected: root.agentFilter === modelData.value
                onClicked: root.agentFilter = modelData.value
              }
            }
          }

          TextField {
            id: searchField
            visible: !root.showSettings
            width: parent.width
            placeholderText: root.showNew ? "Filter folders, or type a path like ~/Projects/new (/)"
              : root.listingProjects ? "Search projects (/)" : "Search titles and folders (/)"
            foreground: root.foreground
            font.family: root.fontFamily
            onAccepted: { root.endSearch(false); root.activate() }
            onTextChanged: { root.newCursor = 0; root.projectCursor = 0 }
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
            visible: root.host.loaded && root.visibleSessions.length === 0 && root.view === "sessions" && !root.listingProjects
            width: parent.width
            textFormat: Text.PlainText
            text: searchField.text.trim() !== "" ? "No sessions match \"" + searchField.text.trim() + "\"."
              : "No sessions yet. Start Claude Code, Codex, Grok, Cursor or OpenCode in any folder and they show up here."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          // The open project: its path, and the way back (as Esc).
          Item {
            visible: root.view === "sessions" && root.openProject !== ""
            width: parent.width
            height: backLabel.implicitHeight
            // A cap-height chevron: "‹" sits on the x-height, below the caps.
            Text {
              id: backArrow
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "\uF053"
              color: backLabel.color
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              id: backLabel
              anchors.left: backArrow.right
              anchors.leftMargin: Style.space(4)
              anchors.right: parent.right
              textFormat: Text.PlainText
              text: "PROJECTS · " + Model.shortPath(root.openProject, root.host.home)
              color: backArea.containsMouse ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              elide: Text.ElideMiddle
            }
            MouseArea {
              id: backArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.leaveProject()
            }
          }
        }

        ListView {
          id: projectList
          width: parent.width
          height: Math.min(contentHeight, root.listRoom)
          visible: root.view === "sessions" && root.listingProjects && root.visibleProjects.length > 0
          clip: true
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds
          model: root.visibleProjects
          currentIndex: root.projectCursor
          onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          delegate: ProjectRow {
            required property var modelData
            required property int index
            width: projectList.width
            project: modelData
            rowIndex: index
          }
        }

        Text {
          visible: root.view === "sessions" && root.listingProjects && root.visibleProjects.length === 0
          width: parent.width
          textFormat: Text.PlainText
          text: "No projects match \"" + searchField.text.trim() + "\"."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        ListView {
          id: sessionList
          width: parent.width
          height: Math.min(contentHeight, root.listRoom)
          visible: root.visibleSessions.length > 0 && root.view === "sessions" && !root.listingProjects
          clip: true
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds
          model: root.visibleSessions
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          // ACTIVE above the running sessions and RECENT above the rest, when
          // anything is running.
          delegate: Column {
            id: entry
            required property var modelData
            required property int index
            readonly property string heading: root.tab !== "sessions" || root.activeShown === 0 ? ""
              : index === 0 ? (modelData.running ? "ACTIVE" : "RECENT")
              : root.visibleSessions[index - 1].running && !modelData.running ? "RECENT" : ""
            width: sessionList.width
            spacing: Style.space(2)
            Text {
              visible: entry.heading !== ""
              topPadding: entry.index === 0 ? 0 : Style.space(8)
              leftPadding: Style.space(10)
              textFormat: Text.PlainText
              text: entry.heading
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            SessionRow {
              width: parent.width
              session: entry.modelData
              rowIndex: entry.index
            }
          }
        }

        Text {
          visible: root.showNew && root.newFolders.length === 0
          width: parent.width
          textFormat: Text.PlainText
          text: root.installedAgents.length === 0 ? "No agent is installed." : "No folders match. Type a full path, like ~/Projects/app."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        ListView {
          id: folderList
          width: parent.width
          height: Math.min(contentHeight, root.listRoom)
          visible: root.showNew && root.newFolders.length > 0
          clip: true
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds
          model: root.newFolders
          currentIndex: root.newCursor
          onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          delegate: FolderRow {
            required property var modelData
            required property int index
            width: folderList.width
            folder: modelData
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
          id: footer
          width: parent.width
          textFormat: Text.PlainText
          text: root.showSettings ? "↑↓ select · ←→ change · Enter toggle · s or Esc back"
            : root.showNew ? "↑↓ folder · ←→ agent · Enter start · / filter or type a path · Esc back"
            : root.listingProjects ? "↑↓ select · Enter open · ←→ view · a agent · / search · n new · s settings"
            : root.openProject !== "" ? "↑↓ select · Enter resume or switch · a agent · n new here · Esc back"
            : "↑↓ select · Enter resume or switch · ←→ view · a agent · / search · n new · s settings"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  component Chip: Rectangle {
    id: chip
    property string label: ""
    property bool selected: false
    signal clicked()

    implicitWidth: chipText.implicitWidth + Style.space(18)
    implicitHeight: chipText.implicitHeight + Style.space(8)
    radius: Style.cornerRadius > 0 ? height / 2 : 0
    color: selected ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14) : "transparent"
    border.width: 1
    border.color: selected ? Color.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, chipMouse.containsMouse ? 0.5 : 0.22)

    Text {
      id: chipText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: chip.label
      color: chip.selected ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }

  component ProjectRow: CursorSurface {
    id: prow
    property var project: ({})
    property int rowIndex: 0
    readonly property bool needsYou: project.needsYou > 0

    hasCursor: root.projectCursor === rowIndex
    foreground: root.foreground
    opacity: project.exists === false ? 0.55 : 1
    implicitHeight: prowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) root.projectCursor = prow.rowIndex
      onClicked: { root.projectCursor = prow.rowIndex; root.enterProject() }
    }

    ColumnLayout {
      id: prowContent
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
          visible: prow.project.running > 0
          textFormat: Text.PlainText
          text: "●"
          color: prow.needsYou ? Color.urgent : Color.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          Layout.alignment: Qt.AlignVCenter
        }
        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: Model.projectName(prow.project, root.host.home)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: Model.shortPath(prow.project.path, root.host.home)
          + " · " + Model.plural(prow.project.sessions, "session", "sessions")
          + " · " + Model.agentList(prow.project.agents)
          + (prow.needsYou ? " · " + prow.project.needsYou + (prow.project.needsYou === 1 ? " needs you" : " need you")
            : prow.project.running > 0 ? " · " + prow.project.running + " running"
            : " · " + Model.relativeTime(prow.project.updated, root.host.now))
        color: prow.needsYou ? Color.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideMiddle
      }
    }
  }

  component FolderRow: CursorSurface {
    id: frow
    property var folder: ({})
    property int rowIndex: 0

    hasCursor: root.newCursor === rowIndex
    foreground: root.foreground
    implicitHeight: frowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) root.newCursor = frow.rowIndex
      onClicked: { root.newCursor = frow.rowIndex; root.startNew() }
    }

    ColumnLayout {
      id: frowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(1)

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: Model.shortPath(frow.folder.path, root.host.home)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideMiddle
      }
      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: frow.folder.typed ? "the folder you typed"
          : Model.plural(frow.folder.sessions, "session", "sessions") + " · last " + Model.agentShortName(frow.folder.lastAgent)
            + " · " + Model.relativeTime(frow.folder.updated, root.host.now)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
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
        text: (root.agentFilter === "all" ? Model.agentShortName(row.session.agent) + " · " : "")
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
