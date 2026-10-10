# Next steps

Updated 2026-10-10 for version 0.4.0 (see the new 0.4.0 checklist first). Earlier 0.3.0 notes follow. Pickup/item, power, realm UI/scenery and approaching-storm implementation is present in source. Sun/Leaf/Moon are now collectible, realm-scoped keys with altar placement and contextual UI; dash lasts one second (1.3 seconds overcharged). Full offline checks/endurance and the final source follow-up pass in build/seal-dash-validation.log and build/seal-dash-final-validation.log. Remaining acceptance below requires Roblox Studio; offline checks do not establish rendered visibility, physical movement or multiplayer behavior.

Storm redesign is implemented in the existing client controllers. Prioritize the Studio checklist in [STORM_SYSTEM.md](STORM_SYSTEM.md): inspect high soft cloud layers/native Clouds, four phase transitions, navigation visibility, directional rain, gust settings, delayed thunder and recovery. No new screenshot was accessible during implementation, and no visual approval is recorded. Configure StormWind, StormRain, Thunder and optional DistantThunder with permitted assets; empty slots are silent.

Hurricane and nearby earthquake fracture code is implemented and offline-tested. Prioritize [DISASTERS.md](DISASTERS.md): inspect the rotating smoke funnel, cave ceiling/house/floor seams, staged ground failure, shelter/causeway protection, brace deadlines, cleanup, rebasing and mobile budgets. The full and final-source logs are build/disaster-validation.log and build/disaster-final-validation.log.

## 0.5.0 Studio acceptance (bridges, expansion, queue card)

1. **Queue card.** Queue from the menu: the card must show a bright gold number, labels and a readable Cancel button. Check the menu card emoji (💎 and 🏆) and the tracker tags render.
2. **Sky Causeway.** Walk it both ways without jumping. Check:
   - plank gaps are visible, but feet never snag or fall through
   - handrail ropes follow the curve and don't block you
   - the sag reads as gentle, not a dip
   - posts sit on the deck ends
   - sway is subtle and stronger in storms and while you're on it
   - nothing jitters when the server collapses the bridge
3. **Sub-areas.** Cross every rope bridge to its sub-area in several realms:
   - check elevation joins at both ends, slopes and signposts
   - walk the Highlands ramp and climb the lookout truss, and the Wildwood treehouse ramp
   - the Cliffside house shelter works in a storm, including breaches
   - chart all cairns
4. **Content on sub-areas.** Lairs, plates, mirrors, mining veins and caches spawned there must stand on the surface; creatures should walk at the island height.
5. **Pacing.** With one player, time how many activities fit in a region's 240s; sub-areas warn before the core. Tune `RegionLifetime` or sub-area Edge if it's too generous or harsh.
6. **Performance.** About 5,000–5,900 parts per region. Profile server heartbeat with 9 resident regions, client streaming, memory and mobile FPS, and the client sway cost near long bridges.

## 0.4.1 Studio acceptance (menu, ocean, queue)

1. Open the place in Studio. Confirm no gray Baseplate remains: a template Baseplate is removed at server start, but delete it from the saved place too.
   - Press Play and check the menu over the orbiting sanctuary.
   - Check the composition on desktop, a tablet, and phone portrait and landscape in Device Emulator.
   - Check the title glow and scan bar, button hover and press, the card pages, and text readability against bright sky.
2. Watch the menu camera for one full orbit (about 140 seconds). It should never clip and the ocean should fill the horizon.
   - With Camera effects off, confirm the static shot.
3. Inspect the ocean:
   - Terrain water appearance and wave settings, and the seam between streamed water and the horizon surface (raise or lower `OceanSurface` color and offset if visible)
   - fog at the horizon
   - mountains, distant islands, waterfalls and sea stacks
4. Click BEGIN ASCENT. The card should appear at once and count 5, 4, 3, 2, 1, START with tick sounds.
   - The match should begin with a short fade showing the realm name and the camera returning to the character.
   - Try Cancel. Queue a second client during the countdown and confirm both start together.
   - Spam the button.
5. Jump off an island during a match: death at the water line, a splash, the notice, and the elimination flow.
   - Jump off the sanctuary in the lobby: respawn at the sanctuary after about 1.5 seconds.
   - Ride the elevator and use the portal: no false ocean deaths.
6. Verify that the engine-bundled `clickfast.wav` and `impact_water.mp3` cues exist and play at a sensible volume.
7. Profile Terrain water memory and mobile FPS with the menu vista and the ocean horizon. If streaming or memory needs it, reduce `OceanSize` or the vista islands.

