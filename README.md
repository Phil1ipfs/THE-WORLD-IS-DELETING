# THE WORLD IS DELETING: FLOATING REALMS

A Roblox exploration and survival adventure: large floating regions, abandoned villages, forest groves, caves, scavenging, cooperative repairs, ancient seals and multiple escapes. Corruption removes ground section by section while storms and earthquakes threaten the route. All geometry uses native Roblox parts.

Version 0.4.0 turns each realm into a small adventure. Every region offers a seeded selection of realm-specific activities: repairs that change the realm, survivor rescues, creature lairs, pressure-plate, dial and light-mirror puzzles, crystal mining, risky caches, air-current courses, artifact hunts and timed vaults. On top of those come live events, active storm shelters, run perks, relics and achievements. The more you explore, the more you gain, but the outskirts and the ground beneath you keep deleting. Each realm also has its own sky, landmark, flora, architecture, creature and hazards. See [docs/GAMEPLAY.md](docs/GAMEPLAY.md) and [docs/VISUALS.md](docs/VISUALS.md).

## Play in Roblox Studio

1. Open `build/FloatingRealms.rbxlx` in Roblox Studio. The built place is included locally after validation.
2. Press **Play (F5)**. Open **View → Output** to see initialization and Studio smoke checks.
3. Click **Begin Ascent**. A server-synchronized 5-second countdown (5 → 4 → 3 → 2 → 1 → START) begins immediately; friends who queue during it join the same match, and Cancel leaves the queue. The menu sits over a cinematic orbit of the sky sanctuary: a floating village above a lethal ocean. Falling into the ocean ends your run (or respawns you at the sanctuary in the lobby).
4. Explore Havenwood Reach. Press E / controller X / the gold interaction button to gather nearby timber, crystals and herbs. Supplies disappear for the collector; other players can gather their share. Repair the cave-to-grove bridge with 6 shared timber. Collect the labeled Sun, Leaf and Moon keys in the cave. At the SEAL ALTAR, press E / X to place the next collected key, or use 1 / 2 / 3 or the key buttons. Order: Sun > Leaf > Moon. Keys are reusable within their realm; a wrong order resets alignment. Alternatively contribute 4 shared crystals to open the gate.
5. Use supplies from your pack: **H** heals 40 HP; **C** overcharges powers for 12 seconds; **V** spends 2 timber to brace nearby ground for 18 seconds. Controller: D-pad Up / Right / Left. Touch: item buttons. Braces cannot stop the rising deletion wave.
6. Escape upward along the continuous sky causeway, sky elevator or cave gate. Approaching storm clouds, lightning, rain and an eight-second countdown warn you to shelter in a house or cave. Purple cracks warn before sections fall. Q / Z / R / F activate Gust Dash / Sky Leap / Aegis / Wind Sail; controller R2 / Y / B / L1. Dash now lasts 1 second at 62 studs/second (about 62 studs on clear level ground); crystal overcharge extends it to 1.3 seconds. Jump again in midair for Sky Leap. Press F again to fold Wind Sail. M / Select opens settings.
7. Check the REALM OBJECTIVES tracker (top right; tap the header to collapse it). Optional activities pay coins, XP, relics and perks. Creatures glow red before attacking: dodge, raise Aegis, then Gust Dash through them or drop onto them. During storms, patch shelter breaches (E / X) or board them up with Timber Brace (V). Spend 2 relics at a realm shrine you already discovered for a random perk, or keep them: they pay out when your run ends.
8. After elimination, queue again, spectate, or return to the sanctuary. Late joins enter only during the safe opening window; otherwise they queue for the next round.

Studio persistence is disabled by default so local tests cannot overwrite live profiles. Sound assets are intentionally unconfigured; the audio controllers remain silent until permitted IDs are supplied in `src/shared/AudioConfig.luau`.

The storm renderer now uses native sky clouds and high, soft textured layers instead of solid spherical cloud Parts. Approaching, Heavy, Extreme and Recovery phases follow the original damage timer, with directional rain, gusts, distant lightning and delayed configured thunder. See `docs/STORM_SYSTEM.md` for implementation, modified files and the pending Studio visual/device checklist.

Strong storms now form a rotating hurricane funnel beside the realm. Earthquakes fracture nearby terrain, house floors/walls and cave ceilings; affected ground warns before falling. Shelter and the primary causeway remain protected from quake selection. See `docs/DISASTERS.md` for implementation limits and pending Studio checks.

## Develop and verify (Windows PowerShell)

```powershell
# Already installed locally in this workspace; run on a new checkout:
powershell -ExecutionPolicy Bypass -File tools/bootstrap.ps1

# Format, lint, type-check pure modules, compile all Luau, run tests, build:
powershell -ExecutionPolicy Bypass -File tools/check.ps1 -Format

# Rebuild the Studio file:
powershell -ExecutionPolicy Bypass -File tools/build.ps1

# Optional live Rojo workflow; install the official Rojo Studio plugin separately:
.\.tools\rojo\rojo.exe serve default.project.json
```

The build contains source scripts; islands are generated when simulation starts. `tools/` scripts run outside Studio and are excluded from the place. `tests/StudioSmoke.luau` is included and runs only in Studio. `tests/core.spec.luau` is an inert ModuleScript in the place and executes through the standalone Luau CLI.

## Status and limits

This is an implemented, buildable prototype, **not a production-validated release**. Offline tests exercise production modules using Lune fixtures, with explicit substitutes for Roblox services. They do not simulate Roblox character physics, networking, rendering or live DataStores. Studio playtesting, mobile/controller evaluation, multiplayer soak testing and profiling remain pending.

The live world uses connected exploration regions with a walking ascent, elevator and cave portal. All ten realms now have matching HUD accents, terrain palettes, foliage and scenery variations. Houses have framed facades, lit windows, chimneys and furnishings; forests have branching crowns and ground cover. Realms share the escape template (village, grove, cave, causeway), but each now adds its own outskirts landmark, activity pool, creature, hazards, sky and architecture. The earlier helix and 20 obstacle builders remain an isolated regression-tested library and are not generated in adventure sessions.

See `docs/DEVELOPMENT.md` for milestone status, `docs/ARCHITECTURE.md` for implementation details, `docs/TESTING.md` for evidence and the Studio checklist, and `docs/NEXT_STEPS.md` for precise follow-up work.
