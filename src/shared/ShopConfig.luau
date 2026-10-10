--!strict
-- Unlock-only cosmetics cannot be bought; their achievement grants ownership.
return {
	{ Id = "azure", Name = "Azure Ribbon", Kind = "Trail", Price = 60, Color = { 80, 200, 255 } },
	{ Id = "ember", Name = "Ember Ribbon", Kind = "Trail", Price = 100, Color = { 255, 140, 65 } },
	{ Id = "aura", Name = "Starlight Aura", Kind = "Effect", Price = 150, Color = { 180, 140, 255 } },
	{ Id = "wave", Name = "Sky Salute", Kind = "Emote", Price = 40, Color = { 255, 215, 120 } },
	{ Id = "royal", Name = "Royal Silhouette", Kind = "Skin", Price = 200, Color = { 210, 160, 255 } },
	{
		Id = "halo",
		Name = "Relic Halo",
		Kind = "Effect",
		Price = 0,
		Unlock = "Treasure",
		Color = { 255, 214, 120 },
	},
	{
		Id = "stormtrail",
		Name = "Stormcaller Ribbon",
		Kind = "Trail",
		Price = 0,
		Unlock = "Keeper",
		Color = { 170, 190, 255 },
	},
	{
		Id = "mantle",
		Name = "Guardian's Mantle",
		Kind = "Skin",
		Price = 0,
		Unlock = "Bossbane",
		Color = { 120, 255, 200 },
	},
}
