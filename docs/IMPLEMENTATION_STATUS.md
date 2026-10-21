# Implementation status

Updated 2026-10-12 for version 0.7.2.

- **Implemented** means the code exists and passes developer checks: format, lint, shared type check, compile, Rojo build and the offline Lune specs listed in CODEX_QA_HANDOFF.md.
- It does **not** mean QA-verified or Studio-verified. Nothing in 0.7.0 has been run in Roblox Studio.

## 0.7.2: Studio playtest fixes, Dragon Preview, shop

| Feature | Status | Notes |
| --- | --- | --- |
| Client crash: `GetPivot` on `FloatingRealms.BalloonFlights` | Fixed | Seen in the user's Studio logs every frame. `EnvironmentController` now only treats Models as regions |
| Client crash: nil spinner hub under streaming | Fixed | Propeller blades can stream in before their hub |
| Dragon Preview (Studio only) | Implemented, unverified in Studio | Workspace attribute `DragonPreview` (on in `default.project.json`). The first island is a tier-1 battle ~20 s after spawning; islands 2–3 are raided. Live servers always use the real progression. The offline harness turns it off |
| Weapons from the first island | Implemented | Forge and Harpoon Rack in every region; ballista and cannon only in battle regions |
| Shop redesign | Implemented, unverified in Studio | Balance header (coins, scales, shards), category tabs, 2-column cards with colour swatch, rarity, description and one action (BUY / NEED / EQUIP / EQUIPPED / CLAIM / CRAFT / LOCKED), unequip, live refresh keeping scroll position |
| New cosmetics | Implemented, prototype art | Sunrise Ribbon, Frostfire Trail, Forge Sparks, Void Shimmer, Golden Silhouette, Gale Wings (15 items total) |
| Emote purchase stripped the worn cosmetic | Fixed | Emotes are owned, not equipped |
| Purchase feedback | Implemented | Clear "not enough coins" text; bought and equipped confirmations |
| Stale instances in the Studio place | Needs the user | The logs show `AchievementService`, `Shared.Modules` and `Shared.Config` errors from the old stale Rojo tree. Reconnecting to the fresh server on 34873 (or opening `build/FloatingRealms.rbxlx`) removes them |

## 0.7.1: Sound design and the Dragonbane Harpoon

| Feature | Status | Notes |
| --- | --- | --- |
| Designed sound for every audio slot except music and wildlife | Implemented, unverified by ear | `SoundBank` builds 41 cues, 4 looping beds and 2 world loops from the 11 files the Roblox client ships. Shaped with speed, time windows, distortion, reverb, EQ, tremolo and chorus. No asset IDs invented. **Nobody has listened to them in Studio yet** |
| Previous built-in cues | Replaced | `swoosh.wav`, `snap.wav`, `electronicpingshort.wav` and `clickfast.wav` are **not** in the installed client, so those cues were silent |
| Music and wildlife | Not available | No designed substitute; silent until permissioned IDs are set in `AudioConfig` |
| AudioConfig overrides | Implemented | Any `rbxassetid://` in a slot replaces its designed cue |
| Dragon audio | Implemented, unverified by ear | Layered roar (far-reaching), looping breath on the head (3D), wing-flap whomp on each downstroke, gust, impacts, hurt |
| Weapon, balloon and forge audio | Implemented, unverified by ear | Crossbow, harpoon, ballista, cannon, hit confirm, crafting; balloon burner loop (3D, server), depart and arrive; forge fire loop (3D, server) |
| Storm and world audio | Implemented, unverified by ear | Wind and rain beds, thunder, distant thunder, earthquake, collapse, deletion, danger drone, designed air bed for biomes |
| SFX setting covers world sounds | Implemented, unverified | Server loops are tagged `RealmSound` and routed into the client's SFX group |
| **Dragonbane Harpoon** (new weapon) | Implemented, unverified | Harpoon Rack beside each forge: 3 harpoons for 3 timber + 1 crystal; restock 2 for 1 timber (max 6). T / L2 / THROW. 150-stud range, 2.4 s cooldown. 11 damage on an exposed weak point (and pins that window open 1.6 s longer, once per window); 2 through scales. Battle only |
| Visible Dragonbane gear | Implemented, prototype art | Crossbow welded to the right hand; harpoons on the back (one per harpoon carried); replicated to all players |

## 0.7.0: Realm Destroyer and Sky Balloon

