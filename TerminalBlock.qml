import QtQuick
import qs.Ui
import qs.Commons

// Terminal section: choose the login shell. Picking Zsh offers to install
// Oh My Zsh first (handled by the host's shell-prompt flow).
Column {
  id: root

  property var host

  visible: host.currentSection === "terminal"
  width: parent.width
  spacing: Style.space(10)

  PanelSeparator { foreground: host.foreground }

  PanelSectionHeader {
    text: "Shell"
    foreground: host.foreground
    fontFamily: host.fontFamily
    fontSize: Style.font.title
  }

  Dropdown {
    width: parent.width
    label: "Default shell"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.shellOptions()
    value: host.currentShell
    onChanged: function(v) { host.setDefaultShell(v) }
  }
}