## 0.4.0 Studio acceptance (realm adventures and visuals)

None of the following has been verified in Roblox Studio. The offline suites check logic and object state only.

1. **Sky per realm.** Visit at least Grasslands, Crystal, Volcanic, Frozen, Celestial and Void (use the elevator or temporarily lower `RegionRise` in a private copy).
   - Compare clock time, cloud cover and color, haze, bloom and sun rays, stars and moon size.
   - Check the cloud sea below the islands and that it turns violet as the wave nears.
   - Look for excessive bloom or route-hiding fog, and test with Detail off.
2. **Storm sequence.**
   - The shelf cloud should roll in during the 8s warning, followed by forked lightning, a thunder rumble and rain sheets.
   - Breaches should appear on house windows; patch one with E/X, board up the rest with V (Timber Brace).
   - Repair a generator (Storm or Mechanical realm) and confirm shelters heal and stay sealed.
   - Confirm the camera shake stays subtle and is off when the Camera setting is disabled or you are sheltered.
3. **Realm layout.**
   - Walk to each outskirts landmark and up its ramp to the viewpoint.
   - Check slope walkability, head clearance, landmark collisions and that no prop blocks the causeway or bridges.
   - Watch the outskirts warn and fall before the core.
4. **Every activity, solo, then with 2 players.**
   - Repair (windmill blades spin, mill stores), rescue escort to the beacon (survivor pathing and following speed), creature lair (telegraph readability, dash hits, Aegis reflect, spoils chest).
   - Plates (6s latch with dash), dials (mural readability, left-to-right order), mirrors (beam clarity), mining, ledge cache with Sky Leap, ring course (updraft lift reaches the pad; glide line through the rings), artifacts (carry and drop), timed vault (7s door; 10s overcharged; inside lever).
5. **Dynamic events.** Supply drop parachute, rare relic at the edge, roaming guardian HP with 1 and 2 players, lost traveler, secret vault, ancient machine. Confirm no event appears with too little region time left.
6. **Rewards.**
   - Coins and XP update leaderstats; the relic shrine blessing works; relics pay out at run end.
   - Perks take effect (second leap, shorter dash cooldown, +HP), achievements pop up, and locked cosmetics unlock in the shop.
   - Test persistence only in a private place with `StudioPersistence` enabled.
7. **Assets and interiors.** Inspect trees, ground cover, rocks, camps and the ten house styles (exterior and interior) for z-fighting, floating parts, wedge orientation (pines, gables, crystal tips, wings) and collision.
8. **Collectibles and pickup.**
   - The highlight follows the nearest prompt; the ghost lift, particles, floating text, feed and sound all play.
   - The built-in `rbxasset://sounds/*` cues exist and play at sensible volume. If not, set `AudioConfig.UseBuiltinCues = false`.
9. **Power effects.** Dash trail and streaks, leap rings and landing dust, Aegis shell and shatter, glider wings and trails, overcharge orbit, heal and brace. Check them on other players' avatars, R6 and R15.
10. **HUD.**
    - Tracker readability and collapse on phone landscape and portrait, tablet, desktop and controller.
    - Feed placement above the touch controls; banner, achievement popup, cooldown sweeps and health bar.
11. **Performance.** Profile client FPS and memory on desktop and a mid-range phone across several resident regions.
    - Watch server heartbeat with 12 players fighting creatures during a storm, and network usage from creature and survivor `PivotTo` updates.
    - Confirm `StreamingMesh` imposters and detail culling work.

## Studio acceptance for the exploration slice

