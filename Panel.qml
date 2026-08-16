import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "pcrisho.power-admin"
  ipcTarget: "pcrisho.power-admin"
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the setLimit/toggle methods below.
  manageIpc: false

  readonly property string sysPath: "/sys/bus/platform/devices/VPC2004:00/conservation_mode"
  property bool limitOn: false
  property bool pending: false
  property string lastError: ""

  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }
  readonly property int batteryPercent: {
    var device = UPower.displayDevice
    return device && device.isPresent ? Math.round(Number(device.percentage || 0) * 100) : -1
  }
  readonly property string batteryStateLabel: {
    var device = UPower.displayDevice
    if (!device || !device.isPresent) return ""
    if (UPower.onBattery) return "Discharging"
    if (device.state === UPowerDeviceState.Charging) return "Charging"
    if (device.state === UPowerDeviceState.FullyCharged) return "Fully charged"
    return "Plugged in"
  }

  function refresh() {
    if (!readProc.running) readProc.running = true
  }

  function setLimit(enabled) {
    if (pending) return
    pending = true
    lastError = ""
    toggleProc.command = [
      "pkexec", "sh", "-c",
      "echo " + (enabled ? "1" : "0") + " > " + root.sysPath
    ]
    toggleProc.running = true
  }

  function toggle() {
    setLimit(!root.limitOn)
  }

  IpcHandler {
    target: "pcrisho.power-admin"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function setLimit(enabled: string): string {
      root.setLimit(enabled === "on" || enabled === "true")
      return "ok"
    }
    function state(): string {
      return root.limitOn ? "on" : "off"
    }
  }

  Process {
    id: readProc
    command: ["sh", "-c", "cat " + root.sysPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.limitOn = String(text).trim() === "1"
    }
  }

  Process {
    id: toggleProc
    onExited: {
      root.pending = false
      root.refresh()
    }
  }

  // Keep the bar icon honest: conservation mode can also change from Lenovo
  // Vantage-style tools or a manual echo, so re-read periodically.
  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.limitOn ? "󰂅" : "󰁹"
    slotSize: Style.bar.iconSlot
    tooltipText: root.limitOn ? "Charge limit 80% ON" : "Full charge (limit OFF)"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.open()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.toggle()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: icon · title · battery state ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Text {
            id: heroIcon
            text: root.limitOn ? "󰂅" : "󰁹"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Power Administrator"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.limitOn ? "LIMIT ACTIVE · 80%" : "LIMIT OFF · FULL CHARGE"
              color: root.limitOn ? Color.accent : Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroPercent
            text: root.batteryPercent >= 0 ? root.batteryPercent + "%" : "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // ---------- Status ----------
        Text {
          width: parent.width
          text: (root.batteryPresent ? root.batteryStateLabel : "No battery detected") + (root.lastError !== "" ? "  ·  " + root.lastError : "")
          color: Qt.darker(root.bar.foreground, 1.3)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        // ---------- Toggle buttons ----------
        PanelSeparator {
          foreground: root.bar.foreground
        }

        Row {
          width: parent.width
          spacing: Style.space(6)

          readonly property real cellWidth: (width - spacing) / 2

          Button {
            width: parent.cellWidth
            iconText: "󰂅"
            iconSize: Style.font.title
            text: "Limit to 80%"
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
            bordered: true
            active: root.limitOn
            onClicked: root.setLimit(true)
          }

          Button {
            width: parent.cellWidth
            iconText: "󰁹"
            iconSize: Style.font.title
            text: "Full charge"
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
            bordered: true
            active: !root.limitOn
            onClicked: root.setLimit(false)
          }
        }

        // ---------- Note ----------
        Text {
          width: parent.width
          text: "The 80% limit is re-applied on every boot (battery-conservation.service). Disabling it here only lasts until the next restart."
          color: Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }
      }
    }
  }
}