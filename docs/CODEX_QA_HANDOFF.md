# Codex QA handoff: 0.7.2 Studio playtest fixes, Dragon Preview, shop

**Source:** the user's Studio logs (`%LOCALAPPDATA%\Roblox\logs`, sessions on 2026-10-10 and 2026-10-11).

## Errors found in the logs

- **`GetPivot is not a valid member of Folder "Workspace.FloatingRealms.BalloonFlights"`** (`EnvironmentController:762`), every frame. It aborted the client Heartbeat loop (environment, audio and storm UI updates).
  - **Fixed:** only Models count as regions.
- **`EnvironmentController:557: attempt to index nil with 'Parent'`**: spinner group without a hub under streaming.
  - **Fixed:** skips the group.
  - **Regression test:** `dragon-client.spec` "Environment update tolerates…".
- **Leftovers from the old stale Rojo tree** (not in this repo): `AchievementService`, `Shared.Modules`, `Shared.Config`. Reconnect to the fresh Rojo server on 34873 to clear them.

## "The dragon is not attacking / I can't see the weapon"

This was by design rather than a bug. Per the spec, battles start in region 5 and the forge started in realm 2, and the playtest stayed on the early islands.

**Changes:**

- **Dragon Preview** (`DragonArmory.preview()`): Studio only, enabled by the Workspace attribute `DragonPreview`.
  - Region 0 becomes a tier-1 encounter (20 s after spawn). Regions 1–2 are raids.
  - The server prints a `[Dragon Preview]` line in Output.
- **Weapons everywhere:** forge and harpoon rack now spawn in every region, including realm 1.
- **Test:** `dragon.spec` "Studio Dragon Preview…" asserts that the battle starts on island 0, the dragon hurts a standing player, and it cracks the realm's ground.

## Shop (`src/client/UI/ShopView.luau`)

- Card UI with tabs, rarity, description and states; unequip; live refresh.
- 15 catalog items, all persisted by `Rules.profile`.
- Server: `CosmeticService` handles `"none"` (unequip), emotes no longer change `Equipped`, and purchases send `Shop` effect events.

**Tests:**

- `dragon-client.spec` "Shop…": card states, purchase requests, no request when unaffordable, tabs, live refresh.
- `dragon.spec` Mantle test: coin purchase, emote keeps cosmetic, unaffordable refusal, unequip.

## Studio checks

1. Play: Output shows `[Dragon Preview]`; the dragon arrives about 20 s in and attacks; forge and rack are near the landing.
2. Craft a crossbow and harpoons; the gear shows on the avatar; FIRE and THROW work.
3. No `GetPivot` / `BalloonFlights` errors in Output.
4. Shop layout at phone size; tabs; buy, equip and unequip; Gale Wings and Dragonwing visuals.

---

# Codex QA handoff: 0.7.1 sound design and Dragonbane Harpoon

## A. Audio (`src/shared/SoundBank.luau`, `src/client/Controllers/AudioController.luau`)

**Finding:** the installed Roblox client ships only 11 files in `content/sounds`. Checked on the developer machine on 2026-10-11, across three client versions:

`action_falling.ogg`, `action_footsteps_plastic.mp3`, `action_get_up.mp3`, `action_jump.mp3`, `action_jump_land.mp3`, `action_swim.mp3`, `impact_explosion_03.mp3`, `impact_water.mp3`, `oof.ogg`, `ouch.ogg`, `volume_slider.ogg`

The 0.6/0.7.0 built-in cues pointed at `swoosh.wav`, `snap.wav`, `electronicpingshort.wav` and `clickfast.wav`, which are **not** shipped, so those cues were silent.

**What 0.7.1 does:**

- `SoundBank` designs **41 cues, 4 looping beds and 2 world loops** using only those 11 files. Each recipe sets playback speed, a start/length window, SoundEffects (distortion, reverb, EQ, tremolo, chorus) and delayed layers.
  - Example: the roar layers `ouch.ogg` at 0.33× with distortion and reverb, a low wind rumble, and a sub-boom.
