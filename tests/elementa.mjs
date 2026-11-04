// Elementa Spaces tests. Run: node tests/elementa.mjs
//
// The functions under test are lifted verbatim out of Workspaces.qml and run
// against small stubs, so these check the code that ships, not a copy.
//   - notification matching: which window blinks (resolveCandidates)
//   - title alerts: unread badges and "messaged you" (extractTitleNotification)
//   - labels, workspace slots and blocks
//   - the four traditions: five elements each, in their traditional order
//   - every skin color reaches 3:1 against its ground, on the bar and the card
//   - settings: every option survives its normalizer; defaults agree
//   - translations: every string the widget asks for exists, none unused
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const qml = readFileSync(join(root, "Workspaces.qml"), "utf8")
const manifest = JSON.parse(readFileSync(join(root, "manifest.json"), "utf8"))
const en = JSON.parse(readFileSync(join(root, "i18n", "en.json"), "utf8"))

let checks = 0, failures = 0
function ok(cond, what) { checks++; if (!cond) { failures++; console.log("FAIL  " + what) } }
function eq(a, b, what) { ok(JSON.stringify(a) === JSON.stringify(b), `${what}: got ${JSON.stringify(a)}, want ${JSON.stringify(b)}`) }

// ---- Lift a function or a property literal out of the QML
function block(start) {
  const open = qml.indexOf("{", start)
  let depth = 0
  for (let i = open; i < qml.length; i++) {
    if (qml[i] === "{") depth++
    else if (qml[i] === "}" && --depth === 0) return qml.slice(open, i + 1)
  }
  throw new Error("unbalanced block at " + start)
}
function fn(name, ctx) {
  const at = qml.indexOf(`  function ${name}(`)
  if (at < 0) throw new Error("function not found: " + name)
  const params = qml.slice(qml.indexOf("(", at) + 1, qml.indexOf(")", at))
  return Function("root", "Qt", "Util", `return function ${name}(${params}) ${block(at)}`)(ctx.root, ctx.Qt, ctx.Util)
}
function literal(name, rootStub) {
  const at = qml.indexOf(`readonly property var ${name}:`)
  if (at < 0) throw new Error("property not found: " + name)
  const body = block(at)
  return Function("root", '"use strict"; return (' + body + ")")(rootStub)
}

// ---- Minimal Qt color stubs (HSV value scaling, as Qt.darker/lighter do)
function hex(h) {
  const m = /^#?([0-9a-f]{6})$/i.exec(h); if (!m) throw new Error("bad color " + h)
  const n = parseInt(m[1], 16); return { r: (n >> 16 & 255) / 255, g: (n >> 8 & 255) / 255, b: (n & 255) / 255, a: 1 }
}
function toHsv(c) {
  const mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b), d = mx - mn
  let h = 0
  if (d) h = mx === c.r ? ((c.g - c.b) / d) % 6 : mx === c.g ? (c.b - c.r) / d + 2 : (c.r - c.g) / d + 4
  return { h: h * 60, s: mx ? d / mx : 0, v: mx }
}
function fromHsv(h, s, v) {
  const c = v * s, x = c * (1 - Math.abs(((h / 60) % 2) - 1)), m = v - c
  const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x]
  return { r: r + m, g: g + m, b: b + m, a: 1 }
}
const Qt = {
  color: c => typeof c === "string" ? hex(c) : c,
  rgba: (r, g, b, a) => ({ r, g, b, a }),
  darker: (c, f) => { const k = toHsv(c); return fromHsv((k.h + 360) % 360, k.s, k.v / f) },
  lighter: (c, f) => {
    const k = toHsv(c); let v = k.v * f, s = k.s
    if (v > 1) { s = Math.max(0, s - (v - 1)); v = 1 }
    return fromHsv((k.h + 360) % 360, s, v)
  }
}

// =========================================================================
// Notification matching
const state = { active: 1 }
const R = { activeWorkspaceId: () => state.active, slots: 10, runs: [] }
const ctx = { root: R, Qt, Util: { shellQuote: s => "'" + s + "'" } }
const resolve = fn("resolveCandidates", ctx)
const win = (title, wsId, focusOrder) => ({ title, wsId, focusOrder })

eq(resolve([], { summary: "x" }), null, "no candidates -> nothing")
eq(resolve([win("only", 3, 5)], {}).title, "only", "one candidate -> that one")
state.active = 1
eq(resolve([win("~/notes", 4, 2), win("build-server", 4, 1)], { summary: "build-server", body: "Deploy finished" }).title,
  "build-server", "the title that matches the notification wins")
