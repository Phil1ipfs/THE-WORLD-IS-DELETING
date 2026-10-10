# Changelog

## 0.5.0 Suspension bridges, larger realms and queue card fix (2026-10-10)

- **Queue card fix.** The countdown card is a CanvasGroup; the shared panel style had added a `UIGradient`, which on a CanvasGroup tints every child. That made the number, labels and Cancel nearly invisible. The card now has a solid fill, and a regression test guards it.
  - Also replaced glyphs the UI font cannot draw (empty boxes in the menu cards and tracker) with emoji or text tags, and creature HP labels with "HP n/m".
- **Suspension bridges.** A new `Services/SuspensionBridge.luau` builds them procedurally:
  - a quadratic Bézier deck with a gentle sag (2.5% of span, at most 8 studs) that connects endpoints at any elevation
  - individual planks with gaps and jittered size, angle and wood tone
  - segmented-cylinder rope handrails (collidable, with a slight droop), lower guide ropes and vertical hangers
  - anchor posts with caps and rope collars, and under-deck beams at both ends
  
  Thin invisible collider segments carry the walking surface and are the deletion cells; they stay invisible while falling. The Sky Causeway, forest and cave crossings, all sub-area bridges and the sanctuary islet bridge use it; frames are built with `CFrame.fromMatrix`. The repairable shortcut keeps its plank-walkway style, because its repair logic toggles every part.
- **Bridge sway.** Clients animate visible planks and ropes only (not colliders or posts): a small sideways sway, strongest mid-span, larger in storms and while you are on the bridge.
- **Realm expansion.** `RegionLayout.satellites` places up to 4 named sub-area landmasses per region: Highlands (+30), Cliffside (+18), Wildwood (+8) and Ruins (−8), radius 50–66. Placement is greedy and clears causeway corridors, grove, cave, outskirts, the mainland, village houses and other islands, within world bounds.
  - Every one of 48 tested regions gets 4 (minimum 3). Land is 2.13× the cells before 0.4.0, plus terraces and decks.
  - Each realm names its sub-areas (40 names, for example Misty Highlands, Ancient Wildwood, Forgotten Ruins, Cliffside Hamlet).
- **Sub-area content:**
  - **Highlands:** a terraced plateau with ramp, a climbable lookout deck and a rock arch.
  - **Wildwood:** a treehouse deck, a giant tree and dense woodland.
  - **Ruins:** a colonnade, statue and broken walls.
  - **Cliffside:** a realm-styled house that is also a storm shelter (with breaches).
  - Every sub-area also gets a waterfall, label, cover, paths and extra supplies.
  - A new **Survey** activity puts a cairn on every sub-area. Each chart pays a small reward, and charting all of them pays a perk and a relic. Signposts with purpose text stand at every bridge head.
  - Pool activities (repairs, lairs, puzzles, mining, caches, artifacts) can now spawn on sub-areas and are height-correct, including creatures, attack markers, plates and mirror beams.
- **Pacing.** `RegionLifetime` 180 → 240s. Sub-areas carry Edge ≥ 0.92, so they warn and fall about 70s before the core; the global wave speed is unchanged. Lobby relocated to x = 2400 so the menu vista never intrudes into the larger realm airspace. The server position guard widened from ±700 to ±1400 studs, and the ocean fill now covers −1536…3584 × ±1536.
- **Tests:** new `tools/expansion.spec.luau` (7 cases), a new core satellite test (15 core cases), and a queue-card assertion.
  - Updated for intentional changes: per-region part budget 3,600 → 7,000; shelter counts ≥ 4 (the Cliffside house adds one); 4 pool activities plus Survey.


## 0.4.1 Main menu, ocean world and 5-second queue (2026-10-10)

- **Queue.** `GameConfig.Intermission` is now 5 seconds and starts on the BEGIN ASCENT click instead of the next server tick.
  - The countdown comes from server snapshots and reads 5 → 4 → 3 → 2 → 1 → START.
  - Players who queue during the countdown join the same match.
  - Repeat clicks cannot extend the countdown or queue twice. A new Cancel request leaves the queue.
  - Snapshots now report how many players are queued.
  - There is no other preparation timer: the realm generates and the character spawns when the round starts.
