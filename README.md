# Elementa Spaces

**Your workspaces as the five elements, for the Omarchy bar.**

*Elementa*, Latin for "the elements". Each workspace on your bar becomes an element (fire, water, earth, air, aether, or their counterparts in three other traditions), drawn in its own color. Hover one to see its windows live; when an app on another workspace wants your attention, its element breathes until you look.

![Elementa Spaces in its four traditions](preview.png)

```bash
omarchy plugin add https://github.com/makehasteslowly/omarchy-elementa-spaces.git --enable
```

---

## Four traditions, four design languages

Right-click any element on the bar and pick a tradition. The choice changes more than the symbols: the preview card, the menu, the type and the motion follow it.

| | Symbols | Design language |
|---|---|---|
| **Elemental** | 󰈸 󰖌 󰌪 󰖝 󰫢 Fire, Water, Earth, Air, Aether | Modern and friendly: moderately rounded cards with vivid edges, a modern sans-serif, snappy motion with a little bounce |
| **Alchemical** | 🜂 🜄 🜃 🜁 ✧ Fire, Water, Earth, Air, Aether | Hermetic precision: razor-thin bright lines on crushed black, square corners, serif type, strictly linear motion |
| **Japanese Godai** 五大 | 地 水 火 風 空 Earth, Water, Fire, Wind, Void | Zen minimalism: square corners, ink black and grays, Mincho brush-stroke kanji; color appears only where something is active, and nothing animates |
| **Chinese Wu Xing** 五行 | 木 火 土 金 水 Wood, Fire, Earth, Metal, Water | Taoist flow: generous rounding, warm earth colors, long smooth curves that settle with a gentle give |

Each tradition has **Soft** and **Bold** colors, or **Theme** to take them from your Omarchy theme. Colors are checked against your bar and darkened or lightened when they would not stand out, so light themes work too.

---

## On the bar

| Mark | Meaning |
|---|---|
| A short bar under the element | The workspace you are on |
| A dot | A workspace with windows |
| Nothing | An empty workspace |

When you switch, the dot grows into the bar, in the tradition's own motion.

- **Click** an element to go to that workspace. Click the one you are on to change its layout (tiled, scrolling, floating).
- **Scroll** over the elements to step through your workspaces.
- **Right-click** for the menu: tradition, colors, preview size and alert blink.
- **Hover** for the preview.

## The preview

Hover an element and a card opens with live thumbnails of that workspace's windows and their titles. A short line on the card's top edge points to the element it belongs to. Click a window to go straight to it; click an empty workspace's card to go there. Choose **S**, **M** or **L**, or turn the preview **Off** (the element then shows a plain tooltip).

## Alert blink

When an app on another workspace asks for attention, that workspace's element breathes on the bar until you visit it, and in the preview the window that asked is outlined. Pick **Slow**, **Steady** or **Fast**, or **Off**.

It notices:

- desktop notifications (matched to the app's window),
- windows that mark themselves urgent,
- browser tabs and web apps whose title shows unread messages, such as `(3) Messenger` or "… messaged you", including tabs in the background.

---

## Settings

Everything is in the right-click menu. The same keys can be set from a terminal:

| Key | Values | Default |
|---|---|---|
| `style` | `elements` · `alchemy` · `godai` · `wuxing` | `elements` |
| `colorMode` | `elemental` (Soft) · `bold` · `theme` | `elemental` |
| `previewSize` | `off` · `small` · `medium` · `large` | `medium` |
| `notificationSpeed` | `off` · `slow` · `medium` (Steady) · `fast` | `fast` |

```bash
omarchy bar set makehasteslowly.elementa style godai
omarchy bar move makehasteslowly.elementa --section left   # next to the launcher
```

On first use, with no tradition chosen yet, the menu opens once so you can pick one. Nothing is saved until you choose.

---

## Element maps

Workspaces 6–10 repeat the same five elements.

**Elemental**

| Workspace | Element | Symbol | Codepoint | Color |
|:---:|---|:---:|:---:|---|
| 1 | Fire | 󰈸 | `U+F0238` | `#FF6B35` |
| 2 | Water | 󰖌 | `U+F058C` | `#38BDF8` |
| 3 | Earth | 󰌪 | `U+F032A` | `#4ADE80` |
| 4 | Air | 󰖝 | `U+F059D` | `#67E8F9` |
| 5 | Aether | 󰫢 | `U+F0AE2` | `#C084FC` |

**Alchemical**: drawn, not taken from a font, so all five share one exact size.

| Workspace | Element | Symbol | Geometry |
|:---:|---|:---:|---|
| 1 | Fire | 🜂 | Triangle pointing up |
| 2 | Water | 🜄 | Triangle pointing down |
| 3 | Earth | 🜃 | Downward triangle, crossed |
| 4 | Air | 🜁 | Upward triangle, crossed |
| 5 | Aether | ✧ | Four-point star |

**Japanese Godai** 五大

| Workspace | Element | Kanji | Reading |
|:---:|---|:---:|---|
| 1 | Earth | 地 | *Chi* |
| 2 | Water | 水 | *Sui* |
| 3 | Fire | 火 | *Ka* |
| 4 | Wind | 風 | *Fū* |
| 5 | Void | 空 | *Kū* |

**Chinese Wu Xing** 五行

| Workspace | Element | Hanzi | Pinyin |
|:---:|---|:---:|---|
| 1 | Wood | 木 | *Mù* |
| 2 | Fire | 火 | *Huǒ* |
| 3 | Earth | 土 | *Tǔ* |
| 4 | Metal | 金 | *Jīn* |
| 5 | Water | 水 | *Shuǐ* |

---

## Works alongside Omarchy

Elementa Spaces uses its own plugin ID and its own shell command name (`makehasteslowly.elementa`), so it never collides with Omarchy's built-in workspaces widget, even if both are on a bar. It follows Omarchy's per-monitor workspace blocks and the workspace layout that Omarchy's layout toggle sets.

```bash
omarchy-shell makehasteslowly.elementa refresh   # re-read layouts and workspace blocks
```

## Privacy

Everything happens on your machine. Elementa Spaces makes no network requests. To know which workspace to blink, it reads window titles from Hyprland and the app names in Omarchy's local notification list (`~/.local/state/omarchy/notifications/live.json`); neither leaves your computer or is written anywhere.

## Dependencies

Omarchy (its shell and Hyprland), a Nerd Font and Noto Sans / Noto Serif with their CJK variants, all included with Omarchy. Nothing else to install.

## Moving from Elemental Workspace Indicator

Before version 2.0 this plugin was called **Elemental Workspace Indicator** (ID `elemental-workspace-indicator`). If you installed that, replace it once:

```bash
omarchy plugin remove elemental-workspace-indicator
omarchy plugin add https://github.com/makehasteslowly/omarchy-elementa-spaces.git --enable
```

## Uninstall

```bash
omarchy plugin remove makehasteslowly.elementa
```

## License

[MIT](LICENSE)
