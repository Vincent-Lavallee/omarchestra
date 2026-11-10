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
    windowPaddingStateFile.reload()
    inputStateFile.reload()
    shellStatusFile.reload()
    inputStateProc.running = true
    keyboardProc.running = true
    displayProc.running = true
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

  // The scale can also change from Omarchy's own panel or Super + /, so
  // re-read it whenever Displays is shown.
  onCurrentSectionChanged: if (currentSection === "displays") displayProc.running = true

  readonly property var sectionGroups: Data.sectionGroups
  readonly property var sections: Data.sections
  readonly property var rows: Data.rows

  readonly property var animOptions: Data.animOptions
  readonly property var displayScalePresets: Data.displayScalePresets
  readonly property var windowPaddingOptions: Data.windowPaddingOptions
  readonly property var touchpadScrollDirectionOptions: Data.touchpadScrollDirectionOptions
  readonly property var mouseScrollDirectionOptions: Data.mouseScrollDirectionOptions
  readonly property var rightClickOptions: Data.rightClickOptions
  readonly property var swipeOptions: Data.swipeOptions
  readonly property var accelOptions: Data.accelOptions
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

  // Rows of the currently-selected section (right pane). `bottom` picks the
  // rows shown after the section's custom blocks rather than before them.
  function sectionRows(bottom) {
    var out = []
    for (var i = 0; i < rows.length; i++) {
      var r = rows[i]
      if (r.section === currentSection && !!r.bottom === !!bottom) out.push(r)
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

  function notify(message) {
    Util.execDetached("omarchy notification send '" + message + "'")
  }

  // ---- workspace animation state -----------------------------------------
  property string animWorkspaceStyle: "none"   // none | slide | slidevert | slidefade | fade

  // ---- window padding state ----------------------------------------------
  property string windowPadding: "default"     // none | compact | default | comfortable | large

  // ---- input state (touchpad / mouse) -------------------------------------
  // `inputState` is the LIVE Hyprland value for each control, read back from
  // `hyprctl getoption` (bin/read-input-state.sh), keyed like the Lua path under
  // `input`: "touchpad.tap_to_click", or "natural_scroll" for the mouse's own.
  // `inputOverrides` holds only what was changed from this app (plus "swipe").
  // It is saved to settings/input.json and written to a toggle file that Omarchy
  // loads after the user's input.lua, so every other setting keeps coming from
  // their own config.
  property var inputState: ({})
  property var inputOverrides: ({})
  property bool hasTouchpad: false
  property bool hasMouse: false
  property bool inputApplyQueued: false
  property bool inputReloadNeeded: false

  readonly property string swipeValue: inputOverrides.swipe !== undefined ? String(inputOverrides.swipe) : "off"

  // ---- keyboard layout state ----------------------------------------------
  property string keyboardLayout: ""            // primary layout, "us" or "us:intl"
  property var keyboardOptions: []              // [{ value, label }]

  // ---- display scale state ------------------------------------------------
  property string displayName: ""               // focused output, e.g. "eDP-1"
  property string displayScale: ""              // selected preset, e.g. "1.6"
  property var displayScaleOptions: []          // [{ value, label }]
  property bool displayFractional: false        // in-between scales unlocked
  property bool displayScalePending: false
  property string displayModePending: ""        // "on" | "off" | ""
  property string displayApplyJob: ""           // "mode" | "scale"

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
  property bool omzInstalled: false

  // ---- shell prompt state -------------------------------------------------
  property bool shellPromptOpen: false
  property string pendingShellPath: "/usr/bin/zsh"
  property string pendingShellToken: ""

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
    // pkexec never *executes* a script straight from the user-writable plugin
    // checkout (where it could be swapped after authorization). We reinstall it
    // only when the source has changed, so updates to bin/set-power-settings.sh
    // deploy without a manual step. Tradeoff vs. a strict install-once: each
    // change re-reads the user-writable source once (a narrow TOCTOU) before
    // running the root-owned copy.
    var helper = "/usr/local/lib/omarchestra/set-power-settings.sh"
    var src = pluginDir() + "/bin/set-power-settings.sh"
    var inner = "cmp -s \"" + src + "\" " + helper + " || install -D -m 0755 -o root -g root \"" + src + "\" " + helper + "; " +
      helper + " " + lidBatteryAction + " " + lidAcAction + " " + sleepTimeout
    powerApplyProc.command = ["pkexec", "bash", "-c", inner]
    powerApplyProc.running = true
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
    // Persist the per-source preference, then re-sync the *active* profile from
    // the source actually in use. `omarchy powerprofiles set <source> <profile>`
    // runs `powerprofilesctl set` on the live profile, so editing "On battery"
    // while plugged in would wrongly flip the active profile. Writing the state
    // file ourselves and letting `autodetect` re-apply keeps the active profile
    // tied to the real power source (and the path mirrors Omarchy's state dir).
    var stateDir = "${OMARCHY_POWERPROFILES_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/powerprofiles}"
    Util.execDetached(
      "state_dir=\"" + stateDir + "\"; " +
      "mkdir -p \"$state_dir\" && " +
      "printf '%s' \"" + profile + "\" > \"$state_dir/" + source + "\" && " +
      "omarchy powerprofiles set autodetect")
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
    if (p.length < 6) return
    defaultBrowser = p[0].trim()
    defaultTerminal = p[1].trim()
    defaultEditor = p[2].trim()
    defaultAgent = p[3].trim()
    currentShell = p[4].trim() || "/bin/bash"
    omzInstalled = p[5].trim() === "yes"
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
  // below decide whether the install script runs before `chsh`. If Oh My Zsh is
  // already installed there is nothing to offer — skip straight to `chsh`.
  function setDefaultShell(shellPath) {
    var bin = shellPath.split("/").pop()
    if (bin === "zsh" && !omzInstalled) {
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
    currentShell = shellPath   // optimistic; defaultsProc reverts it if chsh fails
    var bin = shellPath.split("/").pop()
    var pre = ""
    if (installOmz) pre = "command -v zsh >/dev/null || sudo pacman -S --noconfirm zsh; bash \"" + pluginDir() + "/bin/install-oh-my-zsh.sh\"; "
    else if (bin === "zsh") pre = "command -v zsh >/dev/null || sudo pacman -S --noconfirm zsh; "
    else if (bin === "fish") pre = "command -v fish >/dev/null || sudo pacman -S --noconfirm fish; "
    // `chsh` rewrites the login shell but not the live $SHELL, so new terminals
    // would keep the old shell until the next login. Chain the session-env
    // update (hl.env toggle + systemd/dbus) so the change applies immediately,
    // and write a status marker so a failed `chsh` (wrong/cancelled password)
    // reverts the dropdown instead of leaving it showing the un-applied shell.
    var token = String(Date.now())
    pendingShellToken = token
    var marker = "$HOME/.local/state/omarchy/settings/shell-status"
    var body = "mkdir -p \"$HOME/.local/state/omarchy/settings\"; " +
      "if chsh -s " + shellPath + "; then " +
      "bash \"" + pluginDir() + "/bin/set-default-shell.sh\" " + shellPath + "; " +
      "echo \"ok " + token + "\" > \"" + marker + "\"; " +
      "else echo \"fail " + token + "\" > \"" + marker + "\"; fi"
    Util.execDetached("omarchy-launch-floating-terminal-with-presentation '" + pre + body + "'")
  }

  // Called when the shell-status marker changes (written by the floating
  // terminal after `chsh`). Only act on the token we most recently requested so
  // a stale marker from a previous run doesn't trigger a spurious revert.
  function handleShellStatus(raw) {
    var s = String(raw || "").trim()
    if (s === "") return
    var parts = s.split(" ")
    if (parts.length < 2 || parts[1] !== pendingShellToken) return
    pendingShellToken = ""
    if (parts[0] === "fail") notify("Couldn't change shell — authentication failed")
    defaultsProc.running = true   // re-read /etc/passwd; reverts currentShell on failure
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
      // A spring, so the slide (and the release of a swipe) glides to a stop and
      // keeps its speed if interrupted (see slideAnimation in SettingsModel.js).
      // Hyprland 0.56 spells the field `dampening` while its current docs say
      // `damping`; both are written so a rename can't silently kill the
      // animation. `speed` is required by hl.animation but ignored for springs.
      var s = Data.slideAnimation
      var lua = "-- Generated by omarchestra. Delete to restore Omarchy defaults.\n" +
        'hl.curve("omarchestraSlide", { type = "spring", mass = ' + s.mass + ', stiffness = ' + s.stiffness +
          ', dampening = ' + s.damping + ', damping = ' + s.damping + ' })\n' +
        'hl.animation({ leaf = "workspaces", enabled = true, speed = 1, spring = "omarchestraSlide", style = "' + animWorkspaceStyle + '" })\n'
      writeFile("$HOME/.local/state/omarchy/toggles/hypr/animations.lua", lua)
    }
    writeFile("$HOME/.local/state/omarchy/settings/animations.json",
      JSON.stringify({ workspaceStyle: animWorkspaceStyle, slideVersion: Data.slideAnimation.version }))
    // Same as window padding: reload so a newly-created/removed toggle file
    // takes effect immediately (bin/set-lid-close.sh does the same).
    Util.execDetached("hyprctl reload >/dev/null 2>&1 || true")
  }

  // Shell snippet that writes `content` to `path` (creating its directory). It
  // ends in a newline, so snippets can be concatenated into one script.
  function writeCmd(path, content) {
    return "mkdir -p \"$(dirname \"" + path + "\")\" && cat > \"" + path + "\" <<'OMARCHY_SETTINGS_EOF'\n" + content + "\nOMARCHY_SETTINGS_EOF\n"
  }

  function writeFile(path, content) {
    Util.execDetached(writeCmd(path, content))
  }

  function loadAnimState(raw) {
    try {
      var o = JSON.parse(String(raw || ""))
      if (o && typeof o.workspaceStyle === "string") animWorkspaceStyle = o.workspaceStyle
      // Written by an older version of the slide tuning: regenerate it once.
      if (o && animWorkspaceStyle !== "none" && o.slideVersion !== Data.slideAnimation.version) applyAnimations()
    } catch (e) { /* ignore */ }
  }

  property FileView animStateFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/animations.json"
    watchChanges: false
    printErrors: false
    onLoaded: root.loadAnimState(text())
    onLoadFailed: root.loadAnimState("")
  }

  // Map a window-padding preset to concrete Hyprland gaps (gaps_in = space
  // between windows, gaps_out = space around the screen edge). "default" (and
  // anything unknown) returns null → remove the override so Omarchy's own
  // gaps apply.
  function paddingGaps(preset) {
    switch (preset) {
    case "none": return { gapsIn: 0, gapsOut: 0 }
    case "compact": return { gapsIn: 2, gapsOut: 4 }
    case "comfortable": return { gapsIn: 8, gapsOut: 16 }
    case "large": return { gapsIn: 12, gapsOut: 24 }
    default: return null
    }
  }

  function applyWindowPadding() {
    var g = paddingGaps(windowPadding)
    if (g === null) {
      Util.execDetached("rm -f \"$HOME/.local/state/omarchy/toggles/hypr/window-padding.lua\"")
    } else {
      var lua = "-- Generated by omarchestra. Delete to restore Omarchy defaults.\n" +
        "hl.config({ general = { gaps_in = " + g.gapsIn + ", gaps_out = " + g.gapsOut + " } })\n"
      writeFile("$HOME/.local/state/omarchy/toggles/hypr/window-padding.lua", lua)
    }
    writeFile("$HOME/.local/state/omarchy/settings/window-padding.json", JSON.stringify({ padding: windowPadding }))
    // Hyprland only hot-reloads files it has already sourced, so a brand-new
    // (or just-removed) toggle file won't apply on its own — reload explicitly,
    // matching bin/set-lid-close.sh.
    Util.execDetached("hyprctl reload >/dev/null 2>&1 || true")
  }

  function loadWindowPaddingState(raw) {
    try {
      var o = JSON.parse(String(raw || ""))
      if (o && typeof o.padding === "string") windowPadding = o.padding
    } catch (e) { /* ignore */ }
  }

  property FileView windowPaddingStateFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/window-padding.json"
    watchChanges: false
    printErrors: false
    onLoaded: root.loadWindowPaddingState(text())
    onLoadFailed: root.loadWindowPaddingState("")
  }

  // ---- touchpad / mouse ---------------------------------------------------
  // The options this app may write, and how each is rendered as a Lua literal.
  // Anything not listed here (or failing its check) is dropped, so only known
  // literals ever reach the generated file that Hyprland executes.
  readonly property var inputSpec: ({
    "touchpad.tap_to_click": "bool",
    "touchpad.clickfinger_behavior": "bool",
    "touchpad.natural_scroll": "bool",
    "touchpad.scroll_factor": "scroll",
    "natural_scroll": "bool",
    "scroll_factor": "scroll",
    "accel_profile": "accel"
  })

  function inputLiteral(kind, v) {
    if (kind === "bool") return (v === true || v === false) ? String(v) : null
    if (kind === "scroll") {
      var n = Number(v)
      return (isFinite(n) && n >= 0.1 && n <= 2) ? n.toFixed(2) : null
    }
    if (kind === "accel") return (v === "flat" || v === "adaptive") ? "\"" + v + "\"" : null
    return null
  }

  function copyObject(o) {
    var c = {}
    for (var k in o) c[k] = o[k]
    return c
  }

  function inputValue(key, fallback) {
    var v = inputState[key]
    return (v === undefined || v === null) ? fallback : v
  }

  // Lua for the overridden `input` options, or "" when there are none.
  function inputConfigLua() {
    var top = []
    var pad = []
    for (var key in inputSpec) {
      if (inputOverrides[key] === undefined) continue
      var lit = inputLiteral(inputSpec[key], inputOverrides[key])
      if (lit === null) continue
      if (key.indexOf("touchpad.") === 0) pad.push(key.substring(9) + " = " + lit)
      else top.push(key + " = " + lit)
    }
    if (pad.length > 0) top.push("touchpad = { " + pad.join(", ") + " }")
    return top.length > 0 ? "hl.config({ input = { " + top.join(", ") + " } })" : ""
  }

  function setInput(key, value) {
    if (inputSpec[key] === undefined || inputLiteral(inputSpec[key], value) === null) return
    var o = copyObject(inputOverrides)
    o[key] = value
    inputOverrides = o
    // Optimistic; the live state is re-read once the change has been applied,
    // so a failed apply reverts the control instead of leaving it lying.
    var s = copyObject(inputState)
    s[key] = value
    inputState = s
    applyInput(false)
  }

  function setSwipe(value) {
    if ((value !== "off" && value !== "3" && value !== "4") || value === swipeValue) return
    var o = copyObject(inputOverrides)
    o.swipe = value
    inputOverrides = o
    // Omarchy ships with the workspace animation off, and a swipe with no slide
    // just snaps between workspaces. Turn the slide on so the swipe has
    // something to play.
    if (value !== "off" && animWorkspaceStyle === "none") {
      animWorkspaceStyle = "slide"
      applyAnimations()
    }
    applyInput(true)   // a gesture can only be added or removed by a reload
  }

  // Applies are serialized: a change made while one is still running is queued
  // and applied afterwards from the then-current state, so none is lost.
  function applyInput(reload) {
    if (reload) inputReloadNeeded = true
    if (inputApplyProc.running) { inputApplyQueued = true; return }
    runInputApply()
  }

  function runInputApply() {
    var base = "$HOME/.local/state/omarchy"
    var toggle = base + "/toggles/hypr/omarchestra-input.lua"
    var stateFile = base + "/settings/input.json"
    var reload = inputReloadNeeded
    inputReloadNeeded = false
    var cfg = inputConfigLua()
    var lua = "-- Generated by omarchestra. Delete this file to go back to your own input.lua.\n" + (cfg ? cfg + "\n" : "")
    if (swipeValue === "3" || swipeValue === "4") {
      var t = Data.swipeTuning
      lua += "hl.config({ gestures = { workspace_swipe_distance = " + t.distance +
        ", workspace_swipe_cancel_ratio = " + t.cancelRatio +
        ", workspace_swipe_min_speed_to_force = " + t.minSpeedToForce + " } })\n" +
        "hl.gesture({ fingers = " + swipeValue + ", direction = \"horizontal\", action = \"workspace\" })\n"
    }
    // Plain option changes apply instantly with `hyprctl eval` (no reload, so
    // no flicker); the toggle file is what makes them survive a restart.
    var apply = (reload || cfg === "")
      ? "[ \"$(hyprctl reload 2>&1)\" = ok ]"
      : "[ \"$(hyprctl eval '" + cfg + "' 2>&1)\" = ok ]"
    var cmd = writeCmd(toggle, lua) +
      writeCmd(stateFile, JSON.stringify({ overrides: inputOverrides, tuning: Data.swipeTuning.version })) + apply
    inputApplyProc.command = ["bash", "-c", cmd]
    inputApplyProc.running = true
  }

  function parseInputState(raw) {
    try {
      var o = JSON.parse(String(raw || "").trim())
      hasTouchpad = o.hasTouchpad === true
      hasMouse = o.hasMouse === true
      delete o.hasTouchpad
      delete o.hasMouse
      inputState = o
    } catch (e) { /* keep the previous state */ }
  }

  function loadInputOverrides(raw) {
    var next = {}
    var staleTuning = false
    try {
      var file = JSON.parse(String(raw || ""))
      // The swipe tuning was written by an older version: regenerate it once.
      staleTuning = file.tuning !== Data.swipeTuning.version
      var saved = file.overrides
      if (saved && typeof saved === "object") {
        for (var k in saved) {
          if (k === "swipe") {
            if (["off", "3", "4"].indexOf(String(saved[k])) !== -1) next.swipe = String(saved[k])
          } else if (inputSpec[k] !== undefined && inputLiteral(inputSpec[k], saved[k]) !== null) {
            next[k] = saved[k]
          }
        }
      }
    } catch (e) { staleTuning = false /* no saved overrides */ }
    inputOverrides = next
    if (staleTuning && next.swipe !== undefined && next.swipe !== "off") applyInput(true)
  }

  property FileView inputStateFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/input.json"
    watchChanges: false
    printErrors: false
    onLoaded: root.loadInputOverrides(text())
    onLoadFailed: root.loadInputOverrides("")
  }

  property Process inputStateProc: Process {
    command: ["bash", root.pluginDir() + "/bin/read-input-state.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseInputState(text)
    }
  }

  // Writes the toggle file and applies it. Always re-reads the live state when
  // done, so the controls show what Hyprland is really using, whether or not the
  // change took.
  property Process inputApplyProc: Process {
    onExited: function(exitCode, exitStatus) {
      if (root.inputApplyQueued) {
        root.inputApplyQueued = false
        root.runInputApply()
        return
      }
      if (exitCode !== 0) root.notify("Couldn't apply input settings")
      root.inputStateProc.running = true
    }
  }

  // ---- keyboard layout ----------------------------------------------------
  function parseKeyboard(raw) {
    try {
      var o = JSON.parse(String(raw || "").trim())
      keyboardOptions = o.catalog || []
      keyboardLayout = (o.selection && o.selection.length > 0) ? String(o.selection[0]) : ""
    } catch (e) { /* keep the previous state */ }
  }

  // Changes the primary layout through Omarchy's own code (bin/keyboard-layout.py),
  // which keeps the Hyprland reload and the Fcitx input group in step.
  function setKeyboardLayout(v) {
    if (!v || v === keyboardLayout) return
    keyboardLayout = v   // optimistic; keyboardApplyProc re-reads the real selection
    keyboardApplyProc.command = ["python3", "-I", pluginDir() + "/bin/keyboard-layout.py", "set", v]
    keyboardApplyProc.running = true
  }

  property Process keyboardProc: Process {
    command: ["python3", "-I", root.pluginDir() + "/bin/keyboard-layout.py", "get"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseKeyboard(text)
    }
  }

  property Process keyboardApplyProc: Process {
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0) root.notify("Couldn't change keyboard layout")
      root.keyboardProc.running = true
    }
  }

  // ---- display scale ------------------------------------------------------
  // Mirrors Omarchy's monitor panel: Hyprland only accepts scales that divide
  // the mode into whole logical pixels (in 1/120 steps), so each preset is
  // rounded up to the nearest clean scale for the display, and presets that
  // land on the same scale collapse into the closest one. With in-between
  // scales unlocked (`displayFractional`) the presets are offered as they are.
  function gcd(a, b) {
    while (b) { var t = a % b; a = b; b = t }
    return a
  }

  function cleanScale(scale, width, height) {
    var g = gcd(Math.round(width * 120), Math.round(height * 120))
    var k = Math.round(scale * 120)
    if (k > g) k = g
    while (g % k !== 0) k++
    return k / 120
  }

  function scaleLabel(scale) {
    return Math.round(scale * 100) + "%"
  }

  // `raw` is bin/read-display-state.sh's JSON. The scale belongs to the focused
  // display, which is the one both scale commands change.
  function parseDisplay(raw) {
    var mon = null
    var fractional = false
    try {
      var o = JSON.parse(String(raw || ""))
      fractional = o.fractional === true
      var list = o.monitors || []
      for (var i = 0; i < list.length; i++)
        if (list[i].focused) { mon = list[i]; break }
    } catch (e) { /* keep the previous state */ }
    if (!mon || !(mon.width > 0) || !(mon.height > 0)) return

    var byScale = {}
    var picks = []
    for (var j = 0; j < displayScalePresets.length; j++) {
      var preset = displayScalePresets[j]
      var eff = fractional ? Number(preset) : cleanScale(Number(preset), mon.width, mon.height)
      var key = eff.toFixed(4)
      var dist = Math.abs(Number(preset) - eff)
      var prev = byScale[key]
      if (prev && prev.dist <= dist) continue
      var pick = { value: preset, label: scaleLabel(eff), scale: eff, dist: dist }
      if (prev) picks[picks.indexOf(prev)] = pick
      else picks.push(pick)
      byScale[key] = pick
    }

    // A scale set by hand in monitors.lua may match no preset: show it as is.
    var current = ""
    for (var m = 0; m < picks.length; m++)
      if (Math.abs(picks[m].scale - mon.scale) < 0.001) { current = picks[m].value; break }
    if (current === "") {
      current = String(Math.round(mon.scale * 1000) / 1000)
      picks.push({ value: current, label: scaleLabel(mon.scale) + " (custom)", scale: mon.scale })
      picks.sort(function(a, b) { return a.scale - b.scale })
    }

    var opts = []
    for (var n = 0; n < picks.length; n++) opts.push({ value: picks[n].value, label: picks[n].label })
    displayName = String(mon.name || "")
    displayFractional = fractional
    displayScaleOptions = opts
    displayScale = current
  }

  // Clean scales go through Omarchy's own command, which applies the scale to
  // the focused display right away and saves it (with the matching GDK_SCALE)
  // to monitors.lua — the same path as Omarchy's monitor panel and Super + /.
  // In-between scales go through bin/set-display-scale.sh, which does the same
  // minus Omarchy's rounding to a clean scale.
  function setDisplayScale(v) {
    if (!v || v === displayScale) return
    displayScale = v   // optimistic; re-read once every change is applied
    displayScalePending = true
    kickDisplayApply()
  }

  function setDisplayFractional(on) {
    if (on === displayFractional) return
    displayFractional = on
    displayModePending = on ? "on" : "off"
    kickDisplayApply()
  }

  // Changes are applied one at a time, mode before scale, each from the
  // then-current state, so quick successive picks are never lost or reordered.
  function kickDisplayApply() {
    if (!displayApplyProc.running) runDisplayApply()
  }

  function runDisplayApply() {
    if (displayModePending !== "") {
      displayApplyJob = "mode"
      displayApplyProc.command = ["bash", pluginDir() + "/bin/set-display-fractional.sh", displayModePending]
      displayModePending = ""
    } else if (displayScalePending) {
      displayApplyJob = "scale"
      displayApplyProc.command = displayFractional
        ? ["bash", pluginDir() + "/bin/set-display-scale.sh", displayScale]
        : ["omarchy-hyprland-monitor-scaling", displayScale]
      displayScalePending = false
    } else {
      return false
    }
    displayApplyProc.running = true
    return true
  }

  property Process displayProc: Process {
    command: ["bash", root.pluginDir() + "/bin/read-display-state.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseDisplay(text)
    }
  }

  // Always re-reads the live state once the queue is empty, so the controls
  // show what Hyprland is really using, whether or not the change took.
  property Process displayApplyProc: Process {
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0)
        root.notify(root.displayApplyJob === "mode" ? "Couldn't change in-between scales" : "Couldn't change display scale")
      if (!root.runDisplayApply()) root.displayProc.running = true
    }
  }

  // Watches the marker the floating terminal writes after `chsh` completes, so
  // a failed (wrong/cancelled password) shell change can revert the dropdown.
  property FileView shellStatusFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/shell-status"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.handleShellStatus(text())
    onLoadFailed: root.handleShellStatus("")
  }

  property Process powerStateProc: Process {
    command: ["bash", root.pluginDir() + "/bin/read-power-state.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parsePowerState(text)
    }
  }

  // Runs the privileged logind drop-in write (via pkexec). On auth failure
  // `exitCode` is non-zero, so re-read the real state to revert the dropdowns.
  property Process powerApplyProc: Process {
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0) root.notify("Power settings not applied — authentication failed")
      root.powerStateProc.running = true
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
      "o=$([ -d \"$HOME/.oh-my-zsh\" ] && echo yes || echo no); " +
      "printf \"%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n\" \"$b\" \"$t\" \"$e\" \"$a\" \"$s\" \"$o\""]
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

              AppearanceBlock { host: root }
              AnimationsBlock { host: root }
              DisplaysBlock { host: root }
              PowerBlock { host: root }
              AccountsBlock { host: root }
              SudoBlock { host: root }
              NotificationsBlock { host: root }
              TerminalBlock { host: root }
              DefaultsBlock { host: root }
              InputBlock { host: root }
              KeyboardBlock { host: root }

              // Rows flagged `bottom` (e.g. "open input.lua") sit under the
              // section's blocks as an escape hatch.
              PanelSeparator {
                visible: bottomRows.count > 0
                foreground: root.foreground
              }
              Repeater {
                id: bottomRows
                model: root.sectionRows(true)

                delegate: SettingsRow {
                  host: root
                  width: rowsColumn.width
                }
              }
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