- **Ocean.** A new `Services/Ocean.luau` removes Studio-template `Baseplate` parts and fills a 4096-stud Terrain water slab whose surface sits at `OceanY = -32` (on the 4-stud voxel grid). It also sets water color, transparency, reflectance and waves.
  - Clients add a camera-following 3×3 horizon surface just under the water line, so the ocean reaches the horizon beyond the streamed terrain.
  - The low cloud sea is now a mist layer over the ocean that follows the deletion wave once the wave rises above it.
- **Ocean death.** The server checks a height boundary at the water surface in `PlayerManager.update`; it does not rely on `Touched`.
  - Alive players are eliminated once with "Fell into the ocean". Elevator riders are exempt.
  - Lobby, queued and spectating characters die and respawn at the sanctuary.
  - Clients play a splash, a teal flash and a notice.
- **Menu world.** A new `Services/MenuVista.luau` turns the sanctuary into a grassy floating village island:
  - a hanging rock underside, a cottage, a lookout tower, lanterns, a campfire, trees and flowers
  - a waterfall, plus a satellite islet joined by a rope bridge
  - nine distant floating islands (some with waterfalls), eight sea stacks and a snow-capped mountain range
  - a new shared `MenuScene.luau` defines a cinematic orbit that stays outside every vista object. The camera eases onto the path and hands control back for gameplay.
- **Menu UI.** The menu is now a hero layout over the scene:
  - a gradient-shaded left column with a gradient title and pulsing glow, a violet "deletion" scan bar and an animated accent
  - a large gold BEGIN ASCENT button with a moving shine
  - a 2×2 card grid with icons and subtitles for How to Play, Settings, Shop and Leaderboards
  - a status dot and footer
  - hover, press and click animation on every button, and a fade-and-slide when the menu opens
  - a centered layout on narrow and portrait screens
  - a queue card with a pulsing number, draining bar, queued-player count, honest "ascent in progress" text and Cancel
  - a START transition with a fade showing the realm name, and countdown tick/start/splash cues
- **Tests.** New `tools/menu-ocean.spec.luau` (9 cases).


## 0.4.0 Realm adventures and visual overhaul (2026-10-10)

Gameplay:
- Added a realm objective framework: ObjectiveService, an activity builder and 11 activity modules (repair, rescue, creature hunt, pressure plates, symbol dials, light mirrors, crystal mining, caches, air-current rings, artifacts, timed vaults).
- Each realm has its own pool of 5 activities, a creature, a landmark, events and hazards. Each region draws 4 activities per round from its pool, seeded by the round.
- Added 10 realm creatures with telegraphed lunge, slam, strike and blink attacks. Players defeat them with Gust Dash or by dropping onto them; Aegis reflects lunges.
- Added a seeded dynamic event director with lifetime-aware spawning: supply drops, rare relics, roaming guardians, lost travelers, secret vaults and ancient machines.
- Storms now breach shelters. Players can patch breaches, board them up with Timber Brace, or fortify shelters by repairing generators. Storm-only hoards reward going outside.
- Added risk/reward systems:
  - run perks (7, no stacking)
  - relics (shrine blessing or end-of-run payout)
  - XP grants
  - 9 persisted achievements, 3 of which unlock cosmetics that cannot be bought
- Added lava and void hazards and a slippery ice lake. Overcharge extends vault doors; Explorer's Pack raises supply caps.

