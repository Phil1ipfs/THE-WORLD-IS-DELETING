# Realm gameplay (0.4.0)

Design goal: *the more you explore, the more you can gain, but the longer you stay, the closer deletion gets.* Every region now has a main objective, which is to climb onward by the sky causeway, the elevator or the cave seal. It also offers a seeded set of optional activities, plus live events and active storm shelters. Optional content is never required to progress, and every activity can be completed solo.

## Framework

| Piece | File | Role |
| --- | --- | --- |
| Realm data | `src/shared/RealmConfig.luau` | Per-realm names, lore, flora, architecture, landmark, creature, **activity pool**, event pool, sky profile |
| Objective metadata | `src/shared/ObjectiveConfig.luau` | Hints, rewards per activity type, run perks, achievements, event text, relic rules |
| Builder | `src/server/Systems/Activities/Builder.luau` | Shuffles the realm pool with the round seed and builds 4 activities per region |
| Activity modules | `src/server/Systems/Activities/*.luau` | `build`, `interact`, `update`, `status` per type |
| Service | `src/server/Systems/ObjectiveService.luau` | Runs activities, rewards, perks, achievements, discoveries, hazards, dynamic events, storm breaches and the snapshot view |
| Placement | `src/server/Services/Sites.luau` | Puts activity sites on supported land, clear of shelters, routes, prompts and other activities |

All activity prompts go through the existing `AdventureService:interact` validation, which checks life, readiness, transit, range, trusted position, ground support and debounce. A prompt can only send the player's intent.

## Activity types

| Type | Player interaction | Success / failure | Reward and consequence |
| --- | --- | --- | --- |
| Repair | Contribute timber/crystals (2 per press, shared) | Completes when the cost is met | Shared reward + perk. The machine changes the realm: Windmill opens mill stores, Resonator overcharges everyone, Pump cools lava, Beacon reveals secrets, Generators fortify shelters (and run the elevator express) |
| Rescue | Free the survivor (cut vines ×3 / thaw with an herb), then escort them to the rescue beacon | Saved at the beacon. Lost if their ground is deleted. If the escort dies or runs off, they wait | Coins, XP, perk, *Sky Rescuer* |
| Hunt | Gust Dash through creatures or drop onto them. Aegis reflects lunges | Lair cleared. If creatures fall with their ground, the lair is lost | Shared reward + relic, a spoils chest for everyone |
| Plates | Stand on 3 plates. Each stays latched 6s | All latched at once opens the vault | Reward + vault chest |
| Dials | Turn 3 symbol pillars to match the mural above them | All aligned | Reward + relic |
| Beams | Rotate 3 mirrors until the beam reaches the receiver | Receiver lit | Reward + light-vault chest |
| Mining | Strike each crystal vein 4 times | Every striker shares each vein's 2 crystals | Crystals + completion reward |
| Cache | Ledge (Sky Leap), Edge (crumbling rim / ice lake) or Storm (claimable only during storms) | Personal loot once per player | Coins, XP, relic, perk; hidden caches stay masked until found |
| Rings | Updraft vent onto a launch pad, then Wind Sail through 4 rings within 14s | Times out and resets | Reward + perk |
| Artifacts | Carry 3 artifacts (one at a time) to the pedestal | A dead or departed carrier drops the artifact, which returns home | Reward + relic |
| Gate | Pull the lever; reach the vault within 7s (10s if overcharged). A partner on the lever holds it open | Loot only from inside; an inside lever reopens the door | Reward + vault chest |

## Realm identities

