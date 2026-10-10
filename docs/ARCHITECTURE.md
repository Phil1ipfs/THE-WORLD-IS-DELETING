# Architecture

Rojo maps shared modules to ReplicatedStorage/Shared, server systems to ServerScriptService/Server and clients to StarterPlayerScripts/Client. Main.server owns one gameplay Heartbeat at 10 Hz and player snapshots at 4 Hz. The sanctuary is persistent and separate from procedural world bounds.

## Connected regions

RegionLayout is pure deterministic layout data. Region centers rotate within a bounded horizontal area, rising 128 logical studs per region. ExplorationGenerator builds a large contiguous mainland, smaller grove and cave, an abandoned village, scavenging nodes, shelters and three ascent choices. Rare massive mainlands use a larger grid. Local bridges form a loop after cooperative repair. A 16-stud continuous causeway has flat approaches outside both shores and a sloping span; jumping is optional. Village and forest placement reserves clear approach corridors.

WorldManager delegates to ExplorationWorld. The world generates two regions beyond verified progress, with at most three new regions per generation call and nine resident region models. Each region owns cells, attached structures, shelters, prompts, route references and signal connections. Disposal disconnects prompts, cancels affected travel and destroys geometry. Generated but unvisited regions do not start a local expiry timer.

Physical Y equals logical Y minus WorldOrigin. Rebasing shifts region models, falling reference frames, character positions and camera references together. Elevator endpoints derive from current region centers each update. The wave and saved peak remain logical. The sanctuary stays at fixed physical coordinates.

## Exploration and authority

PlayerManager credits altitude only on a server raycast onto collidable Ground geometry in an adjacent region. It no longer requires a sequential Step attribute. It validates finite coordinates, displacement and supported region progression. Portals and elevators call a server-only adjacent-region transfer; client requests cannot choose a destination. Existing ability cooldowns, collision groups, queue/spectator state and idempotent elimination are retained.

AdventureService binds native ProximityPrompt.Triggered events and accepts an Interact intent containing a bounded registered node ID. InteractionController finds the nearest streamed enabled prompt for a gold touch/click button and E/X fallback. Both paths use the same server validation: life/profile state, cooldown, world membership, trusted position, range, ground support, stock and inventory bounds. GroundProbe samples the center and four foot positions, respecting collidable geometry; small rails or ledges cannot invalidate all support merely by obscuring the center ray. Supplies are collected once per player per node per round, with twelve total shares and capped packs. The server authorizes local hiding; another player's share stays visible. Disposed regions remove their registered IDs.

ItemConfig defines costs, caps, controls and cooldowns. UseItem accepts only an item kind: herbs restore 40 HP (no consumption at full health), crystals overcharge powers for twelve seconds and reduce existing power cooldowns by three seconds, and two timber brace up to six nearby ground cells for eighteen seconds. Braces postpone local expiry and existing crack deadlines; they never stop the lethal deletion wave. Shared repair uses six timber; gate charging uses four crystals. SealConfig defines Sun/Leaf/Moon keys and their order. Labeled tablets are collected once per player into record.Glyphs[regionIndex], separate from portable supplies. The new Seal altar places the next owned key through E/X, or accepts an intent-only UseGlyph name from keyboard 1/2/3 and touch/controller-selectable buttons. Placement runs the same distance, trusted-position, life/profile, debounce and ground checks as other interactions. Keys remain reusable; wrong order resets shared alignment without destroying them. All players can collect their own set and contribute to one shared seal. Keys cannot unlock another region; retired-region pouches are pruned and PlayerManager.begin resets them. Snapshots carry ownership, progress and altar proximity. Near a sealed altar, the existing item row shows key-use controls without increasing HUD height. The village healing station and once-per-region discoveries remain available.

Collected notifications include both the replicated instance and its stable registered ID. InteractionController remembers claimed IDs across stream-out/stream-in and resets them when the snapshot RoundNumber changes. The ID can still be recorded when its instance is unavailable. Server Claims remain authoritative; local hiding never grants inventory.

Elevator rides create a real anchored deck and move a server-controlled rider over fourteen seconds. This is cinematic guided travel, not a physics-driven passenger platform. Transit disables ordinary movement credit and abilities. Arrival, death, disconnect, reset and region disposal release riders and remove decks. Cancellation cannot award ascent. Basic movement auditing is retained, but client-owned Roblox character physics still requires latency/exploit evaluation.

## Corruption and events

Visited regions start a shared local lifetime. Cells warn from their perimeter inward; protected refuge/causeway cells warn later. The rising wave can also trigger a cell. Cracking remains collidable for fourteen seconds, then collision/query are disabled and the section falls/fades over three seconds. Associated rocks, walls, roofs and bridge rails fall with their owning floor. Entire old regions are eventually removed to bound memory. Client atmosphere does not hide intact ground or override server cell destruction.

WorldEventDirector cycles warning/active/calm phases for storms, earthquakes, structure collapse and deletion surges. Storm exposure deals server damage every two seconds; valid roof/cave shelter volumes protect players. Earthquakes group occupied positions by region and select nearby intact nonprotected cells, with shared budgets of 36 cells and 18 refuge/building surfaces. SeismicFractures draws crooked dark seams on ground, house walls/floors and inward-facing cave ceilings. Ground follows the existing 14-second warning/three-second fall; timber braces extend deadlines. Refuge surface cracks expire after 24 seconds without removing shelter. Primary causeways remain protected. Crack offsets follow falling/rebased surfaces; noncolliding/nonqueryable seams cannot grant pickup or altitude support. Structure collapse targets alternate bridges, preserving the early primary causeway. Surges temporarily multiply wave movement. Event timers reset between rounds.

