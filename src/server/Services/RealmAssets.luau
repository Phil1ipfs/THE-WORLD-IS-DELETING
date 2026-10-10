--!nonstrict
-- Realm scenery: landmarks with walkable viewpoints, water/lava/ice/void features, paths,
-- camps, woodland grown beside timber caches and themed ground cover. All placement goes
-- through Sites so decoration never blocks shelters, routes, prompts or activities.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RNG = require(Shared.Random)
local G = require(script.Parent.Geometry)
local Props = require(script.Parent.Props)
local Sites = require(script.Parent.Sites)
local Architecture = require(script.Parent.Architecture)
local Assets = {}
local C = Color3.fromRGB
local function pick(rng, weights)
	local total, keys = 0, {}
	for name, weight in weights do
		table.insert(keys, name)
		total += weight
	end
	table.sort(keys)
	local roll = rng:range(0, total)
	for _, name in keys do
		roll -= weights[name]
		if roll <= 0 then
			return name
		end
	end
	return keys[#keys]
end
-- Elevated walkable plateau with a gentle ramp; both are collapsing Ground cells.
function Assets.plateau(region, x, z, width, height, rampYaw, color, material, edge, base)
	base = base or 0
	local center = region.Center
	local top = region.AddCell(
		"Viewpoint",
		Vector3.new(width, 2, width),
		center + Vector3.new(x, height, z),
		edge or 0.9
	)
	top.Color, top.Material = color, material
	local B = region.Props
	B.Ground = top
	B.part(
		"PlateauRock",
		Vector3.new(width - 2, height - base, width - 2),
		CFrame.new(center + Vector3.new(x, (height + base) / 2 - 1, z)),
		color:Lerp(C(0, 0, 0), 0.25),
		material,
		{ Collide = true }
	)
	local dir = Vector3.new(math.cos(rampYaw), 0, math.sin(rampYaw))
	local upper = center + Vector3.new(x, height, z) + dir * (width / 2 - 0.5)
	local run = (height - base) / math.tan(math.rad(24))
	local lower = upper + dir * run - Vector3.new(0, height - base, 0)
	local cf = CFrame.lookAt((upper + lower) / 2, upper)
	local ramp = region.AddCell(
		"ViewpointRamp",
		Vector3.new(7, 1.2, (upper - lower).Magnitude + 1),
		cf.Position,
		edge or 0.9
	)
	ramp.CFrame = cf - cf.UpVector * 0.6
	ramp.Color, ramp.Material = color:Lerp(C(120, 100, 80), 0.3), material
	return top, upper
end
local landmarks = {}
function landmarks.ElderOak(A, L, pal)
	local top = Assets.plateau(A.Region, L.X, L.Z, 24, 8, A.Yaw, A.Grass, Enum.Material.Grass)
	A.B.Ground = top
	Props.tree(A.B, "Ancient", A.World(L.X, L.Z, 8), 1, pal)
	Props.lantern(A.B, A.World(L.X + 8, L.Z - 8, 8), C(255, 214, 140), 6)
	A.B.part(
		"HouseDetail",
		Vector3.new(5, 0.5, 1.5),
		CFrame.new(A.World(L.X - 7, L.Z + 8, 9.2)),
		C(110, 80, 56),
		"WoodPlanks"
	)
	return "ELDER OAK HILL\nScenic viewpoint"
end
function landmarks.PrismSpire(A, L, pal)
	local top = Assets.plateau(A.Region, L.X, L.Z, 18, 6, A.Yaw, C(190, 200, 228), Enum.Material.Marble)
	A.B.Ground = top
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		Props.shard(
			A.B,
			CFrame.new(A.World(L.X + math.cos(a) * 5, L.Z + math.sin(a) * 5, 6))
				* CFrame.Angles(math.cos(a) * 0.3, a, math.sin(a) * 0.3),
			Vector3.new(3, 18 + (k % 3) * 9, 3),
			pal.Accent,
			k % 2 == 0,
			"Landmark"
		)
	end
	local core = A.B.blob(
		"Landmark",
		Vector3.new(4, 7, 4),
		CFrame.new(A.World(L.X, L.Z, 13)),
		pal.Accent,
		"Neon",
		{ Transparency = 0.2 }
	)
	A.B.light(core, pal.Accent, 30, 1.2)
	return "PRISM SPIRE\nResonant viewpoint"
end
function landmarks.CanopyTree(A, L, pal)
	A.B.Ground = A.Ground(L.X, L.Z)
	Props.tree(A.B, "Ancient", A.World(L.X, L.Z), 1.3, pal)
	local top =
		Assets.plateau(A.Region, L.X + 12, L.Z, 14, 12, A.Yaw, C(120, 90, 60), Enum.Material.WoodPlanks)
	A.B.Ground = top
	Props.fence(A.B, A.World(L.X + 6, L.Z - 6, 12), A.World(L.X + 18, L.Z - 6, 12), C(110, 80, 50))
	return "CANOPY GIANT\nTreehouse lookout"
end
function landmarks.Caldera(A, L, pal)
	A.B.Ground = A.Ground(L.X, L.Z)
	for k = 1, 9 do
		local a = k / 9 * math.pi * 2
		Props.rock(
			A.B,
			A.World(L.X + math.cos(a) * 11, L.Z + math.sin(a) * 11),
			3.2,
			pal.Rock,
			Enum.Material.Basalt
		)
	end
	Assets.pool(A, L.X, L.Z, 7, "Lava")
	local top = Assets.plateau(
		A.Region,
		L.X + math.cos(A.Yaw + 1.6) * 20,
		L.Z + math.sin(A.Yaw + 1.6) * 20,
		12,
		6,
		A.Yaw,
		C(70, 60, 58),
		Enum.Material.Basalt
	)
	A.B.Ground = top
	return "ASHFALL CALDERA\nKeep clear of the magma"
end
function landmarks.IceArch(A, L, pal)
	local top = Assets.plateau(A.Region, L.X, L.Z, 20, 8, A.Yaw, C(214, 232, 246), Enum.Material.Glacier)
	A.B.Ground = top
	for _, side in { -1, 1 } do
		A.B.part(
			"Landmark",
			Vector3.new(3, 14, 3),
			CFrame.new(A.World(L.X + side * 6, L.Z, 15)) * CFrame.Angles(0, 0, side * 0.15),
			C(190, 226, 250),
			"Ice",
			{ Transparency = 0.15 }
		)
		A.B.part(
			"Landmark",
			Vector3.new(8, 2.4, 3),
			CFrame.new(A.World(L.X + side * 3, L.Z, 22.2)) * CFrame.Angles(0, 0, -side * 0.3),
			C(200, 232, 252),
			"Ice",
			{ Transparency = 0.15 }
		)
	end
	for k = 1, 4 do
		Props.cover(A.B, "IceSpike", A.World(L.X + (k - 2.5) * 4, L.Z + 7, 8), pal, Enum.Material.Glacier)
	end
	return "GLACIER ARCH\nFrozen viewpoint"
end
function landmarks.Colonnade(A, L, pal)
	A.B.Ground = A.Ground(L.X, L.Z)
	for k = -2, 2 do
		for _, side in { -1, 1 } do
			Props.column(
				A.B,
				A.World(L.X + k * 6, L.Z + side * 8),
				12,
				pal.Rock,
				Enum.Material.Sandstone,
				(k + side) % 3 == 0
			)
		end
	end
	local top = Assets.plateau(A.Region, L.X, L.Z, 14, 5, A.Yaw, C(196, 182, 150), Enum.Material.Sandstone)
	A.B.Ground = top
	A.B.part(
		"Landmark",
		Vector3.new(2.5, 6, 2.5),
		CFrame.new(A.World(L.X, L.Z, 8)),
		C(210, 200, 176),
		"Marble"
	)
	A.B.blob(
		"Landmark",
		Vector3.new(2.4, 2.6, 2.4),
		CFrame.new(A.World(L.X, L.Z, 12.2)),
		C(210, 200, 176),
		"Marble"
	)
	return "SUNKEN COLONNADE\nTemple terrace"
end
function landmarks.LightningSpire(A, L, _pal)
	local top = Assets.plateau(A.Region, L.X, L.Z, 14, 4, A.Yaw, C(90, 96, 112), Enum.Material.Slate)
	A.B.Ground = top
	local tower = Instance.new("TrussPart")
	tower.Name, tower.Size, tower.CFrame, tower.Anchored =
		"Landmark", Vector3.new(2, 36, 2), CFrame.new(A.World(L.X, L.Z, 22)), true
	tower.Material, tower.Color, tower.Parent = Enum.Material.Metal, C(120, 126, 140), A.Region.Model
	A.Attach(tower, top)
	local tip = A.B.part(
		"Landmark",
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(A.World(L.X, L.Z, 41)),
		C(200, 210, 255),
		"Neon",
		{ Shape = "Ball" }
	)
	A.B.light(tip, C(190, 200, 255), 24, 1)
	for k = 1, 3 do
		A.B.limb(
			"Landmark",
			A.World(L.X, L.Z, 34),
			A.World(L.X + math.cos(k * 2.1) * 8, L.Z + math.sin(k * 2.1) * 8, 4),
			0.2,
			C(160, 166, 180),
			"Metal"
		)
	end
	return "LIGHTNING SPIRE\nThe storm's anchor"
end
function landmarks.GearTower(A, L, _pal)
	local top = Assets.plateau(A.Region, L.X, L.Z, 16, 6, A.Yaw, C(120, 126, 134), Enum.Material.DiamondPlate)
	A.B.Ground = top
	A.B.part(
		"Landmark",
		Vector3.new(8, 22, 8),
		CFrame.new(A.World(L.X, L.Z, 17)),
		C(110, 104, 96),
		"CorrodedMetal",
		{ Collide = true }
	)
	for k = 0, 2 do
		local hub = Props.gear(
			A.B,
			CFrame.new(A.World(L.X + 4.6, L.Z, 12 + k * 7)) * CFrame.Angles(0, 0, 0),
			3 + k,
			C(176, 140, 76),
			"Landmark"
		)
		hub:SetAttribute("Spin", if k % 2 == 0 then 0.8 else -0.6)
	end
	local stack = A.B.part(
		"Landmark",
		Vector3.new(2, 8, 2),
		CFrame.new(A.World(L.X - 2, L.Z - 2, 32)),
		C(80, 80, 84),
		"Metal"
	)
	A.B.emitter(
		stack,
		"rbxasset://textures/particles/smoke_main.dds",
		C(220, 220, 225),
		2,
		{ 3, 5 },
		NumberSequence.new(2, 6),
		{ 3, 5 },
		{ EmissionDirection = Enum.NormalId.Top, Transparency = NumberSequence.new(0.6, 1) }
	)
	return "COGSPIRE\nClockwork tower"
end
function landmarks.MoonPavilion(A, L, pal)
	local top = Assets.plateau(A.Region, L.X, L.Z, 18, 6, A.Yaw, C(236, 226, 240), Enum.Material.Marble)
	A.B.Ground = top
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		A.B.part(
			"Landmark",
			Vector3.new(1.2, 9, 1.2),
			CFrame.new(A.World(L.X + math.cos(a) * 7, L.Z + math.sin(a) * 7, 10.5)),
			C(250, 246, 240),
			"Marble"
		)
	end
	A.B.blob("Landmark", Vector3.new(17, 5, 17), CFrame.new(A.World(L.X, L.Z, 15.5)), pal.Leaf, "Marble")
	local moon = A.B.blob(
		"Landmark",
		Vector3.new(3, 3, 3),
		CFrame.new(A.World(L.X, L.Z, 10)),
		C(255, 246, 210),
		"Neon"
	)
	A.B.light(moon, C(255, 240, 210), 26, 1)
	-- Floating stepping stones: optional jump/Sky Leap climb to a high perch.
	for k = 1, 4 do
		local a = A.Yaw + 2 + k * 0.55
		local stone = A.Region.AddCell(
			"Viewpoint",
			Vector3.new(5, 1.4, 5),
			A.World(L.X + math.cos(a) * 14, L.Z + math.sin(a) * 14, 6 + k * 3.5),
			0.95
		)
		stone.Color, stone.Material = C(230, 220, 240), Enum.Material.Marble
	end
	return "MOON PAVILION\nClimb the floating stones"
end
function landmarks.RiftAltar(A, L, pal)
	local top = Assets.plateau(A.Region, L.X, L.Z, 16, 5, A.Yaw, C(46, 38, 62), Enum.Material.Basalt)
	A.B.Ground = top
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2
		Props.shard(
			A.B,
			CFrame.new(A.World(L.X + math.cos(a) * 6, L.Z + math.sin(a) * 6, 5))
				* CFrame.Angles(math.cos(a) * 0.25, a, math.sin(a) * 0.25),
			Vector3.new(2, 10 + (k % 3) * 5, 2),
			C(40, 30, 60),
			false,
			"Landmark"
		)
	end
	local rift = A.B.blob(
		"Landmark",
		Vector3.new(3, 8, 0.6),
		CFrame.new(A.World(L.X, L.Z, 12)),
		pal.Accent,
		"Neon",
		{ Transparency = 0.15 }
	)
	A.B.emitter(
		rift,
		"rbxasset://textures/particles/sparkles_main.dds",
		pal.Accent,
		6,
		{ 1, 2 },
		0.4,
		{ 1, 3 },
		{ LightEmission = 1 }
	)
	A.B.light(rift, pal.Accent, 26, 1.2)
	return "RIFT ALTAR\nWhere deletion began"
end
-- Pools: decorative water/ice, or hazardous lava/void registered for server damage.
function Assets.pool(A, x, z, radius, kind)
	local B = A.B
	B.Ground = A.Ground(x, z)
	local colors = {
		Pond = { C(86, 160, 196), "Glass", 0.25 },
		Lava = { C(255, 104, 32), "Neon", 0 },
		Void = { C(150, 60, 220), "Neon", 0.1 },
		Ice = { C(196, 230, 250), "Ice", 0.05 },
	}
	local spec = colors[kind] or colors.Pond
	local surface = B.part(
		"PoolSurface",
		Vector3.new(0.3, radius * 2, radius * 2),
		CFrame.new(A.World(x, z, 0.12)) * CFrame.Angles(0, 0, math.pi / 2),
		spec[1],
		spec[2],
		{ Shape = "Cylinder", Transparency = spec[3], Shadow = false }
	)
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		B.part(
			"PoolRim",
			Vector3.new(2.4, 0.9, 1.6),
			CFrame.new(A.World(x + math.cos(a) * radius, z + math.sin(a) * radius, 0.35))
				* CFrame.Angles(0, -a, B.Rng:range(-0.2, 0.2)),
			if kind == "Lava" then C(46, 36, 34) else A.Pal.Rock,
			if kind == "Lava" then "CrackedLava" else A.RockMat
		)
	end
	if kind == "Pond" then
		for k = 1, 4 do
			local a = k * 1.7
			B.part(
				"RealmFlora",
				Vector3.new(0.1, 1.6, 1.6),
				CFrame.new(A.World(x + math.cos(a) * radius * 0.5, z + math.sin(a) * radius * 0.5, 0.3))
					* CFrame.Angles(0, 0, math.pi / 2),
				C(86, 150, 70),
				"Grass",
				{ Shape = "Cylinder", Shadow = false }
			)
			Props.cover(
				B,
				"TallGrass",
				A.World(x + math.cos(a + 0.8) * (radius + 1.5), z + math.sin(a + 0.8) * (radius + 1.5)),
				A.Pal
			)
		end
	elseif kind == "Lava" or kind == "Void" then
		B.emitter(
			surface,
			"rbxasset://textures/particles/smoke_main.dds",
			if kind == "Lava" then C(120, 90, 80) else C(160, 90, 220),
			2,
			{ 3, 5 },
			NumberSequence.new(2, 5),
			{ 2, 4 },
			{ EmissionDirection = Enum.NormalId.Right, Transparency = NumberSequence.new(0.7, 1) }
		)
		B.light(surface, spec[1], 18, 1)
		table.insert(
			A.Region.Hazards,
			{ Kind = kind, Part = surface, Radius = radius - 0.5, Damage = if kind == "Lava" then 12 else 9 }
		)
	end
	return surface
end
local camps = {
	Grasslands = "Cart",
	Ruins = "Cart",
	Jungle = "Tent",
	Frozen = "Tent",
	Storm = "Glider",
	Mechanical = "Scrap",
	Crystal = "Tent",
	Volcanic = "Scrap",
	Celestial = "Tent",
	Void = "Glider",
}
local function camp(A, x, z, kind)
	local B = A.B
	B.Ground = A.Ground(x, z)
	Props.campfire(B, A.World(x, z))
	for _, a in { 0.6, 2.4 } do
		Props.log(
			B,
			A.World(x + math.cos(a) * 4 - 1.5, z + math.sin(a) * 4, 0.6),
			A.World(x + math.cos(a) * 4 + 1.5, z + math.sin(a) * 4, 0.6),
			1,
			A.Pal.Bark
		)
	end
	local cf = CFrame.new(A.World(x - 7, z - 3)) * CFrame.Angles(0, 0.4, 0)
	if kind == "Tent" then
		for _, side in { -1, 1 } do
			B.part(
				"HouseDetail",
				Vector3.new(6, 4, 2.4),
				cf * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0) * CFrame.new(0, 2, -1.2),
				C(196, 170, 120),
				"Fabric",
				{ Class = "WedgePart" }
			)
		end
	elseif kind == "Cart" then
		B.part(
			"HouseDetail",
			Vector3.new(6, 1.6, 3.4),
			cf * CFrame.new(0, 2, 0),
			C(130, 94, 60),
			"WoodPlanks"
		)
		for _, wx in { -2, 2 } do
			for _, wz in { -1.9, 1.9 } do
				B.part(
					"HouseDetail",
					Vector3.new(0.4, 2.4, 2.4),
					cf * CFrame.new(wx, 1.2, wz) * CFrame.Angles(0, math.pi / 2, 0),
					C(90, 64, 44),
					"Wood",
					{ Shape = "Cylinder" }
				)
			end
		end
		Props.crate(B, cf * CFrame.new(-1.2, 3.8, 0), 1.6)
	elseif kind == "Glider" then
		B.part(
			"HouseDetail",
			Vector3.new(10, 0.2, 3),
			cf * CFrame.new(0, 1, 0) * CFrame.Angles(0.2, 0, 0.35),
			C(196, 200, 214),
			"Fabric"
		)
		B.limb(
			"HouseDetail",
			cf.Position + Vector3.new(-4, 0.4, 0),
			cf.Position + Vector3.new(4, 2.6, 0),
			0.3,
			C(120, 110, 100),
			"Metal"
		)
	else
		for k = 1, 4 do
			Props.gear(
				B,
				cf * CFrame.new(k * 1.4 - 3, 0.6 + k * 0.2, 0) * CFrame.Angles(0.3 * k, 0, math.pi / 2),
				1 + k * 0.3,
				C(150, 120, 70)
			)
		end
	end
	Props.crate(B, CFrame.new(A.World(x + 6, z - 4, 1.2)), 2.4)
	Props.barrel(B, CFrame.new(A.World(x + 6.5, z, 1.1)), 2)
