# Testing evidence

Updated 2026-10-10 (0.4.0). Offline automated checks run locally on Windows. No Roblox Studio playtest, rendering review, multiplayer session, live DataStore check or FPS benchmark has been performed.

Run: powershell -ExecutionPolicy Bypass -File tools/check.ps1 -Format

## Latest 0.4.0 realm adventure and visual revision

`tools/check.ps1 -Format` passes; the log is in build/realm-overhaul-validation.log and the command exited with code zero. It covers:

- StyLua formatting, Selene (0 errors, 0 warnings), shared analysis, compilation of all sources, Rojo build and sourcemap
- 14 core cases, including the new outskirts connectivity, clearance and world-bounds case across 5 seeds × 12 regions
- 8 integration, 11 exploration, 9 item/power, 6 seal, 8 client, 12 storm and 10 disaster cases
- **18 new gameplay cases** and **13 new presentation cases**
- the actual Main.server bootstrap, which now asserts that the snapshot carries realm objectives
- the synthetic 50-minute endurance run: 73 regions generated, peak 6 resident, 7 rebases

The gameplay cases (`tools/gameplay.spec.luau`) run one player through the real validated `AdventureService` path:

- distinct realm pools and per-round variation
- windmill repair and mill stores
- pump cooling lava and generators fortifying shelters
- rescue escort to the beacon, plus the lost-to-deletion failure
- thaw and vine variants
- creature telegraph, damage, dash defeat and spoils chest
- plate latch and expiry, and the vault
- dials, mirrors and mining
- hidden ledge cache and storm-only hoard
- updraft authorization, ring order and timeout
- artifact drop and return
- timed vault: inside-only loot, door closing, overcharge extension
- event lifetime gating, supply drop, rare relic and guardian
- storm breaches, leaks, patching, Timber Brace sealing and fortified healing
- perks (dash cooldown, double leap, shield, glide, pack, Heartstone, no duplicates)
- shrine blessing and relic payout
- achievement persistence and cosmetic unlocks
- the objective snapshot

The presentation cases (`tools/visuals.spec.luau`) check object state only:

- no NaN parts, ≤ 3,600 parts and ≤ 20 lights per region
- decoration is non-collidable and attached to collapsing ground
- multi-part trees, recognizable collectibles, distinct house materials and landmarks, furnished shelters with breach anchors, walkable viewpoints, hazards
- sky profile ranges and blending; realm lighting and cloud application
- cloud sea, storm front advance, lightning forks and the low-detail path
- lift wheel spin
- power effect attach, shatter and cleanup; pickup ghost
- HUD bars, banner, cooldown sweeps, tracker rows and collapse, capped feed and popups

Fixture and test adjustments, with reasons:

- The weather anchor budget is now 21 (two new fixed sky anchors).
- `visuals.spec` registers a `Players:GetPlayerByUserId` fixture, as the bootstrap suite already does.
- Intermediate failures found real bugs, which were fixed in source:
  - degenerate vertical `CFrame.lookAt` produced NaN tree trunks in the harness
  - the beam puzzle's own reservation blocked its stations
  - event site search was too brittle on decorated land
  - survivors needed two presses to start an escort
  - opening a hidden cache did not mark it discovered
- Three test expectations were corrected: the mining reward total, and where to stand for breach and vault checks.

Nothing in this revision was run in Roblox Studio. Rendering, sound files, physics, feel, streaming, multiplayer and device performance are not verified. See NEXT_STEPS (0.4.0 checklist).

## Latest hurricane and earthquake revision

Full tools/check.ps1 -Format passes in build/disaster-validation.log, with static/build checks, all existing suites, initial nine disaster cases, the actual server bootstrap and synthetic fifty-minute endurance (73 regions, peak six resident, seven rebases). After correcting cave-ceiling seams to face interior occupants, final static/build checks, ten disaster cases, twelve storm cases and server bootstrap pass again in build/disaster-final-validation.log. Both commands returned zero. Endurance was not repeated for that surface-face-only correction; its world lifecycle source is unchanged.

New tools/disasters.spec.luau exercises tapered/rotating textured funnel state, world anchoring, reset/recovery/rebase, fixed low-detail budgets/shelter, grounded dust, nearby floor/house/ceiling cracks, delayed ground failure, source-following cleanup, braces, nonqueryable seams, protected shelter/causeway, capped work across nine regions/twelve records, HUD warnings and void priority. The storm fixed-part budget now includes the hurricane/dust anchors (19 BaseParts total, including distant island scenery). Source counts and rate/lifetime estimates are not GPU measurements. See DISASTERS.md for exact controls, budgets, files and pending native Studio acceptance.

## Latest seal-key and dash revision

Full tools/check.ps1 -Format passed in build/seal-dash-validation.log: static/build checks, 67 named regression cases, the actual server bootstrap and a synthetic fifty-minute world lifecycle (73 generated regions, peak six resident, seven rebases). Final coyote-jump movement-allowance and client death-cancellation adjustments then passed a complete -Format -SkipEndurance rerun in build/seal-dash-final-validation.log. The world lifecycle source did not change between those runs. Both commands returned exit code zero; build/FloatingRealms.rbxlx and sourcemap.json contain the final source.

Six new tools/seal.spec.luau cases exercise native/fallback key collection, duplicate rejection, missing-key rejection, ordered altar use, wrong-order recovery, independent player pickups/shared progress, forged/distant/displaced/dead/unready/unsupported/transit requests, realm isolation, pouch pruning/reset and local tablet/label hiding. The exploration puzzle case now collects before placing; the actual Main.server fixture exercises Interact and UseGlyph remotes and ownership/progress snapshots before elevator progression. Eight client cases include contextual key buttons and unchanged mobile control height. The nine item/power cases now test dash persistence at 0.75s, expiry after 1s, five-second cooldown, coyote allowance and air-leap interactions. Client movement tests also cover expiry and immediate death/transit cancellation.

