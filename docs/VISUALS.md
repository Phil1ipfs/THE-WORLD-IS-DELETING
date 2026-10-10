# Visual and environment overhaul (0.4.0)

Every asset is procedural, built from native Roblox parts, special meshes, particles, beams and lighting. No Toolbox models, scripts or invented asset IDs were added.

## Sky and atmosphere — `src/client/Controllers/EnvironmentController.luau`

- Each realm has a sky profile (`RealmConfig.*.Sky`) covering clock time, latitude, ambient light, atmosphere (density, offset, color, decay, glare, haze), Terrain cloud cover/density/color, bloom, sun rays, color grading, star count, sun/moon size and cloud-sea color. Profiles blend by altitude through the existing biome band blend and are smoothed over time.
- Lighting effects:
  - A `Sky` object controls celestial bodies, star count and sun/moon size.
  - Bloom and SunRays are reduced during storms; sun rays are halved at low detail.
  - `ShadowMap` lighting technology and environment diffuse/specular scales are set in `default.project.json`.
- Three cloud formations:
  - Terrain cumulus.
  - A flat cloud sea far below the islands that rises with the deletion wave and turns violet as it nears.
  - Storm layers: the existing high sheared layers plus a new dark shelf-cloud front that advances from 640 to 230 studs during the approach.
- The storm also adds distant rain sheets, branching lightning forks, a shelf-cloud flash, a subtle shake during Heavy-phase gusts and a short thunder rumble timed to the thunder delay. Camera settings and shelter suppress shake.
- Storm damage, timing and shelter rules are unchanged. Atmosphere density stays ≤ 0.4 and haze ≤ 1.4 so routes remain readable.
- Distant island silhouettes are now inverted wedge hulls tinted by the realm atmosphere.

## Realm expansion — `RegionLayout.outskirts`, `RealmAssets`

- Every region gains an outskirts lobe of 12–16 cells on the mainland lattice. It is placed with measured clearance from the causeways, grove and cave and is reachable by a guaranteed four-connected neck.
- Each realm gets a landmark with a walkable viewpoint plateau and ramp:
  - Elder Oak Hill
  - Prism Spire
  - Canopy Giant with treehouse
  - Ashfall Caldera with lava
  - Glacier Arch
  - Sunken Colonnade terrace
  - Lightning Spire
  - Cogspire with spinning gears
  - Moon Pavilion with floating stepping stones
  - Rift Altar
- Water features: ponds with reeds and lily pads, lava pools (hazard), void pools (hazard), and a slippery Ice lake slab (walkable ground) in Frozen Sky.
- Island undersides get hanging rock drips for irregular floating silhouettes. Dirt, cobble, snow and plate paths link the landing, houses, bridges and outskirts. Fenced garden plots and abandoned camps (cart, tent, crashed glider or scrap pile) add environmental storytelling.

## Asset library — `src/server/Services/Props.luau`

- Trees:
  - Broadleaf, with a tapered leaning multi-segment trunk, root flares, branches and ellipsoid canopy clusters.
  - Ancient, with buttress roots, six branches, vines and a large canopy.
  - Pine, with four-wedge cone tiers and snow caps in Frozen Sky.
  - Sapling.
  - Dead, with twisted bare branches and twigs.
  - Glowing, with glass canopies and neon pods.
  - Palm, with curved trunk and drooping fronds.
  - Giant fungal tree.
  - Crystal cluster.
  - Fallen logs, with end rings, a branch stub and moss.
- Ground cover: grass clusters, tall grass, flowers, bushes (with berries), ferns, mushrooms (glowing in some realms), vines, moss, pebbles, boulders, crystal and void shards, ice spikes, embers, snowdrifts, rubble, broken columns, gears, pipes and crates.
- Props: barrels, crates, lanterns, fences, campfires with fire and light.
- Placement: woodland grows beside timber caches, herbs sit among flowers and ferns, crystal formations line the cave walls, and all placement goes through `Sites`.

## Houses — `src/server/Services/Architecture.luau`

There are ten styles: Cottage, Crystal Pavilion, Jungle Stilt, Volcanic Bunker, Frozen Lodge, Ruins Stone, Storm Watch, Mechanical Workshop, Celestial Pagoda and Void Obelisk.

- **Shell:** the collidable VillageWall/VillageRoof/GabledRoof footprint is unchanged, so shelter detection is preserved. Wall, roof and foundation materials vary by style.
- **Exterior:** gable ends, ridge beam, foundation skirt, corner posts and beams, half-timbering, framed lit windows with shutters or flower boxes, door frame with an open door, porch and awning, a lantern, and a chimney with smoke.
- **Style signatures:** lightning rod, pipes and gear, neon seams, columns, flared eaves, icicles, bamboo poles, crystals.
- **Interior:** floorboards, rug, bed, table and chairs, lamp, bookshelf, crate and barrel.

