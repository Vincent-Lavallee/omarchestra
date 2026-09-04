import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "SettingsModel.js" as Data

// Windowed system settings app. The data model (sections, rows, option lists)
// lives in SettingsModel.js; the per-section UI blocks live in their own
// *.qml files (AnimationsBlock, PowerBlock, NotificationsBlock, …). This file
// owns the shared state, the shell commands, the sidebar, and the right-pane
// scaffolding. Blocks receive `host: root` and read state / call helpers back
// through it.
Item {
  id: root

  // ---- plugin lifecycle ---------------------------------------------------
  property bool closingFromHost: false

  function open(payloadJson) {
    closingFromHost = false
    window.visible = true
    searchText = ""
    applyOpenSection(payloadJson)
    animStateFile.reload()
    powerStateProc.running = true
    powerProfilesProc.running = true
    defaultsProc.running = true
    dndProc.running = true
    loadAccounts()
    Qt.callLater(function() {
      if (searchField) searchField.forceActiveFocus()
    })
  }

  // Optional deep-link: summon with {"section": "power"} to open on that
  // section (also used to capture section-specific screenshots).
  function applyOpenSection(payloadJson) {
    var section = ""
    try {
      var p = payloadJson ? JSON.parse(payloadJson) : null
      if (p && typeof p.section === "string") section = p.section
    } catch (e) { /* ignore */ }
    if (!section) return
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].id === section) { currentSection = section; return }
    }
  }

  function close() {
    closingFromHost = true
    window.visible = false
    closingFromHost = false
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else window.visible = false
  }

  // ---- host injection -----------------------------------------------------
  property var shell: null
  property var manifest: null

  // Fixed plugin id — the shell registers this plugin under this id, and the
  // bar/launcher reference it for summon/toggle/hide.
  readonly property string pluginId: "io.github.vincent-lavallee.omarchestra"

  // ---- theme --------------------------------------------------------------
  readonly property color foreground: Color.foreground
  readonly property color background: Color.background
  readonly property color accent: Color.accent
  readonly property string fontFamily: Style.font.family

  // ---- model --------------------------------------------------------------
  property string currentSection: "appearance"
  property string searchText: ""

  readonly property var sectionGroups: Data.sectionGroups
  readonly property var sections: Data.sections
  readonly property var rows: Data.rows

  readonly property var animOptions: Data.animOptions
  readonly property var lidActionOptions: Data.lidActionOptions
  readonly property var lockTimeoutOptions: Data.lockTimeoutOptions
  readonly property var sleepTimeoutOptions: Data.sleepTimeoutOptions
  readonly property var muteOptions: Data.muteOptions
  readonly property var sudoOptions: Data.sudoOptions
  readonly property var browserOptions: Data.browserOptions
  readonly property var terminalOptions: Data.terminalOptions
  readonly property var editorOptions: Data.editorOptions
  readonly property var agentOptions: Data.agentOptions

  function sectionLabel(id) {
    for (var i = 0; i < sections.length; i++)
      if (sections[i].id === id) return sections[i].label
    return id
  }

  function sectionKeywords(id) {
    for (var i = 0; i < sections.length; i++)
      if (sections[i].id === id) return sections[i].keywords || []
    return []
  }

  // Sections belonging to a sidebar group, in declaration order.
  function sectionsInGroup(group) {
    var out = []
    for (var i = 0; i < sections.length; i++)
      if (sections[i].group === group) out.push(sections[i])
    return out
  }

  function rowHaystack(r) {
    var parts = [r.label, r.description || "", sectionLabel(r.section)]
    parts = parts.concat(sectionKeywords(r.section))
    if (r.keywords) parts = parts.concat(r.keywords)
    return parts.join(" ").toLowerCase()
  }

  // All rows whose text matches the query, across every section.
  function filteredRows() {
    var q = searchText.trim().toLowerCase()
    if (q === "") return []
    var out = []
    for (var i = 0; i < rows.length; i++) {
      if (rowHaystack(rows[i]).indexOf(q) !== -1) out.push(rows[i])
    }
    return out
  }

  // Rows of the currently-selected section (right pane).
  function sectionRows() {
    var out = []
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].section === currentSection) out.push(rows[i])
    }
    return out
  }

  function runRow(row) {
    if (!row || !row.command) return
    Util.execDetached(row.command)
  }

  function toggleSearch() {
    if (searchField.activeFocus) searchField.focus = false
    else { searchField.forceActiveFocus(); searchField.selectAll() }
  }

  function pluginDir() {
    if (manifest && typeof manifest.__sourceDir === "string" && manifest.__sourceDir)
      return manifest.__sourceDir
    return Quickshell.env("HOME") + "/.config/omarchy/plugins/" + pluginId
  }

  function runAccountScript(name) {
    var p = pluginDir() + "/" + name
    Util.execDetached("omarchy-launch-floating-terminal-with-presentation 'bash \"" + p + "\"'")
  }

  // ---- workspace animation state -----------------------------------------
  property string animWorkspaceStyle: "none"   // none | slide | slidevert | slidefade | fade

  // ---- sizing -------------------------------------------------------------
  readonly property int dropdownRowHeight: Style.space(36)   // taller than the kit's 28px control height

  // ---- power & sleep state ------------------------------------------------
  property string lidBatteryAction: "suspend"   // ignore | lock | suspend | hibernate | poweroff
  property string lidAcAction: "suspend"        // ignore | lock | suspend | hibernate | poweroff
  property string lockTimeout: "never"          // "never" | seconds
  property string sleepTimeout: "never"         // "never" | minutes
  property string powerProfileAc: "balanced"
  property string powerProfileBattery: "balanced"
  property var availableProfiles: ["power-saver", "balanced", "performance"]
  property string sudoMinutes: "60"             // passwordless-sudo duration in minutes

  // ---- notifications state ------------------------------------------------
  property bool dnd: false
  property int muteSeconds: 0                   // 0 = no scheduled mute
  property int muteRemainingSeconds: 0
  property real muteEndsAtEpochMs: 0

  // ---- defaults state -----------------------------------------------------
  property string defaultBrowser: ""
  property string defaultTerminal: ""
  property string defaultEditor: ""
  property string defaultAgent: ""
  property string currentShell: "/bin/bash"

  // ---- shell prompt state -------------------------------------------------
  property bool shellPromptOpen: false
  property string pendingShellPath: "/usr/bin/zsh"

  // ---- accounts state -----------------------------------------------------
  property var accounts: []

  function currentUser() {
    return Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
  }

  function loadAccounts() {
    accountsProc.running = true
  }

  function parseAccounts(raw) {
    var list = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var p = lines[i].split("\t")
      if (p.length >= 3 && p[0])
        list.push({ user: p[0], uid: parseInt(p[1], 10) || 0, home: p[2], isCurrent: p[0] === currentUser() })
    }
    accounts = list
  }

  // ---- power --------------------------------------------------------------
  function savePowerState() {
    writeFile("$HOME/.local/state/omarchy/settings/power.json", JSON.stringify({
      lidBatteryAction: lidBatteryAction, lidAcAction: lidAcAction,
      lockTimeout: lockTimeout, sleepTimeout: sleepTimeout
    }))
  }

  function applyPowerSettings() {
    savePowerState()
    // The privileged helper lives at a root-owned, non-user-writable path so
    // pkexec never executes a script from the user-writable plugin checkout
    // (where it could be swapped after authorization). Install it once
    // (guarded by the existence check), then run it with the validated
    // lid/sleep values.
    var helper = "/usr/local/lib/omarchestra/set-power-settings.sh"
    Util.execDetached("pkexec bash -c '" +
      "[ -x " + helper + " ] || install -D -m 0755 -o root -g root \"" + pluginDir() + "/bin/set-power-settings.sh\" " + helper + "; " +
      helper + " " + lidBatteryAction + " " + lidAcAction + " " + sleepTimeout + "'")
    // Lid-close lock is a Hyprland switch binding, separate from logind, so
    // "Do nothing" must also override it (see bin/set-lid-close.sh).
    Util.execDetached("bash \"" + pluginDir() + "/bin/set-lid-close.sh\" " + lidBatteryAction + " " + lidAcAction)
  }

  function setIdleLock() {
    savePowerState()
    Util.execDetached("bash \"" + pluginDir() + "/bin/set-idle-lock.sh\" " + lockTimeout)
  }

  function setPowerProfile(source, profile) {
    if (source === "ac") powerProfileAc = profile
    else powerProfileBattery = profile
    Util.execDetached("omarchy powerprofiles set " + source + " " + profile)
  }

  function powerProfileOptions() {
    var labels = { "power-saver": "Power saver", "balanced": "Balanced", "performance": "Performance" }
    var out = []
    for (var i = 0; i < availableProfiles.length; i++) {
      var p = availableProfiles[i]
      out.push({ value: p, label: labels[p] || p })
    }
    return out
  }

  function parsePowerState(raw) {
    var p = String(raw || "").split("\t")
    if (p.length < 5) return
    if (p[0]) lidBatteryAction = p[0].trim()
    if (p[1]) lidAcAction = p[1].trim()
    lockTimeout = nearestLockOption(parseInt(p[4], 10) || 300)
    var idleAction = p[2].trim()
    if (idleAction === "ignore" || idleAction === "none") {
      sleepTimeout = "never"
    } else {
      var mins = parseInt(p[3], 10) || 0
      sleepTimeout = mins > 0 ? String(mins) : "30"
    }
  }

  // Snap an arbitrary idle.lock value (seconds) to the nearest dropdown option.
  function nearestLockOption(seconds) {
    var opts = [["never", 86400], ["60", 60], ["300", 300], ["600", 600], ["1800", 1800]]
    var best = "never"
    var bestDiff = 1e18
    for (var i = 0; i < opts.length; i++) {
      var d = Math.abs(opts[i][1] - seconds)
      if (d < bestDiff) { bestDiff = d; best = opts[i][0] }
    }
    return best
  }

  function parsePowerProfiles(raw) {
    var p = String(raw || "").split("\t")
    if (p.length < 3) return
    if (p[0]) powerProfileAc = p[0].trim()
    if (p[1]) powerProfileBattery = p[1].trim()
    var avail = p[2].split(",")
    var list = []
    for (var i = 0; i < avail.length; i++)
      if (avail[i].trim()) list.push(avail[i].trim())
    if (list.length > 0) availableProfiles = list
  }

  // ---- notifications ------------------------------------------------------
  function setDnd(v) {
    dnd = v
    Util.execDetached("omarchy-shell -q notifications setDnd " + (v ? "on" : "off"))
  }

  function toggleDnd() {
    setDnd(!dnd)
  }

  function muteFor(minutes) {
    setDnd(true)
    muteSeconds = minutes * 60
    muteRemainingSeconds = muteSeconds
    muteEndsAtEpochMs = Date.now() + muteSeconds * 1000
    muteTimer.restart()
  }

  function unmuteNow() {
    muteTimer.stop()
    muteSeconds = 0
    muteRemainingSeconds = 0
    setDnd(false)
  }

  function tickMute() {
    var remaining = Math.max(0, Math.ceil((muteEndsAtEpochMs - Date.now()) / 1000))
    muteRemainingSeconds = remaining
    if (remaining <= 0) unmuteNow()
  }

  function muteRemainingLabel() {
    var s = muteRemainingSeconds
    if (s <= 0) return ""
    if (s < 60) return s + "s"
    var m = Math.round(s / 60)
    if (m < 60) return m + " min"
    var h = Math.floor(m / 60)
    var mm = m % 60
    return mm > 0 ? h + "h " + mm + "m" : h + "h"
  }

  function parseDnd(raw) {
    dnd = String(raw || "").trim().toLowerCase() === "on"
  }

  // ---- defaults -----------------------------------------------------------
  function setDefaultBrowser(v) { defaultBrowser = v; Util.execDetached("omarchy-default-browser " + v) }
  function setDefaultTerminal(v) { defaultTerminal = v; Util.execDetached("omarchy-default-terminal " + v) }
  function setDefaultEditor(v) { defaultEditor = v; Util.execDetached("omarchy-default-editor " + v) }
  function setDefaultAgent(v) { defaultAgent = v; writeFile("$HOME/.config/omarchy/defaults/agent", v) }

  function parseDefaults(raw) {
    var p = String(raw || "").split("\t")
    if (p.length < 5) return
    defaultBrowser = p[0].trim()
    defaultTerminal = p[1].trim()
    defaultEditor = p[2].trim()
    defaultAgent = p[3].trim()
    currentShell = p[4].trim() || "/bin/bash"
  }

  function shellOptions() {
    var out = [
      { value: "/bin/bash", label: "Bash" },
      { value: "/usr/bin/zsh", label: "Zsh" }
    ]
    var cur = currentShell
    if (cur && cur !== "/bin/bash" && cur !== "/usr/bin/zsh")
      out.push({ value: cur, label: cur.split("/").pop() })
    return out
  }

  // Picking Zsh offers to install Oh My Zsh first; the confirm/cancel handlers
  // below decide whether the install script runs before `chsh`.
  function setDefaultShell(shellPath) {
    var bin = shellPath.split("/").pop()
    if (bin === "zsh") {
      pendingShellPath = shellPath
      shellPromptOpen = true
    } else {
      applyDefaultShell(shellPath, false)
    }
  }

  function confirmShellPrompt() {
    shellPromptOpen = false
    applyDefaultShell(pendingShellPath, true)
  }

  function cancelShellPrompt() {
    shellPromptOpen = false
    applyDefaultShell(pendingShellPath, false)
  }

  function applyDefaultShell(shellPath, installOmz) {
    var bin = shellPath.split("/").pop()
    var pre = ""
    if (installOmz) pre = "bash \"" + pluginDir() + "/bin/install-oh-my-zsh.sh\"; "
    else if (bin === "zsh") pre = "command -v zsh >/dev/null || sudo pacman -S --noconfirm zsh; "
    else if (bin === "fish") pre = "command -v fish >/dev/null || sudo pacman -S --noconfirm fish; "
    Util.execDetached("omarchy-launch-floating-terminal-with-presentation '" + pre + "chsh -s " + shellPath + "'")
  }

  // ---- security -----------------------------------------------------------
  function runRemoveAccount(user) {
    Util.execDetached("omarchy-launch-floating-terminal-with-presentation 'bash \"" + pluginDir() + "/bin/remove-account.sh\" " + user + "'")
  }

  function enablePasswordlessSudo() {
    Util.execDetached("omarchy-launch-floating-terminal-with-presentation 'omarchy-sudo-passwordless " + sudoMinutes + "'")
  }

  // Rebuild the Hyprland animation toggle file: only the workspace-switch
  // animation is customized. "none" removes the override to restore Omarchy's
  // default (workspace animation off).
  function applyAnimations() {
    if (animWorkspaceStyle === "none") {
      Util.execDetached("rm -f \"$HOME/.local/state/omarchy/toggles/hypr/animations.lua\"")
    } else {
      var lua = "-- Generated by omarchestra. Delete to restore Omarchy defaults.\n" +
        'hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOutQuint", style = "' + animWorkspaceStyle + '" })\n'
      writeFile("$HOME/.local/state/omarchy/toggles/hypr/animations.lua", lua)
    }
    writeFile("$HOME/.local/state/omarchy/settings/animations.json", JSON.stringify({ workspaceStyle: animWorkspaceStyle }))
  }

  function writeFile(path, content) {
    Util.execDetached("mkdir -p \"$(dirname \"" + path + "\")\" && cat > \"" + path + "\" <<'OMARCHY_SETTINGS_EOF'\n" + content + "\nOMARCHY_SETTINGS_EOF\n")
  }

  function loadAnimState(raw) {
    try {
      var o = JSON.parse(String(raw || ""))
      if (o && typeof o.workspaceStyle === "string") animWorkspaceStyle = o.workspaceStyle
    } catch (e) { /* ignore */ }
  }

  property FileView animStateFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/animations.json"
    watchChanges: false
    printErrors: false
    onLoaded: root.loadAnimState(text())
    onLoadFailed: root.loadAnimState("")
  }

  property Process powerStateProc: Process {
    command: ["bash", root.pluginDir() + "/bin/read-power-state.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parsePowerState(text)
    }
  }

  property Process accountsProc: Process {
    command: ["bash", "-lc", "getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1\"\\t\"$3\"\\t\"$6}'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseAccounts(text)
    }
  }

  property Process powerProfilesProc: Process {
    command: ["bash", "-lc",
      "ac=$(cat \"$HOME/.local/state/omarchy/powerprofiles/ac\" 2>/dev/null); " +
      "bat=$(cat \"$HOME/.local/state/omarchy/powerprofiles/battery\" 2>/dev/null); " +
      "avail=$(omarchy powerprofiles list 2>/dev/null | sort | paste -sd, -); " +
      "printf \"%s\\t%s\\t%s\\n\" \"$ac\" \"$bat\" \"$avail\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parsePowerProfiles(text)
    }
  }

  property Process defaultsProc: Process {
    command: ["bash", "-lc",
      "b=$(omarchy-default-browser 2>/dev/null); t=$(omarchy-default-terminal 2>/dev/null); " +
      "e=$(omarchy-default-editor 2>/dev/null); a=$(cat \"$HOME/.config/omarchy/defaults/agent\" 2>/dev/null); " +
      "s=$(getent passwd \"$USER\" 2>/dev/null | cut -d: -f7); " +
      "printf \"%s\\t%s\\t%s\\t%s\\t%s\\n\" \"$b\" \"$t\" \"$e\" \"$a\" \"$s\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseDefaults(text)
    }
  }

  property Process dndProc: Process {
    command: ["bash", "-lc", "omarchy-shell notifications dndState 2>/dev/null || echo off"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseDnd(text)
    }
  }

  property Timer muteTimer: Timer {
    interval: 1000
    repeat: true
    onTriggered: root.tickMute()
  }

  // ---- window -------------------------------------------------------------
  FloatingWindow {
    id: window
    title: "Settings"
    color: root.background
    implicitWidth: 960
    implicitHeight: 660
    minimumSize: Qt.size(560, 420)

    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.shell && typeof root.shell.hide === "function")
        root.shell.hide(root.pluginId)
    }

    Shortcut {
      sequence: "Ctrl+F"
      onActivated: root.toggleSearch()
    }

    FocusScope {
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (root.shellPromptOpen) {
          if (event.key === Qt.Key_Escape) root.cancelShellPrompt()
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.confirmShellPrompt()
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Escape) {
          root.requestClose()
          event.accepted = true
        }
      }

      Item {
        anchors.fill: parent
        anchors.margins: Style.space(16)

        // ---- sidebar ------------------------------------------------------
        BorderSurface {
          id: sidebar
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: Style.space(236)
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
          radius: Style.cornerRadius
          borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10), 1)

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(8)

            TextField {
              id: searchField
              width: parent.width
              placeholderText: "Search (Ctrl+F)…"
              foreground: root.foreground
              accent: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              onTextEdited: root.searchText = text
              onAccepted: {
                var r = root.filteredRows()
                if (r.length > 0) root.runRow(r[0])
              }
            }

            ScrollView {
              id: sidebarScroll
              width: parent.width
              height: parent.height - searchField.implicitHeight - Style.space(8)
              clip: true
              ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

              Column {
                width: sidebarScroll.availableWidth
                spacing: Style.space(2)

                // Suggestions (while searching)
                Column {
                  id: suggestionsCol
                  visible: root.searchText !== ""
                  width: parent.width
                  spacing: Style.space(2)

                  Repeater {
                    model: root.filteredRows()
                    delegate: Button {
                      required property var modelData
                      width: suggestionsCol.width
                      leftAlign: true
                      iconText: modelData.icon
                      text: modelData.label
                      tooltipText: root.sectionLabel(modelData.section) + " · " + modelData.description
                      horizontalPadding: Style.space(10)
                      onClicked: root.runRow(modelData)
                    }
                  }

                  // No-result state (while searching, zero matches)
                  Column {
                    visible: root.searchText.trim() !== "" && root.filteredRows().length === 0
                    width: parent.width
                    spacing: Style.space(4)
                    topPadding: Style.space(18)
                    bottomPadding: Style.space(18)

                    Text {
                      width: parent.width
                      text: "󰍉"
                      color: Qt.darker(root.foreground, 1.7)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.heading
                      horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                      width: parent.width
                      text: "No results"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                      width: parent.width
                      text: "Nothing matches “" + root.searchText.trim() + "”"
                      color: Qt.darker(root.foreground, 1.5)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }
                  }
                }

                // Section rail (while not searching)
                Column {
                  id: sectionsCol
                  visible: root.searchText === ""
                  width: parent.width
                  spacing: Style.space(2)

                  Repeater {
                    model: root.sectionGroups
                    delegate: Column {
                      id: groupCol
                      required property string modelData
                      width: sectionsCol.width
                      spacing: Style.space(2)

                      Text {
                        width: parent.width
                        text: groupCol.modelData
                        color: Qt.darker(root.foreground, 1.6)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        leftPadding: Style.space(10)
                        topPadding: Style.space(10)
                      }

                      Repeater {
                        model: root.sectionsInGroup(groupCol.modelData)
                        delegate: Button {
                          required property var modelData
                          width: sectionsCol.width
                          leftAlign: true
                          iconText: modelData.icon
                          text: modelData.label
                          active: root.currentSection === modelData.id
                          horizontalPadding: Style.space(18)
                          onClicked: {
                            root.currentSection = modelData.id
                            root.searchText = ""
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // ---- right pane ---------------------------------------------------
        Column {
          id: pane
          anchors.left: sidebar.right
          anchors.leftMargin: Style.space(16)
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          spacing: Style.space(12)

          Text {
            id: paneHeader
            width: parent.width
            text: sectionLabel(root.currentSection)
            color: Qt.darker(root.foreground, 1.5)
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          ScrollView {
            id: paneScroll
            width: parent.width
            height: pane.height - paneHeader.implicitHeight - Style.space(12)
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
              id: rowsColumn
              width: paneScroll.availableWidth
              spacing: Style.space(6)

              Repeater {
                model: root.sectionRows()

                delegate: SettingsRow {
                  host: root
                  width: rowsColumn.width
                }
              }

              AnimationsBlock { host: root }
              PowerBlock { host: root }
              AccountsBlock { host: root }
              SudoBlock { host: root }
              NotificationsBlock { host: root }
              TerminalBlock { host: root }
              DefaultsBlock { host: root }
            }
          }
        }
      }
    }

    // ---- Oh My Zsh install prompt ----------------------------------------
    Item {
      id: shellPrompt
      anchors.fill: parent
      visible: root.shellPromptOpen

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.7)
        MouseArea { anchors.fill: parent; onClicked: root.cancelShellPrompt() }
      }

      BorderSurface {
        width: Math.min(parent.width - Style.space(32), Style.space(380))
        anchors.centerIn: parent
        color: root.background
        radius: Style.cornerRadius
        borderSpec: Border.flat(root.accent, 1)
        padding: Style.space(18)

        Column {
          anchors.fill: parent
          spacing: Style.space(12)

          Text {
            width: parent.width
            text: "Install Oh My Zsh?"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            width: parent.width
            text: "Zsh is best with Oh My Zsh and its auto-completion plugin. Install it now?"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }
          Row {
            anchors.right: parent.right
            spacing: Style.space(10)

            Button {
              text: "Not now"
              bordered: true
              horizontalPadding: Style.space(12)
              onClicked: root.cancelShellPrompt()
            }
            Button {
              text: "Install"
              horizontalPadding: Style.space(12)
              onClicked: root.confirmShellPrompt()
            }
          }
        }
      }
    }
  }
}
