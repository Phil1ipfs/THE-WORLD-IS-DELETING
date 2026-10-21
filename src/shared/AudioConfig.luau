--!nonstrict
-- Optional overrides: paste "rbxassetid://<id>" for audio owned by or permitted for this
-- experience. An empty slot plays the designed SoundBank cue of the same name, built from
-- sounds bundled with the Roblox client (no asset IDs are invented). Music has no designed
-- substitute and stays silent until a permissioned track is set.
return {
	Music = "",
	Danger = "", -- Looped low drone bed.
	Wildlife = "", -- Looped; no designed substitute (silent until set).
	-- Movement, powers and supplies.
	Jump = "",
	Land = "",
	Dash = "",
	Leap = "",
	Glide = "",
	Shield = "",
	ShieldBreak = "",
	Ability = "",
	Pickup = "",
	Heal = "",
	Overcharge = "",
	Brace = "",
	Hit = "",
	Chest = "",
	Complete = "",
	Discovery = "",
	Tick = "",
	Start = "",
	Splash = "",
	SheepBleat = "",
	-- World, storms and disasters.
	Collapse = "",
	Deletion = "",
	Storm = "",
	StormWind = "", -- Looped wind bed.
	StormRain = "", -- Looped rain bed.
	Thunder = "",
	DistantThunder = "",
	Earthquake = "",
	-- Realm Destroyer.
	DragonRoar = "",
	DragonFire = "", -- Looped breath.
	DragonWings = "",
	DragonGust = "",
	DragonImpact = "",
	DragonHurt = "",
	-- Dragonbane weapons.
	DragonbaneShot = "",
	HarpoonThrow = "",
	BallistaFire = "",
	CannonFire = "",
	WeakPointHit = "",
	ForgeCraft = "",
	-- Sky Balloon.
	BalloonBurner = "",
	BalloonDepart = "",
	BalloonArrive = "",
	-- Set false to silence every designed cue (only configured IDs then play).
	UseBuiltinCues = true,
	BiomeMusic = {}, -- Optional biome overrides; falls back to Music.
	Biomes = { -- Optional per-biome ambience; empty uses the designed air bed.
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
