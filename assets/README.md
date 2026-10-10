# Asset configuration

The current world, structures, cosmetics and effects use native Roblox geometry and built-in particle textures. No external model dependencies.

Version 0.3.0 adds seeded ground cover/realm flora, layered tree crowns and branches, framed houses with glowing windows/chimneys/furnishings, log/herb/crystal supplies, shield/glider visuals and approaching storm clouds/lightning. RealmAssets owns optional scenery; ExplorationGenerator owns traversable surfaces and resource models. These are editable procedural parts, not imported art packs. Review their appearance and cost in Studio before expanding the density.

Audio is deliberately silent until approved assets are provided. Configure `src/shared/AudioConfig.luau` with `rbxassetid://<permitted-id>` strings for:

- Music: looping fantasy ascent track.
- Danger: looping danger layer matched to the main track.
- Jump, Land, Collapse, Deletion, Ability: one-shots.
- Biomes: ten looping ambient recordings, keyed by biome ID.
- BiomeMusic: optional music overrides keyed by biome ID, falling back to Music.
- Wildlife: looping birds/insect layer, reduced during dangerous events.
- Discovery, Storm, Earthquake: interaction and event cues. StructureCollapse uses Collapse; DeletionSurge uses Deletion.
- StormWind and StormRain: looping storm beds; wind follows gust intensity and both attenuate under shelter.
- Thunder: one-shot lightning thunder, delayed by estimated travel distance. If empty, uses Storm when configured. Optional DistantThunder plays more quietly during buildup; all slots remain silent until configured.

Upload original or licensed recordings through the Creator Dashboard, grant this experience permission, and test load/playback in a published private test place. Do not use arbitrary public IDs. No numeric audio IDs have been invented.

The audio controller crossfades danger according to deletion distance, local stability and active events, changes music/ambience by biome, limits one-shots to eight reusable spatial sources, and exposes independent music/SFX mute controls. Jump/land hooks follow the Humanoid; cell collapse positions and discovery cues come from server effects. Permission errors, synchronization and musical timing need real assets in Studio. Wildlife is an audio layer; no simulated animal NPCs are implemented.
