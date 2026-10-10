--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Route = require(Shared.Route)
local RNG = require(Shared.Random)
local Biomes = require(Shared.BiomeConfig)
local G = require(script.Parent.Parent.Services.Geometry)
local IslandGenerator = {}

function IslandGenerator.build(parent, index, origin, seed)
	local rng = RNG.new(seed + index * 7919)
	local first = index * Config.StepsPerIsland
	assert(Route.validate(first, first + Config.StepsPerIsland, Config), "Unreachable route")
	local point = Route.point(first, Config)
	local biome, nextBiome, blend = Biomes.at(point.Y - Config.StartY)
	local top = G.color(biome.Top):Lerp(G.color(nextBiome.Top), blend)
	local rock, accent = G.color(biome.Rock), G.color(biome.Accent)
	local model = Instance.new("Model")
	model.Name = "Realm_" .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Index", index)
	model:SetAttribute("LogicalY", point.Y)
	model:SetAttribute("Biome", biome.Id)
	model.Parent = parent
	local center = Vector3.new(point.X, point.Y - origin, point.Z)
	-- Always retain a generous, clear landing pad. Decorations occupy the outward terrace.
	local landing = G.part(
		model,
		"Landing",
		Vector3.new(Config.PlatformWidth, 2, Config.PlatformWidth),
		CFrame.new(center - Vector3.new(0, 1, 0)),
		top,
		Enum.Material.Grass
	)
	landing:SetAttribute("Step", first)
	local outward = Vector3.new(point.X, 0, point.Z).Unit
	local terraceCenter = center + outward * 28 - Vector3.new(0, 1.5, 0)
	for i = 1, 3 do
		G.part(
			model,
			"TerraceAccess",
			Vector3.new(7, 1, 7),
			CFrame.new(center + outward * (i * 7) - Vector3.new(0, 0.5, 0)),
			top,
			Enum.Material.Slate
		)
	end
	for lobe = 1, 5 do
		local theta = lobe * math.pi * 2 / 5 + rng:range(-0.25, 0.25)
		local pos = terraceCenter
			+ Vector3.new(math.sin(theta) * 7, rng:range(-0.6, 0.2), math.cos(theta) * 7)
		local size = Vector3.new(rng:range(12, 18), 3, rng:range(12, 18))
		local part = G.part(
			model,
			"OrganicTerrace",
			size,
			CFrame.new(pos) * CFrame.Angles(0, theta, 0),
			top,
			Enum.Material.Grass
		)
		part.Shape = Enum.PartType.Block
	end
	for layer = 1, 4 do
		local width = 27 - layer * 4
		G.part(
			model,
			"RockFoundation",
			Vector3.new(width, 5, width * 0.8),
			CFrame.new(terraceCenter - Vector3.new(0, layer * 4, 0))
				* CFrame.Angles(0.1 * layer, rng:range(-1, 1), 0.12),
			rock,
			Enum.Material.Slate,
			false
		)
	end
	for n = 1, 7 do
		local pos = terraceCenter + Vector3.new(rng:range(-9, 9), 2.5, rng:range(-9, 9))
		if biome.Decor == "Tree" then
			G.part(
				model,
				"Trunk",
				Vector3.new(1.1, 7, 1.1),
				CFrame.new(pos + Vector3.new(0, 3, 0)),
				Color3.fromRGB(104, 77, 71),
				Enum.Material.Wood,
				false
			)
			local crown = G.part(
				model,
				"Canopy",
				Vector3.new(6, 7, 6),
				CFrame.new(pos + Vector3.new(0, 8, 0)),
				top:Lerp(accent, n / 18),
				Enum.Material.Grass,
				false
			)
			crown.Shape = Enum.PartType.Ball
		elseif biome.Decor == "Ruin" or biome.Decor == "Gear" then
			G.part(
				model,
				"Pillar",
				Vector3.new(2, rng:range(5, 11), 2),
				CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, n, 0.1),
				rock:Lerp(accent, 0.25),
				Enum.Material.Marble,
				false
			)
		else
			G.glow(model, pos + Vector3.new(0, 2, 0), accent, rng:range(1, 2))
		end
		G.part(
			model,
			"Flower",
			Vector3.new(0.7, 0.5, 0.7),
			CFrame.new(pos + Vector3.new(2, 0, 1)),
			accent,
			Enum.Material.Neon,
			false
		)
	end
	-- The mandatory route is immutable and ability-independent. Challenges are side routes.
	for step = first + 1, first + Config.StepsPerIsland - 1 do
		local p = Route.point(step, Config)
		local width = Config.PlatformWidth
		local platform = G.part(
			model,
			"Path_" .. step,
			Vector3.new(width, 1.4, width),
			CFrame.new(p.X, p.Y - origin - 0.7, p.Z),
			top,
			Enum.Material.Slate
		)
		platform:SetAttribute("Step", step)
		G.part(
			model,
			"PathRune",
			Vector3.new(2, 0.08, 2),
			CFrame.new(p.X, p.Y - origin + 0.05, p.Z),
			accent,
			Enum.Material.Neon,
			false
		)
	end
	if index % 3 == 1 then
		local waterfall = G.part(
			model,
			"Waterfall",
			Vector3.new(2, 24, 4),
			CFrame.new(terraceCenter + outward * 10 - Vector3.new(0, 12, 0)),
			Color3.fromRGB(143, 220, 255),
			Enum.Material.Glass,
			false
		)
		waterfall.Transparency = 0.55
	end
	G.label(
		model,
		string.format("%s  •  %dm", biome.Name, point.Y - Config.StartY),
		terraceCenter + Vector3.new(0, 13, 0),
		accent
	)
	return {
		Model = model,
		Index = index,
		Y = point.Y,
		Center = center,
		Side = terraceCenter + Vector3.new(0, 1.5, 0),
		Biome = biome,
		Parts = model:GetDescendants(),
	}
end
return IslandGenerator
