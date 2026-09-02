import QtQuick
import qs.Ui
import qs.Commons

// A single setting row in the right pane: icon, label, description, and a
// click target that runs the row's command. `host` is the Settings root so the
// row can reach colors and `runRow`.
BorderSurface {
  id: row

  property var host
  required property var modelData

  width: parent.width
  implicitHeight: rowContent.implicitHeight + Style.space(18)
  color: rowMouse.containsMouse
    ? Style.hoverFillFor(host.foreground, host.accent)
    : Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.04)
  radius: Style.cornerRadius
  borderSpec: rowMouse.containsMouse
    ? Border.controlSpec("hover-cursor", host.foreground, host.accent)
    : Border.flat(Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.10), 1)

  Item {
    id: rowContent
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(12)
    anchors.rightMargin: Style.space(12)
    implicitHeight: Math.max(rowIcon.implicitHeight, rowTextCol.implicitHeight)

    Text {
      id: rowIcon
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(24)
      text: row.modelData.icon
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.title
      horizontalAlignment: Text.AlignHCenter
    }

    Column {
      id: rowTextCol
      anchors.left: rowIcon.right
      anchors.leftMargin: Style.space(10)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        width: parent.width
        text: row.modelData.label
        color: host.foreground
        font.family: host.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: row.modelData.description
        color: Qt.darker(host.foreground, 1.5)
        font.family: host.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: host.runRow(row.modelData)
  }
}