eq(resolve([win("~/code", 1, 0), win("~/scratch", 4, 1)], { summary: "kitty", body: "Command finished" }),
  null, "the reported bug: a candidate on the workspace you are on -> nothing blinks elsewhere")
state.active = 7
eq(resolve([win("~/a", 4, 3), win("~/b", 2, 1)], { summary: "kitty" }).title, "~/b",
  "no title match, none on this workspace -> the most recently used")
state.active = 1
eq(resolve([win("chat one", 2, 3), win("chat two", 1, 1), win("music", 3, 0)], { summary: "chat", body: "message" }),
  null, "several title matches, one of them here -> nothing")
state.active = 9
eq(resolve([win("chat one", 2, 3), win("chat two", 5, 1), win("music", 3, 0)], { summary: "chat", body: "message" }).title,
  "chat two", "several title matches, none here -> the most recent of them")
eq(resolve([win("Report", 2, 1), win("report draft", 3, 2)], { summary: "a", body: "is" }).title, "Report",
  "words under four letters are ignored")

// =========================================================================
// Title alerts
const title = fn("extractTitleNotification", ctx)
eq(title("(3) Messenger - Brave"), { count: 3, flash: false, label: "(3) Messenger" }, "badge, browser suffix stripped")
eq(title("[2] WhatsApp — Mozilla Firefox"), { count: 2, flash: false, label: "(2) WhatsApp" }, "square badge, Firefox suffix")
eq(title("(0) Inbox"), null, "a zero badge is not an alert")
eq(title("Trevor messaged you | Facebook"), { count: 1, flash: true, label: "Trevor messaged you | Facebook" }, "messenger flash title")
eq(title("New message from Ana"), { count: 1, flash: true, label: "New message from Ana" }, "new message from")
eq(title("Quarterly report (2) - Google Chrome"), null, "a number later in the title is not a badge")
eq(title("GitHub - Brave Origin"), null, "an ordinary title")
eq(title(""), null, "empty title")

// Labels
const label = fn("formatNotificationLabel", ctx)
eq(label("Brave", "web.whatsapp.com", "brave"), "Brave · web.whatsapp.com", "app and site")
eq(label("WhatsApp web.whatsapp.com", "web.whatsapp.com", ""), "web.whatsapp.com", "site already in the app name")
eq(label("Slack", "", "slack"), "Slack", "app only")
eq(label("", "", "kitty"), "kitty", "falls back to the window class")
eq(label("", "", ""), "Notification", "falls back to a word")

// Workspace slots and blocks: 10 per block
const slotOf = fn("slotOf", ctx), blockOf = fn("blockOf", ctx)
eq([1, 5, 10, 11, 20, 21].map(slotOf), [1, 5, 10, 1, 10, 1], "slots wrap every 10")
eq([1, 10, 11, 20, 21].map(blockOf), [0, 0, 1, 1, 2], "blocks of 10")

