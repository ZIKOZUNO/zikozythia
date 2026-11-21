# Zikozythia v0.5

## Replay system overhaul

- **Personal bests now remember their replay** - every best score is permanently linked to the exact recording of that run
- **Watch Replay / Watch Autoplay** - two half-width buttons under Start!; Watch Replay only appears for maps you have replays for
- **Mod-specific replays** - the replay button only offers runs recorded with your currently equipped modifiers (1.25x best and 1.15x best each show under their own mods)
- **Replays dropdown** - a compact "Replays" menu next to the song title previews your **top 5 plays** on the map: date, mods, accuracy, pass/fail and a star on the linked best. Click any entry to watch it
- **Every play is recorded** (on by default). Passed runs are kept; failed runs are discarded when you start the next song unless you click **Save Replay** - and passed runs can be discarded with **Don't Save Replay**
- Runs quit via restart/leave are finalized properly so they stay watchable, and broken partial recordings are skipped everywhere

## Humanized autoplay

The autoplay bot no longer moves mathematically perfect. It **learns your movement** from your recorded replays (flick shapes, acceleration rhythm, overshoot, idle drift) and plays new maps the way *you* would move - while still hitting every note. The profile rebuilds itself automatically as you record more.

## Movable HUD (F7)

Press **F7** during a song to pause and unlock the HUD: drag any panel (HP bar, time bar, combo circle, side panels, config display...) anywhere in 3D, right-click a panel to reset it, F7 to save and resume. Layout persists per install.

## Live replay settings

Pressing **Esc** during a replay pauses it and opens a live settings panel: approach rate, spawn distance, fade length, parallax, UI/grid parallax, FOV, cursor drift and camera unlock - applied instantly to the playback.

## Other

- **PB badges on map cards** - your grade (S/A/B/...) on passed maps, progress % on failed bests, ranked across all mod combos
- **Rich Discord presence** - shows what you're doing with an elapsed-time clock: playing (with modifiers), watching a replay/autoplay, browsing menus, and your result after a run
- Recording is now on by default for new installs
- Internal: replay file validation, self-check tooling (`test_selfcheck.gd`)

**Note:** personal best files are now format v4. Older Zikozythia builds cannot read them - keep this version.
