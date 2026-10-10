# Development status

Updated 2026-10-10. Version 0.4.0 adds realm objectives, events, creatures and a visual overhaul (below). Version 0.3.0 added reliable pickup paths, portable item uses, stronger powers, realm UI/scenery and visible approaching storms to the exploration/survival prototype. Source files and a Rojo place are implemented. Roblox Studio playtesting has not been performed: Studio is installed, but this session has no Studio automation bridge.

## 0.4.0 Realm adventures and visual overhaul (2026-10-10)

**Gameplay.** A realm objective framework now gives every region 4 seeded activities from its realm's pool of 5, using 11 activity types. It adds:

- 10 creatures with telegraphed attacks
- a lifetime-aware dynamic event director
- storm shelter breaches
- run perks, relics and persisted achievements that unlock cosmetics
- hazards

Powers have new uses: dash and stomp combat, ledges, ring courses, overcharged vault doors, and sealing breaches with Timber Brace. Details are in [GAMEPLAY.md](GAMEPLAY.md).

**Visuals.** Per-realm sky profiles, a cloud sea and a storm shelf front; outskirts lobes with landmarks and viewpoints; a procedural prop library; ten house styles; redesigned collectibles with pickup feedback; power effects; and a HUD overhaul. Details are in [VISUALS.md](VISUALS.md).

**New production files:**

- `src/shared/RealmConfig.luau`, `src/shared/ObjectiveConfig.luau`
- `src/server/Services/Props.luau`, `Architecture.luau`, `Sites.luau`
- `src/server/Systems/ObjectiveService.luau`
- `src/server/Systems/Activities/` with Builder, Common, Creatures, Repair, Rescue, Hunt, Plates, Dials, Beams, Mining, Cache, Rings, Artifacts and Gate
- `src/client/Controllers/PowerEffects.luau`

**Modified production files:**

- Shared: RegionLayout, Rules, ShopConfig, AudioConfig, GameConfig (version 0.4.0)
- Server: ExplorationGenerator, RealmAssets, ExplorationWorld, AdventureService, AbilityService, PlayerManager, WorldEventDirector, RoundManager, CosmeticService, Main.server
- Client: EnvironmentController, InteractionController, PowerController, CameraController, AudioController, Interface, Main.client
- `default.project.json` (ShadowMap lighting)

**Tests:**

- New: `tools/gameplay.spec.luau`, `tools/visuals.spec.luau`
- Updated: `tests/core.spec.luau`, `tests/StudioSmoke.luau`, `tools/storm.spec.luau` (anchor budget), `tools/bootstrap.spec.luau`, `tools/check.ps1`

**Validation.** `tools/check.ps1 -Format` passes in build/realm-overhaul-validation.log. Studio acceptance is pending; see the 0.4.0 checklist in NEXT_STEPS.

## Hurricane and local earthquake fractures — 2026-10-10

Added a pooled, rotating smoke-ribbon hurricane beside each viewed realm during strong storms, with smooth formation/recovery and a low-detail version. Added nearby earthquake ground selection and crooked floor, wall and cave-ceiling seams. Ground warns for 14 seconds before falling; shelter/causeway protection, braces, pickups, health, storm exposure and progression remain integrated. Dust and optional camera shake accompany quake activity. Refuge/building seams follow their source and clean up after 24 seconds; quake work has shared region budgets.

Modified production: new DisasterConfig, HurricaneController and SeismicFractures; EnvironmentController, ExplorationWorld, WorldEventDirector, Main.server, Main.client and Interface. There are now 45 production Luau files. Added tools/disasters.spec.luau; updated check.ps1 and storm.spec.luau. Rebuilt the Rojo place and sourcemap. The complete file list, limits and acceptance steps are in [DISASTERS.md](DISASTERS.md).

