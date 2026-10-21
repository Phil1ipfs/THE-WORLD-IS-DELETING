--!nonstrict
-- The Realm Destroyer: a recurring world boss that burns the floating realms.
-- Pure data plus deterministic region staging, shared by the server director and the client.
-- Stages follow the existing realm order (BiomeConfig.List), one realm band per 320 studs:
--   Realm 1 (Sky Grasslands)  Omen       distant silhouette and roars, never attacks
--   Realm 2 (Crystal Kingdom) Raid       flies over and burns distant ground away from players
--   Realm 3 (Floating Jungle) Encounter  first fight-or-escape battle in the realm's first region
--   Later realms              Encounter  in each realm's first region (higher tier), raids elsewhere
-- Pure Luau (no Roblox globals): callers pass GameConfig.RegionRise.
local Dragon = {}
Dragon.Id = "RealmDestroyer"
Dragon.Name = "Realm Destroyer"
Dragon.BandHeight = 320 -- Must match BiomeConfig.at.
-- Realm band (0-based, unbounded) of a region index.
function Dragon.band(index: number, rise: number): number
	return math.floor(math.max(0, index) * rise / Dragon.BandHeight)
end
-- Encounter tier for a realm band (Jungle = 1 ... Celestial/Void and beyond = 4).
function Dragon.tier(band: number): number
	if band <= 2 then
		return 1
	elseif band <= 4 then
		return 2
	elseif band <= 7 then
		return 3
	end
	return 4
end
-- Stage of a region: "Omen", "Raid" or "Encounter", plus the tier for raids and encounters.
-- preview (Studio only, see Dragon.Preview): the first island is a tier-1 battle and the
-- next two are raided, so the full dragon can be tested without climbing five regions.
function Dragon.stage(index: number, rise: number, preview: boolean?): (string, number)
	if preview and index == 0 then
		return "Encounter", 1
	elseif preview and index <= 2 then
		return "Raid", 1
	end
	local band = Dragon.band(index, rise)
	if band == 0 then
		return "Omen", 0
	elseif band == 1 then
		return "Raid", 1
	end
	local first = index == 0 or Dragon.band(index - 1, rise) < band
	return if first then "Encounter" else "Raid", Dragon.tier(band)