| Realm | Activity pool (4 drawn per region) | Creature (attack) | Landmark | Hazard / events |
| --- | --- | --- | --- | --- |
| Sky Grasslands | Windmill repair, Shepherd rescue, Bramble lair, Stone circle plates, hidden cliff cache | Bramble Stalker (lunge) | Elder Oak Hill | Supply drop, lost traveler, rare relic, ancient machine |
| Crystal Kingdom | Prism mirrors, resonant veins, elite Crystal Sentinel, Resonator repair, hidden geode | Crystal Sentinel (slam) | Prism Spire | Rare relic, supply drop, guardian, secret vault |
| Floating Jungle | Vine-bound botanist, tree glyph dials, Vine Lurker nest, canopy nest cache, canopy glide | Vine Lurker (lunge) | Canopy Giant + treehouse | Lost traveler, supply drop, rare relic, guardian |
| Volcanic Realm | Coolant pump, Ember Wisps, magma vault gate, obsidian idols, hidden caldera hoard | Ember Wisp (targeted strike) | Ashfall Caldera | **Lava pools**; relic, guardian, supply drop, machine |
| Frozen Sky | Thaw-and-escort scout, glacier glide, Frost Wraiths, signal beacon, ice-lake cache | Frost Wraith (slam) | Glacier Arch | **Slippery ice lake**; supply drop, traveler, relic, vault |
| Ancient Ruins | Crown relic artifacts, sun-dial dials, temple plates, crypt gate, ruins survivor | Dust Golem (slam) | Sunken Colonnade | Secret vault, relic, traveler, guardian |
| Storm Islands | Storm generator, updraft gauntlet, Storm Spirits, lightning-rod plates, storm-only hoard | Storm Spirit (strike) | Lightning Spire | Supply drop, guardian, relic, machine |
| Mechanical Realm | Village generator, piston vault, gear drones, cog dials, weight plates | Gear Drone (lunge) | Cogspire | Machine, supply drop, guardian, vault |
| Celestial Gardens | Moon mirrors, starlight rings, star-keeper escort, floating-isle cache, constellation dials | Star Moth (strike) | Moon Pavilion + floating stones | Relic, machine, traveler, supply drop |
| Corrupted Void | Elite deletion anomaly, memory fragments, rift-anchor plates, last survivor, collapsing vault | Deletion Anomaly (blink + burst) | Rift Altar | **Void pools**; guardian, relic, traveler, vault |

## Risk versus reward

- Outskirts lobes, ledges, launch pads and viewpoints are edge ground (Edge ≥ 0.86). They warn and fall about 70 seconds before the region core. The best content therefore sits on the ground that disappears first.
- **Relics** (cap 9) come from activities, chests and rare-relic events. You can spend 2 at an already discovered realm shrine for a random **run perk**, or keep them: unspent relics pay out 6 coins and 15 XP each when the run ends and count toward the persisted lifetime `Relics` total.
- **Run perks** (one of each, no stacking): Gale Anklet (dash cooldown −25%), Feather Cloak (two Sky Leaps per jump), Aegis Core (+30 shield), Silk Sail (+2s glide), Heartstone (+25 max HP), Explorer's Pack (+3 capacity per supply), Relic Compass (reveals hidden caches).
- **Achievements** are persisted in the profile: Sky Rescuer, Rite Breaker, Creature Hunter, Guardian's Bane, Treasure Seeker, Storm Keeper, Engineer, plus the secret Daredevil and Realm Completionist. Three of them unlock cosmetics that cannot be bought: Relic Halo, Stormcaller Ribbon and Guardian's Mantle.

## Dynamic events

Each visited region runs an event director seeded by world seed and region index. The first event comes 22–36s after activation, then one every 40–65s, with no immediate repeats. An event only spawns if the region's remaining lifetime is at least its requirement: Supply drop 55s, Rare relic 45s, Guardian 100s, Lost traveler 95s, Secret vault 50s, Ancient machine 45s. Events are announced with a compass direction:

- **Supply drop**: the crate parachutes in over 6s. Everyone can claim it once.
- **Rare relic**: appears on an edge cell for 40s. Claiming it gives the *Daredevil* achievement.
- **Roaming guardian**: an elite creature that scales with the number of players present (100s). Defeating it pays coins, XP, 2 relics and a perk.
- **Lost traveler**: spawns a new escort activity.
- **Secret vault**: a chest opens in the cave for 45s.
- **Ancient machine**: the shrine grants a perk for 45s.

