import QtQuick
import qs.Ui
import qs.Commons

// Trackpad & Mouse section: two side-by-side device columns (the same shape as
// Power & Sleep's two power sources) that stack when the pane is too narrow for
// two. Settings are applied live and saved as overrides that Omarchy loads after
// the user's own input.lua.
Column {
  id: root

  property var host

  visible: host.currentSection === "pointer"
  width: parent.width
  spacing: Style.space(12)

  Grid {
    id: devices
    width: parent.width
    // Two columns only when each gets enough room for its slider and labels.
    columns: root.width >= Style.space(520) ? 2 : 1
    columnSpacing: Style.space(12)
    rowSpacing: Style.space(16)

    DeviceColumn {
      host: root.host
      device: "touchpad"
      width: (devices.width - (devices.columns - 1) * devices.columnSpacing) / devices.columns
    }
    DeviceColumn {
      host: root.host
      device: "mouse"
      width: (devices.width - (devices.columns - 1) * devices.columnSpacing) / devices.columns
    }
  }
}
