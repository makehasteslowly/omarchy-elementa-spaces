# Elemental Workspace Indicator (`elemental-workspace-indicator`)

A Hyprland workspace indicator bar widget for [Omarchy](https://omarchy.org/) that represents your workspaces with the symbols and elemental colors of the **Five Elements** (**Fire**, **Water**, **Earth**, **Air**, and **Aether**).

![Preview](preview.png)

## Element & Color Map

| Workspace | Element | Nerd Font Icon | Hex Color |
| :---: | :--- | :---: | :--- |
| **1** *(6)* | **Fire** | `󰈸` (`U+F0238`) | `#FF6B35` (Fiery Orange-Red) |
| **2** *(7)* | **Water** | `󰖌` (`U+F058C`) | `#38BDF8` (Water Blue) |
| **3** *(8)* | **Earth** | `󰌪` (`U+F032A`) | `#4ADE80` (Leaf Green) |
| **4** *(9)* | **Air** | `󰖝` (`U+F059D`) | `#67E8F9` (Wind Cyan) |
| **5** *(10)* | **Aether** | `󱐋` (`U+F140B`) | `#C084FC` (Aether Purple) |

## Features

- **Focused (Active) Workspace:** Rendered at full brightness (`1.0` opacity) in its elemental color with an animated elemental underline bar.
- **Occupied Workspace:** Rendered in its elemental color at `0.78` opacity when windows are open on that workspace.
- **Empty Workspace:** Rendered in the muted bar foreground color at `0.35` opacity.
- **Full Omarchy Multi-Monitor & Layout Support:** Preserves per-monitor workspace blocks (1–10 per monitor), scroll-wheel workspace switching, and clicking the active workspace to cycle Hyprland layouts (`dwindle` / `scrolling` / `floating`).
- **Hover Tooltip:** Shows the workspace number, element name, and (when focused) the active layout mode.

## Dependencies

- **Omarchy Shell** (`omarchy-shell`) and **Hyprland** (included with Omarchy).
- **Nerd Font** (included with Omarchy, e.g., `JetBrainsMono Nerd Font`). No external packages or network access required.

## Installation

Install and enable directly with the `omarchy` CLI:

```bash
omarchy plugin add https://github.com/makehasteslowly/omarchy-five-elements-workspaces.git --enable
```

To move it next to your launcher in the left bar section:

```bash
omarchy bar move elemental-workspace-indicator --section left
```

## Uninstall

```bash
omarchy plugin remove elemental-workspace-indicator
```

## License

[MIT](LICENSE)
