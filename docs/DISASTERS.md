# Hurricane and earthquake extension

Implemented 2026-10-10. Source and offline checks are complete; Roblox Studio visual, physics, network and device acceptance remain pending.

## Hurricane in storms

The existing EnvironmentController owns HurricaneController and updates it through the same 20 Hz weather loop. A 280-stud tapered vortex uses two rotating smoke-textured ribbon strands and seven soft wisp emitters on one invisible, noncolliding anchor. Its base sits beside the current realm, 215 studs outward from the island center, with a slow 32-stud lateral drift. Position derives from the replicated region index, event countdown and world origin. Looking or walking moves the camera independently of the funnel. Spectators use their viewed altitude.

The funnel gradually forms as the storm builds, strengthens during Heavy/Extreme, then disperses with the existing Recovery. Returning to the sanctuary or starting a new round clears it. Rebasing preserves its logical position and strength. The HUD identifies a hurricane during strong storms. Native Clouds, lightning, rain, adaptive wind, shelter and the eight-damage exposure ticks remain part of the same storm. The vortex is a weather visual using the existing storm hazard rules.

Geometry is pooled: one anchor, 42 ribbon attachments, 40 Beams, seven emitter attachments and seven emitters. High detail allows fewer than 30 steady-state wisp particles by rate/lifetime calculation; low detail enables 20 Beams and fewer than six wisps. There are no solid cloud spheres. The entire atmospheric root, including the eleven distant island silhouettes and quake dust anchor, has 19 BaseParts at initialization. These are source budgets, not measured GPU/FPS results.

## Earthquakes crack the occupied place

WorldEventDirector gathers occupied region positions once when Earthquake becomes Active. ExplorationWorld selects nearby intact, unprotected ground instead of the first outer tiles in generator order. Affected cells receive four crooked, dark surface seams and CrackCause=Earthquake. They remain collidable for the existing 14-second warning, then lose collision and fall/fade over three seconds with their attached structures. Seams follow the falling cell and coordinate rebases. Timber braces can extend the deadline.

Nearby village/cave floors and walls also receive surface fractures. Ceiling seams face downward toward occupants. Refuge surfaces retain shelter protection until their ordinary supporting floor is destroyed by corruption. These presentation seams follow their source and expire after 24 seconds. The landing and primary causeway stay protected from earthquake selection; alternate terrain and routes can fail.

Each occupied region receives at most 12 failing cells and six marked refuge/building surfaces. Shared limits of 36 cells and 18 surfaces are divided between occupied regions. With four seam Parts per surface this creates at most 216 earthquake seam Parts across the event. All seams are anchored, noncolliding, nonqueryable and cannot provide pickup/altitude support. Retired regions destroy them. Sparse client dust appears around grounded players during the active quake, with reduced indoor emission and no emission in transit/air or with detail disabled. Existing optional quake camera shake and configured Earthquake audio are reused.

## Files

- Added src/shared/DisasterConfig.luau, src/client/Controllers/HurricaneController.luau and src/server/Services/SeismicFractures.luau.
- Modified EnvironmentController, ExplorationWorld, WorldEventDirector, Main.server, Main.client and Interface.
- Added tools/disasters.spec.luau; modified tools/check.ps1 and tools/storm.spec.luau.
- Updated README and development, next-step, testing, architecture, storm and changelog documentation.
- Rebuilt build/FloatingRealms.rbxlx and build/sourcemap.json.

## Verification and next checks

The complete suite and synthetic 50-minute endurance pass in build/disaster-validation.log: 73 regions generated, peak six resident, seven rebases. The final cave-ceiling face correction then passed formatting, zero-error/warning lint, shared analysis, all-source compilation, build/sourcemap, ten disaster cases, twelve storm cases and actual server bootstrap in build/disaster-final-validation.log. The world lifecycle algorithm was unchanged by that face correction.

Ten disaster cases inspect taper/rotation/textures, world anchoring, recovery, reset/rebase, low-detail and shelter budgets, grounded dust, nearby house/ground fractures, delayed collision loss, protected causeways/shelter, seam cleanup/source following, brace deadlines, nine-region/twelve-player work caps, hurricane/quake HUD and void-warning priority, and cave ceiling orientation. Fixtures do not render particles or simulate Humanoids/networking.

In Studio, inspect the funnel from the village, cave entrance, grove, causeway and higher realms at low/high detail. Confirm navigation and UI remain readable while it forms/disperses, and compare views in two clients. Observe the quake warning at round time 91 and activity at 99: floor/wall/ceiling seams must appear near players, ground must remain solid until its warning expires, and houses/caves must still protect against storm exposure. Check destruction, brace timing, death/transit, region retirement, rebasing and Device Emulator. Profile the listed maximum budgets with twelve clients before calling performance verified. Audio requires experience-permitted IDs in the existing AudioConfig slots; none were invented.