end
-- Satellite sub-area structures (phase 1, reserved before activities claim space).
function Assets.satellites(A, region, rng)
	local B, S, pal = A.B, region.Sites, A.Pal
	local center = region.Center
	for _, sat in region.Satellites or {} do
		local h = sat.Height
		local inward = math.atan2(-sat.Z, -sat.X)
		local out = Vector3.new(math.cos(sat.Angle), 0, math.sin(sat.Angle))
		-- Feature sits beyond the island middle, away from the arriving bridge.
		local fx, fz = sat.X + out.X * sat.Radius * 0.22, sat.Z + out.Z * sat.Radius * 0.22
		if sat.Kind == "Highlands" then
			S:reserve(fx, fz, 16)
			local top = Assets.plateau(
				region,
				fx,
				fz,
				20,
				h + 9,
				inward,
				A.Grass:Lerp(Color3.fromRGB(120, 116, 104), 0.3),
				Enum.Material.Rock,
				0.95,
				h
			)
			B.Ground = top
			local tower = Instance.new("TrussPart")
			tower.Name, tower.Size, tower.Anchored = "SubAreaTower", Vector3.new(2, 14, 2), true
			tower.CFrame = CFrame.new(center + Vector3.new(fx + out.X * 6, h + 9 + 7, fz + out.Z * 6))
			tower.Material, tower.Color, tower.Parent =
				Enum.Material.Wood, Color3.fromRGB(110, 80, 56), region.Model
			A.Attach(tower, top)
			local deck = region.AddCell(
				"Viewpoint",
				Vector3.new(7, 1, 7),
				center + Vector3.new(fx + out.X * 6, h + 23, fz + out.Z * 6),
				0.97
			)
			deck.Color, deck.Material = Color3.fromRGB(130, 94, 60), Enum.Material.WoodPlanks
			B.Ground = deck
			Props.fence(
				B,
				deck.Position + Vector3.new(-3.2, 0.5, -3.2),
				deck.Position + Vector3.new(3.2, 0.5, -3.2),
				pal.Bark
			)
			-- Rock arch: a passage through the heights.
			local ax, az = sat.X - out.X * 6 + out.Z * 16, sat.Z - out.Z * 6 - out.X * 16
			S:reserve(ax, az, 7)
			B.Ground = A.Ground(ax, az)
			for _, side in { -1, 1 } do
				B.blob(
					"SubAreaArch",
					Vector3.new(5, 12, 5),
					CFrame.new(center + Vector3.new(ax + out.X * side * 4, h + 5, az + out.Z * side * 4)),
					pal.Rock,
					"Rock",
					{ Collide = true }
				)
			end
			B.blob(
				"SubAreaArch",
				Vector3.new(14, 4, 6),
				CFrame.new(center + Vector3.new(ax, h + 11, az))
					* CFrame.Angles(0, math.atan2(out.X, out.Z), 0),
				pal.Rock,
				"Rock",
				{ Collide = true }
			)
		elseif sat.Kind == "Wildwood" then
			S:reserve(fx, fz, 14)
			local top = Assets.plateau(
				region,
				fx,
				fz,
				14,
				h + 12,
				inward,
				Color3.fromRGB(120, 90, 60),
				Enum.Material.WoodPlanks,
				0.95,
				h
			)
			B.Ground = top
			Props.fence(
				B,
				center + Vector3.new(fx - 6, h + 12, fz + 6),
				center + Vector3.new(fx + 6, h + 12, fz + 6),
				pal.Bark
			)
			Props.lantern(B, center + Vector3.new(fx + 5, h + 12, fz - 5), Color3.fromRGB(255, 214, 140), 5)
			local tx, tz = sat.X - out.Z * 18, sat.Z + out.X * 18
			if S:fits(tx, tz, 6, { Wildwood = true }) then
				S:reserve(tx, tz, 8)
				B.Ground = A.Ground(tx, tz)
				Props.tree(B, "Ancient", A.World(tx, tz), 0.85, pal)
			end
		elseif sat.Kind == "Ruins" then
			S:reserve(fx, fz, 14)
			B.Ground = A.Ground(fx, fz)
			for k = 1, 6 do
				local a = k / 6 * math.pi * 2
				Props.column(
					B,
					A.World(fx + math.cos(a) * 9, fz + math.sin(a) * 9),
					8 + (k % 3) * 3,
					pal.Rock,
					Enum.Material.Sandstone,
					k % 2 == 0
				)
			end
			B.part(
				"SubAreaRuin",
				Vector3.new(3, 5, 3),
				CFrame.new(A.World(fx, fz, 2.5)),
				Color3.fromRGB(200, 190, 170),
				"Marble",
				{ Collide = true }
			)
			B.blob(
				"SubAreaRuin",
				Vector3.new(2.6, 3, 2.6),
				CFrame.new(A.World(fx, fz, 6.3)),
				Color3.fromRGB(200, 190, 170),
				"Marble"
			)
			for _ = 1, 3 do
				local a = rng:range(0, math.pi * 2)
				B.part(
					"SubAreaRuin",
					Vector3.new(rng:range(5, 9), rng:range(2, 4), 1.4),
					CFrame.new(A.World(fx + math.cos(a) * 16, fz + math.sin(a) * 16, 1.5))
						* CFrame.Angles(0, a, 0),
					pal.Rock,
					"Cobblestone",
					{ Collide = true }
				)
			end
		elseif sat.Kind == "Cliffside" then
			-- A hamlet house that is also a storm shelter on the frontier.
			local hx, hz = sat.X, sat.Z
			S:reserve(hx, hz + 2, 19)
			local floor = region.AddCell(
				"VillageFloor",
				Vector3.new(26, 1, 22),
				center + Vector3.new(hx, h + 0.25, hz),
				0.95,
				false
			)
			floor.Color = A.Grass
			B.Ground = floor
			local breaches = Architecture.house(
				B,
				center + Vector3.new(hx, h, hz),
				A.Style,
				function(name, size, position, color, material)
					local p = B.part(
						name,
						size,
						CFrame.new(position),
						color,
						material,
						{ Collide = true, Shadow = true }
					)
					p:SetAttribute("Detail", nil)
					return p
				end,
				pal.Accent
			)
			table.insert(
				region.Shelters,
				{ Anchor = floor, Half = Vector3.new(12, 16, 10), Breaches = breaches, Name = "House" }
			)
		end
		-- Waterfall off the island rim for a distinct silhouette.
		local rim = Vector3.new(sat.X + out.X * (sat.Radius - 8), h - 1, sat.Z + out.Z * (sat.Radius - 8))
		B.Ground = A.Ground(rim.X - out.X * 6, rim.Z - out.Z * 6)
		local fall = B.part(
			"Waterfall",
			Vector3.new(6, 50, 1),
			CFrame.new(center + rim - Vector3.new(0, 25, 0)),
			Color3.fromRGB(170, 224, 240),
			"Glass",
			{ Transparency = 0.4, Shadow = false }
		)
		B.emitter(
			fall,
			"rbxasset://textures/particles/smoke_main.dds",
			Color3.fromRGB(235, 248, 255),
			2,
			{ 2, 3 },
			NumberSequence.new(3, 7),
			{ 2, 3 },
			{ EmissionDirection = Enum.NormalId.Bottom, Transparency = NumberSequence.new(0.65, 1) }
		)
		G.label(region.Model, string.upper(sat.Name), center + Vector3.new(sat.X, h + 16, sat.Z), pal.Accent)
	end
