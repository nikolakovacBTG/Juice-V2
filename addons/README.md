# Sparkle Lite

A free, drop-in game-feel ("juice") plugin for **Godot 4.6** — seven layered feedback types (camera shakes, hit pauses, screen flashes, audio one-shots, scale punches, and gameplay hooks) authored in a custom inspector and fired with a single `play()` call.

GDScript only. Zero dependencies. MIT licensed.

```gdscript
$FeedbackPlayer.play()           # fire the full authored sequence
$FeedbackPlayer.play(1.8)        # same sequence at 1.8x intensity
```

---

## Install

1. Copy the `addons/sparkle_lite/` folder from this archive into your Godot project's `addons/` directory.
2. In Godot: **Project → Project Settings → Plugins** → enable **Sparkle Lite**.
3. A `FeedbackPlayerLite` node is now available from the **Add Node** dialog.

Requires Godot **4.6+**.

---

## What's inside `addons/sparkle_lite/`

| Folder / file | What it is |
|---|---|
| `plugin.cfg`, `plugin.gd` | The plugin entry points. |
| `feedbacks/`, `players/`, `presets/`, `editor/` | Runtime and editor code. |
| `samples/` | Nine runnable sample scenes. Open `samples/sparklelite_main.tscn` for the demo hub. |
| `documentation/` | Full docs — Getting Started, Authoring in the inspector, Runtime API, one reference page per feedback. |
| `README.md` | Plugin-facing README with the full feature tour. |
| `LICENSE.md` | MIT license. |

**Start here:** **[`addons/sparkle_lite/README.md`](addons/sparkle_lite/README.md)** — the full guide, feature tour, and quick-start.

---

## The seven feedbacks

| # | Type | What it does |
|---|------|--------------|
| 1 | **Camera Shake** | Layered-noise positional + rotational shake on a `Camera3D`. Per-axis amplitudes, smooth/chaotic noise blend, distance falloff. |
| 2 | **Camera Shake 2D** | Same shake for `Camera2D` — pixel amplitudes, degree rotation, distance falloff in pixels. |
| 3 | **Hit Pause** | Drops `Engine.time_scale` briefly for hit-stop. Lowest-wins stacking, 500 ms safety cap. |
| 4 | **Screen Flash 2D** | Full-viewport colour flash on a persistent `CanvasLayer`. `MODULATE` or `ADD` blend. |
| 5 | **Audio** | `AudioStreamPlayer2D`/`3D` one-shots with pitch randomisation. `POOL` / `CACHE` / `ONE_TIME` allocation. |
| 6 | **Scale Punch** | Elastic scale pop on any `Node2D`, `Node3D`, or `Control`. Last-starts-wins per target. |
| 7 | **Call** | Calls a method or emits a signal on a target node at its place in the timeline. Bridge to gameplay code. |

---

## Upgrade to the full Sparkle

Sparkle Lite is the free edition. The full **[Sparkle](https://neohex-interactive.itch.io/sparkle)** plugin on itch.io ships with 33 feedback types, container / conditional / loop / random-one-of groups, particle and decal bursts, typewriters, floating text, post-processing pulses, and more.

If Sparkle Lite is saving you work, consider grabbing the full edition — it's the only reason this free version exists.

---

## License

MIT — see [`addons/sparkle_lite/LICENSE.md`](addons/sparkle_lite/LICENSE.md). Use, modify, and redistribute freely in personal or commercial projects.

Built by **Neohex Interactive**.
