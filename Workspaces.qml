import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  readonly property int slots: 10
  readonly property string pluginId: "elemental-workspace-indicator"

  // "elements" (Nerd Font elemental glyphs) or "alchemy" (Alchemical geometric symbols).
  property string localStyleOverride: ""
  readonly property string configuredStyle: root.settings && root.settings.style !== undefined && root.settings.style !== null
    ? String(root.settings.style)
    : ""
  readonly property string iconStyle: root.localStyleOverride !== ""
    ? root.localStyleOverride
    : (root.configuredStyle === "alchemy" ? "alchemy" : "elements")

  property bool pickerOpen: false
  property bool initialPromptShown: false

  function selectStyle(nextStyle) {
    var normalized = nextStyle === "alchemy" ? "alchemy" : "elements"
    root.localStyleOverride = normalized
    root.pickerOpen = false
    if (root.bar) {
      root.bar.run("omarchy-bar set " + Util.shellQuote(root.pluginId) + " style " + Util.shellQuote(normalized))
    }
  }

  onConfiguredStyleChanged: {
    if (root.configuredStyle !== "") {
      root.localStyleOverride = ""
    }
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

  // The 5 elements mapped across workspace slots (1-5, repeating for 6-10).
  // glyphScale normalizes each Nerd Font glyph's ink height to the exact same 12px target as the Alchemical symbols.
  readonly property real uniformIconSize: 12
  readonly property var elements: [
    { icon: "󰈸", glyphScale: 1.29, alchemySymbol: "🜂", alchemyKind: "fire",   name: "Fire",   color: "#FF6B35" },
    { icon: "󰖌", glyphScale: 1.38, alchemySymbol: "🜄", alchemyKind: "water",  name: "Water",  color: "#38BDF8" },
    { icon: "󰌪", glyphScale: 1.24, alchemySymbol: "🜃", alchemyKind: "earth",  name: "Earth",  color: "#4ADE80" },
    { icon: "󰖝", glyphScale: 1.19, alchemySymbol: "🜁", alchemyKind: "air",    name: "Air",    color: "#67E8F9" },
    { icon: "󱐋", glyphScale: 1.10, alchemySymbol: "✧",  alchemyKind: "aether", name: "Aether", color: "#C084FC" }
  ]

  function elementForSlot(slot) {
    var idx = ((slot - 1) % root.elements.length + root.elements.length) % root.elements.length
    return root.elements[idx]
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
        readonly property var element: root.elementForSlot(slot)
        readonly property bool useAlchemy: root.iconStyle === "alchemy"
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
        tooltipText: shown
          ? (slot + " · " + element.name + " (" + root.activeMode + ") · Right-click: style")
          : (slot + " · " + element.name + " · Right-click: style")
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(22)
        fixedHeight: root.barSize
        onPressed: function(button) {
          if (button === Qt.RightButton) {
            root.pickerOpen = !root.pickerOpen
            return
          }
          if (shown) root.cycleLayout()
          else root.focusWorkspace(modelData)
        }
        onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }

        // Uniform-size Nerd Font elemental glyph renderer (exact 12px ink height across all 5 elements).
        Text {
          visible: !wsBtn.useAlchemy
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -1
          textFormat: Text.PlainText
          text: wsBtn.element.icon
          color: wsBtn.element.color
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Math.round(root.uniformIconSize * wsBtn.element.glyphScale)
          renderType: Text.CurveRendering
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          scale: wsBtn.pressScale
        }

        // Uniform-size vector Alchemical symbol renderer (exact 12px outer bounds matching the elemental glyphs).
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
            // Inset by half the stroke width so the outer painted bounds equal root.uniformIconSize (12px).
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
              // Upward triangle △
              ctx.beginPath()
              ctx.moveTo(midX, top)
              ctx.lineTo(right, bottom)
              ctx.lineTo(left, bottom)
              ctx.closePath()
              ctx.stroke()
              if (kind === "air") {
                // Horizontal crossbar for Air 🜁
                var barY = top + span * 0.48
                ctx.beginPath()
                ctx.moveTo(left + span * 0.1, barY)
                ctx.lineTo(right - span * 0.1, barY)
                ctx.stroke()
              }
            } else if (kind === "water" || kind === "earth") {
              // Downward triangle ▽
              ctx.beginPath()
              ctx.moveTo(left, top)
              ctx.lineTo(right, top)
              ctx.lineTo(midX, bottom)
              ctx.closePath()
              ctx.stroke()
              if (kind === "earth") {
                // Horizontal crossbar for Earth 🜃
                var eBarY = top + span * 0.52
                ctx.beginPath()
                ctx.moveTo(left + span * 0.1, eBarY)
                ctx.lineTo(right - span * 0.1, eBarY)
                ctx.stroke()
              }
            } else {
              // Aether / Quintessence 4-pointed star ✧
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

  // Style selector popup (opens automatically on initial install when style is unset, or on right-click).
  PopupCard {
    id: stylePopup
    anchorItem: root
    bar: root.bar
    open: root.pickerOpen
    onOpenChanged: if (!open) root.pickerOpen = false
    contentWidth: Style.space(260)
    contentHeight: styleColumn.implicitHeight + padding * 2

    ColumnLayout {
      id: styleColumn
      anchors.fill: parent
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: "Workspace Symbol Style"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Button {
        Layout.fillWidth: true
        bordered: true
        text: "󰈸 󰖌 󰌪 󰖝 󱐋   Elemental Icons"
        selected: root.iconStyle === "elements"
        onClicked: root.selectStyle("elements")
      }

      Button {
        Layout.fillWidth: true
        bordered: true
        text: "🜂 🜄 🜃 🜁 ✧   Alchemical Symbols"
        selected: root.iconStyle === "alchemy"
        onClicked: root.selectStyle("alchemy")
      }
    }
  }
}