Visuals:
- Per-realm sky profiles: Sky, Atmosphere, Clouds, Bloom, SunRays and grading, with smooth blending.
- New cloud formations: a cloud sea below the islands and an advancing storm shelf cloud.
- Storm additions: lightning forks, rain sheets, thunder rumble and Heavy-phase shake.
- Outskirts lobes expand every region by about 35%. Each realm has a landmark with a walkable viewpoint, plus water features, paths, camps and hanging island undersides.
- Procedural asset library: 9 tree types, fallen logs, about 15 ground-cover types, rocks and props.
- Ten architectural house styles with detailed exteriors and furnished interiors. The shelter footprint is unchanged.
- Redesigned herbs, crystals, timber, key tablets, altar, portal, elevator and spring.
- Pickup feedback: target highlight, lift-and-dissolve animation, particles, floating text, sound and HUD feed.
- Power effects for all powers and items, including an Aegis shatter. Braced ground shows wooden reinforcement.
- HUD: health/shield bar, deletion meter, realm banner, objective tracker, cooldown sweeps, reward feed, achievement popup and damage/heal flashes.

Performance:
- Per-ground collapse index, tag-indexed interaction lookup, streaming-safe detail registration, StreamingMesh model LOD, light and part budgets.
- ShadowMap lighting set in the project file.

Tests:
- New `tools/gameplay.spec.luau` (18 cases) and `tools/visuals.spec.luau` (13 cases).
- New core outskirts test; bootstrap snapshot assertion; Studio smoke checks.
- Updated the weather anchor budget from 19 to 21 for the two new fixed sky anchors.

## Hurricane and earthquake fractures — 2026-10-10

- Added a world-anchored, tapered smoke-ribbon hurricane during storms, with pooled rotation, cloud wisps, smooth recovery/reset/rebase and reduced-detail budgets.
- Earthquakes target occupied areas and draw crooked terrain, village and cave surface fractures. Ceiling seams face interior occupants. Affected ground warns before falling with its attached structures; refuge/causeway protection and timber braces remain integrated.
- Added bounded surface cleanup, grounded dust and hurricane/quake warnings with deletion priority. Reused storm damage, shelter, camera shake and configured audio slots.
- Added ten disaster regressions and updated storm budgets. Full suite/endurance plus final-source static/build/weather/bootstrap checks pass; native rendering, physics, multiplayer and performance still require Studio.

## Collectible seal keys and longer dash — 2026-10-10

- Replaced static Sun/Leaf/Moon alignment controls with once-per-player collectible tablets, a realm-specific key pouch and a separate SEAL ALTAR. E/X places the next owned key; 1/2/3 and key buttons allow explicit placement. Shared seal progress remains cooperative and crystal charging remains an alternative.
- Added server validation for ownership and realm, retained range/ground/life/debounce checks, and made keys reusable so a wrong order never loses the solution. Collected tablets/labels hide locally and follow collapsing ground. Pouches clear on a new round and prune with retired regions.
- Added ownership/progress HUD and contextual key buttons within the existing mobile item-row footprint. Updated help and native prompt text.
- Extended Gust Dash from 0.3s to 1s at 62 studs/second; overcharge extends it to 1.3s. Camera duration follows the authorized payload and another ability cannot shorten the current movement allowance.
- Added six key regressions and expanded puzzle, client, power and real server bootstrap coverage. Native Studio input, rendering, replication and physical dash distance still require playtesting.

## Storm renderer redesign — 2026-10-10

- Removed the seven nearby solid spherical storm clouds and spherical cloud backdrop. Native Terrain/Clouds and three high soft particle layers now vary cover, color, opacity, shape and wind drift.
- Added Approaching/Heavy/Extreme visual targets and smooth ten-second Recovery while keeping the existing eight-second warning, sixteen-second damaging event and shelter logic unchanged.
- Added directional rain streaks, wind spray/gusts, bounded fog/haze and gradual Lighting/color transitions. Camera options suppress peak gust motion and bright flashes; low detail keeps essential sky/rain/HUD cues.
- Reused six pooled distant lightning Beams and added delayed thunder plus wind/rain audio slots. No numeric audio IDs were added.
- Updated client integration/HUD and added storm QA for cloud geometry, phases, budgets, rebasing, reset, shelter, sound timing/mute and existing server damage timing. Studio appearance, actual playback and performance remain unverified; no new screenshot attachment was accessible.

## 0.3.0 — 2026-10-10

