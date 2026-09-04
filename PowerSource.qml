import QtQuick
import qs.Ui
import qs.Commons

// One power-source column (battery or AC) inside PowerBlock. The lid action and
// power profile are per-source; lock/sleep timeouts are shared and read the
// same root values, so the two columns stay in sync.
Column {
  id: root

  property var host
  property string source   // "battery" | "ac"

  readonly property bool isBattery: source === "battery"

  width: parent.width
  spacing: Style.space(10)

  Row {
    width: parent.width
    spacing: Style.space(8)

    Text {
      text: root.isBattery ? "󰁹" : "󰚥"
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }
    Column {
      spacing: Style.space(1)

      Text {
        text: root.isBattery ? "On Battery" : "Plugged In"
        color: Qt.darker(host.foreground, 1.4)
        font.family: host.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        text: root.isBattery ? "While running on battery" : "While connected to power"
        color: Qt.darker(host.foreground, 1.5)
        font.family: host.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Dropdown {
    width: parent.width
    label: "When lid is closed"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.lidActionOptions
    value: root.isBattery ? host.lidBatteryAction : host.lidAcAction
    onChanged: function(v) {
      if (root.isBattery) host.lidBatteryAction = v
      else host.lidAcAction = v
      host.applyPowerSettings()
    }
  }

  Dropdown {
    width: parent.width
    label: "Power profile"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.powerProfileOptions()
    value: root.isBattery ? host.powerProfileBattery : host.powerProfileAc
    onChanged: function(v) { host.setPowerProfile(root.source, v) }
  }

  Dropdown {
    width: parent.width
    label: "Lock after inactivity"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.lockTimeoutOptions
    value: host.lockTimeout
    onChanged: function(v) { host.lockTimeout = v; host.setIdleLock() }
  }

  Dropdown {
    width: parent.width
    label: "Sleep after inactivity"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.sleepTimeoutOptions
    value: host.sleepTimeout
    onChanged: function(v) { host.sleepTimeout = v; host.applyPowerSettings() }
  }
}