Validation: full tools/check.ps1 -Format passes in build/disaster-validation.log, including static/build checks, thirteen core, eight server/library, eleven exploration, nine item/power, six seal-key, eight client, twelve storm and initial nine disaster cases, server bootstrap and synthetic fifty-minute endurance (73 generated regions, peak six resident, seven rebases). The final cave-ceiling orientation correction passes repeated static/build checks, all ten disaster cases, twelve storm cases and server bootstrap in build/disaster-final-validation.log. Initial targeted assertions were corrected to read fixture attachment CFrames and distinguish route rails from ground; the implementation also fixed an unused-variable warning and ceiling seam orientation. No Studio visual/physics/network/device validation is claimed.

Remaining: inspect hurricane ribbon/cloud appearance, directional visibility, recovery and mobile frame time; walk cracked terrain and cave interiors; confirm native shelter, brace and collision behavior under latency and two/twelve clients. Follow DISASTERS.md and NEXT_STEPS.

## Collectible seal keys and longer dash — 2026-10-10

Sun, Leaf and Moon are now collectible tablets instead of static alignment switches. Each player has a realm-specific key pouch; the cave SEAL ALTAR checks ownership before placement. E/X or the gold interaction button places the next key, while 1/2/3 and contextual key buttons select explicitly. Order is Sun > Leaf > Moon. Progress is shared; keys remain reusable after a wrong order. Collection hides the tablet and its label locally. Other players retain their own pickups, and the four-crystal gate alternative remains available. Pouches reset with each round and prune when regions retire.

Gust Dash now lasts 1 second at 62 studs/second, compared with 0.3 seconds previously; crystal overcharge extends it to 1.3 seconds. Camera duration follows the authorized payload. Other power/coyote activations preserve its movement-audit allowance, and local dash application stops on death or transit.

Modified production: new src/shared/SealConfig.luau; GameConfig; server AdventureService, ExplorationGenerator, PlayerManager, AbilityService and Main.server; client InputController, PowerController, Interface and Main.client. There are 42 production Luau files. Modified tests: new tools/seal.spec.luau; exploration.spec, items-powers.spec, client.spec, bootstrap.spec and check.ps1. README, ARCHITECTURE, CHANGELOG, TESTING, DEVELOPMENT and NEXT_STEPS document controls and acceptance.

Validation: full tools/check.ps1 -Format passed in build/seal-dash-validation.log, including formatting, zero-error/warning Selene, shared analysis, all-source compilation, Rojo build/sourcemap, thirteen core, eight server/library, eleven exploration, nine item/power, six seal-key, eight client and twelve storm cases, actual server bootstrap, and synthetic fifty-minute endurance (73 regions generated, peak six active, seven rebases). After the final coyote-allowance/death-cancellation adjustments, tools/check.ps1 -Format -SkipEndurance passed again against the final source in build/seal-dash-final-validation.log. World lifecycle code did not change between these runs. The rebuilt place is build/FloatingRealms.rbxlx.

Remaining: Studio acceptance for native E/X/touch prompts, controller selection, actual local pickup replication/streaming, cooperative use, physical dash distance/collision/slopes, camera motion and latency. Offline fixtures verify object state and logic, not these engine behaviors. See NEXT_STEPS steps 3, 7, 8 and 9.

## Storm redesign revision — 2026-10-10

Removed the seven solid spherical ThunderCloud Parts and flattened backdrop cloud Parts from EnvironmentController. Reused the existing client controllers for native Terrain/Clouds, three high soft cloud layers, directional wind/rain, bounded atmosphere, pooled distant lightning, delayed thunder and four smooth visual phases. The warning remains eight seconds and damaging activity sixteen seconds; Heavy/Extreme split that activity, followed by ten seconds of visual recovery inside the existing calm interval. Server damage, generated shelter volumes, health and progression code are unchanged.

Modified production: EnvironmentController, AudioController, CameraController, Main.client, Interface and AudioConfig; added StormConfig. Modified OfflineHarness, client.spec and check.ps1; added twelve storm QA cases in tools/storm.spec.luau. That storm revision contained 41 production Luau files. Consolidated formatting, zero-error/warning lint, shared analysis, all-source compilation, fresh build/sourcemap, thirteen pure, eight retained server, eleven exploration, nine item/power, seven client, initial eleven storm cases and actual server bootstrap pass in build/storm-validation.log. The final additional HUD case then passed with all twelve storm cases in build/storm-hud-validation.log; storm production code did not change between that consolidated run and the additional HUD case. The unchanged world endurance was not repeated for this client storm revision; its prior 50-minute result is retained below. Current Studio rendering, screenshot review, sound playback and device performance remain unverified. The referenced new screenshot was not available in the attachments or workspace. See [STORM_SYSTEM.md](STORM_SYSTEM.md) for scope, budgets, audio requirements and complete file list.

