--!nonstrict
-- Realm enemy ecology: populates each region with its realm's common creatures (scaled by
-- player count and realm depth), elites guarding satellite sub-areas, and a seeded rare
-- encounter that becomes more likely in later realms. Spawns stay on open terrain, away from
-- the landing and rescue beacon, and only simulate while players are nearby.
local Bestiary = require(script.Parent.Bestiary)
local Creatures = require(script.Parent.Creatures)
local Random = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Random)
local Ecology = {}
Ecology.ActiveRadius = 260
local order = {
	"Grasslands",
	"Crystal",
	"Jungle",
	"Volcanic",
	"Frozen",
	"Ruins",
	"Storm",
	"Mechanical",
	"Celestial",
	"Void",
}
local depth = {}
for i, id in order do
	depth[id] = i - 1
end
local function safe(region, x, z)
	local beacon = region.Beacon - region.Center
	return math.sqrt(x * x + z * z) > 45 and math.sqrt((x - beacon.X) ^ 2 + (z - beacon.Z) ^ 2) > 25
end
function Ecology.populate(_svc, region, ctx, players)
	local roster = Bestiary.Realms[region.Biome.Id]
	if not roster or region.Ecology then
		return
	end
	local rng = Random.new((region.Seed or 0) + region.Index * 8111 + 3)
	local level = depth[region.Biome.Id] or 0
	local S = region.Sites
	local list = {}
	local function spawn(id, zones, elite)
		for _ = 1, 12 do
			local site = S:find(rng, 4, zones, 6)
			if site then
				table.remove(S.Circles) -- Creatures roam; do not block later placement.
				if safe(region, site.X, site.Z) then
					local c = Creatures.spawn(ctx, id, site.X, site.Z, elite)
					table.insert(list, c)
					return c
				end
			end
		end
		return nil
	end
	local core = { Mainland = true, Outskirts = true }
	local commons = math.min(6, 2 + math.floor(level / 3) + math.floor(math.max(0, (players or 1) - 1) / 2))
	for _ = 1, commons do
		spawn(roster.Common, core, false)
	end
	-- Elites guard the frontier sub-areas (fall back to the core when none exist).
	local elites = if level < 2 then 1 else 2
	local satellites = region.Satellites or {}
	for i = 1, elites do
		local sat = satellites[i]
		spawn(roster.Elite, if sat then { [sat.Kind] = true } else core, false)
	end
	if roster.Rare and rng:next() < 0.2 + level * 0.06 then
		local sat = satellites[#satellites]
		spawn(roster.Rare, if sat then { [sat.Kind] = true } else core, false)
	end
	region.Ecology = list
end
-- Simulates creatures near players; returns nothing. Rewards hitters on defeat.
function Ecology.update(svc, region, dt, now)
	local list = region.Ecology
	if not list then
		return
	end
	for i = #list, 1, -1 do
		local c = list[i]
		if c.State == "Gone" then
			table.remove(list, i)
		else
			local near = false
			for _, record in svc.Players:active() do
				local root = record.Player.Character
					and record.Player.Character:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - Creatures.world(c)).Magnitude < Ecology.ActiveRadius then
					near = true
					break
				end
			end
			if near or c.State == "Dying" then
				local result = Creatures.update(svc, c, dt, now)
				if result == "Defeated" then
					local reward = Bestiary.Rewards[c.Def.Tier] or Bestiary.Rewards.Common
					for record in c.Hitters do
						if record.State == "Alive" then
							svc:reward(record, reward, c.Def.Name)
						end
					end
					svc:achieve(c.Hitters, "Hunter")
					svc:catalog(c.Hitters, c.Kind)
					if c.Def.Tier == "Rare" then
						svc:achieve(c.Hitters, "Bossbane")
					end
				end
			end
		end
	end
end
function Ecology.cleanup(region)
	for _, c in region.Ecology or {} do
		Creatures.remove(c)
	end
	region.Ecology = nil
end
return Ecology