end
-- Satellite woodland, cover and paths (phase 2).
function Assets.satelliteScenery(A, region, rng, design)
	local B, S, pal = A.B, region.Sites, A.Pal
	local trees = { Highlands = 4, Wildwood = 12, Ruins = 3, Cliffside = 4 }
	local kinds = { Highlands = "Pine", Ruins = "Dead" }
	for _, sat in region.Satellites or {} do
		local zone = { [sat.Kind] = true }
		for _ = 1, trees[sat.Kind] or 3 do
			local site = S:find(rng, 4, zone, 10)
			if site then
				B.Ground = site.Entry.Cell.Part
				local kind = if sat.Kind == "Wildwood" and rng:next() < 0.25
					then "Ancient"
					else kinds[sat.Kind] or pick(rng, design.Trees)
				Props.tree(B, kind, A.World(site.X, site.Z), rng:range(0.85, 1.3), pal)
			end
		end
		for _ = 1, 14 do
			local site = S:find(rng, 1.6, zone, 5)
			if site then
				B.Ground = site.Entry.Cell.Part
				local cover = if sat.Kind == "Ruins"
					then "Rubble"
					elseif sat.Kind == "Wildwood" then (if rng:next() < 0.5 then "Fern" else "Mushroom")
					else pick(rng, design.Cover)
				Props.cover(B, cover, A.World(site.X, site.Z), pal, A.RockMat)
			end
		end
		for _ = 1, 3 do
			local site = S:find(rng, 3, zone, 8, function(_, _, entry)
				return entry.Cell.Edge
			end)
			if site then
				B.Ground = site.Entry.Cell.Part
				Props.rock(B, A.World(site.X, site.Z), rng:range(2.2, 3.4), pal.Rock, A.RockMat)
			end
		end
	end