// =========================================================================
// Traditions
const packs = literal("packs", { indexed: (list, pack) => list.map((e, i) => Object.assign({ k: i, pack }, e)) })
const expectedOrder = {
  elements: ["Fire", "Water", "Earth", "Air", "Aether"],
  alchemy: ["Fire", "Water", "Earth", "Air", "Aether"],
  godai: ["地", "水", "火", "風", "空"],                 // chi, sui, ka, fū, kū
  wuxing: ["木", "火", "土", "金", "水"]                 // the generating cycle: wood feeds fire feeds earth ...
}
for (const [t, want] of Object.entries(expectedOrder)) {
  const list = packs[t]
  ok(Array.isArray(list) && list.length === 5, `${t} has five elements`)
  const got = t === "godai" || t === "wuxing" ? list.map(e => e.icon) : list.map(e => e.name)
  eq(got, want, `${t} in its traditional order`)
  ok(new Set(list.map(e => e.icon)).size === 5, `${t} icons are distinct`)
  for (const e of list) {
    for (const key of ["color", "boldColor", "lightColor", "boldLightColor"]) ok(/^#[0-9a-f]{6}$/i.test(e[key] || ""), `${t}/${e.name} ${key} is a color`)
    ok(e.glyphScale >= 0.9 && e.glyphScale <= 1.5, `${t}/${e.name} glyph scale ${e.glyphScale} is sane`)
    ok(["fire", "water", "earth", "air", "aether"].includes(e.alchemyKind), `${t}/${e.name} has a drawable alchemy kind`)
  }
}
ok(packs.godai.every(e => e.ink === true), "Godai glyphs are ink (color only when active)")

// =========================================================================
// Contrast: every skin color, as the widget resolves it, reads at 3:1
const R2 = {}
R2.relLum = fn("relLum", { root: R2, Qt, Util: ctx.Util })
R2.contrastRatio = fn("contrastRatio", { root: R2, Qt, Util: ctx.Util })
const withContrast = fn("withContrast", { root: R2, Qt, Util: ctx.Util })
const skins = literal("skins", {})
const bars = { "dark bar": "#111214", "light bar": "#F5F5F5", "mid-gray bar": "#7A7A7A" }
for (const [t, pair] of Object.entries(skins)) {
  for (const variant of ["light", "bold"]) {
    const sk = pair[variant]
    ok(sk && Array.isArray(sk.palette) && sk.palette.length === 5, `${t}/${variant} skin has five colors`)
    ok(sk && /^#[0-9a-f]{6}$/i.test(sk.bg), `${t}/${variant} skin has a ground`)
    if (!sk) continue
    const grounds = Object.assign({ "its card": sk.bg }, bars)
    for (const [gname, g] of Object.entries(grounds)) {
      sk.palette.forEach((c, i) => {
        const out = withContrast(hex(c), hex(g), 3.0)
        const r = R2.contrastRatio(out, hex(g))
        ok(r >= 2.95, `${t}/${variant} color ${i + 1} (${c}) on ${gname} ${g}: ${r.toFixed(2)}:1 after correction`)
      })
    }
    ok(R2.contrastRatio(hex(sk.text), hex(sk.bg)) >= 4.5, `${t}/${variant} card text reads at 4.5:1 (${R2.contrastRatio(hex(sk.text), hex(sk.bg)).toFixed(2)})`)
  }
}

// =========================================================================
// Settings: each option survives its normalizer, defaults are options
const S = { runs: [], bar: { run: c => S.runs.push(c) }, pluginId: "makehasteslowly.elementa", showSizeSample() {} }
const sctx = { root: S, Qt, Util: ctx.Util }
const normalizers = {
  style: [fn("selectStyle", sctx), "localStyleOverride"],
  colorMode: [fn("selectColorMode", sctx), "localColorModeOverride"],
  previewSize: [fn("selectPreviewSize", sctx), "localPreviewSizeOverride"],
  notificationSpeed: [fn("selectNotificationSpeed", sctx), "localNotificationSpeedOverride"],
  previewCount: [fn("selectPreviewCount", sctx), "localPreviewCountOverride"]
}
const schema = manifest.barWidget.schema
for (const s of schema) {
  const d = manifest.barWidget.defaults[s.key]
  ok(d !== undefined, `default for "${s.key}"`)
  ok(s.defaultValue === d, `"${s.key}" defaultValue matches defaults`)
  if (s.type !== "enum") continue
  ok(s.options.some(o => o.value === d), `"${s.key}" default "${d}" is an option`)
  const n = normalizers[s.key]
  ok(!!n, `"${s.key}" has a selector in the widget`)
  if (!n) continue
  for (const o of s.options) {
    S.runs = []
    n[0](o.value)
    eq(S[n[1]], o.value, `"${s.key}" option "${o.value}" survives the selector`)
    ok(S.runs.some(c => c.endsWith(" " + s.key + " '" + o.value + "'")), `"${s.key}" option "${o.value}" is saved with omarchy-bar`)
  }
  S.runs = []; n[0]("nonsense")
  ok(s.options.some(o => o.value === S[n[1]]), `"${s.key}" maps an unknown value to a real option (${S[n[1]]})`)
}

// =========================================================================
// Translations
const used = [...new Set([...qml.matchAll(/strings\.t\("([^"]+)"\)/g)].map(m => m[1]))]
for (const k of used) ok(typeof en[k] === "string" && en[k].length > 0, `string "${k}" exists in en.json`)
for (const k of Object.keys(en)) ok(used.includes(k), `string "${k}" in en.json is used`)
for (const k of used) {
  const holes = (en[k] || "").match(/%\d/g) || []
  ok(new Set(holes).size === holes.length, `string "${k}" has no repeated placeholder`)
}

ok(!qml.includes("TMP-TEST"), "no TMP-TEST hook left in Workspaces.qml")

console.log(`Elementa: ${checks - failures}/${checks} checks pass`)
process.exit(failures ? 1 : 0)
