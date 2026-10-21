--!nonstrict
-- Shared objective metadata: activity hints, rewards, run perks and achievements.
local Objectives = {}
Objectives.Main = "Climb onward: walk the sky causeway, board the Sky Balloon, or open the cave seal."
Objectives.Hints = {
	Repair = "Bring supplies to the broken machine. Anyone can contribute.",
	Rescue = "Find the stranded survivor, then lead them to the rescue beacon at the causeway.",
	Hunt = "Gust Dash through creatures (or drop onto them) to strike. Watch for glowing wind-ups.",
	Plates = "Stand on every plate. Plates stay pressed briefly: dash between them, or bring friends.",
	Dials = "Rotate each dial to match the symbols carved on the nearby mural.",
	Beams = "Rotate the mirrors until the light reaches the receiver.",
	Mining = "Strike each crystal vein several times. Friends mine faster.",
	Cache = "A cache is hidden somewhere dangerous. Sky Leap, glide or brave the storm.",
	Rings = "Climb the launch tower, open Wind Sail and fly through every ring in order.",
	Artifacts = "Carry each artifact to the pedestal. Dropped artifacts return home.",
	Gate = "Pull the lever, then reach the vault before the door slams shut.",
	Survey = "Cross the rope bridges and chart the cairn on every frontier sub-area.",
	Flock = "Talk to the Lost Shepherd, find his three sheep and escort the flock to the rescue beacon. Keep creatures away: a hit scatters a sheep.",
}
-- Coins/XP granted to each participant on completion; Major activities pay more.
Objectives.Rewards = {
	Repair = { Coins = 20, XP = 40, Perk = true },
	Rescue = { Coins = 30, XP = 60, Perk = true },
	Hunt = { Coins = 18, XP = 45, Relic = 1 },
	Plates = { Coins = 16, XP = 35, Relic = 1 },
	Dials = { Coins = 16, XP = 35, Relic = 1 },
	Beams = { Coins = 18, XP = 40, Relic = 1 },
	Mining = { Coins = 12, XP = 30, Crystal = 2 },
	Cache = { Coins = 22, XP = 30, Relic = 1, Perk = true },
	Rings = { Coins = 18, XP = 45, Perk = true },
	Artifacts = { Coins = 24, XP = 50, Relic = 1 },
	Gate = { Coins = 20, XP = 40, Relic = 1 },
	Survey = { Coins = 20, XP = 50, Relic = 1, Perk = true },
	Flock = { Coins = 40, XP = 80, Perk = true },
}
Objectives.Perks = {
	Gale = { Name = "Gale Anklet", Text = "Gust Dash cooldown -25%" },
	Feather = { Name = "Feather Cloak", Text = "Sky Leap twice per jump" },
	AegisCore = { Name = "Aegis Core", Text = "Aegis absorbs +30 damage" },
	Silk = { Name = "Silk Sail", Text = "Wind Sail lasts +2s" },
	Heart = { Name = "Heartstone", Text = "+25 maximum health" },
	Pack = { Name = "Explorer's Pack", Text = "+3 capacity for every supply" },
	Compass = { Name = "Relic Compass", Text = "Reveals hidden caches" },
}
Objectives.PerkOrder = { "Gale", "Feather", "AegisCore", "Silk", "Heart", "Pack", "Compass" }
Objectives.RelicCap = 9
Objectives.RelicBlessing = 2 -- Relics offered at a realm shrine for a random perk.
Objectives.RelicValue = { Coins = 6, XP = 15 } -- Unspent relics pay out when the run ends.
Objectives.Achievements = {
	Rescuer = { Name = "Sky Rescuer", Text = "Rescue a stranded survivor" },
	Puzzler = { Name = "Rite Breaker", Text = "Solve a realm puzzle" },
	Hunter = { Name = "Creature Hunter", Text = "Defeat a realm creature" },
	Bossbane = { Name = "Guardian's Bane", Text = "Defeat a roaming guardian", Unlock = "mantle" },
	Treasure = { Name = "Treasure Seeker", Text = "Open five caches in one ascent", Unlock = "halo" },
	Keeper = {
		Name = "Storm Keeper",
		Text = "Patch three shelter breaches in one ascent",
		Unlock = "stormtrail",
	},
	Daredevil = { Name = "Daredevil", Text = "Claim a rare relic before it vanishes", Secret = true },
	Engineer = { Name = "Engineer", Text = "Finish a cooperative repair" },
	Completionist = {
		Name = "Realm Completionist",
		Text = "Finish every activity in one region",
		Secret = true,
	},
	Dragonbane = { Name = "Dragonbane", Text = "Repel the Realm Destroyer" },
}
Objectives.EventText = {
	SupplyDrop = "A supply crate is falling from the sky!",
	RareRelic = "A rare relic shimmers near the edge. It will not last!",
	Boss = "A roaming guardian has entered the realm!",
	LostTraveler = "A lost traveler is calling for help!",
	SecretVault = "Rumbling stone: a secret vault opened in the cave!",
	AncientMachine = "The forgotten shrine hums with power. Touch it soon!",
}
return table.freeze(Objectives)