## Retained services and presentation

DataManager retains UpdateAsync session leases, renewal, bounded retries, departure saves, shutdown handling, sanitized profiles and ordered leaderboards. RewardManager and CosmeticService retain server prices and once-only run rewards. Request remotes retain a token bucket and intent-only payloads. Live service behavior is unverified.

AbilityService owns activation, cooldowns and effect budgets. Gust Dash sustains 62 studs/second for one second (about 62 studs on clear level ground); Sky Leap applies 68 upward velocity once per airtime; Aegis absorbs 60 damage over eight seconds; Wind Sail lasts six seconds with a nine-stud/second fall cap and 25-stud/second steering. Crystal activation boosts strength 25%, duration 30% and shortens the new cooldown 25%. PowerController applies only server-authorized local impulses and snapshot-controlled glide steering, because the client normally simulates its avatar. Grounded progression and movement auditing stay on the server; these are prototype safeguards, not proof of complete exploit resistance. Dash retains its speed during a glide. Camera FOV duration follows the authorized duration; activating another power cannot shorten the movement-audit allowance for a running dash.

The HUD includes realm/region, supported altitude, deletion distance, health/shield, inventory controls, cooldowns, active powers, gate/repair status, local stability and shelter. All ten realm palettes style HUD borders, gradients and accents. Camera effects include sanctuary orbit, spectator following, dash FOV and optional danger/quake/gust motion. EnvironmentController now renders native Terrain/Clouds plus three high soft cloud-particle layers; the earlier solid spherical cloud bank is removed. StormConfig maps the existing warning/active timer to Approaching, Heavy and Extreme, then ten seconds of client recovery. Directional rain, wind, atmosphere and pooled distant lightning blend with intensity. Essential sky/reduced rain/countdown survive low detail; shelter suppresses rain, spray and gusts. Camera settings disable bright flash illumination and storm camera motion. AudioController schedules thunder after lightning and fades configured wind/rain beds. See [STORM_SYSTEM.md](STORM_SYSTEM.md) for budgets, invariants and asset slots.

EnvironmentController also owns HurricaneController: one world-anchored invisible Part with pooled rotating smoke ribbons/wisps, forming beside the current region and fading with storm intensity. RegionIndex and countdown snapshots keep it tied to world coordinates rather than camera motion; rebasing preserves strength. Low detail halves ribbon count and reduces wisps. A separate cached emitter provides grounded quake dust. See DISASTERS.md for limits and validation.

RealmAssets builds seeded noncolliding grass or biome flora, tree branches/crowns, house framing/windows/chimneys/furnishings and biome props. Decoration follows its supporting terrain during collapse and is culled locally by distance/detail settings; gameplay ground remains visible. Resources also follow their supporting ground. AudioController manages music/danger/biome/wildlife layers and eight reusable spatial one-shot sources. All audio IDs default to empty.

The old IslandGenerator, Route and twenty obstacle builders are retained as an isolated library with regression coverage; the live adventure does not instantiate their course. Ten biome palettes, ground materials, flora variations and HUD themes now accompany the atmosphere definitions. Regions still share the village/grove/cave template; distinct authored biome layouts and finished meshes remain future work.

## Realm objectives (0.4.0)

The ExplorationGenerator builds content in this order:

1. Cells, including the new outskirts lobe from `RegionLayout.outskirts`.
2. Routes, with reserved corridors.
3. Fixed prompts.
4. The landmark and water feature (`RealmAssets.prepare`).
5. Seeded activities (`Activities/Builder`).
6. Timber caches.
7. Paths, woodland and ground cover (`RealmAssets.build`).

`Sites` maps terrain cells on a 12-stud lattice and keeps every placement on supported land, clear of reserved circles and segments. Activity prompts are ordinary region interactions with `Activity`, `Event` or `Breach` markers. `AdventureService:interact` validates them first and then delegates to `ObjectiveService`. Prompts created at runtime (events, breaches) are registered with `AdventureService:register`.

`ObjectiveService.tick` runs from the round loop at 10 Hz. It:

- updates activities (creatures, escorts, plates, rings, gates, artifacts, storm caches)
- applies hazards
- reveals hidden activities
- schedules one dynamic event per visited region
- starts and ends shelter breaches with the storm

`WorldEventDirector` calls `shelterDamage` for sheltered players. Rewards go through `RewardManager.bonus` and profile XP; achievements, `Relics` and `Rescues` are sanitized by `Rules.profile`. Run perks live on the player record and are read by `AbilityService` and `AdventureService`. Snapshots add an `Objectives` view for the tracker.

Creatures, survivors and supply crates are anchored server models moved with `PivotTo` at the 10 Hz tick. Ground support is checked against intact cells, so they fall with deletion. Structures are indexed by ground in `World:consume`. See [GAMEPLAY.md](GAMEPLAY.md) and [VISUALS.md](VISUALS.md).

## Verification boundary

Pure Luau checks test layout/rules. Lune runs actual built ModuleScripts and the server entrypoint using explicit service/instance shims and analytic oriented-box rays. These tests do not reproduce Roblox physics, replication, streaming, rendering, touch input or live DataStores. Studio acceptance remains separate.
