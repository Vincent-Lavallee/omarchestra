import QtQuick
import qs.Ui
import qs.Commons

// Notifications section: do-not-disturb toggle, mute-for-a-duration dropdown,
// and a live countdown with an "Unmute now" action while a mute is scheduled.
Column {
  id: root

  property var host

  visible: host.currentSection === "notifications"
  width: parent.width
  spacing: Style.space(10)

  PanelSeparator { foreground: host.foreground }

  PanelSectionHeader {
    text: "Do Not Disturb"
    foreground: host.foreground
    fontFamily: host.fontFamily
    fontSize: Style.font.body
  }

  Toggle {
    width: parent.width
    label: "Mute notifications"
    description: "Silence all desktop notifications until you unmute"
    foreground: host.foreground
    accent: host.accent
    fontFamily: host.fontFamily
    checked: host.dnd
    onClicked: host.toggleDnd()
  }

  Dropdown {
    id: muteForDropdown
    width: parent.width
    label: "Mute for"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.muteOptions
    value: ""
    onChanged: function(v) {
      if (v) {
        host.muteFor(parseInt(v, 10))
        muteForDropdown.value = ""
      }
    }
  }

  BorderSurface {
    visible: host.muteSeconds > 0
    width: parent.width
    implicitHeight: muteActiveContent.implicitHeight + Style.space(16)
    color: Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.04)
    radius: Style.cornerRadius
    borderSpec: Border.flat(Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.10), 1)

    Item {
      id: muteActiveContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      implicitHeight: Math.max(muteActiveIcon.implicitHeight, muteActiveText.implicitHeight)

      Text {
        id: muteActiveIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(24)
        text: "󰂛"
        color: host.foreground
        font.family: host.fontFamily
        font.pixelSize: Style.font.title
        horizontalAlignment: Text.AlignHCenter
      }

      Column {
        id: muteActiveText
        anchors.left: muteActiveIcon.right
        anchors.leftMargin: Style.space(10)
        anchors.right: unmuteBtn.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: "Notifications muted"
          color: host.foreground
          font.family: host.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          width: parent.width
          text: "Resumes in " + host.muteRemainingLabel()
          color: Qt.darker(host.foreground, 1.5)
          font.family: host.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Button {
        id: unmuteBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "Unmute now"
        horizontalPadding: Style.space(10)
        verticalPadding: Style.space(3)
        onClicked: host.unmuteNow()
      }
    }
  }
}