| Feature | Status | Notes |
| --- | --- | --- |
| Sky Balloon replaces the sky elevator | Implemented, unverified | Station at the old lift site in every region; old "Lift" prompt removed |
| Balloon boarding, 5 s shared countdown, multiplayer (8 seats) | Implemented, unverified | One departure per station; late riders join; Transit blocks re-triggering |
| Balloon flight, arrival, progression update, turnaround | Implemented, unverified | 14 s flight (8 s express); `PlayerManager:transfer` updates Region and Peak; fresh balloon docks 8 s later |
| Balloon safety: death, leave, sanctuary, region loss, rebase | Implemented, unverified | Riders are released, never transferred; flights survive rebasing and source-region deletion |
| Balloon visuals: navy/cream primary, red/cream variant | Implemented, prototype art | Native parts: striped envelope, gold bands, finial, medallions, gondola, ropes, lanterns, burner, propulsion ring, propeller. Not mesh art |
| Realm 1 (Sky Grasslands): distant silhouette and roars | Implemented, unverified | No combat. Roar audio slot is empty (silent); camera shake and feed text only |
| Realm 2 (Crystal Kingdom): raids on distant ground | Implemented, unverified | Telegraphed; burns cells at least 75 studs from every player; lingering flames |
| Realm 3 (Floating Jungle, first region): fight-or-escape encounter | Implemented, unverified | Starts 20 s after the region activates |
| Later realms: tiers 2–4 | Implemented, unverified | More HP, damage, destruction and faster cadence; Ember Rain (tier 2+), Inferno Sweep (tier 3+) |
| Attacks: Fire Breath, Dive, Wing Gust, Ground Slam (+2 later) | Implemented, unverified | All telegraphed (min 1.1 s); burning DOT; shockwaves can be jumped; walls give cover from the gust |
| Weak points: Heart, Wings, Head | Implemented, unverified | Exposed only in attack windows; glow and "WEAK POINT" labels on the client |
| Dragonbane Crossbow (crafted at Dragonbane Forge) | Implemented, unverified | 2 timber + 1 crystal; bolts 1 timber = 12; G / R1 / FIRE button; server aim assist and line of sight |
| Repairable Ballista | Implemented, unverified | 4 timber; dragon impacts smash it (2 timber to mend) |
| Crystal Cannon | Implemented, unverified | 1 crystal per shot; interrupts wind-ups and exposes the heart |
| Solo and multiplayer balance | Implemented, untuned | HP × (1 + 0.55 per extra fighter, max 6). Scripted perfect-aim solo run: 34 s. Real-player tuning needs Studio playtests |
| Fight or escape; raze timer | Implemented, unverified | Escapees get no boss rewards; an empty or timed-out arena is razed (causeway spared) |
| Rewards: coins, XP, relics, Dragon Scales, Emberheart Shards | Implemented, unverified | Persistent scales and shards; full trophies once per 15 min per player (anti-farming) |
| Dragonbane achievement | Implemented, unverified | |
| Dragonwing Mantle cosmetic | Implemented, prototype art | 20% drop, guaranteed by the 5th roll; craftable from 40 scales + 2 shards. Part-built wings |
| Bestiary entry and discovery progress | Implemented, unverified | 4-stage dragon discovery; defeated creatures catalogued; new Bestiary page and menu card |
| HUD: boss bar, raze timer, weak-point prompt, balloon card | Implemented, unverified | Mobile layout not checked in Studio |
| Dragon model | **Prototype art, incomplete** | Procedural client-side part rig (~180 parts). Does **not** match the concept art. No rigged MeshPart or animation assets exist |

## Earlier features (0.6.0, unchanged)

| Feature | Status | Notes |
| --- | --- | --- |
| Floating HUD, health and deletion bars, objective line | Implemented, unverified | Objective line now mentions the Sky Balloon and the dragon |
| Realm enemy roster and AI | Implemented, prototype art | Creature defeats are now recorded in the bestiary |
| Lost Shepherd and flock quest | Implemented, unverified | |
| Sheep bleat audio | Partial | Slot empty (silent) |

## Known failing tests (pre-existing, unchanged by 0.7.0)

These failed in the baseline run before any 0.7.0 change and still fail the same way:

| Spec | Failing test |
| --- | --- |
| `gameplay.spec` | Creature lair (sub-area ground height) |
| `visuals.spec` | "Viewpoints and ledges are walkable ground": Crystal viewpoint height out of range |
| `menu-ocean.spec` | "Ocean setup … fills Terrain water" (line 156) |