- **No asset IDs were invented.** Any `rbxassetid://` placed in `AudioConfig` overrides the designed cue of the same name. `UseBuiltinCues = false` silences all designed cues.
- **Music and Wildlife** have no designed substitute and stay silent.
- **3D world loops:** the balloon burner (`BalloonModel`) and forge fire (`DragonArmory.loop`) are created on the server, tagged `RealmSound`, and routed into the client's SFX group, so the SFX setting mutes them.
- **Dragon:** looping breath on the head and wing-flap whomps on each downstroke are played by `DragonController`. Roar, gust, impacts, hurt and meteors come through `Main.client`.

**Audio tests:** `dragon-client.spec` asserts:

- Every recipe path is one of the 11 bundled files.
- Every `AudioConfig` slot except Music and Wildlife has a designed sound.
- Cues play all their layers with effects.
- The SFX setting silences cues.
- Positioned cues are range-culled, except long-range ones (thunder, roar).

**Not verified: how any of this sounds.** The offline harness's `Sound:Play` is a no-op.

**Studio checks for audio:**

1. Each file loads (watch Output for content load errors).
2. Every cue and its loudness balance.
3. Roar audible far away; breath loop starts and stops with fire.
4. Wing flaps not too frequent.
5. Burner and forge loops roll off with distance.
6. SFX toggle mutes world loops.
7. Storm beds fade with intensity and shelter.

## B. Dragonbane Harpoon (new weapon)

**Source:** a Harpoon Rack sits next to each Dragonbane Forge (Crystal Kingdom onward). It is placed by site search, with a ring-around-the-forge fallback.

**Stock:**

- First take: 3 timber + 1 crystal gives 3 harpoons.
- Restock: 1 timber gives 2 more, up to 6.

**Use:** T, controller L2, or the THROW button (shown when carrying harpoons). The client sends only the camera look vector (`Request "Throw"`).

**Server rules:**

- Valid only in a battle in the player's own region.
- Range 150 studs, aim assist 18°, line of sight, 2.4 s cooldown.

**Damage:**

| Hit | Damage | Extra |
| --- | --- | --- |
| Exposed weak point | 11 | During a Recover window, **pins** it: +1.6 s, once per window |
| Through scales | 2 | Bolts do 0 here |

**Visible gear:** crafting attaches parts to the character. A crossbow goes in the right hand, and one harpoon per harpoon carried goes on the back. The parts are welded, massless and non-colliding; they are rebuilt on change and removed on death or respawn.

**Changed files:**

| Area | Files |
| --- | --- |
| Config | `DragonConfig.Weapons.Harpoon` |
| Server | `DragonArmory` (rack, sound loop), `RealmDestroyer` (`throw`, `gear`, HarpoonRack interaction, status `Harpoons`), `Main.server` (`Throw` request) |
| Client | `InputController` (T / L2), `Main.client` (OnThrow, audio routing), `DragonHud` (THROW button), `DragonController` (harpoon flight visual, breath loop, wing flaps), `Interface` (help text) |

**Tests:** `dragon.spec` "Dragonbane Harpoon…" covers:

- Rack in battle and raid regions.
- Forge and burner loops exist.
- Craft, restock and visible gear.
- Refusal outside battle; NaN and string payloads.
- Full damage plus pin on an exposed heart; cooldown.
- Glance damage; out-of-range refusal without spending.

**Studio checks for the harpoon:**