## Storm gameplay

The storm timing and outdoor damage (8 HP every 2s) are unchanged. New: when a storm turns active, the house shelters in occupied regions get 1–2 window **breaches**. Each one shows as a dark hole with gusting particles and has a "Patch storm breach" prompt. While any breach is open, occupants of that shelter take 3 HP per tick instead of 0. You can fix this by:

- patching breaches (coins, XP, *Storm Keeper* after 3)
- using Timber Brace inside the shelter, which boards up every breach in it
- having already repaired the realm's generator, which makes shelters breach-proof and heals occupants 4 HP per tick

Storm-only hoards and supply drops reward players who go outside: Aegis absorbs storm damage.

## Power-up uses

- **Gust Dash**: strikes creatures (2 damage when overcharged), crosses plate circuits and beats timed vault doors.
- **Sky Leap**: reaches 14-stud cache ledges and floating stepping stones. Feather Cloak allows a second leap.
- **Aegis**: blocks creature attacks and lava/void ticks, and reflects lunges back into the attacker.
- **Wind Sail**: flies the ring courses and glides to and from viewpoints.
- **Crystal Overcharge**: doubles dash damage and holds vault mechanisms open 3s longer.
- **Timber Brace**: delays ground deletion (unchanged) and seals shelter breaches.

## Multiplayer

Cooperation makes activities faster or easier, but every activity is completable solo:

- shared repair and mining contributions
- partners holding plates or levers
- escort takeover
- elite and guardian HP that scales with players present, rewarding everyone who hits it

Each player can open each chest once.

## Pacing targets (design intent)

These timings are design intent, not playtested measurements.

| Size | Activities | Target time |
| --- | --- | --- |
| Short | Dials, Mining, Plates, Ledge and Edge caches, supply drop, rare relic | 30–60s |
| Medium | Rescue, Hunt, Rings, Gate, Artifacts | 1–2 min |
| Major | Repairs needing gathered supplies, elite guardians, completing a whole region | 2–3 min |

A region core lasts 180s after activation and its outskirts about 112s. The deletion wave follows its existing grace and speed rules, so players must choose which 2–3 activities fit before they leave.

## 0.5.0 Larger realms and sub-areas

Each region now has up to 4 satellite landmasses (48 of 48 tested regions get 4), each a named sub-area at its own elevation and reached by a rope suspension bridge. A signpost at every bridge head names the sub-area and its purpose.

| Sub-area | Elevation | Structures | Gameplay |
| --- | --- | --- | --- |
| Highlands (for example Misty Highlands) | +30 | Terraced plateau with ramp, climbable lookout deck, rock arch | Viewpoint, crystals, Survey cairn, pool activities |
| Wildwood (for example Ancient Wildwood) | +8 | Treehouse deck, giant tree, dense woods | Timber and herbs, lairs and caches, Survey cairn |
| Ruins (for example Forgotten Ruins) | −8 | Colonnade, statue, broken walls | Crystals and timber, puzzles and artifacts, Survey cairn |
| Cliffside (for example Cliffside Hamlet) | +18 | Realm-styled house (a storm shelter with breaches) | Herbs and timber, shelter, Survey cairn |

- **Survey** is added to every region on top of the 4 seeded pool activities.
  - Charting a cairn pays 5 coins and 12 XP.
  - Charting all of them (per player) pays 20 coins, 50 XP, a relic and a perk.
- **Pool activities** can now spawn on sub-areas (repairs, lairs, plates, dials, mirrors, mining, caches, artifacts). Rescues, ring courses and timed vaults stay on the flat core, where escorts, glide lines and lever runs must stay walkable.
- **Pacing:** `RegionLifetime` is 240s (was 180). Sub-area ground (Edge ≥ 0.92) warns and falls about 70s before the region core. The deletion wave, storms and event timings are unchanged. This keeps the choice: a far, high sub-area pays well but disappears first.
