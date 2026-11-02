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

  // Floating hover preview size setting: "off" | "small" | "medium" | "large" (defaults to "medium")
  property string localPreviewSizeOverride: ""
  readonly property string configuredPreviewSize: {
    if (root.settings && root.settings.previewSize !== undefined && root.settings.previewSize !== null) {
      var s = String(root.settings.previewSize).toLowerCase()
      if (s === "off" || s === "small" || s === "medium" || s === "large") return s
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

  Behavior on blinkAlpha {
    NumberAnimation {
      duration: Style.duration(Math.round(root.blinkIntervalMs * 0.92))
      easing.type: Easing.InOutSine
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
            label: root.formatNotificationLabel(appRaw, sourceRaw, wmClass)
          })
        }
      }
      if (pidMatches.length === 1) return pidMatches[0]
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
              inactive: list[i].workspace.id !== activeId ? 0 : 1,
              focusOrder: Number(ipc && ipc.focusHistoryID !== undefined ? ipc.focusHistoryID : 9999),
              label: root.formatNotificationLabel(appRaw, sourceRaw, wmClass)
            })
          }
        }
        if (titleCandidates.length > 0) {
          titleCandidates.sort(function(a, b) {
            if (a.inactive !== b.inactive) return a.inactive - b.inactive
            return a.focusOrder - b.focusOrder
          })
          return titleCandidates[0]
        }
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
          historyCandidates.sort(function(a, b) {
            if (a.inactive !== b.inactive) return a.inactive - b.inactive
            if (a.recency !== b.recency) return a.recency - b.recency
            return a.focusOrder - b.focusOrder
          })
          return historyCandidates[0]
        }
      }
    }

    // 3. Fallback: Match the actual application window (excluding unrelated PWAs with "__" in wmClass),
    // preferring windows on inactive workspaces so an open browser window on the active workspace doesn't shadow an inactive one.
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
      if (pool.length > 0) {
        pool.sort(function(a, b) {
          if (a.inactive !== b.inactive) return a.inactive - b.inactive
          return a.focusOrder - b.focusOrder
        })
        return pool[0]
      }
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

  function selectPreviewSize(nextSize) {
    var normalized = (nextSize === "off" || nextSize === "small" || nextSize === "large")
      ? nextSize : "medium"
    root.localPreviewSizeOverride = normalized
    if (normalized === "off") root.previewOpen = false
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
        readonly property bool notified: !shown && root.isWorkspaceNotified(modelData)
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
        opacity: (shown || notified) ? 1.0 : (occupied ? 0.78 : 0.4)
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
          font.family: wsBtn.isCjk ? "Noto Sans CJK JP" : (root.bar ? root.bar.fontFamily : Style.font.family)
          font.weight: wsBtn.isCjk ? Font.DemiBold : Font.Normal
          font.pixelSize: Math.round(root.uniformIconSize * wsBtn.element.glyphScale)
          renderType: Text.CurveRendering
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          scale: wsBtn.pressScale * wsBtn.blinkScale
        }

        // Uniform-size vector Alchemical symbol renderer (exact 12px outer bounds matching the other packs).
        Canvas {
          id: alchemyCanvas
          visible: wsBtn.useAlchemy
          width: 16
          height: 16
          anchors.centerIn: parent
          anchors.verticalCenterOffset: -1
          opacity: wsBtn.notified ? root.blinkAlpha : 1.0
          scale: wsBtn.pressScale * wsBtn.blinkScale
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
    readonly property string wsNotifLabel: root.workspaceNotificationLabel(wsId)

    borderColor: Qt.alpha(Qt.color(previewPopup.element.color), 0.55)

    readonly property real cardThumbW: root.previewSize === "small"
      ? Style.space(140)
      : (root.previewSize === "large" ? Style.space(256) : Style.space(188))
    readonly property real cardThumbH: root.previewSize === "small"
      ? Style.space(88)
      : (root.previewSize === "large" ? Style.space(158) : Style.space(116))
    readonly property int captureW: root.previewSize === "small" ? 280 : (root.previewSize === "large" ? 512 : 360)
    readonly property int captureH: root.previewSize === "small" ? 176 : (root.previewSize === "large" ? 320 : 225)
    readonly property real emptyW: root.previewSize === "small"
      ? Style.space(196)
      : (root.previewSize === "large" ? Style.space(272) : Style.space(224))
    readonly property real emptyH: root.previewSize === "small"
      ? Style.space(52)
      : (root.previewSize === "large" ? Style.space(76) : Style.space(64))
    readonly property int columnsCount: windowList.length <= 1 ? 1 : 2

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
        Layout.preferredHeight: previewPopup.emptyH
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
            readonly property string winNotifLabel: root.windowNotificationLabel(modelData)
            readonly property bool winNotified: winNotifLabel !== ""
            readonly property int strokeW: (winMouse.containsMouse || winActive || winNotified) ? 2 : 1

            Layout.preferredWidth: previewPopup.cardThumbW
            Layout.preferredHeight: previewPopup.cardThumbH
            radius: Math.max(4, Style.cornerRadius - 2)
            color: Qt.rgba(0, 0, 0, 0.28)
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
                color: Color.foreground
                opacity: 0.45
                font.family: Style.font.family
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
              color: winMouse.containsMouse
                ? Qt.rgba(0, 0, 0, 0.65)
                : Qt.rgba(0, 0, 0, 0.48)

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
                  font.family: Style.font.family
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

                Text {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  textFormat: Text.PlainText
                  text: winCard.winTitle
                  color: winCard.winNotified ? previewPopup.element.color : Color.foreground
                  font.family: Style.font.family
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
                    : Qt.rgba(1, 1, 1, 0.16)))
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
    contentWidth: Style.space(324)
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

      // Divider & Preview Size selector (Off / S / M / L)
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: Style.space(2)
        Layout.bottomMargin: Style.space(2)
        color: Color.foreground
        opacity: 0.12
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          textFormat: Text.PlainText
          text: "Preview Size"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        Repeater {
          model: [
            { key: "off",    label: "Off" },
            { key: "small",  label: "S" },
            { key: "medium", label: "M" },
            { key: "large",  label: "L" }
          ]

          Button {
            required property var modelData
            Layout.preferredWidth: modelData.key === "off" ? Style.space(42) : Style.space(34)
            Layout.preferredHeight: Style.space(28)
            bordered: true
            selected: root.previewSize === modelData.key
            text: modelData.label
            onClicked: root.selectPreviewSize(modelData.key)
          }
        }
      }

      // Notif Blink speed selector (Off / Slow / Med / Fast)
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          textFormat: Text.PlainText
          text: "Notif Blink"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Repeater {
          model: [
            { key: "off",    label: "Off" },
            { key: "slow",   label: "Slow" },
            { key: "medium", label: "Med" },
            { key: "fast",   label: "Fast" }
          ]

          Button {
            required property var modelData
            Layout.preferredWidth: modelData.key === "slow" || modelData.key === "fast"
              ? Style.space(44)
              : Style.space(38)
            Layout.preferredHeight: Style.space(28)
            bordered: true
            selected: root.notificationSpeed === modelData.key
            text: modelData.label
            onClicked: root.selectNotificationSpeed(modelData.key)
          }
        }
      }
    }
  }
}
