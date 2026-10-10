--!nonstrict
-- Populate with audio owned by/permitted for this experience. Empty IDs remain silent.
return {
	Music = "",
	Danger = "",
	Jump = "",
	Land = "",
	Collapse = "",
	Deletion = "",
	Ability = "",
	Discovery = "",
	Storm = "",
	StormWind = "", -- Looped wind bed; permissioned asset required.
	StormRain = "", -- Looped rain bed; permissioned asset required.
	Thunder = "", -- Delayed lightning strike; may fall back to Storm.
	DistantThunder = "", -- Optional quieter approaching-storm cue.
	Earthquake = "",
	Wildlife = "",
	-- Feedback cues. Empty slots fall back to the engine-bundled sounds in Builtin below.
	Pickup = "",
	Dash = "",
	Leap = "",
	Shield = "",
	ShieldBreak = "",
	Glide = "",
	Heal = "",
	Overcharge = "",
	Brace = "",
	Hit = "",
	Chest = "",
	Complete = "",
	Tick = "",
	Start = "",
	Splash = "",
	-- Engine-bundled (rbxasset://) sounds ship with the Roblox client; set UseBuiltinCues = false
	-- to keep cues silent until permissioned assets are configured. Verify each in Studio.
	UseBuiltinCues = true,
	Builtin = {
		Pickup = { "rbxasset://sounds/electronicpingshort.wav", 1.25, 0.35 },
		Dash = { "rbxasset://sounds/swoosh.wav", 1.1, 0.45 },
		Leap = { "rbxasset://sounds/swoosh.wav", 0.8, 0.4 },
		Shield = { "rbxasset://sounds/electronicpingshort.wav", 0.7, 0.35 },
		ShieldBreak = { "rbxasset://sounds/snap.wav", 0.8, 0.45 },
		Glide = { "rbxasset://sounds/swoosh.wav", 0.65, 0.3 },
		Heal = { "rbxasset://sounds/electronicpingshort.wav", 1.5, 0.3 },
		Overcharge = { "rbxasset://sounds/electronicpingshort.wav", 0.55, 0.4 },
		Brace = { "rbxasset://sounds/snap.wav", 0.6, 0.45 },
		Hit = { "rbxasset://sounds/snap.wav", 1.1, 0.4 },
		Chest = { "rbxasset://sounds/electronicpingshort.wav", 1.05, 0.45 },
		Complete = { "rbxasset://sounds/electronicpingshort.wav", 0.9, 0.5 },
		Tick = { "rbxasset://sounds/clickfast.wav", 1, 0.45 },
		Start = { "rbxasset://sounds/electronicpingshort.wav", 1.3, 0.55 },
		Splash = { "rbxasset://sounds/impact_water.mp3", 1, 0.6 },
	},
	BiomeMusic = {}, -- Optional biome overrides; falls back to Music.
	Biomes = {
		Grasslands = "",
		Crystal = "",
		Jungle = "",
		Volcanic = "",
		Frozen = "",
		Ruins = "",
		Storm = "",
		Mechanical = "",
		Celestial = "",
		Void = "",
	},
}
