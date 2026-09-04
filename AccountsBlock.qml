import QtQuick
import qs.Ui
import qs.Commons

// Accounts & Security section: the login accounts on this machine, with
// add/remove actions.
Column {
  id: root

  property var host

  visible: host.currentSection === "security"
  width: parent.width
  spacing: Style.space(10)

  PanelSeparator { foreground: host.foreground }

  PanelSectionHeader {
    text: "Accounts"
    foreground: host.foreground
    fontFamily: host.fontFamily
    fontSize: Style.font.title
  }

  Repeater {
    model: host.accounts
    delegate: BorderSurface {
      required property var modelData
      width: root.width
      implicitHeight: acctContent.implicitHeight + Style.space(16)
      color: Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.04)
      radius: Style.cornerRadius
      borderSpec: Border.flat(Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.10), 1)

      Item {
        id: acctContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        implicitHeight: Math.max(acctIcon.implicitHeight, acctText.implicitHeight)

        Text {
          id: acctIcon
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(24)
          text: "󰌾"
          color: host.foreground
          font.family: host.fontFamily
          font.pixelSize: Style.font.title
          horizontalAlignment: Text.AlignHCenter
        }

        Column {
          id: acctText
          anchors.left: acctIcon.right
          anchors.leftMargin: Style.space(10)
          anchors.right: acctActions.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(1)

          Text {
            width: parent.width
            text: modelData.user
            color: host.foreground
            font.family: host.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: modelData.home
            color: Qt.darker(host.foreground, 1.5)
            font.family: host.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }

        Row {
          id: acctActions
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)

          Text {
            visible: modelData.isCurrent
            text: "You"
            color: host.accent
            font.family: host.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
          Button {
            visible: !modelData.isCurrent
            text: "Remove"
            horizontalPadding: Style.space(10)
            verticalPadding: Style.space(3)
            onClicked: host.runRemoveAccount(modelData.user)
          }
        }
      }
    }
  }

  Text {
    visible: host.accounts.length === 0
    width: parent.width
    text: "Loading accounts…"
    color: Qt.darker(host.foreground, 1.5)
    font.family: host.fontFamily
    font.pixelSize: Style.font.caption
  }

  Button {
    width: parent.width
    text: "Add account"
    bordered: true
    horizontalPadding: Style.space(10)
    onClicked: host.runAccountScript("add-account.sh")
  }
}