These checks load the built place. An initial focused run used the previous build and was rerun successfully after rebuilding; a new HUD test's literal-string pattern was corrected. No Studio input, rendered tablet/HUD appearance, real replication, physical dash distance or networking has been verified.

## Latest storm revision

Ran tools/check.ps1 -Format -SkipEndurance after replacing the sphere renderer. Formatting, Selene (zero errors/warnings), shared analysis, compilation, Rojo build/sourcemap, thirteen pure cases, eight server/library cases, eleven exploration cases, nine item/power cases, seven client cases, initial eleven storm cases and actual server bootstrap all pass in build/storm-validation.log. A final additional HUD case then passed with all twelve storm cases in build/storm-hud-validation.log. No production code changed after the consolidated run. World lifecycle code is unchanged; its prior endurance result below was not rerun for this client-only weather revision.

Storm cases inspect native Clouds parenting, absence of solid spheres, high layer clearance, timer/target continuity, smooth recovery state, haze/density limits, low-detail emission budgets, shelter suppression, pooled distant lightning and thunder delay, rebase/reset, mute/unconfigured audio, gust camera limits and HUD health/void priority. Server warning/active/calm timing and eight-damage exposure remain unchanged in a focused fixture; the existing exploration suite exercises generated house/cave shelter volumes. Native Clouds/particle silhouettes, actual rain visibility, actual audio, frame time and GPU/mobile performance remain unverified.

The offline harness now explicitly supplies the Terrain singleton that Roblox creates automatically and a no-op ParticleEmitter.Clear method. Initial follow-up fixture failures exposed duplicate singleton registration and missing input defaults; the fixture setup was corrected and all twelve cases rerun. These substitutes do not constitute engine rendering or sound playback.

## Checks run

- StyLua formats production, test and harness scripts.
- Selene checks Roblox source; current run has zero errors, warnings or parse errors.
- Luau analyzes strict shared modules and compiles all Luau sources.
- Rojo produces build/FloatingRealms.rbxlx and build/sourcemap.json.
- Thirteen pure core tests pass, including connected mainland grids across seeds/size classes and walkable region ascent slopes. Legacy obstacle ballistic tests are labeled separately.
- Eight retained integration regressions pass: server module loading, isolated legacy geometry/obstacle builders, contact behavior, rounds/late joins and injected persistence failure/lease cases.
- Eleven exploration cases cover production terrain, every realm's palette/scenery/support attachments, capped inventory, rejection of distant/displaced/repeated/dead prompts, shared repair costs, glyph order/reset, crystals, healing, discovery limits, adjacent portal travel, elevator deck movement/rebase/cancellation, staged deletion, hazards/shelter, five region cases of supported/head-clear walking causeways and ground-based player progression.
- Nine item/power cases cover native/fallback collection, separate player shares, forged IDs, footprint support/deleted-ground rejection, portable healing/cooldowns/costs, timber bracing and wave lethality, crystal boost/stack rejection, sustained dash, higher once-per-airtime leap, shield absorption/overflow, glide/fold and local pickup hiding. The glide case also checks dash/glide combination. The pickup case replaces an instance to model stream-out/stream-in and checks that claimed IDs hide the replacement and clear next round; this does not emulate Roblox streaming.
- Eight client constructor/state/controller/layout cases cover adventure HUD construction, intact ground visibility, weather/shelter/rebase, landscape clearance/modal layering, storm-front approach/lightning/countdown with detail disabled, all ten HUD themes, portable item button intents and authorized local movement/transit cancellation. These assert object state and positions; they do not prove rendered appearance or input usability.
- The actual Main.server bootstrap fixture passes queue, spawn, key pickup/use remotes, seal ownership/progress snapshots, native prompt binding, elevator ascent, return, rewards and shutdown.
- Synthetic 50-minute exploration passes at three logical studs/second: 73 regions generated, peak six active (cap nine), seven rebases, uninterrupted generation ahead of the leader. This is not a physics/FPS benchmark.

The version 0.3.0 complete consolidated rerun passed and is recorded in build/validation.log: all static/build checks, 48 regression cases, server bootstrap and synthetic fifty-minute lifecycle. A final collected-ID streaming fix then passed repeated formatting, lint, shared analysis, all-source compilation, fresh build/sourcemap, all nine item/power cases, seven client cases and server bootstrap in build/pickup-validation.log. World generation/collapse/lifecycle code did not change after the consolidated run. The initial run found a first-frame lightning timer boundary, corrected by allowing the cue at time zero; its failure record is retained in build/validation-initial.log. Build artifacts are ignored by Git and reproducible from source.

## Harness limits and fixes

OfflineHarness loads the built place and actual production ModuleScripts. It explicitly substitutes task scheduling, service events, character creation, model pivots and in-memory DataStores. Raycasts use analytic segment/oriented-box intersections, including sloping floors. They are geometric evidence and cannot prove Humanoid contact behavior or network ownership.

Intermediate checks caught old rune-test assumptions, cliff-intersecting ramps, massive shore clearance and fixture gaps in PrimaryPart pivot updates and LocalTransparencyModifier defaults. Version 0.3.0 also corrected repeat-node inventory assumptions, the first-frame lightning timer boundary, and dash speed being clamped by an active glide. Expected persistence warning logs deliberately exercise denial/retry paths. Failures are fixed and their checks rerun before recording final passing results.

## Studio acceptance

Every Studio/device/multiplayer acceptance item remains pending. Follow docs/NEXT_STEPS.md for the concrete exploration traversal, escape, corruption, event, audio, latency and performance checklist. Do not label offline fixtures as a Studio playtest.
