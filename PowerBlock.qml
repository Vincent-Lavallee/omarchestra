import QtQuick
import qs.Ui
import qs.Commons

// Power & Sleep section: two side-by-side power sources ("On Battery" /
// "Plugged In"). Lid close and power profile are per-source; lock and sleep
// timeouts are system-wide, so they mirror across the two columns.
Column {
  id: root

  property var host

  visible: host.currentSection === "power"
  width: parent.width
  spacing: Style.space(12)

  PanelSeparator { foreground: host.foreground }

  PanelSectionHeader {
    text: "Power & Sleep"
    foreground: host.foreground
    fontFamily: host.fontFamily
    fontSize: Style.font.title
  }

  Row {
    width: parent.width
    spacing: Style.space(12)

    PowerSource {
      host: root.host
      source: "battery"
      width: (parent.width - parent.spacing) / 2
    }
    PowerSource {
      host: root.host
      source: "ac"
      width: (parent.width - parent.spacing) / 2
    }
  }
}
