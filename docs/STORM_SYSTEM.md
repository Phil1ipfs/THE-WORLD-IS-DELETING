# Atmospheric storm redesign

Implemented 2026-10-10 in the existing Rojo project. This is source/object-state evidence, not a rendered art approval. The new request did not include an accessible screenshot attachment; the workspace and Codex attachment directory contained no matching image. The reported appearance was investigated against the actual renderer before editing.

The later hurricane/earthquake extension is documented in [DISASTERS.md](DISASTERS.md). HurricaneController now adds a pooled world-anchored smoke funnel during strong storms, and quake ground/surface cracks use the shared destruction system. Storm exposure timing and shelter behavior remain unchanged.

## Cause and replacement

EnvironmentController.new previously created seven PartType.Ball storm objects, each roughly 90 by 24–36 by 70 studs. Its update moved the bank from 180 studs to 35 studs in front of the camera and only 38 studs above it, at 0.15 transparency. This combination produced solid, nearby spherical silhouettes and camera obstruction. The normal backdrop also used flattened spherical cloud Parts.

Both physical cloud constructions are removed. EnvironmentController now uses one native Clouds object under Terrain for the sky, plus three overlapping layers of smoke-texture particles. Their invisible, noncolliding emission anchors stay 240, 300 and 360 studs above the camera, including after coordinate rebasing. Layer sizes, texture rotations, opacity and drift speeds differ. Particles have soft alpha boundaries and flattened proportions; no visible cloud geometry is spherical. Their rendered appearance remains subject to Studio review.

Cloud cover, density and neutral gray/blue-gray color build gradually. GlobalWind drives the native clouds; the supplemental layers drift at different speeds. Lighting brightness/exposure, OutdoorAmbient, Atmosphere density/haze/decay and the existing color grade blend toward a darker, mildly desaturated scene. Atmosphere density is bounded at 0.4. Lightning uses six pooled thin Beams at a distance of at least 280 studs, with an 0.18-second bolt and a restrained nearby light/color flash. Camera settings disable flash illumination and gust shake.

This follows Roblox's [dynamic Clouds](https://create.roblox.com/docs/environment/clouds), [global wind](https://create.roblox.com/docs/environment/global-wind), [Atmosphere](https://create.roblox.com/docs/environment/atmosphere) and [ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter) APIs. Clouds is parented to the engine-provided Terrain; its native sky layer has no script-controlled altitude. The supplemental layers provide height-relative coverage in the rebased floating world.

## Existing gameplay timing

| Visual phase | Existing event state | Behavior |
| --- | --- | --- |
| Approaching | All 8 seconds of Warning | Cloud cover/darkness builds, wind/light rain begin, distant thunder is scheduled. Existing warning countdown stays. |
| Heavy | First 8 seconds of Active | Denser sky, stronger directional rain, wind and haze. Outdoor exposure damage remains active. |
| Extreme | Last 8 seconds of Active | Peak rain/cloud movement, intermittent gusts and lightning. Small gust camera motion; existing exposure damage continues. |
| Recovery | First 10 seconds after Active ends, within the existing 32-second Calm interval | Rain/wind/cloud intensity eases down and lighting/haze returns to the normal biome. No exposure damage. |

StormConfig derives targets from the existing Event/EventPhase/EventRemaining snapshot; late joins use the current timer. Exponential blending smooths snapshot steps. RoundNumber changes cancel the previous weather cycle and pending thunder. Returning to the sanctuary clears storm intensity, rain and gusts.

The original atmospheric renderer revision did not change server gameplay. The later disaster extension changes earthquake target selection and surface fractures while retaining storm gameplay. WorldEventDirector still warns at round time 35, activates at 43, ends at 59 and schedules the next event at 91. Exposure remains eight damage every two seconds; PlayerManager health/shield handling, ExplorationWorld house/cave shelter volumes and all altitude/round/progression systems remain intact. The HUD retains its timer and health display, with Heavy/Extreme/sheltered and clearing-sky text added by the client.

## Rain, wind and audio

Rain uses Roblox's installed SquareParticle texture, stretched into thin streaks and aligned with velocity. Wind acceleration slants falling droplets. Wind spray uses the built-in smoke texture at low opacity. Shelter immediately disables local rain/spray and clears existing particles; it also suppresses gust camera motion and attenuates wind/rain audio.

AudioController adds StormWind and StormRain loops and a bounded delayed thunder queue. Each lightning cue schedules thunder after distance / 343 seconds, clamped to 0.8–3 seconds. Approaching storms can also play quieter DistantThunder. Thunder falls back to the existing Storm slot if necessary. SFX mute applies to all of these sources. No audio asset IDs were invented: StormWind, StormRain, Thunder and DistantThunder need owned/licensed, experience-permitted configuration in AudioConfig before they can be heard. Sound playback and artistic synchronization remain unverified.

## Client budgets and acceptance

Weather uses the existing 20 Hz client Heartbeat. Gust motion is composed into the existing camera loop; no additional RenderStepped callback or server weather loop is added. Eight invisible weather effect anchors (including hurricane and quake dust), three cloud emitters, one rain emitter, one spray emitter, six pooled lightning Beams and seven attachments are reused. The eleven preexisting distant-island silhouettes remain; no cloud Parts remain in that backdrop.

High-detail emission caps: rain 80/second with maximum lifetime 0.55 seconds; cloud layers together under 24 estimated steady-state particles, plus at most six initial puffs; spray at most 12/second with a one-second lifetime. These are emission/lifetime budget calculations, not measured GPU performance. Low detail uses two active cloud layers, at most 24 rain particles/second, no spray and no bright nearby lightning light. Native sky and survival warnings remain present. Particle/UI navigation readability still needs a real device review.

All twelve offline storm cases pass: phase/timer continuity, no solid spheres, anchor clearance, transition/recovery state, atmosphere bounds, low-detail budgets, shelter suppression, lightning delay/pooling, rebase/round reset, thunder queue/mute, camera limits, HUD severity/health/void priority and unchanged server exposure scheduling. Existing exploration tests separately exercise real generated house/cave shelter volumes through analytic fixtures. The broader static/build/gameplay suite also passes; see TESTING.md and build/storm-validation.log plus the final storm-hud-validation.log. These tests cannot establish cloud silhouettes on screen, actual audio playback, Roblox physics, network streaming or FPS.

Required Studio review: inspect all four phases in desktop and phone portrait/landscape, at both detail settings and low Roblox graphics quality. Check the sky from ground level and upward-facing cameras, interior/cave shelter, every realm palette, rebase, elimination and new rounds. Confirm no nearby opaque cloud boundary crosses the camera; roads, exits and HUD must stay readable. Capture actual screenshots and profile GPU/frame time before calling the artwork or mobile performance verified.

## Files modified

- Production: src/client/Controllers/EnvironmentController.luau, AudioController.luau, CameraController.luau; src/client/Main.client.luau; src/client/UI/Interface.luau; src/shared/AudioConfig.luau.
- New production module: src/shared/StormConfig.luau.
- Verification: tools/OfflineHarness.luau, client.spec.luau, check.ps1; new tools/storm.spec.luau.
- Documentation: README.md, assets/README.md, docs/ARCHITECTURE.md, DEVELOPMENT.md, NEXT_STEPS.md, TESTING.md, CHANGELOG.md and this file.
- Generated locally: build/FloatingRealms.rbxlx, build/sourcemap.json and build/storm-validation.log.
