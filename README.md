# Zikozythia

A custom [Sound Space Plus](https://github.com/Rhythia/sound-space-plus) client, built for fun by **ZikoZuno** — started out only being made for his friend, **VROOM**.

Zikozythia takes the full Sound Space Plus game and layers in the signature feature of this client: a **fully configurable, per-element bloom pipeline** in the style of the Rhythia Steam clients.

## Features

- **Layered bloom shader** — notes, cursor + trail, playfield border, background and hit effects each get their own render layer, blur, glow strength and glow radius
- **Live settings preview** — a miniature gameplay scene in the settings screen that re-renders your bloom changes instantly, at 1100×619 (16:9)
- **Alt + scroll volume** — hold Alt and scroll anywhere to adjust master volume in 5% steps, with an on-screen volume ring
- **Smooth continuous song list** — drag, fling and glide scrolling like a website, replacing the old page-stepped list
- **Black / white / red UI theme** — dark red buttons, red-to-black gradient text fields, red accents throughout
- **Rebranding** — Zikozythia splash, icon, logo, credits and window title
- Everything else from Sound Space Plus: online maps, replays, cursordance, VR, content manager

## Bloom settings

Settings → Bloom:

| Setting | What it does |
|---|---|
| Bloom On | Master switch |
| Bloom Cutoff | How bright a pixel must be before it glows |
| Glow Colorfulness | Color intensity of the glow |
| Note / Cursor / Playfield / Background / Effects Glow | Per-element glow strength |
| ...Glow Size | Per-element glow radius |

## Building

1. Open the project in **Godot 3.6.2** and edit, or
2. Build the data pack directly with [GDRE Tools](https://github.com/GDRETools/gdsdecomp):
   ```
   gdre_tools.exe --headless --txt-to-bin=project.godot --output=<dir>   # regenerate project.binary after editing project.godot
   gdre_tools.exe --headless --pck-create=<this folder> --pck-version=1 --pck-engine-version=3.6.2 --output=Zikozythia.pck
   ```
3. Ship `Zikozythia.pck` next to a Godot 3.6.2 Windows export named `Zikozythia.exe`, along with the GDNative DLLs from a Sound Space Plus install.

The included `project.binary` is the compiled project settings used by the runtime.

## Credits

- **ZikoZuno** — Zikozythia client development
- **VROOM** — the friend it was originally made for
- **CAPO Games / [Rhythia](rhythia.com)**
- The bloom shader is an original reimplementation of a Rhythia-style glow pipeline written for this client