end
Dragon.Omen = {
	Radius = 640, -- Orbit radius around the frontier region (a silhouette, never a threat).
	Height = 240,
	Speed = 42,
	RoarMin = 32,
	RoarMax = 52,
}
Dragon.Raid = {
	First = 24, -- Seconds after a region activates before the first raid.
	IntervalMin = 55,
	IntervalMax = 75,
	MaxPerRegion = 3,
	Height = 90, -- Pass altitude above the region.
	Speed = 70,
	SafeDistance = 75, -- Burned ground is always at least this far from every player.
	Telegraph = 2.6, -- Marked ground glows before the strike.
	Cells = { 2, 3, 4, 5 }, -- Cells burned per strike by tier (index 1 = Crystal raids).
	BurnDamage = 6, -- Per second while standing in the flames left behind.
}
Dragon.EncounterDelay = 20 -- Seconds after the encounter region activates.
Dragon.RaidPauseAfterEncounter = 40
Dragon.Tiers = {
	{
		HP = 150,
		Damage = 1,
		Telegraph = 1,
		Cadence = 1,
		Destruction = 1,
		RazeAfter = 150,
		Attacks = { "FireBreath", "Dive", "WingGust", "GroundSlam" },
	},
	{
		HP = 210,
		Damage = 1.15,
		Telegraph = 0.92,
		Cadence = 0.9,
		Destruction = 2,
		RazeAfter = 145,
		Attacks = { "FireBreath", "Dive", "EmberRain", "WingGust", "GroundSlam" },
	},
	{
		HP = 280,
		Damage = 1.3,
		Telegraph = 0.86,
		Cadence = 0.8,
		Destruction = 3,
		RazeAfter = 140,
		Attacks = { "InfernoSweep", "Dive", "EmberRain", "WingGust", "FireBreath", "GroundSlam" },
	},
	{
		HP = 360,
		Damage = 1.45,
		Telegraph = 0.8,
		Cadence = 0.7,
		Destruction = 4,
		RazeAfter = 135,
		Attacks = { "InfernoSweep", "Dive", "EmberRain", "WingGust", "FireBreath", "GroundSlam" },
	},
}
Dragon.PlayerScaling = 0.55 -- Extra HP fraction per additional fighter (up to MaxScaledPlayers).
Dragon.MaxScaledPlayers = 6
Dragon.MinTelegraph = 1.1 -- No wind-up is ever shorter than this, at any tier.
-- Attack timings (seconds, before tier Telegraph scaling of Windup) and base damage.
-- Exposes: weak point that glows (and takes full damage) during Windup/Active/Recover.
Dragon.Attacks = {
	FireBreath = {
		Windup = 1.7,
		Active = 2.0,
		Recover = 2.6,
		Length = 62,
		HalfAngle = math.rad(22),
		Tick = 0.5,
		Damage = 7,
		Exposes = "Heart",
		Label = "Fire Breath",
	},
	Dive = {
		Climb = 1.2,
		Windup = 1.9,
		Active = 0.6,
		Recover = 3.6,
		Radius = 14,
		Shockwave = 26,
		Damage = 28,
		ShockDamage = 12,
		Exposes = "Head",
		Label = "Dive",
	},
	WingGust = {
		Windup = 1.5,
		Active = 0.8,
		Recover = 2.2,
		Width = 26,
		Length = 78,
		Push = 82,
		Lift = 26,
		Damage = 6,
		Exposes = "Wings",
		Label = "Wing Gust",
	},
	GroundSlam = {
		Windup = 1.9,
		Active = 1.2,
		Recover = 4.0,
		Crush = 11,
		Radius = 40,
		Damage = 30,
		ShockDamage = 16,
		Exposes = "Wings",
		Label = "Ground Slam",
	},
	EmberRain = {
		Windup = 1.9,
		Active = 0.6,
		Recover = 2.2,
		Radius = 9,
		Count = 5,
		Damage = 18,
		Exposes = "Heart",
		Label = "Ember Rain",
	},
	InfernoSweep = {
		Windup = 1.9,
		Active = 2.4,
		Recover = 2.6,
		Length = 60,
		Arc = math.rad(100),
		Width = math.rad(13),
		Tick = 0.4,
		Damage = 8,
		Exposes = "Heart",
		Label = "Inferno Sweep",
	},
}
Dragon.Orbit = { Min = 2.6, Max = 4.0, Radius = 62, Height = 58 }
Dragon.Burning = { Duration = 3, Damage = 4 } -- Damage over time after touching dragon fire.
Dragon.FirePatch = { Radius = 6, Lifetime = 8, Damage = 6, Max = 10 }
-- Dragonbane weapons. Players cannot defeat the dragon with ordinary dashes alone.
Dragon.Weapons = {
	Crossbow = {
		Name = "Dragonbane Crossbow",
		Craft = { Timber = 2, Crystal = 1 },
		Bolts = 20,
		Fletch = { Timber = 1 },
		FletchBolts = 12,
		MaxBolts = 40,
		Cooldown = 0.9,
		Range = 230,
		Damage = 4,
		Glance = 0, -- Bolts skip off unexposed scales.
		AimCone = math.rad(14), -- Server aim assist around the player's aim direction.
	},
	Ballista = {
		Name = "Repairable Ballista",
		Repair = 4, -- Shared timber, contributed 2 at a time.
		Mend = 2, -- Timber to fix it again after the dragon smashes it.
		Cooldown = 6,
		Range = 260,
		Damage = 14,
		Glance = 3,
		BreakRadius = 18,
	},
	Cannon = {
		Name = "Crystal Cannon",
		Crystal = 1, -- Per shot, from the firing player's pack.
		Cooldown = 7,
		Range = 260,
		Damage = 22,
		Glance = 8,
	},
	-- Heavy thrown spear from the Harpoon Rack beside each forge. Hits harder than bolts, pierces
	-- unexposed scales a little, and a hit on an exposed weak point pins it open for longer.
	Harpoon = {
		Name = "Dragonbane Harpoon",
		Craft = { Timber = 3, Crystal = 1 },
		Count = 3,
		Refill = { Timber = 1 },
		RefillCount = 2,
		Max = 6,
		Cooldown = 2.4,
		Range = 150,
		Damage = 11,
		Glance = 2,
		Pin = 1.6, -- Seconds added to the current weak-point window (once per window).
		AimCone = math.rad(18),
	},
	Dash = { Damage = 3, Boosted = 5 }, -- Gust Dash into the stunned head only.
}
-- Rewards for repelling the dragon (participants who dealt damage and are alive).
Dragon.Rewards = {
	Coins = { 75, 100, 125, 150 },
	XP = { 150, 200, 250, 300 },
	Relic = 2,
	Scales = { 9, 12, 15, 18 }, -- Persistent Dragon Scales.
	EmberheartChance = { 0.4, 1, 1, 1 }, -- Persistent rare Emberheart Shard.
	TrophyCooldown = 900, -- Real seconds between full trophy rewards per player (anti-farming).
	ReducedFactor = 0.5, -- Coins/XP while trophies are recharging; no scales, shards or rolls.
	Cosmetic = "dragonwing",
	CosmeticChance = 0.2,
	CosmeticPity = 5, -- Guaranteed on the fifth full reward without a drop.
	CraftCost = { DragonScales = 40, Emberhearts = 2 }, -- Deterministic boutique alternative.
}
-- Persistent bestiary discovery stages for the Realm Destroyer (profile.Bestiary.RealmDestroyer).
Dragon.Discovery = { "Sighted from afar", "Survived a raid", "Faced in battle", "Repelled" }
Dragon.Bestiary = {
	Name = "Realm Destroyer",
	Category = "World Boss · Elder Sky Dragon",
	Rarity = "Mythic",
	Lore = "A colossal red dragon that burns the floating realms out of the sky. It returns, angrier, as you climb.",
	Realms = {
		"Sky Grasslands: a distant silhouette and roars",
		"Crystal Kingdom: raids that burn distant ground",
		"Floating Jungle: first battle (fight or escape)",
		"Volcanic Realm onward: stronger battles in every realm's first region",
	},
	Abilities = {
		"Fire Breath: wide cone that leaves burning ground",
		"Dive: marks an area, dives and sends a shockwave",
		"Wing Gust: blasts players back; hide behind cover",
		"Ground Slam: lands and sends a radial shockwave; jump it",
		"Ember Rain (Volcanic onward): marked fireballs",
		"Inferno Sweep (Ancient Ruins onward): sweeping breath",
	},
	WeakPoints = {
		"Heart: glows while it breathes fire and after Ember Rain",
		"Wings: exposed during Wing Gust and while landed",
		"Head: exposed while stunned after a dive (Gust Dash works too)",
		"Dragonbane Harpoons pin an exposed weak point open for longer",
	},
	RewardText = {
		"Coins, XP and relics",
		"Dragon Scales and Emberheart Shards (once per 15 minutes)",
		"Dragonbane achievement",
		"Chance at the Dragonwing Mantle",
	},
}
return Dragon
