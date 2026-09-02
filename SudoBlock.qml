import QtQuick
import qs.Ui
import qs.Commons

// Accounts & Security section: passwordless-sudo duration and enable action.
Column {
  id: root

  property var host

  visible: host.currentSection === "security"
  width: parent.width
  spacing: Style.space(10)

  PanelSeparator { foreground: host.foreground }

  PanelSectionHeader {
    text: "Sudo"
    foreground: host.foreground
    fontFamily: host.fontFamily
    fontSize: Style.font.body
  }

  Dropdown {
    width: parent.width
    label: "Passwordless sudo duration"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.sudoOptions
    value: host.sudoMinutes
    onChanged: function(v) { host.sudoMinutes = v }
  }

  Button {
    width: parent.width
    text: "Enable passwordless sudo"
    bordered: true
    horizontalPadding: Style.space(10)
    onClicked: host.enablePasswordlessSudo()
  }
}