end
function Assets.context(region, biome, seed)
	local model, center, design = region.Model, region.Center, region.Design
	local rng = RNG.new(seed + region.Index * 7283)
	local B, S = region.Props, region.Sites
	B.Rng = rng
	local pal = {
		Leaf = design.Leaf,
		Leaf2 = design.Leaf2,
		Bark = design.Bark,
		Accent = G.color(biome.Accent),
		Flowers = design.Flowers,
		Rock = G.color(biome.Rock),
		Snow = biome.Id == "Frozen",
		GlowMushrooms = biome.Id == "Celestial" or biome.Id == "Void" or biome.Id == "Crystal",
	}
	local rockMat = Enum.Material[design.Rock] or Enum.Material.Rock
	local function world(x, z, y)
		return center + Vector3.new(x, (y or 0) + S:height(x, z), z)
	end
	local function ground(x, z)
		local entry = S:at(x, z)
		return if entry then entry.Cell.Part else region.Landing
	end
	local A = {
		Region = region,
		B = B,
		Pal = pal,
		RockMat = rockMat,
		World = world,
		Ground = ground,
		Grass = G.color(biome.Top),
		Attach = function(p, g)
			p:SetAttribute("Region", region.Index)
			table.insert(region.Structures, { Part = p, Ground = g })
		end,
	}
	return A, B, S, rng, pal, rockMat, world, ground, design, model, center
