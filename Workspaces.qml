import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  readonly property int slots: 10
  readonly property string pluginId: "elemental-workspace-indicator"

  // Supported styles: "elements" | "alchemy" | "godai" | "wuxing"
  property string localStyleOverride: ""
  readonly property string configuredStyle: root.settings && root.settings.style !== undefined && root.settings.style !== null
    ? String(root.settings.style)
    : ""
  readonly property string iconStyle: {
    var candidate = root.localStyleOverride !== "" ? root.localStyleOverride : root.configuredStyle
    if (candidate === "alchemy" || candidate === "godai" || candidate === "wuxing") return candidate
    return "elements"
  }

  // Floating hover preview setting (defaults to true)
  property int localPreviewOverride: -1 // -1 = unset, 0 = false, 1 = true
  readonly property bool configuredPreview: {
    if (!root.settings || root.settings.showPreview === undefined || root.settings.showPreview === null) return true
    var val = root.settings.showPreview
    if (typeof val === "boolean") return val
    return String(val).toLowerCase() !== "false" && String(val) !== "0"
  }
  readonly property bool showPreview: root.localPreviewOverride !== -1
    ? (root.localPreviewOverride === 1)
    : root.configuredPreview

  property bool pickerOpen: false
  property bool initialPromptShown: false
  readonly property var styleOrder: ["elements", "alchemy", "godai", "wuxing"]

  // Hover preview state
  property int hoveredWorkspaceId: -1
  property Item hoveredAnchorItem: null
  property bool previewOpen: false

  function close() {
    root.pickerOpen = false
  }

  function selectStyle(nextStyle) {
    var normalized = (nextStyle === "alchemy" || nextStyle === "godai" || nextStyle === "wuxing")
      ? nextStyle : "elements"
    root.localStyleOverride = normalized
    root.pickerOpen = false
    if (root.bar) {
      root.bar.run("omarchy-bar set " + Util.shellQuote(root.pluginId) + " style " + Util.shellQuote(normalized))
    }
  }

  function cycleStyle() {
    var currentIndex = root.styleOrder.indexOf(root.iconStyle)
    var nextStyle = root.styleOrder[(currentIndex + 1) % root.styleOrder.length]
    root.localStyleOverride = nextStyle
    root.previewOpen = false
    root.pickerOpen = true
    if (root.bar) {
      root.bar.run("omarchy-bar set " + Util.shellQuote(root.pluginId) + " style " + Util.shellQuote(nextStyle))
    }
  }

  function togglePreview() {
    var nextVal = !root.showPreview
    root.localPreviewOverride = nextVal ? 1 : 0
    if (!nextVal) root.previewOpen = false
    if (root.bar) {
      root.bar.run("omarchy-bar set " + Util.shellQuote(root.pluginId) + " showPreview " + (nextVal ? "true" : "false"))
    }
  }

  onConfiguredStyleChanged: {
    if (root.configuredStyle !== "") {
      root.localStyleOverride = ""
    }
  }

  onConfiguredPreviewChanged: {
    root.localPreviewOverride = -1
  }

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""

  // Connector -> block, from the file Hyprland keeps them in.
  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  function blockOf(id) {
    return Math.floor((id - 1) / root.slots)
  }

  function slotOf(id) {
    return (id - 1) % root.slots + 1
  }

  function activeWorkspaceId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }

  readonly property int block: {
    var block = root.blocks[root.monitorName]
    if (block !== undefined) return block
    var active = root.activeWorkspaceId()
    return active > 0 ? root.blockOf(active) : 0
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function workspaceIds() {
    var base = root.block * root.slots
    var ids = [base + 1, base + 2, base + 3, base + 4, base + 5]
    var guests = []
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id <= 0) continue
      if (root.blockOf(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (values[i].monitor && values[i].monitor.name === root.monitorName) {
        guests.push(id)
      }
    }

    ids.sort(function(left, right) { return left - right })
    guests.sort(function(left, right) { return left - right })
    return ids.concat(guests)
  }

  function dispatch(expression) {
    if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote(expression))
  }

  function focusWorkspace(id) {
    if (root.blockOf(id) === root.block) {
      root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")")
    } else {
      root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    }
  }

  function focusWindow(toplevelObj, workspaceId) {
    root.previewOpen = false
    if (!toplevelObj) {
      if (workspaceId > 0) root.focusWorkspace(workspaceId)
      return
    }
    var address = String(toplevelObj.address || "")
    if (address) {
      if (address.indexOf("0x") !== 0) address = "0x" + address
      root.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })")
    } else if (toplevelObj.wayland) {
      toplevelObj.wayland.activate()
    } else if (workspaceId > 0) {
      root.focusWorkspace(workspaceId)
    }
  }

  property real wheelAccumulator: 0

  function scrollWorkspaces(delta) {
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return

    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeWorkspaceId())
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  // Uniform 12px optical height across all 4 symbol packs.
  readonly property real uniformIconSize: 12

  readonly property var packs: ({
    elements: [
      { icon: "󰈸", glyphScale: 1.29, alchemyKind: "fire",   name: "Fire",   color: "#FF6B35" },
      { icon: "󰖌", glyphScale: 1.38, alchemyKind: "water",  name: "Water",  color: "#38BDF8" },
      { icon: "󰌪", glyphScale: 1.24, alchemyKind: "earth",  name: "Earth",  color: "#4ADE80" },
      { icon: "󰖝", glyphScale: 1.19, alchemyKind: "air",    name: "Air",    color: "#67E8F9" },
      { icon: "󱐋", glyphScale: 1.10, alchemyKind: "aether", name: "Aether", color: "#C084FC" }
    ],
    alchemy: [
      { icon: "🜂", glyphScale: 1.0,  alchemyKind: "fire",   name: "Fire (🜂)",   color: "#FF6B35" },
      { icon: "🜄", glyphScale: 1.0,  alchemyKind: "water",  name: "Water (🜄)",  color: "#38BDF8" },
      { icon: "🜃", glyphScale: 1.0,  alchemyKind: "earth",  name: "Earth (🜃)",  color: "#4ADE80" },
      { icon: "🜁", glyphScale: 1.0,  alchemyKind: "air",    name: "Air (🜁)",    color: "#67E8F9" },
      { icon: "✧",  glyphScale: 1.0,  alchemyKind: "aether", name: "Aether (✧)", color: "#C084FC" }
    ],
    godai: [
      { icon: "地", glyphScale: 1.09, alchemyKind: "earth",  name: "Chi · Earth (地)", color: "#4ADE80" },
      { icon: "水", glyphScale: 1.07, alchemyKind: "water",  name: "Sui · Water (水)", color: "#38BDF8" },
      { icon: "火", glyphScale: 1.09, alchemyKind: "fire",   name: "Ka · Fire (火)",   color: "#FF6B35" },
      { icon: "風", glyphScale: 1.11, alchemyKind: "air",    name: "Fū · Wind (風)",   color: "#67E8F9" },
      { icon: "空", glyphScale: 1.10, alchemyKind: "aether", name: "Kū · Void (空)",   color: "#C084FC" }
    ],
    wuxing: [
      { icon: "木", glyphScale: 1.07, alchemyKind: "earth",  name: "Mù · Wood (木)",   color: "#4ADE80" },
      { icon: "火", glyphScale: 1.09, alchemyKind: "fire",   name: "Huǒ · Fire (火)",  color: "#FF6B35" },
      { icon: "土", glyphScale: 1.11, alchemyKind: "earth",  name: "Tǔ · Earth (土)",  color: "#FBBF24" },
      { icon: "金", glyphScale: 1.09, alchemyKind: "air",    name: "Jīn · Metal (金)", color: "#E2E8F0" },
      { icon: "水", glyphScale: 1.07, alchemyKind: "water",  name: "Shuǐ · Water (水)", color: "#38BDF8" }
    ]
  })

  function elementForSlot(slot, styleName) {
    var list = root.packs[styleName] || root.packs.elements
    var idx = ((slot - 1) % list.length + list.length) % list.length
    return list[idx]
  }

  property string activeMode: "dwindle"
  property bool modeStale: false

  function modeGlyph(mode) {
    if (mode === "scrolling") return "󰝥"
    if (mode === "floating") return "󰔶"
    return "󱓻"
  }

  property var modeCache: ({})
  property int modeGeneration: 0
  property int modeProcWorkspace: -1
  property int modeProcGeneration: 0

  function showActiveMode() {
    var mode = root.modeCache[root.activeWorkspaceId()]
    if (mode !== undefined) root.activeMode = mode
    else readMode()
  }

  function readMode() {
    if (modeProc.running) {
      root.modeStale = true
      return
    }
    var id = root.activeWorkspaceId()
    if (id === -1) return
    root.modeProcWorkspace = id
    root.modeProcGeneration = root.modeGeneration
    modeProc.command = ["omarchy-hyprland-workspace-layout-current", String(id)]
    modeProc.running = true
  }

  function refresh() {
    root.modeCache = ({})
    root.modeGeneration++
    readMode()
  }

  function cycleLayout() {
    if (!root.bar) return
    var command = "omarchy-hyprland-workspace-layout-toggle"
    if (root.monitor && !root.monitor.focused) {
      command = "hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ monitor = \"" + root.monitorName + "\" })") + " >/dev/null && " + command
    }
    root.bar.run(command)
  }

  Component.onCompleted: {
    refresh()
    initialPromptTimer.start()
  }
  onMonitorChanged: root.showActiveMode()

  // Show the style picker automatically on first install when no style is stored in shell.json yet.
  Timer {
    id: initialPromptTimer
    interval: 600
    repeat: false
    onTriggered: {
      if (!root.initialPromptShown && root.configuredStyle === "" && (!root.monitor || root.monitor.focused)) {
        root.initialPromptShown = true
        root.pickerOpen = true
      }
    }
  }

  // Hover preview timers: quick open on hover, smooth grace period when moving pointer into preview card.
  Timer {
    id: previewOpenTimer
    interval: 120
    repeat: false
    onTriggered: {
      if (root.showPreview && !root.pickerOpen && root.hoveredWorkspaceId > 0) {
        Hyprland.refreshToplevels()
        root.previewOpen = true
      }
    }
  }

  Timer {
    id: previewCloseTimer
    interval: 180
    repeat: false
    onTriggered: {
      if (!previewPopup.containsMouse) {
        root.previewOpen = false
      }
    }
  }

  function handleButtonHover(wsId, buttonItem, isHovered) {
    if (isHovered) {
      previewCloseTimer.stop()
      root.hoveredWorkspaceId = wsId
      root.hoveredAnchorItem = buttonItem
      if (root.showPreview && !root.pickerOpen) {
        if (root.previewOpen) {
          Hyprland.refreshToplevels()
        } else {
          previewOpenTimer.restart()
        }
      }
    } else {
      previewOpenTimer.stop()
      previewCloseTimer.restart()
    }
  }

  Connections {
    target: root.monitor
    function onActiveWorkspaceChanged() { root.showActiveMode() }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "configreloaded") root.refresh()
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
      if (name === "openwindow" || name === "closewindow" || name === "movewindow" || name === "movewindowv2") {
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
      }
    }
  }

  Process {
    id: modeProc
    stdout: StdioCollector {
      onStreamFinished: {
        var mode = text.trim()
        if (!mode || root.modeProcGeneration !== root.modeGeneration) return
        root.modeCache[root.modeProcWorkspace] = mode
        if (root.modeProcWorkspace === root.activeWorkspaceId()) root.activeMode = mode
      }
    }
    onExited: {
      if (!root.modeStale) return
      root.modeStale = false
      Qt.callLater(root.showActiveMode)
    }
  }

  ShellIpc {
    target: "omarchy.workspaces"

    function refresh(): void { root.broadcast("refresh") }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: wsBtn
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool shown: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === modelData
        readonly property int slot: root.slotOf(modelData)
        readonly property var element: root.elementForSlot(slot, root.iconStyle)
        readonly property bool useAlchemy: root.iconStyle === "alchemy"
        readonly property bool isCjk: root.iconStyle === "godai" || root.iconStyle === "wuxing"
        readonly property bool firstGuest: root.blockOf(modelData) !== root.block && index > 0 && root.blockOf(root.workspaceIds()[index - 1]) === root.block
        required property int index

        Layout.leftMargin: firstGuest && !root.vertical ? Style.space(6) : 0
        Layout.topMargin: firstGuest && root.vertical ? Style.space(6) : 0

        bar: root.bar
        text: element.icon
        labelVisible: false
        hasVisualContent: true
        active: shown
        activeColor: element.color
        foreground: element.color
        opacity: shown ? 1.0 : (occupied ? 0.78 : 0.4)
        // Only show plain bar tooltip when floating preview is disabled
        tooltipText: root.showPreview ? "" : (shown
          ? (slot + " · " + element.name + " (" + root.activeMode + ") · Right-click: style")
          : (slot + " · " + element.name + " · Right-click: style"))
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(22)
        fixedHeight: root.barSize

        onTooltipHoveredChanged: {
          root.handleButtonHover(modelData, wsBtn, tooltipHovered)
        }

        onPressed: function(button) {
          if (button === Qt.RightButton) {
            root.cycleStyle()
            return
          }
          root.previewOpen = false
          if (shown) root.cycleLayout()
          else root.focusWorkspace(modelData)
        }
        onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }

        // Uniform-size glyph/kanji renderer (exact 12px ink height across elements, godai, and wuxing).
        Text {
          visible: !wsBtn.useAlchemy
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -1
          textFormat: Text.PlainText
          text: wsBtn.element.icon
          color: wsBtn.element.color
          font.family: wsBtn.isCjk ? "Noto Sans CJK JP" : (root.bar ? root.bar.fontFamily : Style.font.family)
          font.weight: wsBtn.isCjk ? Font.DemiBold : Font.Normal
          font.pixelSize: Math.round(root.uniformIconSize * wsBtn.element.glyphScale)
          renderType: Text.CurveRendering
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          scale: wsBtn.pressScale
        }

        // Uniform-size vector Alchemical symbol renderer (exact 12px outer bounds matching the other packs).
        Canvas {
          id: alchemyCanvas
          visible: wsBtn.useAlchemy
          width: 16
          height: 16
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -1
          scale: wsBtn.pressScale
          antialiasing: true

          property string kind: wsBtn.element.alchemyKind
          property color strokeColor: wsBtn.element.color

          onKindChanged: requestPaint()
          onStrokeColorChanged: requestPaint()
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()

          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width
            var h = height
            var targetSize = root.uniformIconSize
            var lw = 1.4
            var span = targetSize - lw
            var midX = w / 2
            var midY = h / 2
            var left = midX - span / 2
            var right = midX + span / 2
            var top = midY - span / 2
            var bottom = midY + span / 2

            ctx.strokeStyle = String(strokeColor)
            ctx.lineWidth = lw
            ctx.lineJoin = "round"
            ctx.lineCap = "round"

            if (kind === "fire" || kind === "air") {
              ctx.beginPath()
              ctx.moveTo(midX, top)
              ctx.lineTo(right, bottom)
              ctx.lineTo(left, bottom)
              ctx.closePath()
              ctx.stroke()
              if (kind === "air") {
                var barY = top + span * 0.48
                ctx.beginPath()
                ctx.moveTo(left + span * 0.1, barY)
                ctx.lineTo(right - span * 0.1, barY)
                ctx.stroke()
              }
            } else if (kind === "water" || kind === "earth") {
              ctx.beginPath()
              ctx.moveTo(left, top)
              ctx.lineTo(right, top)
              ctx.lineTo(midX, bottom)
              ctx.closePath()
              ctx.stroke()
              if (kind === "earth") {
                var eBarY = top + span * 0.52
                ctx.beginPath()
                ctx.moveTo(left + span * 0.1, eBarY)
                ctx.lineTo(right - span * 0.1, eBarY)
                ctx.stroke()
              }
            } else {
              var inner = span * 0.22
              ctx.beginPath()
              ctx.moveTo(midX, top)
              ctx.lineTo(midX + inner, midY - inner)
              ctx.lineTo(right, midY)
              ctx.lineTo(midX + inner, midY + inner)
              ctx.lineTo(midX, bottom)
              ctx.lineTo(midX - inner, midY + inner)
              ctx.lineTo(left, midY)
              ctx.lineTo(midX - inner, midY - inner)
              ctx.closePath()
              ctx.stroke()
            }
          }
        }

        Rectangle {
          width: root.vertical ? 2 : 10
          height: root.vertical ? 10 : 2
          radius: 1
          color: wsBtn.element.color
          anchors.bottom: root.vertical ? undefined : parent.bottom
          anchors.bottomMargin: root.vertical ? 0 : 2
          anchors.left: root.vertical ? parent.left : undefined
          anchors.leftMargin: root.vertical ? 2 : 0
          anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
          anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined
          opacity: wsBtn.shown ? 1 : 0
          scale: wsBtn.shown ? 1 : 0.95

          Behavior on opacity {
            NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic }
          }
          Behavior on scale {
            NumberAnimation { duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
          }
        }
      }
    }
  }

  // Floating Workspace Preview Window (on hover)
  PopupCard {
    id: previewPopup
    anchorItem: root.hoveredAnchorItem ? root.hoveredAnchorItem : root
    bar: root.bar
    triggerMode: "hover"
    open: root.previewOpen && root.showPreview && !root.pickerOpen && root.hoveredWorkspaceId > 0

    readonly property int wsId: root.hoveredWorkspaceId > 0 ? root.hoveredWorkspaceId : 1
    readonly property int slot: root.slotOf(wsId)
    readonly property var element: root.elementForSlot(slot, root.iconStyle)
    readonly property var workspaceObj: root.workspaceById(wsId)
    readonly property var windowList: {
      if (!workspaceObj || !workspaceObj.toplevels) return []
      var raw = workspaceObj.toplevels.values
      var out = []
      for (var i = 0; i < raw.length && out.length < 4; i++) {
        if (raw[i]) out.push(raw[i])
      }
      return out
    }
    readonly property int totalWindowCount: workspaceObj && workspaceObj.toplevels ? workspaceObj.toplevels.values.length : 0
    readonly property bool isFocusedWs: root.activeWorkspaceId() === wsId
    readonly property string modeLabel: isFocusedWs ? root.activeMode : (root.modeCache[wsId] || "")

    borderColor: Qt.alpha(Qt.color(previewPopup.element.color), 0.55)

    readonly property real cardThumbW: Style.space(188)
    readonly property real cardThumbH: Style.space(116)
    readonly property int columnsCount: windowList.length <= 1 ? 1 : 2

    contentWidth: windowList.length === 0
      ? Style.space(224)
      : (columnsCount * cardThumbW + (columnsCount - 1) * Style.space(8) + padding * 2)
    contentHeight: previewColumn.implicitHeight + padding * 2

    onContainsMouseChanged: {
      if (containsMouse) {
        previewCloseTimer.stop()
      } else {
        previewCloseTimer.restart()
      }
    }

    ColumnLayout {
      id: previewColumn
      anchors.fill: parent
      spacing: Style.space(8)

      // Header row: Element icon + Workspace number & Element name + Window count / mode
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Item {
          width: 18
          height: 18
          Layout.alignment: Qt.AlignVCenter

          Text {
            visible: root.iconStyle !== "alchemy"
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: previewPopup.element.icon
            color: previewPopup.element.color
            font.family: (root.iconStyle === "godai" || root.iconStyle === "wuxing")
              ? "Noto Sans CJK JP"
              : (root.bar ? root.bar.fontFamily : Style.font.family)
            font.weight: (root.iconStyle === "godai" || root.iconStyle === "wuxing")
              ? Font.DemiBold : Font.Normal
            font.pixelSize: Math.round(root.uniformIconSize * previewPopup.element.glyphScale)
            renderType: Text.CurveRendering
          }

          Canvas {
            visible: root.iconStyle === "alchemy"
            width: 16
            height: 16
            anchors.centerIn: parent
            antialiasing: true
            property string kind: previewPopup.element.alchemyKind
            property color strokeColor: previewPopup.element.color
            onKindChanged: requestPaint()
            onStrokeColorChanged: requestPaint()
            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              var targetSize = root.uniformIconSize
              var lw = 1.4
              var span = targetSize - lw
              var midX = width / 2
              var midY = height / 2
              var left = midX - span / 2
              var right = midX + span / 2
              var top = midY - span / 2
              var bottom = midY + span / 2
              ctx.strokeStyle = String(strokeColor)
              ctx.lineWidth = lw
              ctx.lineJoin = "round"
              ctx.lineCap = "round"
              if (kind === "fire" || kind === "air") {
                ctx.beginPath()
                ctx.moveTo(midX, top)
                ctx.lineTo(right, bottom)
                ctx.lineTo(left, bottom)
                ctx.closePath()
                ctx.stroke()
                if (kind === "air") {
                  var barY = top + span * 0.48
                  ctx.beginPath()
                  ctx.moveTo(left + span * 0.1, barY)
                  ctx.lineTo(right - span * 0.1, barY)
                  ctx.stroke()
                }
              } else if (kind === "water" || kind === "earth") {
                ctx.beginPath()
                ctx.moveTo(left, top)
                ctx.lineTo(right, top)
                ctx.lineTo(midX, bottom)
                ctx.closePath()
                ctx.stroke()
                if (kind === "earth") {
                  var eBarY = top + span * 0.52
                  ctx.beginPath()
                  ctx.moveTo(left + span * 0.1, eBarY)
                  ctx.lineTo(right - span * 0.1, eBarY)
                  ctx.stroke()
                }
              } else {
                var inner = span * 0.22
                ctx.beginPath()
                ctx.moveTo(midX, top)
                ctx.lineTo(midX + inner, midY - inner)
                ctx.lineTo(right, midY)
                ctx.lineTo(midX + inner, midY + inner)
                ctx.lineTo(midX, bottom)
                ctx.lineTo(midX - inner, midY + inner)
                ctx.lineTo(left, midY)
                ctx.lineTo(midX - inner, midY - inner)
                ctx.closePath()
                ctx.stroke()
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          textFormat: Text.PlainText
          text: previewPopup.slot + " · " + previewPopup.element.name
          color: previewPopup.element.color
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          Layout.alignment: Qt.AlignVCenter
          textFormat: Text.PlainText
          text: previewPopup.totalWindowCount === 0
            ? (previewPopup.modeLabel ? previewPopup.modeLabel : "Empty")
            : (previewPopup.totalWindowCount + (previewPopup.totalWindowCount === 1 ? " window" : " windows"))
          color: Color.foreground
          opacity: 0.6
          font.family: Style.font.family
          font.pixelSize: Style.font.small || 11
        }
      }

      // Empty workspace placeholder card
      Rectangle {
        visible: previewPopup.windowList.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(64)
        radius: Math.max(4, Style.cornerRadius - 2)
        color: Qt.rgba(1, 1, 1, emptyMouse.containsMouse ? 0.08 : 0.04)
        border.width: 1
        border.color: emptyMouse.containsMouse ? previewPopup.element.color : Qt.rgba(1, 1, 1, 0.08)

        Behavior on color { ColorAnimation { duration: Style.duration(140) } }
        Behavior on border.color { ColorAnimation { duration: Style.duration(140) } }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.space(2)

          Text {
            Layout.alignment: Qt.AlignHCenter
            textFormat: Text.PlainText
            text: previewPopup.isFocusedWs ? "Active Workspace (Empty)" : "Empty Workspace"
            color: Color.foreground
            opacity: 0.75
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            textFormat: Text.PlainText
            text: previewPopup.isFocusedWs ? "Click bar icon to cycle layout" : "Click to switch workspace"
            color: Color.foreground
            opacity: 0.45
            font.family: Style.font.family
            font.pixelSize: Style.font.small || 11
          }
        }

        MouseArea {
          id: emptyMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.previewOpen = false
            root.focusWorkspace(previewPopup.wsId)
          }
        }
      }

      // Live Window Thumbnails Grid
      GridLayout {
        visible: previewPopup.windowList.length > 0
        Layout.fillWidth: true
        columns: previewPopup.columnsCount
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(8)

        Repeater {
          model: previewPopup.windowList

          Rectangle {
            id: winCard
            required property var modelData
            readonly property var waylandToplevel: modelData ? modelData.wayland : null
            readonly property string winTitle: (modelData && modelData.title)
              ? String(modelData.title)
              : (waylandToplevel && waylandToplevel.title ? String(waylandToplevel.title) : "Window")
            readonly property string winClass: (modelData && modelData.lastIpcObject && modelData.lastIpcObject.class)
              ? String(modelData.lastIpcObject.class)
              : (waylandToplevel && waylandToplevel.appId ? String(waylandToplevel.appId) : "")
            readonly property bool winActive: modelData ? Boolean(modelData.activated) : false

            Layout.preferredWidth: previewPopup.cardThumbW
            Layout.preferredHeight: previewPopup.cardThumbH
            radius: Math.max(4, Style.cornerRadius - 2)
            color: Qt.rgba(0, 0, 0, 0.28)
            border.width: (winMouse.containsMouse || winActive) ? 1.5 : 1
            border.color: winMouse.containsMouse
              ? previewPopup.element.color
              : (winActive ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.1))
            clip: true

            Behavior on border.color { ColorAnimation { duration: Style.duration(140) } }

            // Thumbnail viewport area
            Item {
              id: thumbViewport
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: titleBar.top
              anchors.margins: 3
              anchors.bottomMargin: 0
              clip: true

              // Live Wayland ScreencopyView
              ScreencopyView {
                id: screencopy
                anchors.centerIn: parent
                captureSource: (previewPopup.open && winCard.waylandToplevel) ? winCard.waylandToplevel : null
                live: previewPopup.open && winCard.waylandToplevel !== null
                paintCursor: false
                constraintSize: Qt.size(320, 200)

                readonly property real aspect: (sourceSize.width > 0 && sourceSize.height > 0)
                  ? (sourceSize.width / sourceSize.height)
                  : (16.0 / 10.0)
                readonly property real availW: Math.max(1, thumbViewport.width)
                readonly property real availH: Math.max(1, thumbViewport.height)

                width: (availW / availH > aspect) ? Math.round(availH * aspect) : availW
                height: (availW / availH > aspect) ? availH : Math.round(availW / aspect)
              }

              // Fallback label when window buffer is not yet captured
              Text {
                visible: !screencopy.hasContent
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: winCard.winClass || winCard.winTitle
                color: Color.foreground
                opacity: 0.45
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }
            }

            // Bottom title strip
            Rectangle {
              id: titleBar
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: Style.space(24)
              color: winMouse.containsMouse
                ? Qt.rgba(0, 0, 0, 0.65)
                : Qt.rgba(0, 0, 0, 0.48)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(4)

                Rectangle {
                  visible: winCard.winActive
                  width: 5
                  height: 5
                  radius: 2.5
                  color: previewPopup.element.color
                  Layout.alignment: Qt.AlignVCenter
                }

                Text {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  textFormat: Text.PlainText
                  text: winCard.winTitle
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.small || 11
                  elide: Text.ElideRight
                }
              }
            }

            MouseArea {
              id: winMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.focusWindow(winCard.modelData, previewPopup.wsId)
            }
          }
        }
      }

      // Overflow footer when > 4 windows are on the workspace
      Text {
        visible: previewPopup.totalWindowCount > 4
        Layout.alignment: Qt.AlignRight
        textFormat: Text.PlainText
        text: "+" + (previewPopup.totalWindowCount - 4) + " more"
        color: Color.foreground
        opacity: 0.55
        font.family: Style.font.family
        font.pixelSize: Style.font.small || 11
      }
    }
  }

  // Style selector popup (opens automatically on initial install when style is unset, or on right-click).
  PopupCard {
    id: stylePopup
    owner: root
    anchorItem: root
    bar: root.bar
    open: root.pickerOpen
    contentWidth: Style.space(296)
    contentHeight: styleColumn.implicitHeight + padding * 2

    readonly property var styleChoices: [
      { key: "elements", label: "Elemental Icons" },
      { key: "alchemy",  label: "Alchemical Symbols" },
      { key: "godai",    label: "Japanese Godai" },
      { key: "wuxing",   label: "Chinese Wu Xing" }
    ]

    ColumnLayout {
      id: styleColumn
      anchors.fill: parent
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: "Workspace Symbol Style"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        Layout.bottomMargin: Style.space(2)
      }

      Repeater {
        model: stylePopup.styleChoices

        Button {
          id: choiceBtn
          required property var modelData
          readonly property string choiceKey: modelData.key
          readonly property var packList: root.packs[choiceKey] || root.packs.elements

          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(32)
          bordered: true
          selected: root.iconStyle === choiceKey
          onClicked: root.selectStyle(choiceKey)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(10)

            // Fixed-width 5-slot icon preview grid so all 4 rows align vertically and horizontally.
            Row {
              Layout.preferredWidth: 100
              Layout.alignment: Qt.AlignVCenter
              spacing: 4

              Repeater {
                model: choiceBtn.packList

                Item {
                  required property var modelData
                  width: 16
                  height: 16

                  Text {
                    visible: choiceBtn.choiceKey !== "alchemy"
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData.icon
                    color: modelData.color
                    font.family: (choiceBtn.choiceKey === "godai" || choiceBtn.choiceKey === "wuxing")
                      ? "Noto Sans CJK JP"
                      : (root.bar ? root.bar.fontFamily : Style.font.family)
                    font.weight: (choiceBtn.choiceKey === "godai" || choiceBtn.choiceKey === "wuxing")
                      ? Font.DemiBold : Font.Normal
                    font.pixelSize: Math.round(root.uniformIconSize * modelData.glyphScale)
                    renderType: Text.CurveRendering
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }

                  Canvas {
                    visible: choiceBtn.choiceKey === "alchemy"
                    width: 16
                    height: 16
                    anchors.centerIn: parent
                    antialiasing: true
                    property string kind: modelData.alchemyKind
                    property color strokeColor: modelData.color

                    onPaint: {
                      var ctx = getContext("2d")
                      ctx.reset()
                      var targetSize = root.uniformIconSize
                      var lw = 1.4
                      var span = targetSize - lw
                      var midX = width / 2
                      var midY = height / 2
                      var left = midX - span / 2
                      var right = midX + span / 2
                      var top = midY - span / 2
                      var bottom = midY + span / 2

                      ctx.strokeStyle = String(strokeColor)
                      ctx.lineWidth = lw
                      ctx.lineJoin = "round"
                      ctx.lineCap = "round"

                      if (kind === "fire" || kind === "air") {
                        ctx.beginPath()
                        ctx.moveTo(midX, top)
                        ctx.lineTo(right, bottom)
                        ctx.lineTo(left, bottom)
                        ctx.closePath()
                        ctx.stroke()
                        if (kind === "air") {
                          var barY = top + span * 0.48
                          ctx.beginPath()
                          ctx.moveTo(left + span * 0.1, barY)
                          ctx.lineTo(right - span * 0.1, barY)
                          ctx.stroke()
                        }
                      } else if (kind === "water" || kind === "earth") {
                        ctx.beginPath()
                        ctx.moveTo(left, top)
                        ctx.lineTo(right, top)
                        ctx.lineTo(midX, bottom)
                        ctx.closePath()
                        ctx.stroke()
                        if (kind === "earth") {
                          var eBarY = top + span * 0.52
                          ctx.beginPath()
                          ctx.moveTo(left + span * 0.1, eBarY)
                          ctx.lineTo(right - span * 0.1, eBarY)
                          ctx.stroke()
                        }
                      } else {
                        var inner = span * 0.22
                        ctx.beginPath()
                        ctx.moveTo(midX, top)
                        ctx.lineTo(midX + inner, midY - inner)
                        ctx.lineTo(right, midY)
                        ctx.lineTo(midX + inner, midY + inner)
                        ctx.lineTo(midX, bottom)
                        ctx.lineTo(midX - inner, midY + inner)
                        ctx.lineTo(left, midY)
                        ctx.lineTo(midX - inner, midY - inner)
                        ctx.closePath()
                        ctx.stroke()
                      }
                    }
                  }
                }
              }
            }

            // Left-aligned style label starting at the exact same column across all 4 rows.
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText
              text: choiceBtn.modelData.label
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignLeft
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }
          }
        }
      }

      // Divider & toggle for Floating Hover Preview
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: Style.space(2)
        Layout.bottomMargin: Style.space(2)
        color: Color.foreground
        opacity: 0.12
      }

      Button {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(30)
        bordered: true
        selected: root.showPreview
        onClicked: root.togglePreview()

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(10)

          Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            textFormat: Text.PlainText
            text: "Floating Hover Preview"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }

          Text {
            Layout.alignment: Qt.AlignVCenter
            textFormat: Text.PlainText
            text: root.showPreview ? "ON" : "OFF"
            color: root.showPreview ? "#4ADE80" : Color.foreground
            opacity: root.showPreview ? 1.0 : 0.5
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
          }
        }
      }
    }
  }
}
