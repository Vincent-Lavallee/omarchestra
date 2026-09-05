import QtQuick
import qs.Ui
import qs.Commons

// Appearance section: window padding (Hyprland gaps), written to a toggle file
// so it hot-reloads — same mechanism as the workspace-animation control.
Column {
  id: root

  property var host

  visible: host.currentSection === "appearance"
  width: parent.width
  spacing: Style.space(10)

  PanelSeparator { foreground: host.foreground }

  PanelSectionHeader {
    text: "Window padding"
    foreground: host.foreground
    fontFamily: host.fontFamily
    fontSize: Style.font.title
  }

  Dropdown {
    width: parent.width
    label: "Padding amount"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.windowPaddingOptions
    value: host.windowPadding
    onChanged: function(v) { host.windowPadding = v; host.applyWindowPadding() }
  }
}
