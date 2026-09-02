import QtQuick
import qs.Ui
import qs.Commons

// Defaults section: the default browser/terminal/editor/agent, editable inline
// (no submenu). Values are read once on open and set directly on change.
Column {
  id: root

  property var host

  visible: host.currentSection === "defaults"
  width: parent.width
  spacing: Style.space(10)

  PanelSeparator { foreground: host.foreground }

  PanelSectionHeader {
    text: "Default Apps"
    foreground: host.foreground
    fontFamily: host.fontFamily
    fontSize: Style.font.body
  }

  Dropdown {
    width: parent.width
    label: "Browser"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.browserOptions
    value: host.defaultBrowser
    onChanged: function(v) { host.setDefaultBrowser(v) }
  }
  Dropdown {
    width: parent.width
    label: "Terminal"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.terminalOptions
    value: host.defaultTerminal
    onChanged: function(v) { host.setDefaultTerminal(v) }
  }
  Dropdown {
    width: parent.width
    label: "Editor"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.editorOptions
    value: host.defaultEditor
    onChanged: function(v) { host.setDefaultEditor(v) }
  }
  Dropdown {
    width: parent.width
    label: "Agent"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.agentOptions
    value: host.defaultAgent
    onChanged: function(v) { host.setDefaultAgent(v) }
  }
}