## Current enhancement milestones

| Milestone | Implemented changes / modified files | Test evidence / remaining work |
| --- | --- | --- |
| Pickup and useful items | ItemConfig, GroundProbe, AdventureService, ExplorationGenerator, ExplorationWorld, Main.server, InteractionController, InputController, client Main and Interface. Native E/X prompts and gold fallback button share validated intent handling; resource claims are once per player with local hiding. Herb heals 40 HP, crystal boosts powers for 12s, two timber brace ground for 18s. Resource shapes follow collapsing terrain. | Nine item/power regressions cover collection, shared stock, forged/distant/dead/displaced requests, support obstructions, deleted ground, costs, healing, bracing and overcharge. Actual prompt/input/replication acceptance pending Studio. |
| Stronger powers | GameConfig, AbilityService, PlayerManager, PowerController, MovementController, Main.server, client Main, Interface and EnvironmentController. Sustained 62-speed dash, 68-upward air leap, 60-damage shield, six-second steerable glide; crystal strength/duration/cooldown bonuses, second jump activation, shield/wing effects and state feedback. | Offline regressions exercise cooldowns, one air leap, absorption overflow, glide/fold/ground rejection, dash/glide combination and authorized local impulses. Native character/network movement pending Studio. |
| Realm UI and scenery | RealmAssets, ExplorationGenerator, Interface, EnvironmentController and client tests. All ten palettes style the HUD/ground/flora; added grass, tree branches/crowns, house framing, windows, chimneys and furnishings. Item buttons show counts, uses and cooldowns; HUD shows HP/shield/active powers. | All-realm geometry/theme cases and desktop/short-landscape constructor/layout checks added. Rendered art, safe insets and mobile/controller usability pending Studio. Layouts still share one exploration template. |
| Approaching storm | Initial 0.3.0 sphere renderer is superseded by the atmospheric storm revision above: native Clouds, high soft layers, four phases, wind/rain, lightning and delayed thunder. Existing server timer/damage remains intact. | Client/storm state, budgets, countdown, shelter and server damage regressions pass. Actual appearance, audio and pacing pending Studio. |

New files: src/shared/ItemConfig.luau; src/server/Services/GroundProbe.luau, RealmAssets.luau; src/client/Controllers/InteractionController.luau, PowerController.luau; tools/items-powers.spec.luau. Expanded tools/exploration.spec.luau, client.spec.luau and check.ps1. README and development, architecture, testing, changelog and next-step documentation updated.

## Underlying exploration milestones (0.2.0)

