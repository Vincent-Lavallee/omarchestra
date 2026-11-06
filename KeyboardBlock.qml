import QtQuick
import qs.Ui
import qs.Commons

// Keyboard & Config → "Keyboard": the primary layout. Changing it goes through
// Omarchy's own keyboard code (bin/keyboard-layout.py), which keeps Hyprland and
// the input-method group in step. Other layouts already configured are kept.
Column {
  id: root

  property var host

  visible: host.currentSection === "keyboard"
  width: parent.width
  spacing: Style.space(10)

  PanelSeparator { foreground: host.foreground }

  PanelSectionHeader {
    text: "Keyboard"
    foreground: host.foreground
    fontFamily: host.fontFamily
    fontSize: Style.font.title
  }

  SearchableDropdown {
    id: layoutDropdown
    width: parent.width
    label: "Layout"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.keyboardOptions
    value: host.keyboardLayout
    onChanged: function(v) { host.setKeyboardLayout(v) }

    // The dropdown overwrites its own `value` on selection, so re-sync from the
    // re-read selection: a change Omarchy rejected reverts the dropdown.
    Connections {
      target: host
      function onKeyboardLayoutChanged() { layoutDropdown.value = host.keyboardLayout }
    }
  }
}
