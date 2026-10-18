# Rift Hub · Survive The Hulk · v1.1

Standalone Luau with an animated Hulk-themed UI for [Survive The Hulk](https://www.roblox.com/games/109166720609444), by Survive The Hulk. Game metadata verified through Roblox: place `109166720609444`, universe `10742937135`.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/copperpoppercms-sys/Rift-Hub-Survive-The-Hulk/main/main.lua"))()
```

## Controls

Four tabs: Overview, Visuals, Movement and Utility. Drag the header to move the window. Minimize to the draggable H button; tap H to restore. RightShift also toggles the window on a keyboard. Closing the window unloads the script. Re-executing replaces the previous copy. Portrait and landscape layouts adapt to the viewport, with scrollable content.

Visuals start on; movement changes start off. ESP shows only green Hulk chams, black highlights with pale outlines for other players, and exact @usernames. Range, fill opacity and through-wall controls remain available. Distance labels, role labels and health bars have been removed from player overlays. The nearest-Hulk warning remains available while the window is minimized.

Hulk detection uses replicated player/team/model role data or a clearly named Hulk NPC. Green clothes, usernames containing Hulk and Hulkbuster are not treated as proof. The live game's role schema is unverified. If Hulk stays black, enter that player's exact username under Visuals → Hulk identity, or use Copy Hulk detection report during an active round. Reports are only printed/copied locally.

Movement includes fly with adjustable speed, hold-to-sprint, speed boost, jump power, infinite jump, auto-hop and noclip. Flight uses the joystick or WASD, with Space / Ctrl for vertical movement. On touch devices, minimize the hub to show UP / DOWN flight buttons or the hold-to-sprint button. The UI releases held input when reopened, after typing, or when focus is lost. Flight does not enable noclip automatically.

The game can enforce movement/collision limits. Noclip can pass through floors; use it carefully around gaps. Disabling a feature restores the script's saved values. Respawn restores the old character before applying enabled movement to the new one. Fly uses local physics constraints and is not an anti-cheat bypass.

Utility includes nearby-Hulk and low-health alerts, fog/haze removal, fullbright, field of view, extended camera zoom, anti-idle, reduce motion, refresh scan, detection report, rejoin and unload. Anti-idle attempts a brief VirtualUser input only when the idle event fires; executor restrictions are reported in the footer. Restore all changes switches gameplay and visibility features off, restores saved values, and leaves the UI open. Opening, hover, toggle and press animations are native Roblox tweens; no flashing lights or downloaded UI library is used.

## Full editable code

Download `docs/SurviveTheHulk_Editor.html` and open it in a browser. The whole source is editable; Copy all code and Download .lua use your current edits. Paste the full code into Delta. `main.lua` contains the same complete Lua, with no external script dependencies.

## Verification

The fixture uses simulated Roblox services. Run `python tests/run_checks.py` with `LUAU_BIN` and `LUAU_COMPILE_BIN` pointing to native Luau tools. The current suite passes 101 checks covering color/role behavior, usernames-only overlays, collision and movement restoration, sprint and mobile input release, flight constraints, fog/camera settings, respawns, reset, failed flight startup and cleanup. These checks do not verify live role replication, server acceptance or Roblox rendering.

## Rift branding

The header uses the user-supplied Rift Hub R emblem from `assets/rift_logo.jpg`. Existing minimized controls use the same emblem. The original JPEG is preserved unchanged; logo cache names include its content hash. If custom images are unavailable, text branding remains usable.
