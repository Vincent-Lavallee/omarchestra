import QtQuick
import qs.Ui

// The taskbar "cogwheel". Clicking it toggles the windowed Settings app through
// the same IPC path the keyboard shortcut and launcher-menu entry use, so the
// three stay on one code path.
BarWidget {
  id: root
  moduleName: "io.github.vincent-lavallee.omarchestra"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: "Settings"
    onPressed: function(button) {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell toggle io.github.vincent-lavallee.omarchestra")
    }
  }
}