- Fixed resource interaction reliability with explicit native keys, an on-screen fallback and server-validated node IDs. Footprint ground checks tolerate nearby small obstructions. Each resource is collected once per player; it hides locally and remains available to other players.
- Added useful portable items: 40 HP herbs, 12-second crystal overcharge and 18-second timber bracing. Inventory caps, costs, cooldowns and duplicate collection are server-owned. Supplies now have log, crystal and herb shapes and collapse with supporting ground.
- Strengthened all four powers: sustained Gust Dash, higher Sky Leap, 60-damage Aegis and six-second steerable Wind Sail. Added activation feedback, power visuals, boosted stats, jump-button air leap and foldable glide. Authorized client impulses support character ownership; dash and glide can combine.
- Added realm-specific HUD colors, item controls, health/shield values, power status and shortcut labels. Updated help and phone landscape placement.
- Added seeded grass/realm flora, tree branches/crowns, house framing, glowing windows, chimneys, beds, tables and lamps. Ten realm palettes/materials vary the shared exploration template; optional detail respects distance and performance settings.
- Made approaching storms visible during the eight-second warning: moving dark cloud bank, lightning, building rain, lighting changes and HUD countdown/shelter status. Essential storm cues remain with detail disabled.
- Added item/power, all-realm scenery, storm-warning, themed UI and local impulse regressions. Roblox Studio rendering, physics and multiplayer acceptance remain pending.

## 0.2.0 — 2026-10-10

- Replaced the live helix/rune loop with broad exploration regions: village, forest, cave, grove, native climbable lookout, varied island sizes and continuous walking causeways.
- Added finite scavenging, capped packs, shared bridge repairs, cave glyph puzzles, crystal-powered gates, herb healing and discoveries.
- Added server-controlled elevator decks and adjacent-region portals with cancellation/rebase handling.
- Replaced checkpoint ordering with supported-ground altitude and region progression while retaining rounds, rewards, persistence and server validation.
- Added local section corruption, glowing warnings, falling terrain/attached structures, real storm shelter, earthquakes, alternate bridge collapse and deletion surges.
- Added adventure HUD/status, native interaction controls, adaptive event/music/wildlife audio slots and weather/camera integration. Audio IDs remain unconfigured.
- Retained the earlier obstacle course only as an isolated library. Updated tests and handoff documentation; Studio runtime acceptance remains pending.

## 0.1.0 — 2026-10-09

- Initialized the empty workspace as a modular Rojo/Luau project and Git repository.
- Added deterministic procedural islands, ten biome palettes/decorations, outward terraces, main route runes and access paths.
- Added bounded world generation, logical altitude and physical origin rebasing.
- Added shared rounds, lobby, nonblocking player collisions, late joins, elimination, reentry and spectator replication focus.
- Added rising deletion, catch-up pressure, corruption warnings, fragments, fades and cleanup.
- Added all 20 obstacle mechanics with server-side gameplay logic, optional bonus runes and altitude-based combinations.
- Added server-validated dash, double jump, shield and glide; keyboard, touch and controller bindings.
- Added jump input buffering and server-validated coyote time, separate current/verified HUD altitude, corruption fissures and foundation shaking, and distance-based detail/light limits.
- Added persistent profile leases/retries, XP/levels, coins, records, leaderstats and global leaderboard storage.
- Added earnable trail, effect, procedural emote and outline-skin cosmetics.
- Added responsive UI, lobby camera, biome lighting, dynamic local weather and a finite cloud/island backdrop.
- Added adaptive audio routing without invented asset IDs; real audio assets remain unconfigured.
- Added local pinned CLI tooling, build/check commands, pure Luau tests, Lune server/client fixtures, endurance simulation and Studio smoke checks.
- Exercised the actual server entrypoint and shutdown wiring offline; verified lease expiry and failed departing-save retry paths.
- Fixed correlated per-stage PRNG seeds, obstructing landing geometry, character-load state races, insufficient streaming pressure, nullable spectator focus and elimination-screen close behavior during implementation.

Studio physics, multiplayer replication, rendered UI/visuals, audio permissions, real DataStores and device performance remain unverified.
