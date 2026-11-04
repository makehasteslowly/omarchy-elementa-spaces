import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  // Our own ID: the shell uses it to find this widget's settings and its copies
  // on other monitors. (It was "omarchy.workspaces", the built-in widget's.)
  moduleName: "makehasteslowly.elementa"

  // A skin's ground and edge, painted under a card's content (which sits
  // `inset` in from the card edge). Grounds: flat or softly graded color, rice
  // paper fibers, vellum with a darker edge, a silk sheen. Edge: one hairline on
  // continuous corners (Luminescence: a whisper of glow instead).
  component SkinGround: Canvas {
    property var skinSpec: null
    property color accent: Color.accent
    property real inset: 0
    property real radius: 0
    anchors.fill: parent
    anchors.margins: -inset
    z: -1
    visible: skinSpec !== null
    antialiasing: true
    onSkinSpecChanged: requestPaint()
    onAccentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var k = skinSpec
      if (!k) return
      var w = width, h = height, r = Math.min(radius, w / 2, h / 2)
      // Continuous ("squircle") corner: the curve starts 1.6 r from the corner
      // and eases in, instead of an abrupt quarter circle
      function shape(x, y, ww, hh, rr) {
        var c = Math.min(rr * 1.6, ww / 2, hh / 2), p = c * 0.2
        ctx.beginPath()
        ctx.moveTo(x + c, y)
        ctx.lineTo(x + ww - c, y);      ctx.bezierCurveTo(x + ww - p, y, x + ww, y + p, x + ww, y + c)
        ctx.lineTo(x + ww, y + hh - c); ctx.bezierCurveTo(x + ww, y + hh - p, x + ww - p, y + hh, x + ww - c, y + hh)
        ctx.lineTo(x + c, y + hh);      ctx.bezierCurveTo(x + p, y + hh, x, y + hh - p, x, y + hh - c)
        ctx.lineTo(x, y + c);           ctx.bezierCurveTo(x, y + p, x + p, y, x + c, y)
        ctx.closePath()
      }
      var seed = 7
      function rnd() { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }

      // ground
      shape(0.5, 0.5, w - 1, h - 1, r)
      ctx.save()
      ctx.clip()
      var g
      if (k.texture === "vellum") {
        g = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.2, w / 2, h / 2, Math.max(w, h) * 0.75)
        g.addColorStop(0, k.bg); g.addColorStop(1, k.bg2)
      } else if (k.bg2) {
        g = ctx.createLinearGradient(0, 0, 0, h)
        g.addColorStop(0, k.bg); g.addColorStop(1, k.bg2)
      } else g = k.bg
      ctx.fillStyle = g
      ctx.fillRect(0, 0, w, h)
      var i
      if (k.texture === "paper") {            // rice paper fibers
        ctx.strokeStyle = "rgba(90, 75, 55, 0.045)"; ctx.lineWidth = 0.6
        for (i = 0; i < Math.round(w * h / 90); i++) {
          var px = rnd() * w, py = rnd() * h, a = rnd() * Math.PI, l = 2 + rnd() * 7
          ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(px + Math.cos(a) * l, py + Math.sin(a) * l); ctx.stroke()
        }
      } else if (k.texture === "vellum") {    // age speckles
        ctx.fillStyle = "rgba(80, 55, 30, 0.06)"
        for (i = 0; i < Math.round(w * h / 160); i++) ctx.fillRect(rnd() * w, rnd() * h, 1, 1)
      } else if (k.texture === "sunburst") {  // Art Deco rays from above the top center
        ctx.fillStyle = k.rayColor
        var ox = w / 2, oy = -h * 0.35, R = Math.hypot(w, h) * 1.4
        for (i = 0; i < 26; i++) {
          if (i % 2) continue
          var a0 = Math.PI * (0.08 + 0.84 * i / 26), a1 = Math.PI * (0.08 + 0.84 * (i + 1) / 26)
          ctx.beginPath(); ctx.moveTo(ox, oy)
          ctx.lineTo(ox + Math.cos(a0) * R, oy + Math.sin(a0) * R)
          ctx.lineTo(ox + Math.cos(a1) * R, oy + Math.sin(a1) * R)
          ctx.closePath(); ctx.fill()
        }
      } else if (k.texture === "yakisugi") {  // charred cedar: soft wavy grain, a silver sheen
        ctx.lineWidth = 1
        for (i = 0; i < Math.round(h / 3.2); i++) {
          var gy = i * 3.2 + rnd() * 1.6, amp = 0.8 + rnd() * 2.2, ph = rnd() * 6.28, f = 0.012 + rnd() * 0.02
          ctx.strokeStyle = rnd() < 0.82 ? "rgba(0, 0, 0, 0.22)" : "rgba(200, 190, 175, " + (0.035 + rnd() * 0.04).toFixed(3) + ")"
          ctx.beginPath()
          for (var gx = 0; gx <= w; gx += 6) {
            var yy = gy + Math.sin(gx * f + ph) * amp
            if (gx === 0) ctx.moveTo(gx, yy); else ctx.lineTo(gx, yy)
          }
          ctx.stroke()
        }
      } else if (k.texture === "silk") {      // a faint woven sheen
        ctx.strokeStyle = "rgba(255, 255, 255, 0.18)"; ctx.lineWidth = 1
        for (i = -h; i < w; i += 7) { ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i + h, h); ctx.stroke() }
      }
      ctx.restore()

      // a scholar's seal: a small red chop in the top-right corner
      if (k.seal) {
        var sz = 9, sx = w - sz - 9, sy = 9
        ctx.fillStyle = k.seal; ctx.globalAlpha = 0.9
        ctx.fillRect(sx, sy, sz, sz)
        ctx.globalAlpha = 1
        ctx.strokeStyle = String(Qt.color(k.bg)); ctx.lineWidth = 1
        ctx.strokeRect(sx + 2.5, sy + 2.5, sz - 5, sz - 5)
      }

      // edge: one hairline; on a dark ground a faint inner highlight for depth
      var dark = (Qt.color(k.bg).hslLightness < 0.5)
      if (k.glow) {
        ctx.strokeStyle = String(accent); ctx.globalAlpha = 0.85
        ctx.shadowColor = String(accent); ctx.shadowBlur = 6; ctx.lineWidth = 1
        shape(1, 1, w - 2, h - 2, r); ctx.stroke()
        ctx.shadowBlur = 0; ctx.globalAlpha = 1
      } else {
        ctx.strokeStyle = k.hairline; ctx.lineWidth = 1
        shape(0.5, 0.5, w - 1, h - 1, r); ctx.stroke()
      }
      if (dark && !k.stark) {
        ctx.strokeStyle = "rgba(255, 255, 255, 0.06)"; ctx.lineWidth = 1
        shape(1.5, 1.5, w - 3, h - 3, Math.max(0, r - 1)); ctx.stroke()
      }
    }
  }

  // The five alchemical symbols, drawn: fire and air point up, water and earth
  // down, earth and air are crossed, aether is a four-point star
  component AlchemyGlyph: Canvas {
    property string kind: "fire"
    property color strokeColor: Color.foreground
    property real strokeWeight: 1.4
    width: 16
    height: 16
    antialiasing: true
    onKindChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onStrokeWeightChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var lw = strokeWeight
      var span = root.uniformIconSize - lw
      var midX = width / 2, midY = height / 2
      var left = midX - span / 2, right = midX + span / 2
      var top = midY - span / 2, bottom = midY + span / 2
      ctx.strokeStyle = String(strokeColor)
      ctx.lineWidth = lw
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      function bar(y) { ctx.beginPath(); ctx.moveTo(left + span * 0.1, y); ctx.lineTo(right - span * 0.1, y); ctx.stroke() }
      if (kind === "fire" || kind === "air") {
        ctx.beginPath(); ctx.moveTo(midX, top); ctx.lineTo(right, bottom); ctx.lineTo(left, bottom); ctx.closePath(); ctx.stroke()
        if (kind === "air") bar(top + span * 0.48)
      } else if (kind === "water" || kind === "earth") {
        ctx.beginPath(); ctx.moveTo(left, top); ctx.lineTo(right, top); ctx.lineTo(midX, bottom); ctx.closePath(); ctx.stroke()
        if (kind === "earth") bar(top + span * 0.52)
      } else {
        var inner = span * 0.22
        ctx.beginPath()
        ctx.moveTo(midX, top); ctx.lineTo(midX + inner, midY - inner); ctx.lineTo(right, midY); ctx.lineTo(midX + inner, midY + inner)
        ctx.lineTo(midX, bottom); ctx.lineTo(midX - inner, midY + inner); ctx.lineTo(left, midY); ctx.lineTo(midX - inner, midY - inner)
        ctx.closePath(); ctx.stroke()
      }
    }
  }

  // ---- One design language per tradition (cards, menu, marks, motion):
  //   Elemental  modern and friendly: moderate rounding, vivid edges, a modern
  //              sans, snappy motion with a little bounce
  //   Alchemical hermetic precision: razor-thin bright lines on crushed black,
  //              serif type, strictly linear motion
  //   Godai      zen minimalism: square corners, ink black and grays, color only
  //              where something is active, no transitions
  //   Wu Xing    scholar's discipline: nearly square corners, serif type and
  //              Song-style kanji, calm deliberate motion, a red seal
  readonly property var looks: ({
    elements: { radius: 10, inner: 7,  border: 1.5, borderAlpha: 0.6,  font: "Noto Sans",         bg: "",        ink: false,
                easing: Easing.OutBack, overshoot: 1.7, duration: 220 },
    alchemy:  { radius: 1,  inner: 0,  border: 1,   borderAlpha: 0.95, font: "Noto Serif",        bg: "#050505", ink: false,
                easing: Easing.Linear,  overshoot: 0,   duration: 130 },
    godai:    { radius: 0,  inner: 0,  border: 1,   borderAlpha: 0.22, font: "Noto Serif CJK JP", bg: "#000000", ink: true,
                easing: Easing.Linear,  overshoot: 0,   duration: 0 },
    wuxing:   { radius: 4,  inner: 2,  border: 1,   borderAlpha: 0.35, font: "Noto Serif",        bg: "",        ink: false,
                easing: Easing.OutCubic, overshoot: 0, duration: 260 }
  })
  readonly property var look: root.looks[root.iconStyle] || root.looks.elements

  // ---- Light (Soft) and Bold variants of each tradition: their own palette
  // and card ground, framed the way Apple frames things: a hairline edge (with a
  // faint inner highlight on dark grounds) and continuous corners. Character
  // comes from the ground, palette, type and corner size, not from ornament.
  // Theme keeps the Omarchy theme's colors instead.
  readonly property var skins: ({
    elements: {
      // Folio: an aged page of The Secret Teachings of All Ages (1928), gold leaf,
      // muted jewel colors, a faint gold sunburst
      light: { palette: ["#B5432F", "#2E5A8A", "#3E7A4F", "#3F7E85", "#6B4C8C"],
               bg: "#F0E6CC", bg2: "#E5D5AE", texture: "sunburst", rayColor: "rgba(150, 112, 30, 0.07)",
               text: "#33291A", accent: "#9A7428", hairline: "rgba(150, 112, 30, 0.45)", radius: 12 },
      // Lapis: midnight lapis lazuli, gold leaf, vivid jewel colors
      bold:  { palette: ["#FF6B4A", "#5B9BFF", "#3CCB7F", "#62D3CC", "#C48EFF"],
               bg: "#141C3A", bg2: "#0B1026", texture: "sunburst", rayColor: "rgba(212, 175, 55, 0.07)",
               text: "#EAD9A6", accent: "#D4AF37", hairline: "rgba(212, 175, 55, 0.5)", radius: 12 }
    },
    alchemy: {
      // Parchment: sepia vellum, iron-gall ink, faded marginalia colors
      light: { palette: ["#C98E7A", "#8FA9BC", "#A3B28E", "#A7C3C2", "#B9A5C2"],
               bg: "#EADCBE", bg2: "#D9C49C", texture: "vellum", text: "#3A2C1E", accent: "#5A4632",
               hairline: "rgba(58, 44, 30, 0.22)", radius: 10 },
      // Luminescence: void black, the five colors as light
      bold:  { palette: ["#FF4A1C", "#00B7FF", "#39FF14", "#00FFE5", "#E040FB"],
               bg: "#050505", bg2: "", texture: "", text: "#E8E8E8", accent: "#E8E8E8",
               hairline: "", glow: true, radius: 10 }
    },
    godai: {
      // Ink wash: rice paper, faded watercolor, soft grays
      light: { palette: ["#9DB58F", "#8FB1CC", "#D98E7E", "#9FC8C6", "#B7A6CC"],
               bg: "#F1EADB", bg2: "", texture: "paper", text: "#1E1E1E", accent: "#6B6B6B",
               hairline: "rgba(30, 30, 30, 0.16)", radius: 6, ink: "#CFCFCF" },
      // Yakisugi (shou sugi ban): charred cedar, silver grain, one vermilion
      bold:  { palette: ["#E2553F", "#E2553F", "#E2553F", "#E2553F", "#E2553F"],
               bg: "#1A1512", bg2: "#100D0B", texture: "yakisugi", text: "#E8E1D6", accent: "#E2553F",
               hairline: "rgba(232, 225, 214, 0.14)", radius: 6, ink: "#CFC7BB" }
    },
    wuxing: {
      // Xuan paper: the scholar's desk, ink-black type, sober ink colors, a red seal
      light: { palette: ["#4F7A4F", "#B23A2A", "#A07A2E", "#6B6F74", "#2F4F6F"],
               bg: "#F4EFE3", bg2: "#ECE5D4", texture: "paper", text: "#1C1A17", accent: "#B22222",
               hairline: "rgba(28, 26, 23, 0.22)", radius: 4, seal: "#B22222" },
      // Black lacquer: ash-ivory type, deeper ink colors, the same red seal
      bold:  { palette: ["#6FAF7A", "#E2553F", "#D8A84A", "#C9CDD2", "#6E9CC9"],
               bg: "#17130F", bg2: "#0C0A08", texture: "", text: "#EDE6D8", accent: "#C8322A",
               hairline: "rgba(237, 230, 216, 0.14)", radius: 4, seal: "#C8322A" }
    }
  })
  readonly property string variant: root.useThemeColors ? "theme" : (root.useBoldColors ? "bold" : "light")
  function skinFor(styleName) {
    if (root.variant === "theme") return null
    var t = root.skins[styleName] || root.skins.elements
    return t[root.variant]
  }
  readonly property var skin: root.skinFor(root.iconStyle)
  // Card text and accents follow the skin (dark ink on the light grounds)
  readonly property color cardText: root.skin ? Qt.color(root.skin.text) : Color.foreground
  readonly property color cardAccent: root.skin && root.skin.accent !== "" ? Qt.color(root.skin.accent) : Color.accent
  readonly property real cardRadius: root.skin ? root.skin.radius : root.look.radius
  readonly property real cardInner: root.skin ? Math.max(3, root.skin.radius - 6) : root.look.inner
  // Kanji in each tradition's hand: Mincho (brush) for Godai, gothic for Wu Xing
  function styleSurface(content) {
    var surface = content && content.parent ? content.parent.parent : null
    if (!surface || surface.radius === undefined) return
    surface.radius = Qt.binding(function() { return root.cardRadius })
    // A skin paints its own ground; Theme mode takes the theme's popup color
    surface.color = Qt.binding(function() { return root.skin ? "transparent" : Color.popups.background })
  }
  function glyphFont(styleName) {
    if (styleName === "godai") return "Noto Serif CJK JP"
    if (styleName === "wuxing") return "Noto Serif CJK JP"   // Song (Ming) style, the scholar's printed hand
    return root.bar ? root.bar.fontFamily : Style.font.family
  }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  readonly property int slots: 10
  readonly property string pluginId: "makehasteslowly.elementa"

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

  // Icon color mode setting: "elemental" (Soft) | "bold" (Vivid) | "theme" (Active Omarchy theme)
  property string localColorModeOverride: ""
  readonly property string configuredColorMode: {
    if (root.settings && root.settings.colorMode !== undefined && root.settings.colorMode !== null) {
      var cm = String(root.settings.colorMode).toLowerCase()
      if (cm === "theme" || cm === "bold" || cm === "elemental") return cm
      if (cm === "soft") return "elemental"
    }
    return "elemental"
  }
  readonly property string colorMode: root.localColorModeOverride !== ""
    ? root.localColorModeOverride
    : root.configuredColorMode
  readonly property bool useThemeColors: root.colorMode === "theme"
  readonly property bool useBoldColors: root.colorMode === "bold"

  // Live bar & popup background luminance detection for automatic light/dark/colored theme contrast
  readonly property color effectiveBarBg: {
    var bg = (Color.bar && Color.bar.background !== undefined) ? Color.bar.background : Color.background
    return (bg.a !== undefined && bg.a < 0.25) ? Color.background : bg
  }
  readonly property real barLuminance: 0.2126 * root.effectiveBarBg.r + 0.7152 * root.effectiveBarBg.g + 0.0722 * root.effectiveBarBg.b
  readonly property bool isLightBar: root.barLuminance > 0.48

  readonly property color effectivePopupBg: {
    if (root.skin) return Qt.color(root.skin.bg)
    var pbg = (Color.popups && Color.popups.background !== undefined) ? Color.popups.background : Color.background
    return (pbg.a !== undefined && pbg.a < 0.25) ? Color.background : pbg
  }
  readonly property real popupLuminance: 0.2126 * root.effectivePopupBg.r + 0.7152 * root.effectivePopupBg.g + 0.0722 * root.effectivePopupBg.b
  readonly property bool isLightPopup: root.popupLuminance > 0.48

  // How many windows the preview shows: "auto" (as many as fit the screen at
  // the chosen size, up to 9) or 2 / 4 / 6 / 9 (as many of those as fit)
  property string localPreviewCountOverride: ""
  readonly property string previewCount: {
    var v = root.localPreviewCountOverride !== "" ? root.localPreviewCountOverride : String(root.setting("previewCount", "auto")).toLowerCase()
    return ["auto", "2", "4", "6", "9"].indexOf(v) >= 0 ? v : "auto"
  }
  function selectPreviewCount(v) {
    var n = ["auto", "2", "4", "6", "9"].indexOf(v) >= 0 ? v : "auto"
    root.localPreviewCountOverride = n
    if (root.bar) root.bar.run("omarchy-bar set " + Util.shellQuote(root.pluginId) + " previewCount " + Util.shellQuote(n))
    root.showSizeSample()
  }

  // Floating hover preview size setting: "off" | "small" | "medium" | "large" | "xlarge" (defaults to "medium")
  property string localPreviewSizeOverride: ""
  readonly property string configuredPreviewSize: {
    if (root.settings && root.settings.previewSize !== undefined && root.settings.previewSize !== null) {
      var s = String(root.settings.previewSize).toLowerCase()
      if (s === "off" || s === "small" || s === "medium" || s === "large" || s === "xlarge") return s
    }
    if (root.settings && root.settings.showPreview !== undefined && root.settings.showPreview !== null) {
      var v = root.settings.showPreview
      if (v === false || String(v).toLowerCase() === "false" || String(v) === "0") return "off"
    }
    return "medium"
  }
  readonly property string previewSize: root.localPreviewSizeOverride !== ""
    ? root.localPreviewSizeOverride
    : root.configuredPreviewSize
  readonly property bool showPreview: root.previewSize !== "off"

  // Notification blink & speed setting: "off" | "slow" | "medium" | "fast" (defaults to "fast")
  property string localNotificationSpeedOverride: ""
  readonly property string configuredNotificationSpeed: {
    if (root.settings && root.settings.notificationSpeed !== undefined && root.settings.notificationSpeed !== null) {
      var s = String(root.settings.notificationSpeed).toLowerCase()
      if (s === "off" || s === "slow" || s === "medium" || s === "fast") return s
    }
    if (root.settings && root.settings.showNotifications !== undefined && root.settings.showNotifications !== null) {
      var v = root.settings.showNotifications
      if (v === false || String(v).toLowerCase() === "false" || String(v) === "0") return "off"
    }
    return "fast"
  }
  readonly property string notificationSpeed: root.localNotificationSpeedOverride !== ""
    ? root.localNotificationSpeedOverride
    : root.configuredNotificationSpeed
  readonly property bool showNotifications: root.notificationSpeed !== "off"
  readonly property int blinkIntervalMs: root.notificationSpeed === "slow"
    ? 1350
    : (root.notificationSpeed === "medium" ? 850 : 520)

  property bool pickerOpen: false
  property bool initialPromptShown: false
  readonly property var styleOrder: ["elements", "alchemy", "godai", "wuxing"]

  // Hover preview state
  property int hoveredWorkspaceId: -1
  property Item hoveredAnchorItem: null
  property bool previewOpen: false

  // Notification & urgent workspace blink state
  // blinkingWorkspaces[wsId] = { label: "Discord", address: "0x..." }
  property var blinkingWorkspaces: ({})
  // notifiedWindows[normalizedAddress] = { wsId: 2, label: "Discord" }
  property var notifiedWindows: ({})
  // ackWindowUnread[normalizedAddress] = last acknowledged unread count on that window
  property var ackWindowUnread: ({})
  // windowSeenTitles[normalizedAddress] = array of lowercase titles seen in that window (tracks background tabs)
  property var windowSeenTitles: ({})
  property var seenNotificationKeys: ({})
  property bool liveNotifsInitialized: false
  property bool blinkPhase: false
  property real blinkAlpha: root.blinkPhase ? 1.0 : 0.22

  // The breath follows the tradition: a sine swell, a linear ramp (Alchemical),
  // or a plain on/off cut with no fade at all (Godai)
  Behavior on blinkAlpha {
    NumberAnimation {
      duration: root.look.duration === 0 ? 0 : Style.duration(Math.round(root.blinkIntervalMs * 0.92))
      easing.type: root.look.easing === Easing.Linear ? Easing.Linear : Easing.InOutSine
    }
  }

  Timer {
    id: blinkTimer
    interval: root.blinkIntervalMs
    repeat: true
    running: root.showNotifications && root.hasAnyBlinkingWorkspace()
    onTriggered: root.blinkPhase = !root.blinkPhase
    onRunningChanged: if (!running) root.blinkPhase = false
  }

  function normalizeAddress(addr) {
    var s = String(addr || "").trim().toLowerCase()
    if (!s) return ""
    return s.indexOf("0x") === 0 ? s : ("0x" + s)
  }

  function hasAnyBlinkingWorkspace() {
    if (!root.showNotifications) return false
    for (var k in root.blinkingWorkspaces) {
      if (root.blinkingWorkspaces[k]) return true
    }
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].urgent && values[i].id !== root.activeWorkspaceId()) return true
    }
    return false
  }

  function markWorkspaceBlinking(wsId, address, label) {
    if (!root.showNotifications) return
    if (wsId <= 0 || wsId === root.activeWorkspaceId()) return
    var cleanLabel = String(label || "Notification").trim()
    var normAddr = root.normalizeAddress(address)

    var nextWs = Object.assign({}, root.blinkingWorkspaces)
    nextWs[wsId] = { label: cleanLabel, address: normAddr }
    root.blinkingWorkspaces = nextWs

    if (normAddr) {
      var nextWin = Object.assign({}, root.notifiedWindows)
      nextWin[normAddr] = { wsId: wsId, label: cleanLabel }
      root.notifiedWindows = nextWin
    }
  }

  function clearWorkspaceBlink(wsId) {
    // Record current unread badge count on windows in wsId as acknowledged so leaving wsId doesn't re-trigger old counts
    var list = Hyprland.toplevels ? Hyprland.toplevels.values : []
    if (list && list.length > 0) {
      var nextAck = Object.assign({}, root.ackWindowUnread)
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].workspace && list[i].workspace.id === wsId) {
          var ipc = list[i].lastIpcObject
          var normAddr = root.normalizeAddress(list[i].address || (ipc && ipc.address))
          var t = String(list[i].title || (ipc && ipc.title) || "")
          var info = root.extractTitleNotification(t)
          if (normAddr) {
            nextAck[normAddr] = info ? info.count : 0
          }
        }
      }
      root.ackWindowUnread = nextAck
    }

    var hadWs = Boolean(root.blinkingWorkspaces[wsId])
    if (hadWs) {
      var nextWs = Object.assign({}, root.blinkingWorkspaces)
      delete nextWs[wsId]
      root.blinkingWorkspaces = nextWs
    }
    var nextWin = {}
    var changedWin = false
    for (var addr in root.notifiedWindows) {
      if (root.notifiedWindows[addr] && root.notifiedWindows[addr].wsId === wsId) {
        changedWin = true
      } else {
        nextWin[addr] = root.notifiedWindows[addr]
      }
    }
    if (changedWin) root.notifiedWindows = nextWin
  }

  function extractTitleNotification(titleRaw) {
    var t = String(titleRaw || "").trim()
    if (!t) return null
    // Strip trailing browser suffix like " - Brave Origin", " - Google Chrome", " — Mozilla Firefox"
    var clean = t.replace(/\s+[-—|]\s+(Brave(\s+Origin)?|Google Chrome|Chromium|Mozilla Firefox|Firefox|Zen Browser|Vivaldi|Microsoft Edge|Helium)$/i, "").trim()

    // 1. Leading unread badge count: "(1) Facebook", "(3) Messenger", "[2] WhatsApp"
    var badgeMatch = clean.match(/^(?:\((\d+)\)|\[(\d+)\])\s*(.+)$/)
    if (badgeMatch) {
      var count = Number(badgeMatch[1] || badgeMatch[2] || 0)
      if (count > 0) {
        return {
          count: count,
          flash: false,
          label: "(" + count + ") " + String(badgeMatch[3] || clean).trim()
        }
      }
    }

    // 2. Web messenger flashing title alerts: "Trevor messaged you", "Alex sent a photo", "New message from ..."
    if (/\b(messaged you|sent (you )?(a |an |some )|replied to you|is calling you|new message from)\b/i.test(clean)) {
      return {
        count: 1,
        flash: true,
        label: clean
      }
    }

    return null
  }

  function recordWindowTitle(addrRaw, titleRaw) {
    var normAddr = root.normalizeAddress(addrRaw)
    var t = String(titleRaw || "").trim().toLowerCase()
    if (!normAddr || !t || t.indexOf("new tab") === 0) return
    var prev = root.windowSeenTitles[normAddr] ? root.windowSeenTitles[normAddr].slice() : []
    var idx = prev.indexOf(t)
    if (idx >= 0) prev.splice(idx, 1)
    prev.unshift(t)
    if (prev.length > 24) prev.length = 24
    var nextMap = Object.assign({}, root.windowSeenTitles)
    nextMap[normAddr] = prev
    root.windowSeenTitles = nextMap
  }

  function checkWindowTitleNotification(addrRaw, titleRaw) {
    var normAddr = root.normalizeAddress(addrRaw)
    if (!normAddr) return

    var list = Hyprland.toplevels ? Hyprland.toplevels.values : []
    var targetToplevel = null
    for (var i = 0; i < list.length; i++) {
      var ipc = list[i] ? list[i].lastIpcObject : null
      var a = root.normalizeAddress((list[i] && list[i].address) || (ipc && ipc.address))
      if (a === normAddr) {
        targetToplevel = list[i]
        break
      }
    }
    if (!targetToplevel || !targetToplevel.workspace) return

    var wsId = targetToplevel.workspace.id
    var activeId = root.activeWorkspaceId()
    var title = String(titleRaw !== undefined ? titleRaw : (targetToplevel.title || (targetToplevel.lastIpcObject && targetToplevel.lastIpcObject.title) || ""))
    root.recordWindowTitle(normAddr, title)
    if (!root.showNotifications) return
    var info = root.extractTitleNotification(title)

    if (!info) {
      if (root.ackWindowUnread[normAddr]) {
        var resetAck = Object.assign({}, root.ackWindowUnread)
        delete resetAck[normAddr]
        root.ackWindowUnread = resetAck
      }
      return
    }

    if (wsId <= 0 || wsId === activeId) {
      var activeAck = Object.assign({}, root.ackWindowUnread)
      activeAck[normAddr] = info.count
      root.ackWindowUnread = activeAck
      return
    }

    var prevCount = Number(root.ackWindowUnread[normAddr] || 0)
    if (info.flash || info.count > prevCount) {
      var nextAck = Object.assign({}, root.ackWindowUnread)
      nextAck[normAddr] = Math.max(prevCount, info.count)
      root.ackWindowUnread = nextAck
      root.markWorkspaceBlinking(wsId, normAddr, info.label)
    }
  }

  function scanInactiveWindowTitles() {
    if (!root.showNotifications) return
    var list = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < list.length; i++) {
      if (!list[i] || !list[i].workspace) continue
      var ipc = list[i].lastIpcObject
      var addr = list[i].address || (ipc && ipc.address)
      var title = list[i].title || (ipc && ipc.title) || ""
      if (addr && title) {
        root.checkWindowTitleNotification(addr, title)
      }
    }
  }

  function isWorkspaceNotified(wsId) {
    // Always touch reactive properties first so QML tracks bindings even when wsId is currently active
    var enabled = root.showNotifications
    var map = root.blinkingWorkspaces
    var activeId = root.activeWorkspaceId()
    var ws = root.workspaceById(wsId)
    var wsUrgent = ws ? Boolean(ws.urgent) : false

    if (!enabled || wsId <= 0 || wsId === activeId) return false
    if (map && map[wsId]) return true
    if (wsUrgent) return true
    if (ws && ws.toplevels && ws.toplevels.values) {
      var list = ws.toplevels.values
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].urgent) return true
      }
    }
    return false
  }

  function workspaceNotificationLabel(wsId) {
    var enabled = root.showNotifications
    var map = root.blinkingWorkspaces
    if (!enabled) return ""
    if (map && map[wsId] && map[wsId].label) {
      return String(map[wsId].label)
    }
    var ws = root.workspaceById(wsId)
    if (ws && ws.toplevels && ws.toplevels.values) {
      var list = ws.toplevels.values
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].urgent) {
          var ipc = list[i].lastIpcObject
          return String((ipc && ipc["class"]) || list[i].title || "Urgent")
        }
      }
    }
    if (ws && ws.urgent) return "Urgent"
    return ""
  }

  function windowNotificationLabel(toplevelObj) {
    var enabled = root.showNotifications
    var winMap = root.notifiedWindows
    if (!enabled || !toplevelObj) return ""
    var normAddr = root.normalizeAddress(toplevelObj.address || (toplevelObj.lastIpcObject && toplevelObj.lastIpcObject.address))
    if (normAddr && winMap && winMap[normAddr] && winMap[normAddr].label) {
      return String(winMap[normAddr].label)
    }
    if (toplevelObj.urgent) {
      var ipc = toplevelObj.lastIpcObject
      return String((ipc && ipc["class"]) || toplevelObj.title || "Urgent")
    }
    return ""
  }

  function formatNotificationLabel(appRaw, sourceRaw, fallbackClass) {
    var app = String(appRaw || "").trim()
    var source = String(sourceRaw || "").trim()
    if (source && source.indexOf(".") > 0) {
      if (app && app.toLowerCase().indexOf(source.toLowerCase()) < 0) {
        return app + " · " + source
      }
      return source
    }
    if (app) return app
    return String(fallbackClass || "Notification")
  }

  // Several windows could have sent a notification (terminals share one process,
  // so a notification only says "kitty"). Pick one without guessing wrong:
  // 1. one candidate: that one; 2. the notification's text matches exactly one
  // window's title: that one; 3. one candidate is on the workspace you are on:
  // assume it came from there and blink nothing; 4. otherwise the most recently
  // used. (Each candidate carries its title, workspace and focus order.)
  function resolveCandidates(pool, entry) {
    if (!pool || pool.length === 0) return null
    if (pool.length === 1) return pool[0]
    var words = []
    var text = (String(entry.summary || "") + " " + String(entry.body || "")).toLowerCase()
    var raw = text.split(/[^a-z0-9]+/)
    for (var w = 0; w < raw.length; w++) if (raw[w].length >= 4 && words.indexOf(raw[w]) < 0) words.push(raw[w])
    var byText = pool.filter(function(c) {
      var t = String(c.title || "").toLowerCase()
      for (var i = 0; i < words.length; i++) if (t.indexOf(words[i]) >= 0) return true
      return false
    })
    if (byText.length === 1) return byText[0]
    var active = root.activeWorkspaceId()
    var narrowed = byText.length > 1 ? byText : pool
    for (var j = 0; j < narrowed.length; j++) if (narrowed[j].wsId === active) return null
    narrowed.sort(function(a, b) { return a.focusOrder - b.focusOrder })
    return narrowed[0]
  }

  function matchNotificationTarget(entry) {
    if (!entry) return null
    var appRaw = String(entry.app || "").trim()
    var sourceRaw = String(entry.source || "").trim()
    var summaryRaw = String(entry.summary || "").trim()
    var app = appRaw.toLowerCase()
    var source = sourceRaw.toLowerCase()
    var summary = summaryRaw.toLowerCase()
    var pid = Number(entry.senderPid || 0)
    if (app === "omarchy-action" || app === "omasnap" || entry.transient) return null

    var list = Hyprland.toplevels ? Hyprland.toplevels.values : []
    if (!list || list.length === 0) return null

    var activeId = root.activeWorkspaceId()
    var i, ipc, wmClass, title, addr

    // 1. Exact sender PID match (only when source is not a web domain and only 1 window owns that PID)
    if (pid > 0 && source.indexOf(".") < 0) {
      var pidMatches = []
      for (i = 0; i < list.length; i++) {
        ipc = list[i].lastIpcObject
        if (ipc && Number(ipc.pid || 0) === pid && list[i].workspace) {
          wmClass = String((ipc && ipc["class"]) || "")
          addr = String(list[i].address || (ipc && ipc.address) || "")
          pidMatches.push({
            wsId: list[i].workspace.id,
            address: addr,
            title: String(list[i].title || (ipc && ipc.title) || ""),
            focusOrder: Number(ipc && ipc.focusHistoryID !== undefined ? ipc.focusHistoryID : 9999),
            label: root.formatNotificationLabel(appRaw, sourceRaw, wmClass)
          })
        }
      }
      if (pidMatches.length > 0) return root.resolveCandidates(pidMatches, entry)
    }

    // 2. Domain/source match against PWA class or browser tab title (e.g., "messages.google.com" -> "messages")
    var browserRe = /^(brave|chrome|chromium|firefox|zen|vivaldi|edge|helium)/
    var genericWords = { www: 1, app: 1, web: 1, mail: 1, google: 1, com: 1, org: 1, net: 1, io: 1, co: 1, dev: 1, ai: 1 }

    if (source.indexOf(".") > 0) {
      // 2a. Check if a standalone PWA window class contains the exact source host (e.g. "brave-discord.com__...")
      for (i = 0; i < list.length; i++) {
        if (!list[i].workspace) continue
        ipc = list[i].lastIpcObject
        wmClass = String((ipc && ipc["class"]) || (list[i].wayland && list[i].wayland.appId) || "").toLowerCase()
        if (wmClass.indexOf(source) >= 0) {
          addr = String(list[i].address || (ipc && ipc.address) || "")
          return {
            wsId: list[i].workspace.id,
            address: addr,
            label: root.formatNotificationLabel(appRaw, sourceRaw, wmClass)
          }
        }
      }

      // 2b. Check non-PWA browser window titles for brand keywords from the source domain (or notification summary)
      var keywords = []
      var parts = source.split(".")
      for (var p = 0; p < parts.length; p++) {
        if (parts[p].length >= 3 && !genericWords[parts[p]]) keywords.push(parts[p])
      }
      if (source.indexOf("messenger.com") >= 0 || source.indexOf("facebook.com") >= 0) {
        keywords.push("messenger", "facebook", "messaged you")
      } else if (source.indexOf("mail.google.com") >= 0) {
        keywords.push("gmail")
      }
      if (summary.length >= 3 && !genericWords[summary]) {
        keywords.push(summary)
      }

      var titleCandidates = []
      for (var k = 0; k < keywords.length; k++) {
        var kw = keywords[k]
        for (i = 0; i < list.length; i++) {
          if (!list[i].workspace) continue
          ipc = list[i].lastIpcObject
          wmClass = String((ipc && ipc["class"]) || (list[i].wayland && list[i].wayland.appId) || "").toLowerCase()
          if (wmClass.indexOf("__") >= 0) continue
          title = String(list[i].title || (ipc && ipc.title) || "").toLowerCase()
          if (browserRe.test(wmClass) && title.indexOf(kw) >= 0) {
            addr = String(list[i].address || (ipc && ipc.address) || "")
            titleCandidates.push({
              wsId: list[i].workspace.id,
              address: addr,
              title: title,
              inactive: list[i].workspace.id !== activeId ? 0 : 1,
              focusOrder: Number(ipc && ipc.focusHistoryID !== undefined ? ipc.focusHistoryID : 9999),
              label: root.formatNotificationLabel(appRaw, sourceRaw, wmClass)
            })
          }
        }
        if (titleCandidates.length > 0) return root.resolveCandidates(titleCandidates, entry)
      }

      // 2c. Check remembered tab titles seen earlier in each browser window (handles background tabs behind "New Tab")
      var historyCandidates = []
      for (var hk = 0; hk < keywords.length; hk++) {
        var hkw = keywords[hk]
        for (i = 0; i < list.length; i++) {
          if (!list[i].workspace) continue
          ipc = list[i].lastIpcObject
          wmClass = String((ipc && ipc["class"]) || (list[i].wayland && list[i].wayland.appId) || "").toLowerCase()
          if (wmClass.indexOf("__") >= 0 || !browserRe.test(wmClass)) continue
          addr = String(list[i].address || (ipc && ipc.address) || "")
          var normA = root.normalizeAddress(addr)
          var seenList = root.windowSeenTitles[normA] || []
          for (var sIdx = 0; sIdx < seenList.length; sIdx++) {
            if (seenList[sIdx].indexOf(hkw) >= 0) {
              historyCandidates.push({
                wsId: list[i].workspace.id,
                address: addr,
                title: String(list[i].title || (ipc && ipc.title) || ""),
                inactive: list[i].workspace.id !== activeId ? 0 : 1,
                recency: sIdx,
                focusOrder: Number(ipc && ipc.focusHistoryID !== undefined ? ipc.focusHistoryID : 9999),
                label: root.formatNotificationLabel(appRaw, sourceRaw, wmClass)
              })
              break
            }
          }
        }
        if (historyCandidates.length > 0) {
          historyCandidates.sort(function(a, b) { return a.recency - b.recency })
          return root.resolveCandidates(historyCandidates, entry)
        }
      }
    }

    // 3. Fallback: the application's windows (excluding unrelated PWAs with "__" in
    // wmClass), resolved without guessing (see resolveCandidates)
    var appHyphen = app.replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
    var appToken = app.split(/[\s-_]+/)[0].replace(/[^a-z0-9]/g, "")
    if (appToken.length >= 3) {
      var exactCandidates = []
      var prefixCandidates = []
      for (i = 0; i < list.length; i++) {
        if (!list[i].workspace) continue
        ipc = list[i].lastIpcObject
        wmClass = String((ipc && ipc["class"]) || (list[i].wayland && list[i].wayland.appId) || "").toLowerCase()
        if (wmClass.indexOf("__") >= 0) continue
        addr = String(list[i].address || (ipc && ipc.address) || "")
        var focusOrder = Number(ipc && ipc.focusHistoryID !== undefined ? ipc.focusHistoryID : 9999)
        var cand = {
          wsId: list[i].workspace.id,
          address: addr,
          title: String(list[i].title || (ipc && ipc.title) || ""),
          inactive: list[i].workspace.id !== activeId ? 0 : 1,
          focusOrder: focusOrder,
          label: root.formatNotificationLabel(appRaw, sourceRaw, wmClass)
        }
        if (wmClass === appHyphen || wmClass === appToken) {
          exactCandidates.push(cand)
        } else if (wmClass.indexOf(appToken) >= 0) {
          prefixCandidates.push(cand)
        }
      }
      var pool = exactCandidates.length > 0 ? exactCandidates : prefixCandidates
      if (pool.length > 0) return root.resolveCandidates(pool, entry)
    }

    return null
  }

  function processLiveNotifications(text) {
    var raw = String(text || "").trim()
    var entries = []
    if (raw.length > 0) {
      try {
        var parsed = JSON.parse(raw)
        if (Array.isArray(parsed)) entries = parsed
      } catch (e) {
        entries = []
      }
    }

    if (!root.liveNotifsInitialized) {
      var initialSeen = {}
      for (var i = 0; i < entries.length; i++) {
        if (entries[i] && entries[i].key) initialSeen[entries[i].key] = true
      }
      root.seenNotificationKeys = initialSeen
      root.liveNotifsInitialized = true
      return
    }

    var nextSeen = Object.assign({}, root.seenNotificationKeys)
    for (var j = 0; j < entries.length; j++) {
      var entry = entries[j]
      if (!entry || !entry.key) continue
      var key = String(entry.key)
      if (!nextSeen[key]) {
        nextSeen[key] = true
        var target = root.matchNotificationTarget(entry)
        if (target && target.wsId > 0 && target.wsId !== root.activeWorkspaceId()) {
          root.markWorkspaceBlinking(target.wsId, target.address, target.label)
        }
      }
    }
    root.seenNotificationKeys = nextSeen
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/notifications/live.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.processLiveNotifications(text())
    onLoadFailed: root.processLiveNotifications("[]")
  }

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

  function toggleStyleMenu() {
    root.previewOpen = false
    root.pickerOpen = !root.pickerOpen
  }

  function selectColorMode(nextMode) {
    var normalized = (nextMode === "theme" || nextMode === "bold") ? nextMode : "elemental"
    root.localColorModeOverride = normalized
    if (root.bar) {
      root.bar.run("omarchy-bar set " + Util.shellQuote(root.pluginId) + " colorMode " + Util.shellQuote(normalized))
    }
  }

  function selectPreviewSize(nextSize) {
    var normalized = (nextSize === "off" || nextSize === "small" || nextSize === "large" || nextSize === "xlarge")
      ? nextSize : "medium"
    root.localPreviewSizeOverride = normalized
    if (normalized === "off") root.previewOpen = false
    else root.showSizeSample()
    if (root.bar) {
      root.bar.run("omarchy-bar set " + Util.shellQuote(root.pluginId) + " previewSize " + Util.shellQuote(normalized))
    }
  }

  function selectNotificationSpeed(nextSpeed) {
    var normalized = (nextSpeed === "off" || nextSpeed === "slow" || nextSpeed === "medium")
      ? nextSpeed : "fast"
    root.localNotificationSpeedOverride = normalized
    if (normalized === "off") {
      root.blinkingWorkspaces = ({})
      root.notifiedWindows = ({})
    }
    if (root.bar) {
      root.bar.run("omarchy-bar set " + Util.shellQuote(root.pluginId) + " notificationSpeed " + Util.shellQuote(normalized))
    }
  }

  onConfiguredStyleChanged: {
    if (root.configuredStyle !== "") {
      root.localStyleOverride = ""
    }
  }

  onConfiguredColorModeChanged: {
    root.localColorModeOverride = ""
  }

  onConfiguredPreviewSizeChanged: {
    root.localPreviewSizeOverride = ""
  }

  onConfiguredNotificationSpeedChanged: {
    root.localNotificationSpeedOverride = ""
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
    if (workspaceId > 0) root.clearWorkspaceBlink(workspaceId)
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

  // Middle-click on a window in the preview: close it the polite way (like
  // Super+W); the app may still ask to save first
  function closeWindow(toplevelObj) {
    var address = toplevelObj ? String(toplevelObj.address || "") : ""
    if (!address) return
    if (address.indexOf("0x") !== 0) address = "0x" + address
    root.dispatch("hl.dsp.window.close({ window = \"address:" + address + "\" })")
  }

  // The app icon for a window class, from its desktop entry (or the icon theme)
  function appIconFor(cls) {
    var name = String(cls || "")
    if (!name) return ""
    var _apps = DesktopEntries.applications.values.length   // re-resolve when apps change
    var entry = DesktopEntries.heuristicLookup(name)
    var icon = entry && entry.icon ? String(entry.icon) : name
    if (icon.charAt(0) === "/") return "file://" + icon
    return Quickshell.iconPath(icon, true) || Quickshell.iconPath(name.toLowerCase(), true) || ""
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

  function indexed(list, pack) {
    var out = []
    for (var i = 0; i < list.length; i++) out.push(Object.assign({ k: i, pack: pack }, list[i]))
    return out
  }
  readonly property var packs: ({
    elements: root.indexed([
      { icon: "󰈸", glyphScale: 1.29, alchemyKind: "fire",   name: "Fire",   color: "#FF6B35", boldColor: "#FF3B00", lightColor: "#D93800", boldLightColor: "#C22800" },
      { icon: "󰖌", glyphScale: 1.38, alchemyKind: "water",  name: "Water",  color: "#38BDF8", boldColor: "#0088FF", lightColor: "#0284C7", boldLightColor: "#0055D4" },
      { icon: "󰌪", glyphScale: 1.24, dx: -0.06, alchemyKind: "earth",  name: "Earth",  color: "#4ADE80", boldColor: "#00E640", lightColor: "#15803D", boldLightColor: "#008A2E" },
      { icon: "󰖝", glyphScale: 1.19, alchemyKind: "air",    name: "Air",    color: "#67E8F9", boldColor: "#00F0FF", lightColor: "#0E7490", boldLightColor: "#007A8C" },
      { icon: "󰫢", glyphScale: 1.06, dx: -0.24, alchemyKind: "aether", name: "Aether", color: "#C084FC", boldColor: "#B829FF", lightColor: "#7E22CE", boldLightColor: "#6B00D7" }
    ], "elements"),
    alchemy: root.indexed([
      { icon: "🜂", glyphScale: 1.0,  alchemyKind: "fire",   name: "Fire",   color: "#FF6B35", boldColor: "#FF3B00", lightColor: "#D93800", boldLightColor: "#C22800" },
      { icon: "🜄", glyphScale: 1.0,  alchemyKind: "water",  name: "Water",  color: "#38BDF8", boldColor: "#0088FF", lightColor: "#0284C7", boldLightColor: "#0055D4" },
      { icon: "🜃", glyphScale: 1.0,  alchemyKind: "earth",  name: "Earth",  color: "#4ADE80", boldColor: "#00E640", lightColor: "#15803D", boldLightColor: "#008A2E" },
      { icon: "🜁", glyphScale: 1.0,  alchemyKind: "air",    name: "Air",    color: "#67E8F9", boldColor: "#00F0FF", lightColor: "#0E7490", boldLightColor: "#007A8C" },
      { icon: "✧",  glyphScale: 1.0,  alchemyKind: "aether", name: "Aether", color: "#C084FC", boldColor: "#B829FF", lightColor: "#7E22CE", boldLightColor: "#6B00D7" }
    ], "alchemy"),
    godai: root.indexed([
      { icon: "地", glyphScale: 1.09, alchemyKind: "earth",  ink: true, name: "Chi · Earth", color: "#4ADE80", boldColor: "#00E640", lightColor: "#15803D", boldLightColor: "#008A2E" },
      { icon: "水", glyphScale: 1.07, alchemyKind: "water",  ink: true, name: "Sui · Water", color: "#38BDF8", boldColor: "#0088FF", lightColor: "#0284C7", boldLightColor: "#0055D4" },
      { icon: "火", glyphScale: 1.09, alchemyKind: "fire",   ink: true, name: "Ka · Fire",   color: "#FF6B35", boldColor: "#FF3B00", lightColor: "#D93800", boldLightColor: "#C22800" },
      { icon: "風", glyphScale: 1.11, alchemyKind: "air",    ink: true, name: "Fū · Wind",   color: "#67E8F9", boldColor: "#00F0FF", lightColor: "#0E7490", boldLightColor: "#007A8C" },
      { icon: "空", glyphScale: 1.10, alchemyKind: "aether", ink: true, name: "Kū · Void",   color: "#C084FC", boldColor: "#B829FF", lightColor: "#7E22CE", boldLightColor: "#6B00D7" }
    ], "godai"),
    wuxing: root.indexed([
      { icon: "木", glyphScale: 1.07, alchemyKind: "earth",  name: "Mù · Wood",   color: "#4ADE80", boldColor: "#00E640", lightColor: "#15803D", boldLightColor: "#008A2E" },
      { icon: "火", glyphScale: 1.09, alchemyKind: "fire",   name: "Huǒ · Fire",  color: "#FF6B35", boldColor: "#FF3B00", lightColor: "#D93800", boldLightColor: "#C22800" },
      { icon: "土", glyphScale: 1.11, alchemyKind: "earth",  name: "Tǔ · Earth",  color: "#FBBF24", boldColor: "#FFB800", lightColor: "#B45309", boldLightColor: "#9A3412" },
      { icon: "金", glyphScale: 1.09, alchemyKind: "air",    name: "Jīn · Metal", color: "#E2E8F0", boldColor: "#FFFFFF", lightColor: "#334155", boldLightColor: "#0F172A" },
      { icon: "水", glyphScale: 1.07, alchemyKind: "water",  name: "Shuǐ · Water", color: "#38BDF8", boldColor: "#0088FF", lightColor: "#0284C7", boldLightColor: "#0055D4" }
    ], "wuxing")
  })

  function relLum(c) {
    function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
  }
  function contrastRatio(a, b) {
    var la = root.relLum(a), lb = root.relLum(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
  }
  function withContrast(c, bg, minRatio) {
    var out = c
    var lightGround = root.relLum(bg) > 0.4
    for (var i = 0; i < 12 && root.contrastRatio(out, bg) < minRatio; i++)
      out = lightGround ? Qt.darker(out, 1.12) : Qt.lighter(out, 1.12)
    return out
  }

  function resolveElementColor(item, forPopup, isHighlighted) {
    if (!item) return Color.foreground
    var sk = root.skinFor(item.pack || root.iconStyle)
    if (item.ink && !isHighlighted) {
      var onLightInk = forPopup ? root.isLightPopup : root.isLightBar
      if (sk && sk.ink) return onLightInk ? (sk.stark ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(0.2, 0.2, 0.2, 1)) : Qt.color(sk.ink)
      return onLightInk ? Qt.rgba(0.2, 0.2, 0.2, 1) : Qt.rgba(0.86, 0.86, 0.86, 1)
    }
    var onLight = forPopup ? root.isLightPopup : root.isLightBar
    var bg = forPopup ? root.effectivePopupBg : root.effectiveBarBg

    if (root.useThemeColors) {
      if (isHighlighted) {
        var act = (!forPopup && Color.bar && Color.bar.active !== undefined) ? Color.bar.active : Color.accent
        return act
      }
      return (!forPopup && Color.bar && Color.bar.text !== undefined) ? Color.bar.text : Color.foreground
    }

    var hex
    var own = root.skinFor(item.pack || root.iconStyle)
    if (own && own.palette && item.k !== undefined) {
      hex = own.palette[item.k]
    } else if (root.useBoldColors) {
      hex = onLight ? (item.boldLightColor || item.lightColor || item.color) : (item.boldColor || item.color)
    } else {
      hex = onLight ? (item.lightColor || item.color) : item.color
    }
    var c = Qt.color(hex)
    // Every element color must read against its ground: at least 3:1 (WCAG's
    // bar for icons). Short of that it is deepened on a light ground and
    // lightened on a dark one, keeping its hue (faded watercolor on rice paper,
    // blue on cinnabar lacquer).
    if (forPopup && root.skin) return root.withContrast(c, Qt.color(root.skin.bg), 3.0)
    if (!forPopup && root.skin) return root.withContrast(c, root.effectiveBarBg, 3.0)   // the bar is the ground here
    var cLum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    var bgLum = onLight ? root.popupLuminance : root.barLuminance
    if (!forPopup) bgLum = root.barLuminance
    var lumDiff = Math.abs(cLum - bgLum)
    var rgbDist = Math.sqrt(Math.pow(c.r - bg.r, 2) + Math.pow(c.g - bg.g, 2) + Math.pow(c.b - bg.b, 2))

    // If a custom colored theme background is close to this element's color, boost contrast automatically
    if (lumDiff < 0.22 && rgbDist < 0.42) {
      return onLight ? Qt.darker(c, 1.55) : Qt.lighter(c, 1.45)
    }
    return c
  }

  function elementForSlot(slot, styleName, forPopup, isHighlighted) {
    var list = root.packs[styleName] || root.packs.elements
    var idx = ((slot - 1) % list.length + list.length) % list.length
    var raw = list[idx]
    return {
      icon: raw.icon,
      glyphScale: raw.glyphScale,
      dx: raw.dx || 0,   // optical correction: some glyphs sit off-center in their font box
      alchemyKind: raw.alchemyKind,
      ink: Boolean(raw.ink),
      k: raw.k,
      pack: raw.pack,
      name: raw.name,
      color: root.resolveElementColor(raw, Boolean(forPopup), isHighlighted !== false),
      rawColor: raw.color,
      lightColor: raw.lightColor || raw.color
    }
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
    layoutRefresh.restart()
  }

  // The toggle script runs detached; read the new layout once it has applied
  Timer {
    id: layoutRefresh
    interval: 700
    onTriggered: root.refresh()
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
      Hyprland.refreshToplevels()
      root.scanInactiveWindowTitles()
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

  // After a preview size is picked: close the menu (previews never show over it)
  // and show the preview at the new size for a moment, on the workspace the menu
  // was opened from (or the one you are on), so the choice is seen at once
  function showSizeSample() {
    root.pickerOpen = false
    if (root.hoveredWorkspaceId <= 0 || !root.hoveredAnchorItem) {
      root.hoveredWorkspaceId = root.activeWorkspaceId()
      root.hoveredAnchorItem = root.buttonForWorkspace(root.hoveredWorkspaceId)
    }
    if (root.hoveredWorkspaceId <= 0 || !root.hoveredAnchorItem) return
    Hyprland.refreshToplevels()
    root.previewOpen = true
    sizeSampleTimer.restart()
  }
  function buttonForWorkspace(wsId) {
    for (var i = 0; i < wsRepeater.count; i++) {
      var b = wsRepeater.itemAt(i)
      if (b && b.modelData === wsId) return b
    }
    return null
  }
  Timer {
    id: sizeSampleTimer
    interval: 2600
    onTriggered: if (!previewPopup.containsMouse) root.previewOpen = false
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
    function onActiveWorkspaceChanged() {
      root.showActiveMode()
      var activeId = root.activeWorkspaceId()
      if (activeId > 0) root.clearWorkspaceBlink(activeId)
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      var data = event && event.data !== undefined ? String(event.data) : ""
      if (name === "configreloaded") root.refresh()
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
        var activeId = root.activeWorkspaceId()
        if (activeId > 0) root.clearWorkspaceBlink(activeId)
      }
      if (name === "windowtitlev2" && data.indexOf(",") > 0) {
        var commaIdx = data.indexOf(",")
        var addrPart = data.substring(0, commaIdx)
        var titlePart = data.substring(commaIdx + 1)
        root.checkWindowTitleNotification(addrPart, titlePart)
      } else if (name === "urgent" && data) {
        var normUrgentAddr = root.normalizeAddress(data)
        var tList = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (var u = 0; u < tList.length; u++) {
          var uIpc = tList[u] ? tList[u].lastIpcObject : null
          var uAddr = root.normalizeAddress((tList[u] && tList[u].address) || (uIpc && uIpc.address))
          if (uAddr === normUrgentAddr && tList[u].workspace) {
            root.markWorkspaceBlinking(tList[u].workspace.id, uAddr, tList[u].title || (uIpc && uIpc.title) || "Urgent")
            break
          }
        }
      }
      if (name === "openwindow" || name === "closewindow" || name === "movewindow" || name === "movewindowv2" || name === "urgent" || name === "windowtitle" || name === "windowtitlev2") {
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

  // Our own IPC target. The reserved "omarchy.workspaces" belongs to the built-in
  // widget: the shell routes a target to the first handler only, so sharing it
  // broke one of the two whenever both were on a bar. Omarchy's layout scripts
  // still call that one; we re-read the layout after our own layout click and
  // whenever a preview opens instead.
  ShellIpc {
    target: "makehasteslowly.elementa"

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
      id: wsRepeater
      model: root.workspaceIds()

      WidgetButton {
        id: wsBtn
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool shown: root.monitor !== null && root.monitor.activeWorkspace !== null && root.monitor.activeWorkspace.id === modelData
        readonly property bool notified: !shown && root.isWorkspaceNotified(modelData)
        readonly property int slot: root.slotOf(modelData)
        readonly property var element: root.elementForSlot(slot, root.iconStyle, false, shown || notified)
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
        opacity: (shown || notified)
          ? 1.0
          : (occupied
            ? (root.useBoldColors ? 0.90 : (root.isLightBar ? 0.85 : 0.78))
            : (root.useBoldColors ? 0.58 : (root.isLightBar ? 0.50 : 0.42)))
        // Only show plain bar tooltip when floating preview is disabled
        tooltipText: root.showPreview ? "" : (shown
          ? strings.t("tip.active").arg(slot).arg(element.name).arg(root.activeMode)
          : strings.t("tip.other").arg(slot).arg(element.name))
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(22)
        fixedHeight: root.barSize

        onTooltipHoveredChanged: {
          root.handleButtonHover(modelData, wsBtn, tooltipHovered)
        }

        onPressed: function(button) {
          if (button === Qt.RightButton) {
            root.toggleStyleMenu()
            return
          }
          root.previewOpen = false
          root.clearWorkspaceBlink(modelData)
          if (shown) root.cycleLayout()
          else root.focusWorkspace(modelData)
        }
        onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }

        property real blinkScale: notified ? (0.94 + 0.18 * ((root.blinkAlpha - 0.22) / 0.78)) : 1.0

        // Uniform-size glyph/kanji renderer (exact 12px ink height across elements, godai, and wuxing).
        Text {
          visible: !wsBtn.useAlchemy
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -1
          textFormat: Text.PlainText
          text: wsBtn.element.icon
          color: wsBtn.element.color
          opacity: wsBtn.notified ? root.blinkAlpha : 1.0
          font.family: root.glyphFont(root.iconStyle)
          font.weight: wsBtn.isCjk ? Font.DemiBold : Font.Normal
          font.pixelSize: Math.round(root.uniformIconSize * wsBtn.element.glyphScale)
          anchors.horizontalCenterOffset: Math.round(font.pixelSize * wsBtn.element.dx * 2) / 2
          renderType: Text.CurveRendering
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          scale: wsBtn.pressScale * wsBtn.blinkScale
        }

        // Alchemical symbols are drawn (exact 12px outer bounds, like the other packs)
        AlchemyGlyph {
          visible: wsBtn.useAlchemy
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -1
          opacity: wsBtn.notified ? root.blinkAlpha : 1.0
          scale: wsBtn.pressScale * wsBtn.blinkScale
          kind: wsBtn.element.alchemyKind
          strokeColor: wsBtn.element.color
          strokeWeight: root.useBoldColors ? 1.65 : 1.4
        }

        // State mark under the symbol: a bar for the workspace you are on, a dot
        // for one with windows, nothing for an empty one. The mark grows from
        // dot to bar, so moving between workspaces reads as one motion.
        Rectangle {
          readonly property real len: wsBtn.shown ? 10 : 3
          width: root.vertical ? (wsBtn.shown ? 2 : 3) : len
          height: root.vertical ? len : (wsBtn.shown ? 2 : 3)
          radius: Math.min(width, height) / 2
          color: wsBtn.element.color
          anchors.bottom: root.vertical ? undefined : parent.bottom
          anchors.bottomMargin: root.vertical ? 0 : 2
          anchors.left: root.vertical ? parent.left : undefined
          anchors.leftMargin: root.vertical ? 2 : 0
          anchors.horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
          anchors.verticalCenter: root.vertical ? parent.verticalCenter : undefined
          opacity: wsBtn.shown ? 1 : (wsBtn.occupied ? 0.75 : 0)

          Behavior on opacity {
            NumberAnimation { duration: Style.duration(root.look.duration); easing.type: root.look.easing === Easing.Linear ? Easing.Linear : Easing.OutCubic }
          }
          Behavior on width {
            NumberAnimation { duration: Style.duration(root.look.duration); easing.type: root.look.easing; easing.overshoot: root.look.overshoot }
          }
          Behavior on height {
            NumberAnimation { duration: Style.duration(root.look.duration); easing.type: root.look.easing; easing.overshoot: root.look.overshoot }
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
    readonly property var element: root.elementForSlot(slot, root.iconStyle, true, true)
    readonly property var workspaceObj: root.workspaceById(wsId)
    // What fits on this screen at this size: up to 3 columns and 3 rows
    readonly property int fitCols: Math.max(1, Math.min(3, Math.floor((screenWidth - 2 * margin - 2 * padding + Style.space(8)) / (cardThumbW + Style.space(8)))))
    readonly property real availHeight: (screenH > 0 ? screenH : 864) - barThickness - 2 * margin - 2 * padding - Style.space(64)
    readonly property int fitRows: Math.max(1, Math.min(3, Math.floor((availHeight + Style.space(8)) / (cardThumbH + Style.space(8)))))
    readonly property int maxWindows: {
      var cap = fitCols * fitRows
      return root.previewCount === "auto" ? Math.min(9, cap) : Math.min(parseInt(root.previewCount), cap)
    }
    readonly property var windowList: {
      if (!workspaceObj || !workspaceObj.toplevels) return []
      var raw = workspaceObj.toplevels.values
      // Windows asking for attention first, so the one that flashes is always on
      // the card even when the workspace has more windows than the grid shows
      var asking = [], rest = []
      for (var i = 0; i < raw.length; i++) {
        if (!raw[i]) continue
        if (root.windowNotificationLabel(raw[i]) !== "") asking.push(raw[i]); else rest.push(raw[i])
      }
      return asking.concat(rest).slice(0, maxWindows)
    }
    readonly property int totalWindowCount: workspaceObj && workspaceObj.toplevels ? workspaceObj.toplevels.values.length : 0
    readonly property bool isFocusedWs: root.activeWorkspaceId() === wsId
    readonly property string modeLabel: isFocusedWs ? root.activeMode : (root.modeCache[wsId] || "")
    readonly property string wsNotifLabel: root.workspaceNotificationLabel(wsId)

    // A quiet frame in the element's tone; the mark on the top edge below says
    // which workspace this is, even when the card is held against the screen edge
    borderSpec: root.skin ? Border.flat("transparent", 0)
      : Border.flat(root.look.ink ? Qt.alpha(root.cardText, root.look.borderAlpha)
                                  : Qt.alpha(Qt.color(previewPopup.element.color), root.look.borderAlpha), root.look.border)
    onOpenChanged: if (open) root.refresh()   // the layout label is never stale

    // Sizes scale with the screen: a thumbnail is a share of the screen's width
    // (S 17%, M 22%, L 28%, XL 34%), 16:10, never so wide that two side by side
    // leave the screen. Captures are taken at twice the size so they stay sharp.
    readonly property real fraction: ({ small: 0.17, medium: 0.22, large: 0.28, xlarge: 0.34 })[root.previewSize] || 0.22
    readonly property real screenWidth: previewPopup.screenW > 0 ? previewPopup.screenW : 1536
    readonly property real twoUpMax: (screenWidth - 2 * previewPopup.margin - 2 * previewPopup.padding - Style.space(8)) / 2
    readonly property real cardThumbW: Math.round(Math.max(140, Math.min(screenWidth * fraction, twoUpMax)))
    readonly property real cardThumbH: Math.round(cardThumbW * 0.625)
    readonly property int captureW: Math.round(cardThumbW * 2)
    readonly property int captureH: Math.round(cardThumbH * 2)
    readonly property real emptyW: Math.round(Math.max(Style.space(196), cardThumbW * 0.9))
    readonly property real emptyH: Math.round(Math.max(Style.space(52), cardThumbH * 0.36))
    // 1 window: one column; up to 4: two; more: three, if they fit
    readonly property int columnsCount: windowList.length <= 1 ? 1 : (windowList.length <= 4 ? Math.min(2, fitCols) : fitCols)

    contentWidth: windowList.length === 0
      ? emptyW
      : (columnsCount * cardThumbW + (columnsCount - 1) * Style.space(8) + padding * 2)
    contentHeight: previewColumn.implicitHeight + padding * 2

    onContainsMouseChanged: {
      if (containsMouse) {
        previewCloseTimer.stop()
      } else {
        previewCloseTimer.restart()
      }
    }

    // Under the hovered symbol: a short element-colored line on the card's top edge
    Rectangle {
      readonly property Item target: root.hoveredAnchorItem
      readonly property real targetX: target && previewPopup.visible
        ? target.mapToGlobal(target.width / 2, 0).x - previewColumn.mapToGlobal(0, 0).x : -100
      visible: target !== null && !root.vertical && targetX > 0 && targetX < previewColumn.width
      z: 10
      width: Style.space(18)
      height: 2
      radius: 1
      x: targetX - width / 2
      // On a skin it sits just inside the frame, like an inlay
      y: -previewPopup.padding + (root.skin ? 2 : 0)
      color: previewPopup.element.color
    }

    // The skin's ground and frame, under the content (not part of the layout)
    SkinGround {
      skinSpec: root.skin
      accent: previewPopup.element.color
      inset: previewPopup.padding
      radius: root.cardRadius
    }

    ColumnLayout {
      id: previewColumn
      anchors.fill: parent
      spacing: Style.space(8)
      // The card surface (holder's parent) takes the tradition's corners and ground
      Component.onCompleted: root.styleSurface(previewColumn)

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
            font.family: root.glyphFont(root.iconStyle)
            font.weight: (root.iconStyle === "godai" || root.iconStyle === "wuxing")
              ? Font.DemiBold : Font.Normal
            font.pixelSize: Math.round(root.uniformIconSize * previewPopup.element.glyphScale)
            anchors.horizontalCenterOffset: Math.round(font.pixelSize * previewPopup.element.dx * 2) / 2
            renderType: Text.CurveRendering
          }

          AlchemyGlyph {
            visible: root.iconStyle === "alchemy"
            anchors.centerIn: parent
            kind: previewPopup.element.alchemyKind
            strokeColor: previewPopup.element.color
          }
        }

        Text {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          textFormat: Text.PlainText
          text: previewPopup.slot + " · " + previewPopup.element.name
          color: root.skin ? root.cardText : previewPopup.element.color
          font.family: root.look.font
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          Layout.alignment: Qt.AlignVCenter
          textFormat: Text.PlainText
          text: previewPopup.totalWindowCount === 0
            ? previewPopup.modeLabel
            : (previewPopup.totalWindowCount === 1 ? strings.t("preview.oneWindow")
              : strings.t("preview.windows").arg(previewPopup.totalWindowCount))
          color: root.cardText
          opacity: 0.6
          font.family: root.look.font
          font.pixelSize: Style.font.small || 11
        }
      }

      // Empty workspace placeholder card
      Rectangle {
        visible: previewPopup.windowList.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: previewPopup.emptyH
        radius: root.cardInner
        color: Qt.alpha(root.cardText, emptyMouse.containsMouse ? 0.09 : 0.04)
        border.width: 1
        border.color: emptyMouse.containsMouse ? previewPopup.element.color : Qt.alpha(root.cardText, 0.14)

        Behavior on color { ColorAnimation { duration: Style.duration(Math.min(140, root.look.duration)) } }
        Behavior on border.color { ColorAnimation { duration: Style.duration(Math.min(140, root.look.duration)) } }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.space(2)

          Text {
            Layout.alignment: Qt.AlignHCenter
            textFormat: Text.PlainText
            text: strings.t("preview.noWindows")
            color: root.cardText
            opacity: 0.75
            font.family: root.look.font
            font.pixelSize: Style.font.body
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            textFormat: Text.PlainText
            text: previewPopup.isFocusedWs ? strings.t("preview.hintLayout") : strings.t("preview.hintGo")
            color: root.cardText
            opacity: 0.45
            font.family: root.look.font
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
              : (waylandToplevel && waylandToplevel.title ? String(waylandToplevel.title) : strings.t("preview.window"))
            readonly property string winClass: (modelData && modelData.lastIpcObject && modelData.lastIpcObject.class)
              ? String(modelData.lastIpcObject.class)
              : (waylandToplevel && waylandToplevel.appId ? String(waylandToplevel.appId) : "")
            readonly property bool winActive: modelData ? Boolean(modelData.activated) : false
            readonly property string winNotifLabel: root.windowNotificationLabel(modelData)
            readonly property bool winNotified: winNotifLabel !== ""
            readonly property string appIcon: root.appIconFor(winClass)
            readonly property int strokeW: (winMouse.containsMouse || winActive || winNotified) ? 2 : 1

            Layout.preferredWidth: previewPopup.cardThumbW
            Layout.preferredHeight: previewPopup.cardThumbH
            radius: root.cardInner
            color: root.isLightPopup ? Qt.alpha(root.cardText, 0.06) : Qt.rgba(0, 0, 0, 0.28)
            border.width: 0
            clip: true

            // Thumbnail viewport area
            Item {
              id: thumbViewport
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: titleBar.top
              anchors.margins: winCard.strokeW + 2
              anchors.bottomMargin: 0
              clip: true

              // Live Wayland ScreencopyView
              ScreencopyView {
                id: screencopy
                anchors.centerIn: parent
                captureSource: (previewPopup.open && winCard.waylandToplevel) ? winCard.waylandToplevel : null
                live: previewPopup.open && winCard.waylandToplevel !== null
                paintCursor: false
                constraintSize: Qt.size(previewPopup.captureW, previewPopup.captureH)

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
                color: root.cardText
                opacity: 0.45
                font.family: root.look.font
                font.pixelSize: Style.font.body
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }
            }

            // Bottom title strip (inset inside the border so it never darkens or covers the border ring)
            Rectangle {
              id: titleBar
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.leftMargin: winCard.strokeW
              anchors.rightMargin: winCard.strokeW
              anchors.bottomMargin: winCard.strokeW
              height: Style.space(24)
              color: root.isLightPopup
                ? Qt.alpha(root.cardText, winMouse.containsMouse ? 0.14 : 0.08)
                : (winMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.65) : Qt.rgba(0, 0, 0, 0.48))

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                spacing: Style.space(4)

                Text {
                  visible: winCard.winNotified
                  Layout.alignment: Qt.AlignVCenter
                  textFormat: Text.PlainText
                  text: "󰂚"
                  color: previewPopup.element.color
                  opacity: root.blinkAlpha
                  font.family: root.look.font
                  font.pixelSize: Style.font.small || 11
                }

                Rectangle {
                  visible: winCard.winActive && !winCard.winNotified
                  width: 5
                  height: 5
                  radius: 2.5
                  color: previewPopup.element.color
                  Layout.alignment: Qt.AlignVCenter
                }

                // The app's own icon, when it has one
                Image {
                  visible: winCard.appIcon !== "" && status === Image.Ready
                  source: winCard.appIcon
                  Layout.preferredWidth: Style.space(14)
                  Layout.preferredHeight: Style.space(14)
                  Layout.alignment: Qt.AlignVCenter
                  sourceSize.width: Style.space(28)
                  sourceSize.height: Style.space(28)
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  smooth: true
                }

                Text {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  textFormat: Text.PlainText
                  text: winCard.winTitle
                  color: winCard.winNotified ? previewPopup.element.color : root.cardText
                  font.family: root.look.font
                  font.pixelSize: Style.font.small || 11
                  font.bold: winCard.winNotified
                  elide: Text.ElideRight
                }
              }
            }

            // Top-level border ring rendered above both thumbnail and title strip for uniform 360° opacity
            Rectangle {
              id: borderOverlay
              z: 10
              anchors.fill: parent
              radius: winCard.radius
              color: "transparent"
              border.width: winCard.strokeW
              border.color: winMouse.containsMouse
                ? previewPopup.element.color
                : (winCard.winNotified
                  ? Qt.alpha(Qt.color(previewPopup.element.color), root.blinkAlpha)
                  : (winCard.winActive
                    ? Qt.alpha(Qt.color(previewPopup.element.color), 0.78)
                    : Qt.alpha(root.cardText, 0.18)))
            }

            MouseArea {
              id: winMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.MiddleButton
              onClicked: function(mouse) {
                if (mouse.button === Qt.MiddleButton) root.closeWindow(winCard.modelData)
                else root.focusWindow(winCard.modelData, previewPopup.wsId)
              }
            }
          }
        }
      }

      // Overflow footer for the windows that are not shown
      Text {
        visible: previewPopup.totalWindowCount > previewPopup.windowList.length
        Layout.alignment: Qt.AlignRight
        textFormat: Text.PlainText
        text: strings.t("preview.more").arg(previewPopup.totalWindowCount - previewPopup.windowList.length)
        color: root.cardText
        opacity: 0.55
        font.family: root.look.font
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
    contentWidth: Style.space(360)
    borderSpec: root.skin ? Border.flat("transparent", 0) : Border.flat(Qt.alpha(root.cardText, root.look.ink ? 0.22 : 0.3), root.look.border)
    contentHeight: styleColumn.implicitHeight + padding * 2

    readonly property var styleChoices: [
      { key: "elements", label: strings.t("style.elements") },
      { key: "alchemy",  label: strings.t("style.alchemy") },
      { key: "godai",    label: strings.t("style.godai") },
      { key: "wuxing",   label: strings.t("style.wuxing") }
    ]

    SkinGround {
      skinSpec: root.skin
      accent: root.cardAccent
      inset: stylePopup.padding
      radius: root.cardRadius
    }

    ColumnLayout {
      id: styleColumn
      anchors.fill: parent
      spacing: Style.space(6)
      Component.onCompleted: root.styleSurface(styleColumn)

      Text {
        textFormat: Text.PlainText
        text: strings.t("menu.title")
        color: root.cardText
        font.family: root.look.font
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
          bordered: !root.skin   // on a skin: quiet filled chips, no theme-colored outlines
            radius: root.skin ? Math.max(4, root.cardRadius - 6) : Style.cornerRadius
          foreground: root.cardText
          accent: root.cardAccent
          fontFamily: root.look.font
          // On a skin the selection is drawn here (the theme's selected color is fixed
          // and can vanish on the light grounds)
          selected: !root.skin && (root.iconStyle === choiceKey)
          background: !root.skin ? "transparent" : ((root.iconStyle === choiceKey) ? Qt.alpha(root.cardText, 0.16) : Qt.alpha(root.cardText, 0.05))
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
                    color: root.resolveElementColor(modelData, true, false)
                    font.family: root.glyphFont(choiceBtn.choiceKey)
                    font.weight: (choiceBtn.choiceKey === "godai" || choiceBtn.choiceKey === "wuxing")
                      ? Font.DemiBold : Font.Normal
                    font.pixelSize: Math.round(root.uniformIconSize * modelData.glyphScale)
                    anchors.horizontalCenterOffset: Math.round(font.pixelSize * (modelData.dx || 0) * 2) / 2
                    renderType: Text.CurveRendering
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }

                  AlchemyGlyph {
                    visible: choiceBtn.choiceKey === "alchemy"
                    anchors.centerIn: parent
                    kind: modelData.alchemyKind
                    strokeColor: root.resolveElementColor(modelData, true, false)
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
              color: root.cardText
              font.family: root.look.font
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignLeft
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }
          }
        }
      }

      // Divider & Icon Colors / Preview Size / Notif Blink selectors
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: Style.space(2)
        Layout.bottomMargin: Style.space(2)
        color: root.cardText
        opacity: 0.12
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          Layout.preferredWidth: Style.space(102)
          Layout.alignment: Qt.AlignVCenter
          textFormat: Text.PlainText
          text: strings.t("menu.colors")
          color: root.cardText
          font.family: root.look.font
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Repeater {
          model: [
            { key: "elemental", label: strings.t("opt.soft") },
            { key: "bold",      label: strings.t("opt.bold") },
            { key: "theme",     label: strings.t("opt.theme") }
          ]

          Button {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1   // equal segments
            Layout.preferredHeight: Style.space(28)
            bordered: !root.skin   // on a skin: quiet filled chips, no theme-colored outlines
            radius: root.skin ? Math.max(4, root.cardRadius - 6) : Style.cornerRadius
            foreground: root.cardText
            accent: root.cardAccent
            fontFamily: root.look.font
            // On a skin the selection is drawn here (the theme's selected color is fixed
            // and can vanish on the light grounds)
            selected: !root.skin && (root.colorMode === modelData.key)
            background: !root.skin ? "transparent" : ((root.colorMode === modelData.key) ? Qt.alpha(root.cardText, 0.16) : Qt.alpha(root.cardText, 0.05))
            text: modelData.label
            onClicked: root.selectColorMode(modelData.key)
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          Layout.preferredWidth: Style.space(102)
          Layout.alignment: Qt.AlignVCenter
          textFormat: Text.PlainText
          text: strings.t("menu.preview")
          color: root.cardText
          font.family: root.look.font
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Repeater {
          model: [
            { key: "off",    label: strings.t("opt.off") },
            { key: "small",  label: strings.t("opt.small") },
            { key: "medium", label: strings.t("opt.medium") },
            { key: "large",  label: strings.t("opt.large") },
            { key: "xlarge", label: strings.t("opt.xlarge") }
          ]

          Button {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1   // equal segments
            Layout.preferredHeight: Style.space(28)
            bordered: !root.skin   // on a skin: quiet filled chips, no theme-colored outlines
            radius: root.skin ? Math.max(4, root.cardRadius - 6) : Style.cornerRadius
            foreground: root.cardText
            accent: root.cardAccent
            fontFamily: root.look.font
            // On a skin the selection is drawn here (the theme's selected color is fixed
            // and can vanish on the light grounds)
            selected: !root.skin && (root.previewSize === modelData.key)
            background: !root.skin ? "transparent" : ((root.previewSize === modelData.key) ? Qt.alpha(root.cardText, 0.16) : Qt.alpha(root.cardText, 0.05))
            text: modelData.label
            onClicked: root.selectPreviewSize(modelData.key)
          }
        }
      }

      // How many windows the preview shows
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          Layout.preferredWidth: Style.space(102)
          Layout.alignment: Qt.AlignVCenter
          textFormat: Text.PlainText
          text: strings.t("menu.windows")
          color: root.cardText
          font.family: root.look.font
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Repeater {
          model: [
            { key: "auto", label: strings.t("opt.auto") },
            { key: "2",    label: "2" },
            { key: "4",    label: "4" },
            { key: "6",    label: "6" },
            { key: "9",    label: "9" }
          ]

          Button {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1   // equal segments
            Layout.preferredHeight: Style.space(28)
            bordered: !root.skin
            radius: root.skin ? Math.max(4, root.cardRadius - 6) : Style.cornerRadius
            foreground: root.cardText
            accent: root.cardAccent
            fontFamily: root.look.font
            enabled: root.showPreview
            opacity: root.showPreview ? 1 : 0.4
            selected: !root.skin && (root.previewCount === modelData.key)
            background: !root.skin ? "transparent" : ((root.previewCount === modelData.key) ? Qt.alpha(root.cardText, 0.16) : Qt.alpha(root.cardText, 0.05))
            text: modelData.label
            onClicked: root.selectPreviewCount(modelData.key)
          }
        }
      }

      // Notif Blink speed selector (Off / Slow / Med / Fast)
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          Layout.preferredWidth: Style.space(102)
          Layout.alignment: Qt.AlignVCenter
          textFormat: Text.PlainText
          text: strings.t("menu.blink")
          color: root.cardText
          font.family: root.look.font
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Repeater {
          model: [
            { key: "off",    label: strings.t("opt.off") },
            { key: "slow",   label: strings.t("opt.slow") },
            { key: "medium", label: strings.t("opt.steady") },
            { key: "fast",   label: strings.t("opt.fast") }
          ]

          Button {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1   // equal segments
            Layout.preferredHeight: Style.space(28)
            bordered: !root.skin   // on a skin: quiet filled chips, no theme-colored outlines
            radius: root.skin ? Math.max(4, root.cardRadius - 6) : Style.cornerRadius
            foreground: root.cardText
            accent: root.cardAccent
            fontFamily: root.look.font
            // On a skin the selection is drawn here (the theme's selected color is fixed
            // and can vanish on the light grounds)
            selected: !root.skin && (root.notificationSpeed === modelData.key)
            background: !root.skin ? "transparent" : ((root.notificationSpeed === modelData.key) ? Qt.alpha(root.cardText, 0.16) : Qt.alpha(root.cardText, 0.05))
            text: modelData.label
            onClicked: root.selectNotificationSpeed(modelData.key)
          }
        }
      }

    }
  }
}
