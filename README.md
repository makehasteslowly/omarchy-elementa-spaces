# Elemental Workspace Indicator (`elemental-workspace-indicator`)

A Hyprland workspace indicator bar widget for [Omarchy](https://omarchy.org/) that represents your workspaces with the symbols and elemental colors of the **Five Elements** (**Fire**, **Water**, **Earth**, **Air**, and **Aether**) — selectable between **Elemental Icons** and **Alchemical Symbols**.

![Preview](preview.png)

## Element & Color Map

| Workspace | Element | Elemental Icon (`elements`) | Alchemical Symbol (`alchemy`) | Hex Color |
| :---: | :--- | :---: | :---: | :--- |
| **1** *(6)* | **Fire** | `󰈸` (`U+F0238`) | `🜂` (`△`) | `#FF6B35` (Fiery Orange-Red) |
| **2** *(7)* | **Water** | `󰖌` (`U+F058C`) | `🜄` (`▽`) | `#38BDF8` (Water Blue) |
| **3** *(8)* | **Earth** | `󰌪` (`U+F032A`) | `🜃` (`▽` + crossbar) | `#4ADE80` (Leaf Green) |
| **4** *(9)* | **Air** | `󰖝` (`U+F059D`) | `🜁` (`△` + crossbar) | `#67E8F9` (Wind Cyan) |
| **5** *(10)* | **Aether** | `󱐋` (`U+F140B`) | `✧` (Quintessence star) | `#C084FC` (Aether Purple) |

## Features

- **Two Selectable Symbol Styles:**
  - **Elemental Icons (`elements`):** Nerd Font elemental glyphs (`󰈸 󰖌 󰌪 󰖝 󱐋`).
  - **Alchemical Symbols (`alchemy`):** Crisp vector-rendered Alchemical geometry (`🜂 🜄 🜃 🜁 ✧`) with zero extra font dependencies.
- **Style Selector on Install & Right-Click:** Automatically opens a style selector popup on first install when no style is stored in `shell.json`, and you can **right-click** any workspace indicator on the bar at any time to switch between styles.
- **Focused (Active) Workspace:** Rendered at full brightness (`1.0` opacity) in its elemental color with an animated elemental underline bar.
- **Occupied Workspace:** Rendered in its elemental color at `0.78` opacity when windows are open on that workspace.
- **Empty Workspace:** Rendered in its muted elemental tint at `0.40` opacity.
- **Full Omarchy Multi-Monitor & Layout Support:** Preserves per-monitor workspace blocks (1–10 per monitor), scroll-wheel workspace switching, and left-clicking the active workspace to cycle Hyprland layouts (`dwindle` / `scrolling` / `floating`).

## Dependencies

- **Omarchy Shell** (`omarchy-shell`) and **Hyprland** (included with Omarchy).
- **Nerd Font** (included with Omarchy, e.g., `JetBrainsMono Nerd Font`). No external packages or network access required.

## Installation

Install and enable directly with the `omarchy` CLI:

```bash
omarchy plugin add https://github.com/makehasteslowly/omarchy-five-elements-workspaces.git --enable
```

On first load, a popup lets you pick **Elemental Icons** or **Alchemical Symbols**. You can also switch styles anytime by **right-clicking** the workspace indicators on the bar or running:

```bash
# Use Nerd Font elemental icons (󰈸 󰖌 󰌪 󰖝 󱐋)
omarchy bar set elemental-workspace-indicator style elements

# Use Alchemical symbols (🜂 🜄 🜃 🜁 ✧)
omarchy bar set elemental-workspace-indicator style alchemy
```

To move the widget next to your launcher in the left bar section:

```bash
omarchy bar move elemental-workspace-indicator --section left
```

## Uninstall

```bash
omarchy plugin remove elemental-workspace-indicator
```

## License

[MIT](LICENSE)
