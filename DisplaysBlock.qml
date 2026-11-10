import QtQuick
import qs.Ui
import qs.Commons

// Displays section: the scale of the display this window is on. Clean scales go
// through Omarchy's own command (omarchy-hyprland-monitor-scaling), so they apply
// instantly and are saved to monitors.lua, like Omarchy's panel and Super + /.
// "Allow in-between scales" lifts Hyprland's whole-pixel check so any preset
// can be used (bin/set-display-fractional.sh, bin/set-display-scale.sh).
Column {
  id: root

  property var host

  visible: host.currentSection === "displays" && host.displayScaleOptions.length > 0
  width: parent.width
  spacing: Style.space(10)

  PanelSeparator { foreground: host.foreground }

  PanelSectionHeader {
    text: "Scale"
    foreground: host.foreground
    fontFamily: host.fontFamily
    fontSize: Style.font.title
  }

  Dropdown {
    id: scaleDropdown
    width: parent.width
    label: host.displayName ? "Display scale (" + host.displayName + ")" : "Display scale"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.displayScaleOptions
    value: host.displayScale
    onChanged: function(v) { host.setDisplayScale(v) }

    // The dropdown overwrites its own `value` on selection, so re-sync from the
    // re-read scale: a change that failed reverts the dropdown.
    Connections {
      target: host
      function onDisplayScaleChanged() { scaleDropdown.value = host.displayScale }
    }
  }

  Text {
    width: parent.width
    text: host.displayFractional
      ? "Applies to the display this window is on."
      : "Applies to the display this window is on. Only scales that fit its resolution are listed."
    color: Qt.darker(host.foreground, 1.5)
    font.family: host.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Toggle {
    width: parent.width
    label: "Allow in-between scales"
    description: "Offers 125%, 150%, 175%… even when the resolution doesn't divide evenly. Edges can look slightly soft."
    foreground: host.foreground
    accent: host.accent
    fontFamily: host.fontFamily
    checked: host.displayFractional
    onClicked: host.setDisplayFractional(!checked)
  }
}