end
-- Phase 1 (before activities): landmark, viewpoint and water so activities avoid them.
function Assets.prepare(region, biome, seed)
	local A, B, S, rng, pal, _, world, _, design, model = Assets.context(region, biome, seed)
	-- Landmark and viewpoint at the outskirts; label guides exploration.
	local L = region.Outskirts
	local lobeYaw = math.atan2(-L.Z, -L.X)
	A.Yaw = lobeYaw
	local builder = landmarks[design.Landmark]
	if builder and S:supported(L.X, L.Z, 10, Sites.Land) then
		S:reserve(L.X, L.Z, 18)
		local text = builder(A, L, pal)
		G.label(model, text, world(L.X, L.Z, 16), pal.Accent)
		region.Model:SetAttribute("Landmark", design.Landmark)
	end
	-- Water feature (pond, lava pool, frozen lake slab or void pool).
	local water = S:find(rng, 9, Sites.Land, 50)
	if water then
		if design.Water == "Ice" then
			local slab = region.AddCell(
				"FrozenLake",
				Vector3.new(18, 0.6, 18),
				world(water.X, water.Z, 0.55),
				water.Entry.Cell.Edge
			)
			slab.Material, slab.Color = Enum.Material.Ice, C(196, 228, 248)
			slab.Transparency = 0.1
			B.Ground = slab
			for k = 1, 6 do
				local a = k / 6 * math.pi * 2
				Props.cover(
					B,
					"Snowdrift",
					world(water.X + math.cos(a) * 10, water.Z + math.sin(a) * 10),
					pal
				)
			end
			region.IceLake = slab
		else
			Assets.pool(A, water.X, water.Z, 7, design.Water)
		end
	end
	A.Style = design.Architecture
	Assets.satellites(A, region, rng)
