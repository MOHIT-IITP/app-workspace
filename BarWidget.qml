import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "mohiitp.app-workspaces"

  property var buttonsMap: ({})

  function registerButton(id, btn) {
    var next = {}
    for (var k in buttonsMap) next[k] = buttonsMap[k]
    next[id] = btn
    buttonsMap = next
  }

  function unregisterButton(id) {
    var next = {}
    for (var k in buttonsMap) {
      if (Number(k) !== Number(id)) next[k] = buttonsMap[k]
    }
    buttonsMap = next
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (Hyprland.dispatch) {
      Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    } else if (root.bar) {
      root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
    }
  }

  function focusWindow(address) {
    if (!address) return
    var addr = String(address)
    if (addr.indexOf("0x") !== 0) addr = "0x" + addr
    if (Hyprland.dispatch) {
      Hyprland.dispatch('hl.dsp.focus({window = hl.get_window("address:' + addr + '")})')
    } else if (root.bar) {
      root.bar.run("hyprctl dispatch " + Util.shellQuote('hl.dsp.focus({window = hl.get_window("address:' + addr + '")})'))
    }
  }

  property real wheelAccumulator: 0

  function scrollWorkspaces(delta) {
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return

    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeWsId)
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  function addCandidate(candidates, name) {
    if (!name || typeof name !== "string") return
    var clean = name.trim()
    if (clean.length === 0) return

    // Prefer symbolic icons first for clean monochrome look
    var sym = clean + "-symbolic"
    if (candidates.indexOf(sym) === -1) candidates.push(sym)

    if (candidates.indexOf(clean) === -1) candidates.push(clean)

    var lower = clean.toLowerCase()
    var lowerSym = lower + "-symbolic"
    if (candidates.indexOf(lowerSym) === -1) candidates.push(lowerSym)
    if (candidates.indexOf(lower) === -1) candidates.push(lower)

    if (clean.indexOf(".") !== -1) {
      var parts = clean.split(".")
      var lastPart = parts[parts.length - 1]
      if (lastPart) {
        var lastSym = lastPart + "-symbolic"
        if (candidates.indexOf(lastSym) === -1) candidates.push(lastSym)
        if (candidates.indexOf(lastPart) === -1) candidates.push(lastPart)
        var lastLower = lastPart.toLowerCase()
        if (candidates.indexOf(lastLower) === -1) candidates.push(lastLower)
      }
    }
  }

  function resolveIcon(toplevel) {
    if (!toplevel) return ""
    var candidates = []

    if (toplevel.wayland && toplevel.wayland.appId) {
      addCandidate(candidates, toplevel.wayland.appId)
    }

    if (toplevel.lastIpcObject) {
      addCandidate(candidates, toplevel.lastIpcObject["initialClass"])
      addCandidate(candidates, toplevel.lastIpcObject["class"])
    }

    for (var i = 0; i < candidates.length; i++) {
      var name = candidates[i]
      if (!name) continue

      if (root.bar && root.bar.shell && root.bar.shell.appLibrary) {
        var libSrc = root.bar.shell.appLibrary.iconSource(name)
        if (libSrc && libSrc.length > 0 && libSrc.indexOf("application-x-executable") === -1) {
          return libSrc
        }
      }

      var qsIcon = Quickshell.iconPath(name, true)
      if (qsIcon && qsIcon.length > 0 && qsIcon !== "image://icon/" && qsIcon.indexOf("application-x-executable") === -1) {
        return qsIcon
      }
    }

    if (candidates.length > 0 && candidates[0]) {
      return Quickshell.iconPath(candidates[0], true)
    }

    return ""
  }

  function workspaceAppList(ws, currentActiveAddress) {
    if (!ws || !ws.toplevels || !ws.toplevels.values) return []
    var tls = ws.toplevels.values
    var list = []
    var seen = {}

    for (var i = 0; i < tls.length; i++) {
      var tl = tls[i]
      if (!tl) continue
      var addr = String(tl.address || i)
      if (seen[addr]) continue
      seen[addr] = true

      var iconPath = resolveIcon(tl)
      if (!iconPath) continue

      var isAct = false
      if (currentActiveAddress && tl.address) {
        isAct = (currentActiveAddress === tl.address)
      } else {
        isAct = tl.activated === true
      }

      list.push({
        address: addr,
        title: String(tl.title || ""),
        icon: iconPath,
        activated: isAct
      })
    }

    return list
  }

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property int activeWsId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)
  readonly property var activeToplevel: Hyprland.activeToplevel
  readonly property string activeAddress: activeToplevel ? String(activeToplevel.address || "") : ""
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: root.vertical ? root.barSize : (grid.implicitWidth + trailingGap)
  implicitHeight: root.vertical ? grid.implicitHeight : root.barSize

  // Sliding active indicator with corner brackets
  Item {
    id: slidingReticle
    z: 0

    property bool ready: false

    readonly property var targetBtn: root.buttonsMap[root.activeWsId]

    visible: targetBtn !== undefined && targetBtn !== null && width > 0 && height > 0
    x: targetBtn ? grid.x + targetBtn.x : 0
    y: targetBtn ? grid.y + targetBtn.y : 0
    width: targetBtn ? (targetBtn.width > 0 ? targetBtn.width : targetBtn.fixedWidth) : 0
    height: targetBtn ? (targetBtn.height > 0 ? targetBtn.height : targetBtn.fixedHeight) : 0

    Behavior on x {
      enabled: slidingReticle.ready
      NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic }
    }
    Behavior on y {
      enabled: slidingReticle.ready
      NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic }
    }
    Behavior on width {
      enabled: slidingReticle.ready
      NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic }
    }
    Behavior on height {
      enabled: slidingReticle.ready
      NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic }
    }

    Component.onCompleted: Qt.callLater(function() { slidingReticle.ready = true })

    // Active workspace pill background
    Rectangle {
      id: activeBgPill
      anchors.fill: parent
      anchors.margins: Style.space(2)
      radius: Style.space(2)
      color: root.bar ? root.bar.background : Commons.Color.background
      opacity: 0.65
    }

    // Active workspace corner brackets: ┌ ┐ └ ┘
    Item {
      id: cornerFrame
      anchors.fill: parent
      anchors.margins: Style.space(2)

      readonly property color bracketColor: root.bar ? root.bar.barForeground : "#ffffff"
      readonly property real strokeWidth: Math.max(1.5, Style.space(1.5))
      readonly property real bracketLength: Style.space(5)

      // Top-Left corner ┌
      Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        width: cornerFrame.bracketLength
        height: cornerFrame.strokeWidth
        color: cornerFrame.bracketColor
      }
      Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        width: cornerFrame.strokeWidth
        height: cornerFrame.bracketLength
        color: cornerFrame.bracketColor
      }

      // Top-Right corner ┐
      Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: cornerFrame.bracketLength
        height: cornerFrame.strokeWidth
        color: cornerFrame.bracketColor
      }
      Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: cornerFrame.strokeWidth
        height: cornerFrame.bracketLength
        color: cornerFrame.bracketColor
      }

      // Bottom-Left corner └
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: cornerFrame.bracketLength
        height: cornerFrame.strokeWidth
        color: cornerFrame.bracketColor
      }
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: cornerFrame.strokeWidth
        height: cornerFrame.bracketLength
        color: cornerFrame.bracketColor
      }

      // Bottom-Right corner ┘
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: cornerFrame.bracketLength
        height: cornerFrame.strokeWidth
        color: cornerFrame.bracketColor
      }
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: cornerFrame.strokeWidth
        height: cornerFrame.bracketLength
        color: cornerFrame.bracketColor
      }
    }
  }

  GridLayout {
    id: grid
    z: 1
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(3)
    rowSpacing: root.vertical ? Style.space(3) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: wsBtn
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: root.activeWsId === modelData
        readonly property var appList: root.workspaceAppList(workspace, root.activeAddress)
        readonly property bool hasApps: appList.length > 0

        bar: root.bar
        text: modelData === 10 ? "0" : String(modelData)
        keepSpace: true
        labelVisible: false
        opacity: 1.0
        tooltipText: "Workspace " + modelData + (hasApps ? " (" + appList.length + " app" + (appList.length > 1 ? "s" : "") + ")" : "")

        fixedWidth: root.vertical
          ? root.barSize
          : (hasApps ? contentRow.implicitWidth + Style.space(20) : (focused ? Style.space(26) : Style.space(20)))

        fixedHeight: root.vertical
          ? (hasApps ? Math.max(root.barSize, contentCol.implicitHeight + Style.space(16)) : root.barSize)
          : root.barSize

        Layout.preferredWidth: fixedWidth
        Layout.preferredHeight: fixedHeight
        Layout.minimumWidth: fixedWidth
        Layout.maximumWidth: fixedWidth
        Layout.minimumHeight: fixedHeight
        Layout.maximumHeight: fixedHeight

        Behavior on fixedWidth {
          enabled: slidingReticle.ready
          NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic }
        }
        Behavior on fixedHeight {
          enabled: slidingReticle.ready
          NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic }
        }

        // Register button for sliding reticle tracking
        Component.onCompleted: root.registerButton(modelData, wsBtn)
        Component.onDestruction: if (root) root.unregisterButton(modelData)

        // Background for inactive occupied workspaces
        Rectangle {
          id: inactiveBgPill
          anchors.fill: parent
          anchors.margins: Style.space(2)
          radius: Style.space(2)
          color: root.bar ? root.bar.background : Commons.Color.background
          opacity: !wsBtn.focused && wsBtn.hasApps ? 0.25 : 0
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation { duration: Style.duration(140) }
          }
        }

        Component {
          id: appIconDelegate

          Item {
            id: iconSlot
            required property var modelData
            width: Style.space(16)
            height: Style.space(16)
            implicitWidth: Style.space(16)
            implicitHeight: Style.space(16)
            anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
            anchors.verticalCenter: !root.vertical ? parent.verticalCenter : undefined

            readonly property bool isCurrent: modelData.activated

            Image {
              id: rawIcon
              anchors.fill: parent
              source: modelData.icon
              sourceSize.width: Math.round(width * Screen.devicePixelRatio)
              sourceSize.height: Math.round(height * Screen.devicePixelRatio)
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              smooth: true
              visible: false
              layer.enabled: true
            }

            MultiEffect {
              anchors.fill: rawIcon
              source: rawIcon
              visible: rawIcon.status === Image.Ready
              colorization: 1.0
              colorizationColor: root.bar ? root.bar.barForeground : "#ffffff"
              opacity: iconSlot.isCurrent ? 1.0 : (appMouse.containsMouse ? 0.95 : (wsBtn.focused ? 0.75 : 0.55))

              Behavior on opacity {
                NumberAnimation { duration: Style.duration(140) }
              }
            }

            MouseArea {
              id: appMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                root.focusWindow(modelData.address)
              }
              onEntered: {
                if (root.bar && modelData.title) {
                  root.bar.showTooltip(iconSlot, modelData.title)
                }
              }
              onExited: {
                if (root.bar) root.bar.hideTooltip(iconSlot)
              }
              onWheel: function(wheel) {
                root.scrollWorkspaces(wheel.angleDelta.y)
              }
            }
          }
        }

        // Horizontal layout (for top / bottom bar)
        Row {
          id: contentRow
          visible: !root.vertical
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            id: wsLabelRow
            textFormat: Text.PlainText
            text: wsBtn.modelData === 10 ? "0" : String(wsBtn.modelData)
            color: root.bar ? root.bar.barForeground : Commons.Color.foreground
            font.bold: wsBtn.focused
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            renderType: Text.NativeRendering
            anchors.verticalCenter: parent.verticalCenter
            opacity: wsBtn.occupied || wsBtn.focused ? 1.0 : 0.45

            Behavior on color {
              enabled: !root.bar || root.bar.foregroundAnimationEnabled
              ColorAnimation { duration: Style.duration(160) }
            }
            Behavior on opacity {
              NumberAnimation { duration: Style.duration(140) }
            }
          }

          // Pipe separator between workspace number and open apps
          Text {
            visible: wsBtn.hasApps
            textFormat: Text.PlainText
            text: "|"
            color: root.bar ? root.bar.barForeground : Commons.Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            renderType: Text.NativeRendering
            opacity: wsBtn.focused ? 0.35 : 0.2
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color {
              enabled: !root.bar || root.bar.foregroundAnimationEnabled
              ColorAnimation { duration: Style.duration(160) }
            }
            Behavior on opacity {
              NumberAnimation { duration: Style.duration(140) }
            }
          }

          Repeater {
            model: !root.vertical ? wsBtn.appList : []
            delegate: appIconDelegate
          }
        }

        // Vertical layout (for left / right bar)
        Column {
          id: contentCol
          visible: root.vertical
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            id: wsLabelCol
            textFormat: Text.PlainText
            text: wsBtn.modelData === 10 ? "0" : String(wsBtn.modelData)
            color: root.bar ? root.bar.barForeground : Commons.Color.foreground
            font.bold: wsBtn.focused
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            renderType: Text.NativeRendering
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: wsBtn.occupied || wsBtn.focused ? 1.0 : 0.45

            Behavior on color {
              enabled: !root.bar || root.bar.foregroundAnimationEnabled
              ColorAnimation { duration: Style.duration(160) }
            }
            Behavior on opacity {
              NumberAnimation { duration: Style.duration(140) }
            }
          }

          // Dash separator between workspace number and open apps
          Rectangle {
            id: wsDividerCol
            visible: wsBtn.hasApps
            width: Style.space(8)
            height: 1
            implicitWidth: Style.space(8)
            implicitHeight: 1
            color: root.bar ? root.bar.barForeground : Commons.Color.foreground
            opacity: wsBtn.focused ? 0.35 : 0.2
            anchors.horizontalCenter: parent.horizontalCenter

            Behavior on color {
              enabled: !root.bar || root.bar.foregroundAnimationEnabled
              ColorAnimation { duration: Style.duration(160) }
            }
            Behavior on opacity {
              NumberAnimation { duration: Style.duration(140) }
            }
          }

          Repeater {
            model: root.vertical ? wsBtn.appList : []
            delegate: appIconDelegate
          }
        }

        onPressed: function() { root.focusWorkspace(modelData) }
        onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }
      }
    }
  }
}
