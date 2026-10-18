# Rift Hub · Survive The Hulk · v1.0

Standalone Luau with an animated Hulk-themed UI for [Survive The Hulk](https://www.roblox.com/games/109166720609444), by Survive The Hulk. Game metadata verified through Roblox: place `109166720609444`, universe `10742937135`.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/copperpoppercms-sys/Rift-Hub-Survive-The-Hulk/main/main.lua"))()
```

## Controls

Four tabs: Overview, Visuals, Movement and Utility. Drag the header to move the window. Minimize to the draggable H button; tap H to restore. RightShift also toggles the window on a keyboard. Closing the window unloads the script. Re-executing replaces the previous copy. Portrait and landscape layouts adapt to the viewport, with scrollable content.

Visuals start on; movement changes start off. ESP offers green Hulk chams, black highlights with pale outlines for other players, usernames, distance, health bars, range, fill opacity and through-wall controls. The nearest-Hulk warning remains available while the window is minimized.

Hulk detection uses replicated player/team/model role data or a clearly named Hulk NPC. Green clothes, usernames containing Hulk and Hulkbuster are not treated as proof. The live game's role schema is unverified. If Hulk stays black, enter that player's exact username under Visuals → Hulk identity, or use Copy Hulk detection report during an active round. Reports are only printed/copied locally.

Movement includes speed, jump power, infinite jump and noclip. The game can enforce speed/collision limits. Noclip can pass through floors; use it carefully around gaps. Disabling a feature restores the script's saved values. Respawn restores the old character before applying enabled movement to the new one.

Utility includes nearby-Hulk alerts, fullbright, field of view, reduce motion, refresh scan, detection report, rejoin and unload. Opening, hover, toggle and press animations are native Roblox tweens; no flashing lights or downloaded UI library is used.

## Full editable code

Download `docs/SurviveTheHulk_Editor.html` and open it in a browser. The whole source is editable; Copy all code and Download .lua use your current edits. Paste the full code into Delta. `main.lua` contains the same complete Lua, with no external script dependencies.

## Verification

The fixture uses simulated Roblox services. Run `python tests/run_checks.py` with `LUAU_BIN` and `LUAU_COMPILE_BIN` pointing to native Luau tools. Checks cover color/role behavior, collision and movement restoration, visibility, respawns, UI controls and cleanup. These checks do not verify live role replication, server acceptance or Roblox rendering.
