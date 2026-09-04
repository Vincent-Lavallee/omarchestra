import QtQuick
import qs.Ui
import qs.Commons

// Appearance section: workspace-switch animation control (writes a Hyprland
// toggle file instead of opening a config editor).
Column {
  id: root

  property var host

  visible: host.currentSection === "appearance"
  width: parent.width
  spacing: Style.space(10)

  PanelSeparator { foreground: host.foreground }

  PanelSectionHeader {
    text: "Animations"
    foreground: host.foreground
    fontFamily: host.fontFamily
    fontSize: Style.font.title
  }

  Dropdown {
    width: parent.width
    label: "Workspace animation"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.animOptions
    value: host.animWorkspaceStyle
    onChanged: function(v) { host.animWorkspaceStyle = v; host.applyAnimations() }
  }
}