1. Open build/FloatingRealms.rbxlx in Roblox Studio and press F5. Check Output, queue through the 5-second countdown, and confirm arrival at Havenwood Reach.
2. Walk through village interiors, forest paths, grove and cave. Traverse the entire sky causeway without jumping or abilities. Inspect shore joins, rare massive islands, rails, avatar headroom and cave entrances with R6 and R15.
3. Use E, controller X, native touch prompts and the gold interaction button to gather timber, crystals and herbs. Verify each supply disappears for the collector, remains for another player, and cannot be farmed repeatedly. Check pack caps (12 timber / 8 crystals / 5 herbs), pickup feedback, foliage-obscured prompts and rejection over deleted ground. Repair the shortcut with three contributions of two timber. Confirm everyone can cross it. Collect each Sun/Leaf/Moon tablet with E/X, native touch or the gold button: it must disappear only for its collector and show [+] in the key pouch. At the labeled SEAL ALTAR use E/X for the next key, or 1/2/3 and the three key buttons. Verify missing keys are rejected, wrong order keeps keys and resets alignment, correct order opens the gate for everyone, and keys from a previous realm cannot open the next seal. Try separate players contributing different keys; also test the independent four-crystal unlock in a fresh round.
4. Ride the sky elevator, use the gate and walk upward in separate attempts. Confirm grounded altitude and adjacent-region activation, ahead generation, arrival floor support, and exactly-once end rewards. Eliminate/leave during elevator travel and confirm the character is released and the deck removed.
5. Remain for corruption: verify visible cracks precede collision loss by 14 seconds, sections fall over three seconds, buildings collapse with their floor, and protected exits survive the early phase. Check that interactions over deleted ground cannot be used.
6. Observe storm warning at 35 seconds: native cloud cover and high soft layers build, wind/light rain start and the countdown precedes exposure damage at 43 seconds. Heavy lasts until 51 seconds, then Extreme until 59; recovery eases weather for ten seconds without extending damage. Enter a house/cave: rain and gust motion stop and HUD says sheltered. Repeat with detail/camera disabled and low graphics settings. Check no solid cloud shape approaches/blocks the camera, fog leaves routes readable and lightning is distant. Test configured thunder delay and SFX mute. Watch the hurricane form beside the realm during strong storm activity and disperse through recovery; repeat from different camera directions and from shelter. At round time 91 observe the quake warning, then at 99 inspect nearby crooked ground seams, house floors/walls and cave ceiling undersides. Ground must remain solid for 14 seconds before falling; refuge surfaces show cracks while shelter protection persists. Repeat with timber braces, different regions, rebasing and detail off. Observe alternate bridge collapse and deletion surge.
7. Run two clients, then twelve if available. Test simultaneous resource deposits, shared puzzle progress, late join, disconnected riders, spectating, queue/reset and different region positions. Rebase under simulated latency; check cracks, elevator endpoints, cameras and logical altitude.

## Content and release work

8. Test portable items: H / D-pad Up / Herb heals 40 HP without wasting herbs at full health; C / D-pad Right / Crystal strengthens new powers for 12 seconds; V / D-pad Left / Timber spends two to brace nearby ground for 18 seconds. Watch costs/cooldowns; the wave must still kill. Test the extended Gust Dash (1 second at 62 studs/second, 1.3 seconds while overcharged) on level ground, slopes, near walls and edges. Verify camera duration, five-second cooldown, and death/transit/reset cancellation. Test Sky Leap (Z/Y or a second jump), 60-damage Aegis and steerable/foldable Wind Sail. Combine dash with glide, test expiry/death/reset and test over simulated latency.
9. Review desktop, phone portrait/landscape, tablet and controller in Device Emulator. Check the health, item, seal-key and power controls, notifications and modal layering against Roblox safe insets and native controls. Visit all ten realms: verify realm labels, themed HUD accents, grass/crystal/snow/basalt/metal terrain, fuller trees and framed/furnished houses. Toggle detail and inspect scenery collapse. Confirm E/X prompts do not trigger abilities; double jump is Z/Y, dash Q/R2.
10. Configure owned/licensed experience-permitted audio in src/shared/AudioConfig.luau. Empty slots are deliberately silent. Test music, danger crossfades, biome beds, wildlife, jump/land, discovery, collapse, storm, quake and deletion cues in a private place.
11. Partly addressed in 0.4.0 (outskirts landmarks, realm activity pools, architecture and flora). Still open: authored terrain beyond the shared village/grove/cave escape template and Studio-reviewed art passes. Add deeper caves, optional climbing/discovery routes, navigation landmarks and puzzles after the first traversal review.
12. Test live persistence and session contention in an isolated private test experience. Keep StudioPersistence false for ordinary local tests. Profile instance count, streaming latency, server frame time, memory and mobile FPS with twelve players before tuning budgets or expanding art.
13. Run tools/check.ps1 after fixes and update DEVELOPMENT.md/TESTING.md. Publish only after the private acceptance pass; no public release has occurred.

## Autonomous continuation

Continue from the existing exploration systems. Do not restore the old helix or mandatory rune loop. Runtime acceptance requires Studio; offline fixtures cannot supply that evidence. Use the documented asset slots rather than inventing IDs.
