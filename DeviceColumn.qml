import QtQuick
import qs.Ui
import qs.Commons

// One pointing-device column (trackpad or mouse) inside InputBlock. Both read
// and write Hyprland's `input` options through the host: the trackpad's live in
// `input.touchpad.*`, the mouse's directly under `input`, which is all `key()`
// has to tell apart. Everything shown is the LIVE value (host.inputState), so a
// change that didn't apply reverts the control instead of leaving it lying.
//
// The two columns are meant to be read side by side, so the controls they share
// (scroll direction, scroll speed) come first and in the same order, with equal
// heights; each device's own controls follow.
Column {
  id: root

  property var host
  property string device   // "touchpad" | "mouse"

  readonly property bool isTouchpad: device === "touchpad"
  readonly property bool present: isTouchpad ? host.hasTouchpad : host.hasMouse

  // Hyprland option path of a control for this device.
  function key(name) { return isTouchpad ? "touchpad." + name : name }

  function scrollDirection() {
    return host.inputValue(root.key("natural_scroll"), false) === true ? "natural" : "traditional"
  }

  width: parent.width
  spacing: Style.space(10)

  // ---- header ---------------------------------------------------------------
  Row {
    width: parent.width
    spacing: Style.space(8)

    Text {
      id: deviceIcon
      text: root.isTouchpad ? "󰟸" : "󰍽"
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.body
      anchors.verticalCenter: parent.verticalCenter
    }
    Column {
      width: parent.width - deviceIcon.implicitWidth - parent.spacing
      spacing: Style.space(1)

      Text {
        text: root.isTouchpad ? "Trackpad" : "Mouse"
        color: Qt.darker(host.foreground, 1.4)
        font.family: host.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        width: parent.width
        text: root.present
          ? (root.isTouchpad ? "Taps, clicks, scrolling and gestures" : "Scrolling and pointer speed")
          : (root.isTouchpad ? "No trackpad detected" : "None connected — applies when plugged in")
        color: Qt.darker(host.foreground, 1.5)
        font.family: host.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }

  // ---- shared: same rows, same order, in both columns -----------------------
  Dropdown {
    id: directionDropdown
    width: parent.width
    label: "Scroll direction"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: root.isTouchpad ? host.touchpadScrollDirectionOptions : host.mouseScrollDirectionOptions
    value: root.scrollDirection()
    onChanged: function(v) { host.setInput(root.key("natural_scroll"), v === "natural") }

    // Dropdown overwrites its own `value` on selection (breaking the binding),
    // so re-sync from the live state: a change that failed reverts the dropdown.
    Connections {
      target: host
      function onInputStateChanged() { directionDropdown.value = root.scrollDirection() }
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(4)

    Item {
      width: parent.width
      height: Math.max(speedLabel.implicitHeight, speedValue.implicitHeight)

      Text {
        id: speedLabel
        text: "Scroll speed"
        color: host.foreground
        font.family: host.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        id: speedValue
        anchors.right: parent.right
        text: speedSlider.liveValue.toFixed(2) + "×"
        color: Qt.darker(host.foreground, 1.5)
        font.family: host.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    // Applies when released (not while dragging), so you set a speed and then
    // try it, instead of re-applying on every pixel of the drag.
    PanelSlider {
      id: speedSlider
      width: parent.width
      bar: host
      minimum: 0.1
      maximum: 2.0
      step: 0.05
      value: host.inputValue(root.key("scroll_factor"), 1)
      onReleased: function(v) { host.setInput(root.key("scroll_factor"), Math.round(v * 20) / 20) }
    }
  }

  // ---- trackpad only ----------------------------------------------------------
  // The dropdown comes first so it lines up with the mouse's "Pointer acceleration".
  Dropdown {
    id: rightClickDropdown
    visible: root.isTouchpad
    width: parent.width
    label: "Right click"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.rightClickOptions
    value: host.inputValue("touchpad.clickfinger_behavior", false) === true ? "twofinger" : "corner"
    onChanged: function(v) { host.setInput("touchpad.clickfinger_behavior", v === "twofinger") }

    Connections {
      target: host
      function onInputStateChanged() {
        rightClickDropdown.value = host.inputValue("touchpad.clickfinger_behavior", false) === true ? "twofinger" : "corner"
      }
    }
  }

  Toggle {
    visible: root.isTouchpad
    width: parent.width
    label: "Tap to click"
    description: "A two-finger tap right-clicks"
    foreground: host.foreground
    accent: host.accent
    fontFamily: host.fontFamily
    checked: host.inputValue("touchpad.tap_to_click", false) === true
    onClicked: host.setInput("touchpad.tap_to_click", !checked)
  }

  Dropdown {
    id: swipeDropdown
    visible: root.isTouchpad
    width: parent.width
    label: "Workspace swipe"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.swipeOptions
    value: host.swipeValue
    onChanged: function(v) { host.setSwipe(v) }

    Connections {
      target: host
      function onSwipeValueChanged() { swipeDropdown.value = host.swipeValue }
    }
  }

  // ---- mouse only -------------------------------------------------------------
  Dropdown {
    id: accelDropdown
    visible: !root.isTouchpad
    width: parent.width
    label: "Pointer acceleration"
    fontFamily: host.fontFamily
    foreground: host.foreground
    accent: host.accent
    rowHeight: host.dropdownRowHeight
    popupRowHeight: host.dropdownRowHeight
    options: host.accelOptions
    value: host.inputValue("accel_profile", "adaptive")
    onChanged: function(v) { host.setInput("accel_profile", v) }

    Connections {
      target: host
      function onInputStateChanged() { accelDropdown.value = host.inputValue("accel_profile", "adaptive") }
    }
  }
}