| Milestone | Actual changes | Verification / remaining acceptance |
| --- | --- | --- |
| Foundation | Existing Rojo hierarchy, modular bootstrap, sanctuary, multiplayer queue, character lifecycle and collision groups retained. Sanctuary moved away from exploration bounds. | Rojo build and actual server-entrypoint fixture execute. Real avatar spawn pending Studio. |
| Exploration world | RegionLayout, ExplorationGenerator, ExplorationWorld; connected mainland, grove and cave, varied size classes, village interiors, denser forest, waterfalls, shrine, climbable lookout and clear walking causeways. WorldManager delegates to ExplorationWorld. | Pure connectivity/slope tests and geometry/walking-progression fixtures pass, including massive-island shore clearance. Actual traversal and visuals pending Studio. |
| Adventure interactions | AdventureService: finite shared caches, capped session inventory, shared bridge repair, cave glyph puzzle, crystal-powered emergency gate, elevator decks, herb healing and once-per-region discoveries. | Interaction, rejection, travel, rebase and cancellation fixtures pass. Cooperative play and mobile prompts pending Studio. |
| Destruction and survival | Section-specific cracks, 14-second warning, loss of collision, falling/fading terrain and attached structures. Visited regions destabilize from outside inward; shelters and causeway last longer. Rising wave retained. | Warning/ground-loss timing fixtures pass. Physical falls and replicated telegraphs pending Studio. |
| Dynamic events | WorldEventDirector: storm warnings and exposure damage, genuine shelter protection, earthquake sections, collapsing alternate bridges and temporary deletion surges. | Hazard/shelter/surge fixtures pass. Runtime pacing and multiplayer balance pending Studio. |
| Ascension and multiplayer | Ground-supported altitude replaces rune sequencing. Adjacent region entry, server-authorized portals/elevators, ahead generation, bounded region count, logical coordinate rebasing, late joins, spectating and rounds retained. | Bootstrap fixture reaches the next region by elevator and records rewards. Synthetic 50 minutes: 73 regions generated, peak 6 resident, 7 rebases. Real streaming/latency pending Studio. |
| Progression and security | Existing server rewards, cosmetics, profiles, leases, retries and leaderboards retained. Prompt distance, trusted position, life state, ground support, inventory caps, shared costs and cooldowns are validated server-side. | Persistence and rejection fixtures pass. Live services and exploit review pending. |
| Presentation | Adventure HUD shows resources, repair/gate status, stability, shelter and events, with a compact landscape layout and modal layering. Help and controls updated. E/controller X reserved for native prompts; double jump moves to Z and dash controller input to R2. Adaptive music/ambience/wildlife architecture and event sound hooks added; storm weather and earthquake camera effects integrated. | Four offline UI/controller/layout tests pass. Actual rendering, device usability and permitted audio playback pending Studio. |

## Files from the exploration correction (0.2.0)

New: src/shared/RegionLayout.luau; src/server/Systems/ExplorationGenerator.luau, ExplorationWorld.luau, AdventureService.luau, WorldEventDirector.luau; tools/exploration.spec.luau.

Updated: GameConfig, AudioConfig, WorldManager, PlayerManager, RoundManager, DeletionController, AbilityService, Main.server; client Main, Interface, InputController, CameraController, EnvironmentController, AudioController; OfflineHarness, check.ps1, core, integration, client, bootstrap, endurance and StudioSmoke tests; README, assets/README and project documentation.

The previous IslandGenerator/Route/ObstacleGenerator remain an isolated library with regression tests. They are not used to generate the live adventure world. There are no mandatory numbered rune checkpoints in the active gameplay loop.

## Verification status

Local tools: Rojo 7.7.1, StyLua 2.5.2, Luau 0.741, Selene 0.32.0, Lune 0.10.5. Current storm verification is recorded above. The earlier complete 0.3.0 lifecycle result is in build/validation.log: synthetic fifty minutes, 73 regions generated, peak six resident (cap nine), seven rebases. The subsequent streaming-pickup follow-up is in build/pickup-validation.log. The final place is build/FloatingRealms.rbxlx; 45 production Luau files are present; the latest disaster evidence is recorded above. No Studio results are inferred from these tests.

Found and corrected: E/gamepad X ability conflicts with prompts; old rune-only progression; initial cliff-intersecting ascent; massive-island shore clearance; stale offline character pivots; missing Lune property defaults; early repair of corrupted bridge sections; elevator anchoring cleanup; cross-round storm damage timer.

Version 0.3.0 fixes also include once-per-node pickup claims, footprint support next to small obstructions, portable-item cost/cooldown handling, first-frame lightning timing, dash/glide interference and preserving collected IDs through streaming until the next round. Streaming pickup state has a focused follow-up regression; this is not evidence of real network streaming.

## Remaining limits

No Studio physics, rendered visual inspection, multiplayer session, live DataStore access, FPS/memory measurement or public publishing is claimed. Ten realm palettes/materials/scenery/UI themes vary the shared exploration template; bespoke biome layouts remain unfinished. Sound IDs remain empty until permitted assets are configured. Wildlife is an audio layer, not animal NPCs. Geometry uses native parts and needs art review, terrain refinement and pacing validation. Public deployment has not occurred.
