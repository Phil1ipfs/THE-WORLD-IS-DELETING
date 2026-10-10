--!nonstrict
-- Cinematic sanctuary vista shown behind the main menu: a floating village island with
-- cliffs, waterfall, lookout tower and bridge, distant floating islands, sea stacks and a
-- mountain range rising from the ocean. Built once on the server from native parts.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local RNG = require(Shared.Random)
local Props = require(script.Parent.Props)
local Architecture = require(script.Parent.Architecture)
local Bridge = require(script.Parent.SuspensionBridge)
local Scene = require(Shared.MenuScene)
local Vista = {}
local C = Color3.fromRGB
Vista.Center = Vector3.new(Config.LobbyX, Scene.Height, 0)
local pal = {
	Leaf = { 82, 150, 70 },
	Leaf2 = { 128, 184, 86 },
	Bark = { 96, 70, 50 },
	Accent = C(255, 214, 120),
	Flowers = { { 250, 214, 92 }, { 236, 120, 150 }, { 245, 245, 235 } },
	Rock = C(112, 108, 104),
}
-- Floating island mass: grass cap plus layered rock ellipsoids tapering into hanging drips.
local function island(B, center, radius, depth, rng, grassy, walkable)
	local top = B.part(
		"VistaIsland",
		Vector3.new(3, radius * 2, radius * 2),
		CFrame.new(center - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		if grassy == false then C(120, 112, 100) else C(96, 158, 78),
		if grassy == false then "Rock" else "Grass",
		{ Shape = "Cylinder", Collide = walkable == true }
	)
	for k = 1, 4 do
		local r = radius * (1.05 - k * 0.18)
		B.blob(
			"VistaRock",
			Vector3.new(r * 2, depth * (0.35 + k * 0.08), r * 2),
			CFrame.new(center - Vector3.new(rng:range(-3, 3), 3 + k * depth * 0.18, rng:range(-3, 3))),
			C(118, 108, 100):Lerp(C(70, 64, 62), k / 5),
			"Rock",
			{ Shadow = true }
		)
	end
	for _ = 1, math.max(2, math.floor(radius / 8)) do
		local a = rng:range(0, math.pi * 2)
		local d = rng:range(0, radius * 0.6)
		B.blob(
			"VistaRock",
			Vector3.new(radius * 0.3, depth * rng:range(0.5, 0.9), radius * 0.3),
			CFrame.new(center + Vector3.new(math.cos(a) * d, -depth * rng:range(0.75, 1), math.sin(a) * d)),
			C(84, 78, 74),
			"Rock"
		)
	end
	return top
end
local function waterfall(B, origin, height)
	local fall = B.part(
		"VistaWaterfall",
		Vector3.new(7, height, 1.2),
		CFrame.new(origin - Vector3.new(0, height / 2, 0)),
		C(170, 224, 240),
		"Glass",
		{ Transparency = 0.35, Shadow = false }
	)
	B.emitter(
		fall,
		"rbxasset://textures/particles/smoke_main.dds",
		C(235, 248, 255),
		4,
		{ 2, 3 },
		NumberSequence.new(4, 10),
		{ 2, 4 },
		{ EmissionDirection = Enum.NormalId.Bottom, Transparency = NumberSequence.new(0.6, 1) }
	)
	return fall
end
function Vista.build(model)
	local rng = RNG.new(Config.Seed + 77)
	local B = Props.builder(model, function(p)
		p:SetAttribute("Vista", true)
	end, rng)
	B.LightBudget = 10
	local c = Vista.Center
	-- Sanctuary island underside (the walkable top is the existing Sanctuary platform).
	island(B, c - Vector3.new(0, 2.6, 0), 58, 70, rng, true)
	-- Village: one cottage, lantern-lit plaza, trees, fences and a lookout tower.
	B.Ground = nil
	Architecture.house(
		B,
		c + Vector3.new(26, 0, -30),
		"Cottage",
		function(name, size, position, color, material)
			return B.part(name, size, CFrame.new(position), color, material, { Collide = true })
		end,
		pal.Accent
	)
	for _, spot in { { -38, -26 }, { -44, 14 }, { -20, 40 }, { 34, 30 }, { 46, 8 }, { -30, -44 } } do
		Props.tree(
			B,
			if spot[1] > 0 then "Broadleaf" else "Pine",
			c + Vector3.new(spot[1], 0, spot[2]),
			rng:range(0.9, 1.2),
			pal
		)
	end
	for _ = 1, 26 do
		local a, d = rng:range(0, math.pi * 2), rng:range(22, 52)
		Props.cover(
			B,
			if rng:next() < 0.5 then "Flower" else "Grass",
			c + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d),
			pal,
			Enum.Material.Rock
		)
	end
	for _, spot in { { -14, -14 }, { 14, -14 }, { -14, 14 }, { 14, 14 } } do
		Props.lantern(B, c + Vector3.new(spot[1], 0, spot[2]), C(255, 214, 140), 7)
	end
	Props.fence(B, c + Vector3.new(-52, 0, -10), c + Vector3.new(-52, 0, 20), pal.Bark)
	Props.campfire(B, c + Vector3.new(-24, 0, 22))
	Props.rock(B, c + Vector3.new(40, 0, -6), 3, pal.Rock, Enum.Material.Rock)
	local tower = c + Vector3.new(-40, 0, -8)
	for _, offset in { { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } } do
		B.limb(
			"VistaTower",
			tower + Vector3.new(offset[1], 0, offset[2]),
			tower + Vector3.new(offset[1] * 0.7, 22, offset[2] * 0.7),
			0.9,
			C(110, 80, 56),
			"Wood",
			{ Collide = true }
		)
	end
	B.part(
		"VistaTower",
		Vector3.new(9, 1, 9),
		CFrame.new(tower + Vector3.new(0, 22, 0)),
		C(130, 94, 60),
		"WoodPlanks",
		{ Collide = true }
	)
	B.cone("VistaTower", tower + Vector3.new(0, 26.5, 0), 6, 5, C(150, 72, 52), "RoofShingles", 0.785)
	-- Waterfall pouring off the island edge toward the ocean.
	waterfall(B, c + Vector3.new(52, -1, 26), 96)
	-- Satellite islet linked by a wooden rope bridge (decorative backdrop for the camera).
	local islet = c + Vector3.new(-176, 18, 72)
	island(B, islet, 16, 30, rng, true, true)
	Props.tree(B, "Broadleaf", islet, 1, pal)
	local from, to = c + Vector3.new(-56, 0, 30), islet + Vector3.new(12, 0, -8)
	Bridge.build({
		Parent = model,
		A = from,
		B = to,
		Width = 6,
		Name = "VistaBridgeDeck",
		Rng = rng,
		Attach = function(p)
			p:SetAttribute("Vista", true)
		end,
	})
	-- Distant floating islands at varied heights, some with waterfalls and trees.
	for k = 1, 9 do
		local a = k / 9 * math.pi * 2 + rng:range(-0.2, 0.2)
		local d = rng:range(260, 560)
		local center = c + Vector3.new(math.cos(a) * d, rng:range(-30, 120), math.sin(a) * d)
		local radius = rng:range(18, 42)
		island(B, center, radius, radius * 1.6, rng, true)
		for _ = 1, math.floor(radius / 12) do
			local o = Vector3.new(rng:range(-radius, radius) * 0.5, 0, rng:range(-radius, radius) * 0.5)
			Props.tree(
				B,
				if rng:next() < 0.5 then "Pine" else "Broadleaf",
				center + o,
				rng:range(1, 1.6),
				pal
			)
		end
		if k % 3 == 0 then
			waterfall(B, center + Vector3.new(radius * 0.8, -1, 0), 70)
		end
	end
	-- Sea stacks below the sanctuary, rising from the ocean surface.
	for _ = 1, 8 do
		local a = rng:range(0, math.pi * 2)
		local d = rng:range(110, 230)
		local base = Vector3.new(c.X + math.cos(a) * d, Config.OceanY, c.Z + math.sin(a) * d)
		local h = rng:range(16, 44)
		B.blob(
			"VistaStack",
			Vector3.new(rng:range(12, 22), h * 2, rng:range(12, 22)),
			CFrame.new(base),
			C(110, 104, 98),
			"Rock"
		)
		B.blob(
			"VistaStack",
			Vector3.new(10, 3, 10),
			CFrame.new(base + Vector3.new(0, h - 1, 0)),
			C(96, 158, 78),
			"Grass"
		)
	end
	-- Mountain range on the horizon with snow caps.
	for k = 1, 22 do
		local a = k / 22 * math.pi * 2 + rng:range(-0.1, 0.1)
		local d = rng:range(1100, 1450)
		if math.cos(a) < -0.15 then
			continue -- Never raise mountains inside realm airspace (realms lie toward -X).
		end
		local base = Vector3.new(c.X + math.cos(a) * d, Config.OceanY, c.Z + math.sin(a) * d)
		local h = rng:range(160, 340)
		local w = rng:range(220, 380)
		B.blob(
			"VistaMountain",
			Vector3.new(w, h * 2, w * 0.8),
			CFrame.new(base) * CFrame.Angles(0, a, 0),
			C(96, 104, 118),
			"Rock",
			{ Shadow = false }
		)
		B.blob(
			"VistaMountain",
			Vector3.new(w * 0.32, h * 0.5, w * 0.28),
			CFrame.new(base + Vector3.new(0, h * 0.86, 0)) * CFrame.Angles(0, a, 0),
			C(236, 242, 248),
			"Snow",
			{ Shadow = false }
		)
	end
	model:SetAttribute("VistaParts", B.Count)
	return B.Count
end
return Vista