1. Throw feel and aim on PC, controller and touch.
2. Gear placement on R15 and R6 avatars (offsets are estimates).
3. Pin timing.
4. THROW / FIRE buttons don't overlap the ability buttons on phones.
5. Balance alongside the crossbow (the solo bot doesn't use harpoons yet).

---

# Codex QA handoff: 0.7.0 Realm Destroyer and Sky Balloon

## 0. What was and was not verified

Developer checks run on 2026-10-10:

- StyLua format check: clean
- Selene lint on `src`: 0 errors, 0 warnings
- `luau-analyze src/shared`: clean
- `luau-compile` on every Luau file: clean
- `tests/core.spec.luau`: 15 passed
- Rojo build and sourcemap
- Every Lune spec, run one by one (`check.ps1` stops at the first failure, so it cannot show this)

| Spec | Result |
| --- | --- |
| integration, exploration, items-powers, seal, client, storm, disasters, expansion, bootstrap, endurance | Pass |
| **dragon** (new, 11 tests) | Pass |
| **dragon-client** (new, 6 tests) | Pass |
| gameplay | Fails: creature lair. Pre-existing (failed in the baseline before any 0.7.0 change) |
| visuals | Fails: Crystal viewpoint height. Pre-existing. Also fails the objective-tracker test (line 404), which the baseline never reached because it stopped earlier. 0.7.0 changed no tracker code; the test likely predates 0.6.0's collapsed-by-default tracker. Please confirm |
| menu-ocean | Fails: ocean fill (line 156). Pre-existing |

**Nothing was tested in Roblox Studio.** There was no playtest, rendering, physics, mobile, or multiplayer network run.

The offline harness raycast ignores `RaycastParams.Exclude`, so cover and line-of-sight always read as clear offline. Real-Roblox cover behaviour is untested.

Rojo: a stale `rojo serve --port 34873` (serving a pre-0.6 tree) was replaced with a fresh server from this folder. The separate ParkourRealms server on 34872 was left alone.

## 1. Realm progression (existing realm order, nothing renamed)

Stages come from `DragonConfig.stage(index, RegionRise)`, using the same 320-stud bands as `BiomeConfig.at`.

| Regions | Realm | Dragon stage |
| --- | --- | --- |
| 0–2 | Sky Grasslands | **Omen**: silhouette orbits about 640 studs out, roars every 32–52 s. No combat |
| 3–4 | Crystal Kingdom | **Raid** (up to 3 per region): marks ground at least 75 studs from every player for 2.6 s, then burns it. Cells crack and fall after 14 s; flames linger |
| 5 | Floating Jungle | **Encounter, tier 1**: first fight-or-escape battle, 20 s after the region activates |
| 6–7 | Floating Jungle | Raids |
| 8, 10, 13, 15, 18, 20, 23… | first region of each later realm | **Encounter, tier 2–4** |

## 2. Encounter design (`src/server/Systems/RealmDestroyer.luau`)

**Loop:** approach, roar, then orbit and attack in turn.

**Attacks.** Every attack telegraphs with neon ground markers for at least 1.1 s; markers brighten 0.4 s before the hit.

| Attack | Behaviour | Exposes |
| --- | --- | --- |
| Fire Breath | Hovers 68 studs out; 62-stud, ±22° cone locked to the marker; 7 dmg per 0.5 s plus burning (4/s for 3 s); leaves fire patches | Heart |
| Dive | Climbs, locks a mark on the target; 28 dmg within 14 studs; 12 dmg shockwave to 26 studs, grounded players only (jump to dodge); then stunned 3.6 s | Head (Gust Dash also works) |
| Wing Gust | 26×78 lane; knockback via the client `Knockback` event; 6 dmg; walls and shelters block it | Wings |
| Ground Slam | Lands on supported ground near the fighters; 30 dmg crush within 11 studs; ring expands to 40 studs, 16 dmg, grounded only; then landed 4 s | Wings |
| Ember Rain (tier 2+) | Marked fireballs | Heart |
| Inferno Sweep (tier 3+) | 100° sweeping breath | Heart |

**Destruction:** attacks crack 1–4 cells per tier. Never touched: refuges, the landing, the causeway, Dragonbane equipment ground, or the balloon station.

**Weapons** (all server-authoritative):

- **Crossbow:** forged at the Dragonbane Forge (2 timber + 1 crystal, 20 bolts; fletch 1 timber = 12, max 40).
  - Client sends only the camera look vector (`Request "Fire"`).
  - Server validates it, aim-assists within 14°, checks line of sight, and enforces a 0.9 s cooldown.
  - 4 dmg on an exposed weak point; scales deflect other hits.
- **Ballista:** starts broken; 4 timber to repair (2 per contribution). Auto-aims, 14 dmg / 3 glance, 6 s reload. Dive, slam or ember impacts within 18 studs smash it (2 timber to mend).
- **Crystal Cannon:** 1 crystal per shot, 22 dmg / 8 glance, 7 s reload. Firing during a wind-up interrupts it and exposes the heart for 2.5 s.

**HP:** tier base 150 / 210 / 280 / 360, × (1 + 0.55 × (fighters − 1)), capped at 6 fighters.

**Endings:**

| Ending | Trigger | Result |
| --- | --- | --- |
| Repelled | HP reaches 0 | Rewards (below) |
| Razed | Timer runs out (150 / 145 / 140 / 135 s) | Every cell except the causeway warns and falls |
| Escaped | No fighters present for 6 s | Arena razed. Players who left get a "no boss rewards" notice |

**Rewards** (fighters who dealt damage, are alive, and did not escape):

- 75–150 coins, 150–300 XP, 2 relics
- Dragonbane achievement; bestiary stage 4
- Full trophies once per 15 real minutes per player (persistent `DragonAt`):
  - 9/12/15/18 Dragon Scales
  - Emberheart Shard (40% at tier 1, guaranteed above)
  - Dragonwing Mantle roll: 20%, guaranteed by the 5th roll
- Inside the cooldown: coins and XP are halved and no trophies drop.

## 3. Sky Balloon (`Systems/SkyBalloon.luau`, `Services/BalloonModel.luau`)

**Station:** replaces the elevator at local (−36, 18) in every region. Prompt kind `Balloon`. Navy on even regions, red on odd.

**States:** Docked → Boarding → Flight → Returning → Docked.

1. **Docked → Boarding:** the first boarding starts a 5 s countdown.
2. **Boarding:** more riders can join (8 max). The countdown never extends. Riders are anchored, seated and in `Transit`.
3. **Flight:** the balloon model moves into `FloatingRealms/BalloonFlights`, so it survives the source region's deletion. 14 s flight (8 s express), arc +46 studs.
4. **Arrival:** riders are released through `PlayerManager:transfer(index + 1)`, the only place Region and Peak change.
5. **Returning:** a new balloon docks 8 s later.

**Refusals:** boarding is refused during a flight or turnaround, for players whose `Region` is not this station's, when the balloon is full, or when the next region is missing.

**Release (no progression):** riders who die, leave or go to the sanctuary are released; an empty countdown is cancelled. If the destination is deleted mid-flight, riders are returned to the departure landing.

## 4. Files

**New, server:**

- `src/server/Systems/RealmDestroyer.luau`
- `src/server/Systems/SkyBalloon.luau`
- `src/server/Services/BalloonModel.luau`
- `src/server/Services/DragonArmory.luau`

**New, shared** (pure Luau, no Roblox globals):

- `src/shared/DragonConfig.luau`
- `src/shared/DragonRig.luau`
- `src/shared/BalloonConfig.luau`

**New, client:**

- `src/client/Controllers/DragonController.luau`
- `src/client/UI/DragonHud.luau`

**New, tests:** `tools/dragon.spec.luau`, `tools/dragon-client.spec.luau`

**Modified, server:**

| File | Change |
| --- | --- |
| `Main.server.luau` | Dragon system, `Fire` request, `Balloon`/`Dragon` snapshot fields |
| `RoundManager.luau` | Dragon tick, rebase, reset (resets happen before `World:reset`; see §6) |
| `AdventureService.luau` | Balloon and Dragonbane routing; elevator trips removed |
| `ExplorationGenerator.luau` | Balloon station replaces the lift; armory placement |
| `ObjectiveService.luau` | `catalog` for the bestiary |
| `Activities/Bestiary.luau` | RealmDestroyer entry, never spawned as a creature |
| `Activities/Ecology.luau`, `Activities/Hunt.luau` | Bestiary catalogue |
| `Activities/Repair.luau` | Wording |
| `Services/CosmeticService.luau` | `Wings` kind; drop/craft purchase |

**Modified, shared:**

| File | Change |
| --- | --- |
| `Rules.luau` | Persists DragonScales, Emberhearts, DragonKills, DragonAt, DragonRolls, a bounded Bestiary, `dragonwing`, Dragonbane |
| `ShopConfig.luau` | Dragonwing Mantle |
| `ObjectiveConfig.luau` | Main text, Dragonbane |
| `AudioConfig.luau` | New cue slots |
| `GameConfig.luau` | 0.7.0 |

**Modified, client:**

| File | Change |
| --- | --- |
| `Main.client.luau` | Events, renderer |
| `UI/Interface.luau` | HUD hooks, Bestiary page and menu card (cards are now 52 px tall), shop drop row, help text |
| `Controllers/InputController.luau` | G / R1 fire |
| `Controllers/PowerController.luau` | Knockback |

**Modified, tests:**

- `tools/exploration.spec.luau`, `tools/bootstrap.spec.luau`, `tools/visuals.spec.luau`: elevator tests rewritten for the balloon
- `tools/check.ps1`: runs the two new specs

## 5. Missing assets (not invented)

- **Dragon:** no rigged MeshPart or animations. The current dragon is a procedural client-side part rig (~180 parts) with code-driven wing, neck, jaw, tail and leg animation. It has the requested anatomy (long neck, horned head, jaw, four limbs, articulated membrane wings, spiked tail, layered scales, glowing eyes) but is **prototype art and does not match the concept art**. Replace it with a rigged model: keep `DragonRig` head, heart and wing-root offsets consistent with the server hit spheres.
- **Balloon:** part-built, no mesh or texture.
- **Dragonwing Mantle:** part-built wings.
- **Audio** (silent until permitted IDs are set in `AudioConfig`): DragonRoar, DragonFire, BalloonBurner. DragonGust, DragonImpact and DragonbaneShot reuse engine-bundled sounds.

## 6. Known limitations and risks

- **Round-start ordering (fixed, please regression-check):** the balloon and dragon reset after `World:reset`, which wiped station and region registration in real rounds. Resets now happen before it. `bootstrap.spec` covers the balloon, and the dragon omen is now visible in a round.
- **Choppy motion:** the server moves the balloon and its riders at the 10 Hz tick, so motion may look stepped. The dragon is smoothed on the client from 10 Hz attributes.
- **Movement audit during knockback:** `MovementUntil` is extended 1.8 s on knockback. Check that legitimate gust launches aren't rubber-banded.
- **Hit approximation:** dash hits on the stunned head use a 10-stud horizontal radius around the server head point.
- **Balance:** a scripted perfect-aim solo bot repels tier 1 in about 34 s and takes about 58 damage standing still. Human balance is unknown.
- **Placement:** emplacements and the forge are placed by site search. In crowded regions one can be missing (handled: it is simply absent).
- **Network cost:** raids and attacks crack cells via `World:warnCell`; full raze warns hundreds of cells at once.

## 7. Studio tests required

1. **Balloon:**
   - Boarding prompt and countdown card.
   - Two or more players joining one departure.
   - Seat positions and gondola visuals for both colour variants; propeller spin.
   - Flight smoothness, arrival at the next landing, turnaround.
   - Death, leaving and sanctuary while aboard.
2. **Omen (Grasslands):** silhouette visibility and scale at distance through atmosphere and fog; roar shake.
3. **Raid (Crystal):** telegraph readability, burn distance, falling cells, fire patches.
4. **Encounter (region 5):**
   - Every attack's telegraph and dodge window; jump vs. shockwave; wall cover vs. gust.
   - Weak-point glow and labels; crossbow aim on PC, controller and touch.
   - Ballista repair, smash and mend; cannon interrupt.
   - Raze timer, escape notice, rewards.
   - Repeat with 2–4 players for HP scaling and target rotation.
5. **Later tiers:** Ember Rain, Inferno Sweep, difficulty curve.
6. **HUD:** boss bar, FIRE button and balloon card on phone portrait and landscape, tablet and desktop. Must not overlap the player list, tracker, menu button or touch controls.
7. **Bestiary page and menu card layout** (5 cards); shop row for the Mantle; Mantle drop and craft; persistence across rejoin.
8. **Performance:** client FPS with the dragon near and far on mobile; server heartbeat during a raze.

---

# Previous handoff (0.6.0)


Developer checks only were run:
- StyLua formatting and Selene lint (0 errors, 0 warnings)
- shared Luau analysis
- compiling every Luau file
- the Rojo build
- a one-off runtime smoke: all 10 realms spawn their enemy ecosystems, and the shepherd quest accepts talk and sheep rescues

**The regression suites were not re-run.** Nothing was tested in Roblox Studio.

### 1. Features implemented

### Floating HUD (`src/client/UI/Interface.luau`)

- **Layout:** the old top-center black panel is gone. The HUD is a transparent frame on the right side at 30% screen height, below the Roblox player list. On short screens it moves to the top-right at 0.72 scale; on narrow screens it scales to 0.86.
- **Realm line:** `REGION · Biome`, for example `HAVENWOOD REACH · Sky Grasslands`.
- **Altitude:** `256m ALTITUDE`.
- **Health bar:** 24px thick and 250px wide with rounded ends and an "n/m" readout.
  - Colors: green (> 60%), orange (> 30%), red (≤ 30%), with tweened fill and color.
  - A thin cyan Aegis overlay sits along the bottom of the bar.
- **Deletion bar:** the same size, driven by the real `data.Distance`.
  - States: SAFE (cyan, ≥ 2 × `WaveWarningDistance`), WARNING (orange, ≥ `WaveWarningDistance`), CRITICAL (red, below it).
  - Fill is `1 - distance / (4 × WaveWarningDistance)`. CRITICAL adds a subtle pulse in `UI:animate`.
- **Current objective:** a diamond icon, a "CURRENT OBJECTIVE" caption and bold text chosen from real state: carrying an artifact, at the seal altar, gate open, danger, or the default "climb to the next realm". It fades in when it changes.
- **Optional activities:** the tracker is now transparent and right-aligned below the HUD, collapsed by default, and toggled from its header. It no longer repeats the realm name or the main objective; its first row is the region-collapse timer.
- **Removed from the HUD:** BEST/VERIFIED, the time and coin line, the Stability/EXPOSED/Gate status line and duplicate supply counts. The `Best` and `Time` labels still exist but are hidden. The key/repair line appears only when keys, the altar or a shared repair matter.
- **Other:** the Danger warning text has no dark backing; the ☰ menu button moved to the top-left; a new dialogue line UI (`UI:dialogue`) shows NPC speech.

### Realm enemies

- **`Activities/Bestiary.luau`:** 30 enemy definitions, a common, an elite and a rare encounter for each of the 10 existing realms.
  - 9 procedural body plans: Quadruped, Crawler, Serpent, Biped, Colossus, Flyer, Floater, Wraith, Burrower and Plant (each with distinct silhouette and motion).
  - Each enemy has its own HP, speed, detect radius, attack set, damage, radius, weakness, armor, stagger resistance, and ambush, stalk or erratic traits.
  - Difficulty rises by realm through attack complexity (single lunge → mixed volley, blink and slam sets), not only stats.
- **`Activities/Animated.luau`:** procedural animation (legs, wings, tails, jaws, heads, orbiting shards, bob) placed with `workspace:BulkMoveTo`, falling back to per-part CFrames.
- **`Activities/Creatures.luau`** (rewritten, same API):
  - **States:** Patrol, Chase/Stalk, Hidden (ambush and burrow), Windup (red tint plus ground markers), Attack, Recover (an opening), Stagger, Retreat (at 30% HP), a 75-stud leash, and Dying (fade and sink) → Gone.
  - **Attacks:** Lunge, Charge, Slam, Strike, Volley (three markers), Blink, Dive and Burrow.
  - **Weaknesses:** Exposed (only hurt while recovering), Armored (armor absorbs plain hits; overcharged dashes remove 2; stomps bypass it), Aerial (dash must be at flight height, or stomp).
  - **Targets:** players and registered region "Followers" (the shepherd and sheep).
- **`Activities/Ecology.luau`** spawns per region on activation:
  - **Commons:** 2 + realm depth / 3 + players / 2 (at most 6) on the core.
  - **Elites:** 1–2, on satellite sub-areas.
  - **Rare encounter:** chance 0.2 + 0.06 × depth.
  - **Spawn rules:** never within 45 studs of the landing or 25 of the beacon, never on reserved building circles, and always on intact cells.
  - **Simulation and loot:** creatures simulate only within 260 studs of a player. Loot per tier goes to every hitter (Common 6 coins / 15 XP; Elite 14 / 35 plus a relic; Rare 35 / 80, 2 relics and a perk), plus the Hunter and Guardian's Bane achievements.
- **Wiring:** Hunt lairs use the realm's common or elite tier (the Void hunt keeps the Deletion Sentinel via `Creature = "Anomaly"`); roaming-guardian events use the rare tier.

### Lost Shepherd and flock quest

- **Rig (`src/server/Services/NpcRig.luau`):** an R15-structured rig with HumanoidRootPart, an R15 Humanoid, an Animator, the 15 standard parts and correctly named Motor6Ds built from rest-pose joint positions.
  - Animations: Roblox's default R15 Idle, Walk and Cheer IDs from `src/shared/AnimationConfig.luau`, with a procedural Motor6D swing fallback.
- **Shepherd outfit:** brown tunic, cream sleeves, belt and pouch, boots, hood with drape and fringe, a worried face (raised brows, frown), backpack with bedroll, a crooked staff and a lit lantern. Scale 0.88, slightly shorter than a player.
- **Quest (`Activities/Flock.luau`, type "Flock", Grasslands pool):**
  1. Talking to the shepherd gives dialogue and directional hints to each lost sheep.
  2. Three sheep, made of multi-blob wool with legs, ears, eyes and a tail, idle and bleat in distant reachable core spots.
  3. Rescued sheep and the shepherd follow the player in a line. They avoid obstacles, wait if the player is more than 70 studs away, and cower or shake near creatures.
  4. A creature hit scatters a sheep, which must be found again.
  5. Getting everyone to the beacon triggers celebration hops and cheer, thank-you dialogue, one `svc:complete` (40 coins, 80 XP, a perk, the Rescuer achievement), the tracker update, and a fade-out despawn after 8 seconds.
  6. If ground under a member is deleted, the quest fails.

### 2. Files modified

- **Client:** `src/client/UI/Interface.luau`, `src/client/Main.client.luau` (Dialogue and Bleat events)
- **Server:**
  - `src/server/Systems/Activities/Creatures.luau` (rewrite)
  - `src/server/Systems/Activities/Hunt.luau`
  - `src/server/Systems/ObjectiveService.luau` (ecology hooks, rare guardian)
- **Shared:** `src/shared/RealmConfig.luau` (Flock activity, Void hunt creature), `src/shared/ObjectiveConfig.luau` (Flock hint and reward), `src/shared/AudioConfig.luau` (`SheepBleat` slot), `src/shared/GameConfig.luau` (version 0.6.0)
- **Config:** `selene.toml` (allows mixed figure-spec tables)
- **Tests:**
  - `tools/gameplay.spec.luau`: the rescue test now uses the Ruins survivor, region 13.
  - `tools/visuals.spec.luau`: the tracker check expands the tracker first and looks for "COLLAPSES IN".

### 3. New modules and dependencies

`Activities/Animated.luau`, `Activities/Bestiary.luau`, `Activities/Ecology.luau`, `Activities/Flock.luau`, `Services/NpcRig.luau` and `shared/AnimationConfig.luau`. There are no external packages.

### 4. Expected gameplay behaviour

See section 1. Enemies stay leashed to their territory, telegraph before damage, and can be beaten solo. The shepherd quest is completable solo within a region's 240-second lifetime.

### 5. Known limitations

- **Missing dragon and balloon:** no red dragon or Sky Balloon exists in the codebase (searched), so neither was "preserved" or integrated. The dragon needs a spec before it can be built.
- **Placeholder enemy art:** enemy and sheep bodies are part-built prototypes, not rigged MeshParts.
- **Placeholder shepherd art:** the shepherd uses block body parts with hand-made accessories.
- **Movement:** enemies don't use PathfindingService. They steer over intact terrain cells with ±45/90° sidesteps, ignore small props, and cannot cross bridges.
- **Tick rate:** the server moves creatures and NPCs at the 10 Hz objective tick, so motion may look stepped.
- **No-op calls in the harness:** `BulkMoveTo` and `LoadAnimation` silently do nothing offline.
- **Sheep scattering:** in the developer smoke, a sheep was scattered within 2 seconds of following. QA should check this isn't too punishing near spawns.

### 6. Areas requiring regression testing

Run the full `tools/check.ps1 -Format`. Expected impact:

- **HUD:** `client.spec` (Biome and Health text, Adventure visibility), `storm.spec` and `disasters.spec` (Danger text) and `visuals.spec`. The HUD fields changed (Health text is now "n/m  +k AEGIS"; Danger has no backing).
- **Creatures and hunts:** `gameplay.spec`. The creature-lair test was already failing in 0.5.0 because it ignores ground height for creatures on sub-areas, and creature HP, armor and weakness now differ by tier.
- **Rescue test:** this round moved the rescue test to region 13. Verify the move.
- **Expansion:** `expansion.spec` and `exploration.spec` (realm 0 now has a Flock activity instead of Rescue).
- **Endurance:** ecology adds creature simulation to the 9 resident regions.

### 7. Roblox Studio tests required

1. **HUD:** desktop, phone portrait and landscape, and tablet.
   - Must not overlap the player list (with 1, 6 and 12 players), the tracker, the touch controls or the safe areas.
   - Check readability over bright sky, the bar colors and transitions, the critical pulse and the objective changes.
2. **Enemies in each realm:**
   - Telegraph readability and dodge windows; weaknesses (armor, exposed openings, aerial, burrow vulnerability); stagger and retreat.
   - Leash; difficulty curve; part counts and server heartbeat with 9 regions; animation look; spawns never inside buildings or on the landing.
3. **Shepherd:**
   - The rig stands on the ground (no sinking) and the default R15 animations play. If they don't, set `AnimationConfig.UseDefaults = false`.
   - Accessory placement, staff in hand, lantern light.
   - Dialogue flow, sheep pathing over long distances, waiting and catch-up, fear reactions, scatter and re-find, completion, one-time reward and despawn; two players sharing the quest.
4. **Interactions:** dialogue UI placement on mobile; the bleat sound (silent until `AudioConfig.SheepBleat` is set).

### 8. Unavailable visual assets

- Rigged creature meshes for the 30 bestiary entries.
- A shepherd outfit (clothing, hood and staff MeshParts, a worried face decal), a sheep mesh with animations.
- Permitted sheep bleat audio.
- Dragon and balloon models (also not designed).