end
-- Phase 2 (after activities): paths, camp, woodland, boulders and ground cover.
function Assets.build(region, biome, seed)
	local A, B, S, rng, pal, rockMat, world, ground, design = Assets.context(region, biome, seed + 1)
	local L = region.Outskirts
	-- Dirt paths link the landing to homes, bridges and the outskirts.
	local pathColor = G.color(design.Path.Color)
	local pathMat = Enum.Material[design.Path.Material] or Enum.Material.Ground
	local function path(ax, az, bx, bz)
		local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local steps = math.max(1, math.floor(length / 7))
		for k = 0, steps - 1 do
			local t0, t1 = k / steps, (k + 1) / steps
			local x0, z0 = ax + (bx - ax) * t0, az + (bz - az) * t0
			local x1, z1 = ax + (bx - ax) * t1, az + (bz - az) * t1
			local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
			local entry = S:at(mx, mz)
			if entry then
				B.Ground = entry.Cell.Part
				local cf = CFrame.lookAt(world(mx, mz, 0.06), world(x1, z1, 0.06))
				B.part(
					"RealmPath",
					Vector3.new(rng:range(4, 5.5), 0.12, length / steps + 1.2),
					cf * CFrame.Angles(0, rng:range(-0.05, 0.05), 0),
					pathColor:Lerp(C(0, 0, 0), rng:range(0, 0.08)),
					pathMat,
					{ Shadow = false }
				)
			end
		end
	end
	for _, h in { { -60, -16 }, { 0, -60 }, { 60, -16 } } do
		path(0, 0, h[1], h[2] + 16)
	end
	path(0, 0, 66, 24)
	path(0, 0, -48, -48)
	path(0, 0, L.X * 0.85, L.Z * 0.85)
	for _, sat in region.Satellites or {} do
		path(sat.EndX, sat.EndZ, sat.X, sat.Z)
	end
	Assets.satelliteScenery(A, region, rng, design)
	-- Fenced garden plots beside the village.
	if
		design.Architecture == "Cottage"
		or design.Architecture == "Lodge"
		or design.Architecture == "Stilt"
	then
		for _, h in { { -60, -16 }, { 60, -16 } } do
			B.Ground = ground(h[1], h[2] + 20)
			Props.fence(B, world(h[1] - 14, h[2] + 18), world(h[1] - 8, h[2] + 18), pal.Bark)
			Props.fence(B, world(h[1] + 8, h[2] + 18), world(h[1] + 14, h[2] + 18), pal.Bark)
		end
	end
	-- Abandoned camp: environmental storytelling.
	local campSite = S:find(rng, 10, Sites.Land, 40)
	if campSite then
		camp(A, campSite.X, campSite.Z, camps[biome.Id] or "Tent")
	end
	-- Woodland grows beside timber caches; fallen logs mark scavenging spots.
	local treeKinds = 0
	for i, spot in region.TimberSpots or {} do
		for _ = 1, 6 do
			local a = rng:range(0, math.pi * 2)
			local d = rng:range(6, 9)
			local x, z = spot.X + math.cos(a) * d, spot.Z + math.sin(a) * d
			if S:fits(x, z, 3, Sites.Land) then
				S:reserve(x, z, 3)
				B.Ground = ground(x, z)
				if i % 4 == 0 then
					local yaw = rng:range(0, 6.3)
					local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
					Props.log(
						B,
						world(x, z, 0.9) - dir * 3.5,
						world(x, z, 0.9) + dir * 3.5,
						1.8,
						pal.Bark,
						pal.Leaf
					)
				else
					Props.tree(B, pick(rng, design.Trees), world(x, z), rng:range(0.85, 1.15), pal)
					treeKinds += 1
				end
				break
			end
		end
	end
	for _ = 1, 22 do
		local site = S:find(rng, 4, Sites.Land, 12)
		if site then
			B.Ground = site.Entry.Cell.Part
			Props.tree(B, pick(rng, design.Trees), world(site.X, site.Z), rng:range(0.8, 1.25), pal)
		end
	end
	-- Boulders along island edges.
	for _ = 1, 10 do
		local site = S:find(rng, 3.5, Sites.Land, 10, function(_, _, entry)
			return entry.Cell.Edge
		end)
		if site then
			B.Ground = site.Entry.Cell.Part
			Props.rock(B, world(site.X, site.Z), rng:range(2.4, 3.8), pal.Rock, rockMat)
		end
	end
	-- Themed ground cover across the land and grove; herbs sit among flowers and ferns.
	for _ = 1, 64 do
		local site = S:find(rng, 1.8, { Mainland = true, Outskirts = true, Grove = true }, 6)
		if site then
			B.Ground = site.Entry.Cell.Part
			Props.cover(B, pick(rng, design.Cover), world(site.X, site.Z), pal, rockMat)
		end
	end
	for _, spot in region.HerbSpots or {} do
		local a = rng:range(0, 6.3)
		local x, z = spot.X + math.cos(a) * 3, spot.Z + math.sin(a) * 3
		B.Ground = ground(x, z)
		Props.cover(B, if rng:next() < 0.5 then "Flower" else "Fern", world(x, z), pal, rockMat)
	end
	-- Crystal formations line the cave walls near crystal supplies.
	B.Ground = region.Landing
	for _, c in region.Cells do
		if c.Part.Name == "CaveFloor" then
			B.Ground = c.Part
		end
	end
	for k, spot in { { -139, -50 }, { -139, -38 }, { -132, -68 }, { -116, -68 }, { -101, -68 } } do
		for j = 1, 2 do
			Props.shard(
				B,
				CFrame.new(world(spot[1] + j, spot[2], 0.3))
					* CFrame.Angles(rng:range(-0.4, 0.4), rng:range(0, 6), rng:range(-0.4, 0.4)),
				Vector3.new(1.2, rng:range(2.5, 5), 1.2),
				C(139, 210, 255):Lerp(pal.Accent, 0.3),
				j == 1 and k % 2 == 1
			)
		end
	end
	region.Model:SetAttribute("SceneryTheme", biome.Id)
	region.Model:SetAttribute("SceneryParts", B.Count)
	local _ = treeKinds
end
return Assets