## Collectibles and pickup feedback

- **Herb:** a soil mound, a stem, a seven-leaf rosette and white/violet blooms.
- **Crystal:** a faceted glass prism with a chisel tip, neon core, two side shards and a rock base.
- **Timber:** a bundle of three bark logs with ring end caps and rope bands.
- **Keys:** stone tablets with Sun, Leaf or Moon emblems.
- **Seal altar:** three sockets.
- **Portal:** an arch with a veil and swirl.
- **Elevator:** posts, a beam, rope and a spinning wheel.
- **Healing spring.**
- **Feedback:** the nearest prompt gets a gold outline highlight. On pickup, a ghost copy lifts toward the player and dissolves, with a particle burst, floating "+1 Herb", a pickup sound and a HUD feed entry.

## Power effects — `src/client/Controllers/PowerEffects.luau`

| Power or item | Effects |
| --- | --- |
| Gust Dash | Directional ring, smoke burst, wind trail, speed streaks |
| Sky Leap | Double ground ring, wind burst, landing dust |
| Aegis | Animated ForceField shell with a pulsing glow; it shatters (burst and ring) when spent or expired |
| Wind Sail | Fabric wings with spars, wingtip trails, wind particles |
| Heal | Green sparkles, "+40 HP", green highlight, HUD bar flash |
| Overcharge | Three orbiting crystal shards, rising energy |
| Timber Brace | Wood-chip burst and ring. Braced cells now show crossed planks pinned by stakes |

Audio cues fall back to engine-bundled `rbxasset://sounds/*` files with pitch variation. Set `AudioConfig.UseBuiltinCues = false` to keep them silent.

## HUD — `src/client/UI/Interface.luau`

- Health bar with a shield overlay, a deletion proximity meter and a realm title card on entry.
- Objective tracker: realm, time to collapse, main objective, activities sorted by distance, live event, perks and relics. It is collapsible and starts collapsed on short screens.
- Notification feed (at most 5 entries), achievement popup and damage/heal screen flashes.
- Cooldown sweep overlays with a ready flash; resource color chips.
- Help and Shop pages cover objectives, and the Shop lists locked achievement cosmetics.

## Performance measures

- Collapse uses a per-ground structure index, so it no longer scans every structure for every falling cell.
- Clients find interaction prompts through a `CollectionService` tag instead of scanning every world descendant; the full scan remains as a fallback.
- Scenery that streams in after a region model arrives is registered via `DescendantAdded`.
- Region models use `StreamingMesh` level of detail.
- Decoration is anchored and non-collidable/non-queryable, small parts cast no shadow, and decoration is culled by distance and the Detail setting.
- Scenery point lights are budgeted (≤ 14 from the prop builder), shadowless and enabled within 140 studs.
- Weather uses a fixed 21-anchor budget.
- Offline generation measured about 2,100–2,900 parts per region (test cap 3,600).

## 0.5.0 Suspension bridges and expansion

- **`Services/SuspensionBridge.luau`:**
  - **Curve:** a quadratic Bézier deck between any two endpoints. Sag is 2.5% of the span, clamped to 1.5–8 studs; the grove and cave crossings, which sit mostly over land, are near-flat.
  - **Planks:** separate boards about 1.6–1.8 deep on a 2.2 pitch, so the gaps are visible, with jittered width, offset and rotation and varied browns (Wood and WoodPlanks).
  - **Ropes:** segmented-cylinder handrails with a slight droop (collidable as rails), lower guide ropes and vertical hangers.
  - **Ends:** anchor posts with caps and rope collars, and under-deck beams.
  - **Collision:** invisible collider segments (about 10 studs) form the walking surface and the deletion cells.
  - **Frames:** built with `CFrame.fromMatrix`.
- **Client sway** (EnvironmentController): visual parts tagged `Sway`/`SwayDir` drift sideways by about 0.14 studs, up to about 0.6 in storms and while occupied. Colliders, posts and caps never move. It runs for bridges within 420 studs and only with Detail on.
- **Satellite dressing** (RealmAssets): structures are placed before activities and reserve their space; woodland, cover, rocks and paths follow, along with a waterfall and a label per sub-area.
- **Lobby:** moved to x = 2400. Vista mountains appear only on the side away from the realms.
