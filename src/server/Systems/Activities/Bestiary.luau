--!nonstrict
-- Realm enemy ecosystems: a common, an elite and a rare encounter for every existing realm.
-- Bodies come from distinct procedural body plans (silhouette, size and motion differ), not
-- recolors. These are modular prototypes built from parts; final art should replace them with
-- rigged MeshParts (see docs/CODEX_QA_HANDOFF.md).
local Bestiary = {}
local C = Color3.fromRGB
local function ball(name, size, at, color, mat, anim, extra)
	local spec = { name, size, at, color, mat or "SmoothPlastic", Mesh = "Sphere", Anim = anim }
	for k, v in extra or {} do
		spec[k] = v
	end
	return spec
end
local function box(name, size, at, color, mat, anim, extra)
	local spec = { name, size, at, color, mat or "SmoothPlastic", Anim = anim }
	for k, v in extra or {} do
		spec[k] = v
	end
	return spec
end
local function cyl(name, length, d, at, color, mat, anim)
	-- Vertical cylinder (Roblox cylinders run along X).
	return {
		name,
		Vector3.new(length, d, d),
		at * CFrame.Angles(0, 0, math.pi / 2),
		color,
		mat or "SmoothPlastic",
		Shape = "Cylinder",
		Anim = anim,
	}
end
local function leg(name, x, z, height, d, color, mat, phase, hipY)
	return cyl(
		name,
		height,
		d,
		CFrame.new(x, hipY - height / 2, z),
		color,
		mat,
		{ Kind = "Leg", Pivot = Vector3.new(x, hipY, z), Amp = 0.55, Speed = 9, Phase = phase }
	)
end
local function eyes(y, z, spread, size, color)
	return {
		ball("Eye", Vector3.one * size, CFrame.new(spread, y, z), color, "Neon"),
		ball("Eye", Vector3.one * size, CFrame.new(-spread, y, z), color, "Neon"),
	}
end
local function add(list, items)
	for _, item in items do
		table.insert(list, item)
	end
	return list
end
-- Body plans ----------------------------------------------------------------------------
local plans = {}
function plans.Quadruped(d)
	local body, acc, glow, mat = d.Colors[1], d.Colors[2], d.Colors[3], d.Material
	local s = {
		ball("Core", Vector3.new(3.4, 2.6, 5.6), CFrame.new(0, 2.9, 0), body, mat),
		ball(
			"Head",
			Vector3.new(2.2, 2, 2.6),
			CFrame.new(0, 3.5, -3.4),
			body,
			mat,
			{ Kind = "Head", Amp = 0.25 }
		),
		box(
			"Jaw",
			Vector3.new(1.4, 0.5, 1.6),
			CFrame.new(0, 2.7, -4.2),
			acc,
			mat,
			{ Kind = "Jaw", Pivot = Vector3.new(0, 2.9, -3.6), Amp = 0.5, Speed = 3 }
		),
		cyl(
			"Tail",
			3,
			0.5,
			CFrame.new(0, 3.1, 3.6) * CFrame.Angles(-1.1, 0, 0),
			acc,
			mat,
			{ Kind = "Tail", Pivot = Vector3.new(0, 3, 2.8), Amp = 0.5, Speed = 4 }
		),
		leg("Leg", 1.2, -1.8, 2.2, 0.7, acc, mat, 0, 2.2),
		leg("Leg", -1.2, -1.8, 2.2, 0.7, acc, mat, math.pi, 2.2),
		leg("Leg", 1.2, 1.8, 2.2, 0.7, acc, mat, math.pi, 2.2),
		leg("Leg", -1.2, 1.8, 2.2, 0.7, acc, mat, 0, 2.2),
	}
	add(s, eyes(3.8, -4.4, 0.55, 0.45, glow))
	for k = -1, 1 do
		table.insert(
			s,
			box(
				"Spike",
				Vector3.new(0.3, 1.4, 0.9),
				CFrame.new(0, 4.4, k * 1.5) * CFrame.Angles(0.3, 0, 0),
				glow,
				d.SpikeMat or mat,
				nil,
				{ Mesh = nil }
			)
		)
	end
	if d.Claws then
		for _, x in { 0.9, -0.9 } do
			table.insert(
				s,
				box("Claw", Vector3.new(0.25, 0.25, 1.4), CFrame.new(x, 0.2, -2.6), C(30, 26, 22), "Slate")
			)
		end
	end
	return s
end
function plans.Crawler(d)
	local body, acc, glow, mat = d.Colors[1], d.Colors[2], d.Colors[3], d.Material
	local s = {
		ball("Core", Vector3.new(4, 1.6, 4.8), CFrame.new(0, 1.5, 0), body, mat),
		ball(
			"Head",
			Vector3.new(2.2, 1.3, 1.8),
			CFrame.new(0, 1.6, -3),
			body,
			mat,
			{ Kind = "Head", Amp = 0.2 }
		),
	}
	for i, z in { -1.4, 0, 1.4 } do
		for _, side in { -1, 1 } do
			table.insert(
				s,
				cyl(
					"Leg",
					2.6,
					0.35,
					CFrame.new(side * 2.4, 1, z) * CFrame.Angles(0, 0, side * 1.1),
					acc,
					mat,
					{
						Kind = "Leg",
						Pivot = Vector3.new(side * 1.6, 1.5, z),
						Amp = 0.45,
						Speed = 14,
						Phase = i + (if side > 0 then 0 else math.pi),
					}
				)
			)
		end
	end
	for _, side in { -1, 1 } do
		table.insert(
			s,
			box(
				"Mandible",
				Vector3.new(0.3, 0.3, 1.4),
				CFrame.new(side * 0.6, 1.2, -4) * CFrame.Angles(0, side * 0.4, 0),
				acc,
				mat,
				{ Kind = "Jaw", Pivot = Vector3.new(side * 0.6, 1.2, -3.4), Amp = 0.4, Speed = 6 }
			)
		)
	end
	for k = 1, 3 do
		table.insert(
			s,
			box(
				"Spike",
				Vector3.new(0.6, 1.8, 0.6),
				CFrame.new((k - 2) * 1.1, 2.6, (k - 2) * 0.8) * CFrame.Angles(0.2, k, 0.3),
				glow,
				d.SpikeMat or "Glass"
			)
		)
	end
	return add(s, eyes(1.9, -3.8, 0.45, 0.35, glow))
end
function plans.Serpent(d)
	local body, acc, glow, mat = d.Colors[1], d.Colors[2], d.Colors[3], d.Material
	local s = {}
	for k = 0, 6 do
		local size = 2.4 - k * 0.22
		table.insert(
			s,
			ball(
				if k == 0 then "Core" else "Segment",
				Vector3.new(size, size, size * 1.3),
				CFrame.new(0, 1.3 + (if k == 0 then 1 else 0), k * 1.9),
				if k % 2 == 0 then body else acc,
				mat,
				{
					Kind = "Tail",
					Pivot = Vector3.new(0, 1, k * 1.9 - 1.9),
					Amp = 0.25 + k * 0.04,
					Speed = 5,
					Phase = -k * 0.6,
				}
			)
		)
	end
	table.insert(
		s,
		ball(
			"Head",
			Vector3.new(2, 1.6, 2.6),
			CFrame.new(0, 2.6, -2),
			body,
			mat,
			{ Kind = "Head", Amp = 0.3 }
		)
	)
	table.insert(
		s,
		box(
			"Jaw",
			Vector3.new(1.4, 0.4, 1.8),
			CFrame.new(0, 1.9, -2.6),
			acc,
			mat,
			{ Kind = "Jaw", Pivot = Vector3.new(0, 2.2, -1.8), Amp = 0.6, Speed = 3 }
		)
	)
	for _, side in { -1, 1 } do
		table.insert(
			s,
			box(
				"Frill",
				Vector3.new(1.6, 1.4, 0.2),
				CFrame.new(side * 1.2, 2.9, -1.4) * CFrame.Angles(0, side * 0.6, side * 0.4),
				glow,
				"Neon",
				nil,
				{ Transparency = 0.25 }
			)
		)
	end
	return add(s, eyes(3, -3, 0.5, 0.35, glow))
end
function plans.Biped(d)
	local body, acc, glow, mat = d.Colors[1], d.Colors[2], d.Colors[3], d.Material
	local s = {
		box("Core", Vector3.new(2.6, 2.8, 1.6), CFrame.new(0, 4.6, 0), body, mat),
		ball(
			"Head",
			Vector3.new(1.8, 1.8, 1.8),
			CFrame.new(0, 6.7, -0.2),
			acc,
			mat,
			{ Kind = "Head", Amp = 0.2 }
		),
		box("Hips", Vector3.new(2.2, 0.9, 1.4), CFrame.new(0, 3, 0), acc, mat),
		leg("Leg", 0.6, 0, 3, 0.8, body, mat, 0, 2.8),
		leg("Leg", -0.6, 0, 3, 0.8, body, mat, math.pi, 2.8),
		leg("Arm", 1.7, 0, 3, 0.7, body, mat, math.pi, 5.8),
		leg("Arm", -1.7, 0, 3, 0.7, body, mat, 0, 5.8),
	}
	add(s, eyes(6.9, -0.95, 0.4, 0.35, glow))
	if d.Horns then
		for _, side in { -1, 1 } do
			table.insert(
				s,
				box(
					"Horn",
					Vector3.new(0.3, 1.4, 0.3),
					CFrame.new(side * 0.6, 7.8, 0) * CFrame.Angles(0, 0, -side * 0.5),
					glow,
					"Neon"
				)
			)
		end
	end
	return s
end
function plans.Colossus(d)
	local body, acc, glow, mat = d.Colors[1], d.Colors[2], d.Colors[3], d.Material
	local s = {
		ball("Core", Vector3.new(6, 5.2, 4.4), CFrame.new(0, 8, 0), body, mat),
		ball(
			"Head",
			Vector3.new(2.6, 2.4, 2.6),
			CFrame.new(0, 11.2, -1),
			acc,
			mat,
			{ Kind = "Head", Amp = 0.12 }
		),
		ball("Shoulder", Vector3.new(3, 2.6, 3), CFrame.new(3.6, 9.4, 0), acc, mat),
		ball("Shoulder", Vector3.new(3, 2.6, 3), CFrame.new(-3.6, 9.4, 0), acc, mat),
		leg("Arm", 3.9, -0.4, 6, 1.6, body, mat, math.pi, 9),
		leg("Arm", -3.9, -0.4, 6, 1.6, body, mat, 0, 9),
		leg("Leg", 1.4, 0, 5.4, 1.9, acc, mat, 0, 5.4),
		leg("Leg", -1.4, 0, 5.4, 1.9, acc, mat, math.pi, 5.4),
	}
	add(s, eyes(11.4, -2.25, 0.6, 0.5, glow))
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2
		table.insert(
			s,
			box(
				"Armor",
				Vector3.new(1.2, 2.6, 1.2),
				CFrame.new(math.cos(a) * 2.6, 10.3, math.sin(a) * 1.8)
					* CFrame.Angles(math.sin(a) * 0.4, a, math.cos(a) * 0.4),
				glow,
				d.SpikeMat or "Glass"
			)
		)
	end
	return s
end
function plans.Flyer(d)
	local body, acc, glow, mat = d.Colors[1], d.Colors[2], d.Colors[3], d.Material
	local s = {
		ball("Core", Vector3.new(2.2, 1.8, 3.4), CFrame.new(0, 0, 0), body, mat),
		ball(
			"Head",
			Vector3.new(1.4, 1.3, 1.8),
			CFrame.new(0, 0.4, -2.2),
			acc,
			mat,
			{ Kind = "Head", Amp = 0.25 }
		),
		box("Beak", Vector3.new(0.4, 0.4, 1.4), CFrame.new(0, 0.2, -3.3), glow, "Neon"),
		cyl(
			"Tail",
			2.4,
			0.4,
			CFrame.new(0, 0.2, 2.6) * CFrame.Angles(-1.3, 0, 0),
			acc,
			mat,
			{ Kind = "Tail", Pivot = Vector3.new(0, 0, 1.6), Amp = 0.3, Speed = 3 }
		),
	}
	for _, side in { -1, 1 } do
		table.insert(
			s,
			box(
				"Wing",
				Vector3.new(4.6, 0.2, 2.4),
				CFrame.new(side * 3, 0.4, 0.2) * CFrame.Angles(0, side * 0.15, 0),
				glow,
				d.WingMat or "Fabric",
				{ Kind = "Wing", Pivot = Vector3.new(side * 0.8, 0.4, 0.2), Amp = side * 0.6, Speed = 10 }
			)
		)
		table.insert(s, box("Talon", Vector3.new(0.3, 1.1, 0.3), CFrame.new(side * 0.5, -1.2, 0.4), acc, mat))
	end
	return add(s, eyes(0.7, -2.95, 0.4, 0.3, glow))
end
function plans.Floater(d)
	local body, acc, glow, mat = d.Colors[1], d.Colors[2], d.Colors[3], d.Material
	local s = {
		ball(
			"Core",
			Vector3.new(2.4, 2.4, 2.4),
			CFrame.new(0, 0, 0),
			glow,
			"Neon",
			{ Kind = "Bob", Amp = 0.25, Speed = 3 }
		),
		box(
			"Shell",
			Vector3.new(3.2, 0.6, 3.2),
			CFrame.new(0, 1.5, 0) * CFrame.Angles(0, math.pi / 4, 0),
			body,
			mat
		),
		box(
			"Shell",
			Vector3.new(3.2, 0.6, 3.2),
			CFrame.new(0, -1.5, 0) * CFrame.Angles(0, math.pi / 4, 0),
			body,
			mat
		),
		ball("Eye", Vector3.new(1, 1, 0.4), CFrame.new(0, 0, -1.25), C(255, 255, 255), "Neon"),
	}
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2
		table.insert(
			s,
			box(
				"Shard",
				Vector3.new(0.7, 2.2, 0.7),
				CFrame.new(math.cos(a) * 3, 0, math.sin(a) * 3) * CFrame.Angles(0.3, 0, 0.3),
				acc,
				d.SpikeMat or "Glass",
				{ Kind = "Orbit", Speed = 1.6, Phase = 0 }
			)
		)
	end
	return s
end
function plans.Wraith(d)
	local body, acc, glow, mat = d.Colors[1], d.Colors[2], d.Colors[3], d.Material
	local s = {
		ball(
			"Core",
			Vector3.new(2.6, 4.4, 2.2),
			CFrame.new(0, 0, 0),
			body,
			mat,
			{ Kind = "Bob", Amp = 0.35, Speed = 2 }
		),
		ball(
			"Head",
			Vector3.new(1.9, 2, 1.9),
			CFrame.new(0, 2.6, -0.2),
			acc,
			mat,
			{ Kind = "Head", Amp = 0.3 }
		),
	}
	for k = 1, 4 do
		local x = (k - 2.5) * 0.6
		table.insert(
			s,
			box(
				"Tatter",
				Vector3.new(0.5, 2.6, 0.15),
				CFrame.new(x, -2.8, 0.3),
				body,
				"Fabric",
				{ Kind = "Tail", Pivot = Vector3.new(x, -1.6, 0.3), Amp = 0.4, Speed = 5, Phase = k },
				{ Transparency = 0.2 }
			)
		)
	end
	for _, side in { -1, 1 } do
		table.insert(
			s,
			cyl(
				"Arm",
				2.6,
				0.4,
				CFrame.new(side * 1.6, 0.2, -0.6) * CFrame.Angles(0.5, 0, side * 0.5),
				acc,
				mat,
				{
					Kind = "Leg",
					Pivot = Vector3.new(side * 1.2, 1.2, -0.2),
					Amp = 0.4,
					Speed = 4,
					Phase = if side > 0 then 0 else math.pi,
				}
			)
		)
	end
	return add(s, eyes(2.7, -1.1, 0.4, 0.35, glow))
end
function plans.Burrower(d)
	local body, acc, glow, mat = d.Colors[1], d.Colors[2], d.Colors[3], d.Material
	local s = {
		ball("Core", Vector3.new(3.6, 3, 3.6), CFrame.new(0, 1.6, 0), body, mat),
		ball(
			"Head",
			Vector3.new(2.6, 2.2, 2.8),
			CFrame.new(0, 3.6, -0.6),
			acc,
			mat,
			{ Kind = "Head", Amp = 0.35 }
		),
		box(
			"Jaw",
			Vector3.new(1.8, 0.5, 1.8),
			CFrame.new(0, 2.6, -1.6),
			acc,
			mat,
			{ Kind = "Jaw", Pivot = Vector3.new(0, 2.9, -0.8), Amp = 0.7, Speed = 4 }
		),
		ball("Mound", Vector3.new(6, 1.4, 6), CFrame.new(0, 0.3, 0), C(96, 74, 52), "Ground"),
	}
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2
		table.insert(
			s,
			cyl(
				"Root",
				3.4,
				0.45,
				CFrame.new(math.cos(a) * 2.6, 1, math.sin(a) * 2.6)
					* CFrame.Angles(math.sin(a) * 0.7, 0, math.cos(a) * 0.7),
				C(90, 66, 44),
				"Wood",
				{
					Kind = "Tail",
					Pivot = Vector3.new(math.cos(a) * 1.6, 0.4, math.sin(a) * 1.6),
					Amp = 0.3,
					Speed = 3,
					Phase = k,
				}
			)
		)
	end
	return add(s, eyes(4, -1.85, 0.55, 0.45, glow))
end
function plans.Plant(d)
	local body, acc, glow, mat = d.Colors[1], d.Colors[2], d.Colors[3], d.Material
	local s = {
		cyl(
			"Core",
			4,
			0.9,
			CFrame.new(0, 2, 0),
			acc,
			"Grass",
			{ Kind = "Tail", Pivot = Vector3.new(0, 0, 0), Amp = 0.15, Speed = 2 }
		),
		ball(
			"Head",
			Vector3.new(2.6, 2.4, 2.6),
			CFrame.new(0, 4.6, 0),
			body,
			mat,
			{ Kind = "Head", Amp = 0.3 }
		),
		ball("Eye", Vector3.new(1.2, 1.2, 0.5), CFrame.new(0, 4.7, -1.2), glow, "Neon"),
	}
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		table.insert(
			s,
			box(
				"Petal",
				Vector3.new(1.6, 0.2, 2.4),
				CFrame.new(math.cos(a) * 1.8, 4.6, math.sin(a) * 1.8)
					* CFrame.Angles(0, -a + math.pi / 2, 0.5),
				glow,
				"SmoothPlastic",
				{
					Kind = "Wing",
					Pivot = Vector3.new(math.cos(a) * 1, 4.6, math.sin(a) * 1),
					Amp = 0.25,
					Speed = 3,
					Phase = k,
				}
			)
		)
	end
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + 0.4
		table.insert(
			s,
			box(
				"Leaf",
				Vector3.new(0.2, 0.15, 2.6),
				CFrame.new(math.cos(a) * 1.4, 0.4, math.sin(a) * 1.4) * CFrame.Angles(0, -a, 0.2),
				acc,
				"Grass"
			)
		)
	end
	return s
end
Bestiary.Plans = plans
-- Enemy definitions ---------------------------------------------------------------------
-- Attacks: Lunge, Charge, Slam, Strike, Volley, Blink, Dive, Burrow, Ambush (behaviour).
-- Weakness: Dash (default), Exposed (only hurt while recovering), Armored (armor absorbs plain
-- hits; overcharged dashes shred it), Stomp (only drops land), Aerial (dash or stomp in the air).
local defs = {
	-- Sky Grasslands: forest predators.
	BrambleStalker = {
		Name = "Bramble Stalker",
		Realm = "Grasslands",
		Tier = "Common",
		Plan = "Quadruped",
		Scale = 1,
		Colors = { C(86, 70, 46), C(64, 52, 36), C(180, 255, 110) },
		Material = "Wood",
		Claws = true,
		HP = 3,
		Speed = 11,
		Detect = 34,
		Attacks = { "Lunge" },
		Damage = 12,
		Stalks = true,
	},
	RootBurrower = {
		Name = "Root Burrower",
		Realm = "Grasslands",
		Tier = "Elite",
		Plan = "Burrower",
		Scale = 1,
		Colors = { C(110, 84, 58), C(90, 120, 60), C(255, 200, 90) },
		Material = "Wood",
		HP = 4,
		Speed = 8,
		Detect = 30,
		Attacks = { "Burrow" },
		Damage = 16,
		Radius = 7,
		Weakness = "Exposed",
	},
	AncientTreant = {
		Name = "Ancient Treant",
		Realm = "Grasslands",
		Tier = "Rare",
		Plan = "Colossus",
		Scale = 1.15,
		Colors = { C(92, 70, 48), C(72, 120, 60), C(170, 255, 120) },
		Material = "Wood",
		SpikeMat = "Grass",
		HP = 9,
		Speed = 5,
		Detect = 40,
		Attacks = { "Slam", "Strike" },
		Damage = 20,
		Radius = 13,
		StaggerResist = true,
		Armor = 3,
	},
	-- Crystal Kingdom.
	CrystalCrawler = {
		Name = "Crystal Crawler",
		Realm = "Crystal",
		Tier = "Common",
		Plan = "Crawler",
		Scale = 1,
		Colors = { C(90, 110, 160), C(70, 80, 120), C(130, 240, 255) },
		Material = "Slate",
		HP = 3,
		Speed = 14,
		Detect = 36,
		Attacks = { "Lunge" },
		Damage = 12,
		Armor = 1,
	},
	CrystalSentinel = {
		Name = "Shard Sentinel",
		Realm = "Crystal",
		Tier = "Elite",
		Plan = "Floater",
		Scale = 1.2,
		Colors = { C(150, 190, 240), C(170, 220, 255), C(120, 240, 255) },
		Material = "Marble",
		Hover = 5,
		HP = 5,
		Speed = 6,
		Detect = 40,
		Attacks = { "Volley" },
		Damage = 14,
		Radius = 6,
		Weakness = "Exposed",
	},
	CrystalColossus = {
		Name = "Crystal Colossus",
		Realm = "Crystal",
		Tier = "Rare",
		Plan = "Colossus",
		Scale = 1.25,
		Colors = { C(110, 120, 170), C(80, 90, 140), C(140, 240, 255) },
		Material = "Slate",
		HP = 10,
		Speed = 5,
		Detect = 42,
		Attacks = { "Slam", "Charge" },
		Damage = 22,
		Radius = 13,
		StaggerResist = true,
		Armor = 5,
	},
	-- Floating Jungle.
	VineLurker = {
		Name = "Vine Lurker",
		Realm = "Jungle",
		Tier = "Common",
		Plan = "Serpent",
		Scale = 1,
		Colors = { C(48, 110, 60), C(70, 140, 70), C(230, 255, 90) },
		Material = "Grass",
		HP = 3,
		Speed = 12,
		Detect = 18,
		Attacks = { "Lunge" },
		Damage = 13,
		Ambush = true,
	},
	SporeSpitter = {
		Name = "Spore Spitter",
		Realm = "Jungle",
		Tier = "Elite",
		Plan = "Plant",
		Scale = 1.2,
		Colors = { C(200, 70, 120), C(60, 120, 60), C(255, 220, 90) },
		Material = "SmoothPlastic",
		HP = 4,
		Speed = 0,
		Detect = 40,
		Attacks = { "Volley" },
		Damage = 12,
		Radius = 6,
		Rooted = true,
	},
	CanopyMatriarch = {
		Name = "Canopy Matriarch",
		Realm = "Jungle",
		Tier = "Rare",
		Plan = "Quadruped",
		Scale = 1.9,
		Colors = { C(70, 90, 50), C(50, 70, 40), C(255, 180, 80) },
		Material = "Grass",
		Claws = true,
		HP = 9,
		Speed = 10,
		Detect = 44,
		Attacks = { "Charge", "Slam" },
		Damage = 20,
		Radius = 11,
		StaggerResist = true,
	},
	-- Volcanic Realm.
	EmberWisp = {
		Name = "Ember Wisp",
		Realm = "Volcanic",
		Tier = "Common",
		Plan = "Flyer",
		Scale = 0.9,
		Colors = { C(255, 120, 40), C(200, 70, 30), C(255, 210, 90) },
		Material = "Neon",
		WingMat = "Neon",
		Hover = 6,
		HP = 2,
		Speed = 11,
		Detect = 38,
		Attacks = { "Strike" },
		Damage = 14,
		Radius = 7,
		Weakness = "Aerial",
	},
	MagmaHound = {
		Name = "Magma Hound",
		Realm = "Volcanic",
		Tier = "Elite",
		Plan = "Quadruped",
		Scale = 1.3,
		Colors = { C(60, 44, 42), C(40, 30, 30), C(255, 110, 40) },
		Material = "Basalt",
		SpikeMat = "Neon",
		HP = 5,
		Speed = 13,
		Detect = 40,
		Attacks = { "Charge", "Lunge" },
		Damage = 16,
		Armor = 1,
	},
	CinderGolem = {
		Name = "Cinder Golem",
		Realm = "Volcanic",
		Tier = "Rare",
		Plan = "Colossus",
		Scale = 1.3,
		Colors = { C(54, 44, 44), C(80, 50, 40), C(255, 120, 40) },
		Material = "Basalt",
		SpikeMat = "Neon",
		HP = 11,
		Speed = 4,
		Detect = 44,
		Attacks = { "Slam", "Volley" },
		Damage = 22,
		Radius = 14,
		StaggerResist = true,
		Armor = 4,
	},
	-- Frozen Sky.
	FrostWraith = {
		Name = "Frost Wraith",
		Realm = "Frozen",
		Tier = "Common",
		Plan = "Wraith",
		Scale = 1,
		Colors = { C(200, 230, 255), C(170, 210, 240), C(140, 220, 255) },
		Material = "Ice",
		Hover = 3,
		HP = 3,
		Speed = 9,
		Detect = 34,
		Attacks = { "Slam" },
		Damage = 13,
		Radius = 9,
	},
	GlacierLynx = {
		Name = "Glacier Lynx",
		Realm = "Frozen",
		Tier = "Elite",
		Plan = "Quadruped",
		Scale = 1.1,
		Colors = { C(230, 240, 250), C(180, 200, 220), C(120, 220, 255) },
		Material = "Snow",
		SpikeMat = "Ice",
		Claws = true,
		HP = 4,
		Speed = 16,
		Detect = 44,
		Attacks = { "Lunge", "Lunge", "Blink" },
		Damage = 14,
		Radius = 7,
		Stalks = true,
	},
	RimeColossus = {
		Name = "Rime Colossus",
		Realm = "Frozen",
		Tier = "Rare",
		Plan = "Colossus",
		Scale = 1.3,
		Colors = { C(190, 220, 240), C(150, 190, 220), C(160, 240, 255) },
		Material = "Glacier",
		SpikeMat = "Ice",
		HP = 11,
		Speed = 4,
		Detect = 44,
		Attacks = { "Slam", "Volley" },
		Damage = 22,
		Radius = 14,
		StaggerResist = true,
		Armor = 4,
	},
	-- Ancient Ruins.
	DustGolem = {
		Name = "Dust Golem",
		Realm = "Ruins",
		Tier = "Common",
		Plan = "Biped",
		Scale = 1.1,
		Colors = { C(176, 156, 124), C(150, 134, 108), C(255, 210, 120) },
		Material = "Sandstone",
		HP = 4,
		Speed = 7,
		Detect = 30,
		Attacks = { "Slam" },
		Damage = 15,
		Radius = 10,
		Armor = 1,
	},
	RelicWarden = {
		Name = "Relic Warden",
		Realm = "Ruins",
		Tier = "Elite",
		Plan = "Floater",
		Scale = 1.1,
		Colors = { C(196, 182, 150), C(255, 214, 120), C(255, 230, 160) },
		Material = "Marble",
		SpikeMat = "Marble",
		Hover = 5,
		HP = 5,
		Speed = 7,
		Detect = 40,
		Attacks = { "Volley", "Blink" },
		Damage = 14,
		Radius = 6,
		Weakness = "Exposed",
	},
	SandstoneTitan = {
		Name = "Sandstone Titan",
		Realm = "Ruins",
		Tier = "Rare",
		Plan = "Colossus",
		Scale = 1.3,
		Colors = { C(200, 176, 136), C(170, 150, 116), C(255, 200, 110) },
		Material = "Sandstone",
		SpikeMat = "Marble",
		HP = 11,
		Speed = 4,
		Detect = 44,
		Attacks = { "Slam", "Charge" },
		Damage = 22,
		Radius = 14,
		StaggerResist = true,
		Armor = 4,
	},
	-- Storm Islands.
	StormSpirit = {
		Name = "Storm Wraith",
		Realm = "Storm",
		Tier = "Common",
		Plan = "Wraith",
		Scale = 1,
		Colors = { C(90, 96, 130), C(130, 140, 190), C(220, 230, 255) },
		Material = "SmoothPlastic",
		Hover = 4,
		HP = 3,
		Speed = 12,
		Detect = 38,
		Attacks = { "Strike", "Blink" },
		Damage = 14,
		Radius = 8,
		Erratic = true,
	},
	ThunderRaptor = {
		Name = "Thunder Raptor",
		Realm = "Storm",
		Tier = "Elite",
		Plan = "Flyer",
		Scale = 1.4,
		Colors = { C(60, 66, 90), C(90, 100, 130), C(200, 220, 255) },
		Material = "Slate",
		WingMat = "Neon",
		Hover = 10,
		HP = 4,
		Speed = 16,
		Detect = 48,
		Attacks = { "Dive" },
		Damage = 18,
		Radius = 7,
		Weakness = "Aerial",
	},
	TempestGuardian = {
		Name = "Tempest Guardian",
		Realm = "Storm",
		Tier = "Rare",
		Plan = "Floater",
		Scale = 2.2,
		Colors = { C(70, 76, 110), C(160, 170, 220), C(220, 230, 255) },
		Material = "Slate",
		SpikeMat = "Neon",
		Hover = 7,
		HP = 11,
		Speed = 6,
		Detect = 50,
		Attacks = { "Volley", "Slam", "Blink" },
		Damage = 20,
		Radius = 13,
		StaggerResist = true,
		Weakness = "Exposed",
	},
	-- Mechanical Realm.
	GearDrone = {
		Name = "Gear Drone",
		Realm = "Mechanical",
		Tier = "Common",
		Plan = "Floater",
		Scale = 0.8,
		Colors = { C(140, 130, 110), C(176, 140, 76), C(255, 190, 80) },
		Material = "Metal",
		SpikeMat = "Metal",
		Hover = 3,
		HP = 3,
		Speed = 13,
		Detect = 36,
		Attacks = { "Lunge" },
		Damage = 12,
	},
	PistonBrute = {
		Name = "Piston Brute",
		Realm = "Mechanical",
		Tier = "Elite",
		Plan = "Biped",
		Scale = 1.4,
		Colors = { C(110, 104, 96), C(150, 120, 70), C(255, 180, 70) },
		Material = "CorrodedMetal",
		Horns = true,
		HP = 6,
		Speed = 9,
		Detect = 40,
		Attacks = { "Charge", "Slam" },
		Damage = 18,
		Radius = 10,
		Armor = 2,
	},
	ClockworkSentinel = {
		Name = "Clockwork Sentinel",
		Realm = "Mechanical",
		Tier = "Rare",
		Plan = "Colossus",
		Scale = 1.25,
		Colors = { C(120, 126, 134), C(176, 140, 76), C(255, 200, 100) },
		Material = "Metal",
		SpikeMat = "Metal",
		HP = 11,
		Speed = 5,
		Detect = 46,
		Attacks = { "Volley", "Charge", "Slam" },
		Damage = 22,
		Radius = 13,
		StaggerResist = true,
		Armor = 5,
	},
	-- Celestial Gardens.
	StarMoth = {
		Name = "Star Moth",
		Realm = "Celestial",
		Tier = "Common",
		Plan = "Flyer",
		Scale = 1,
		Colors = { C(236, 210, 250), C(200, 170, 230), C(255, 240, 170) },
		Material = "SmoothPlastic",
		WingMat = "Glass",
		Hover = 5,
		HP = 2,
		Speed = 12,
		Detect = 36,
		Attacks = { "Strike" },
		Damage = 12,
		Radius = 7,
		Weakness = "Aerial",
		Erratic = true,
	},
	AstralSeraph = {
		Name = "Astral Seraph",
		Realm = "Celestial",
		Tier = "Elite",
		Plan = "Wraith",
		Scale = 1.3,
		Colors = { C(250, 240, 255), C(255, 230, 180), C(255, 240, 170) },
		Material = "Marble",
		Hover = 5,
		HP = 5,
		Speed = 10,
		Detect = 42,
		Attacks = { "Volley", "Blink" },
		Damage = 14,
		Radius = 6,
		Weakness = "Exposed",
	},
	EclipseSerpent = {
		Name = "Eclipse Serpent",
		Realm = "Celestial",
		Tier = "Rare",
		Plan = "Serpent",
		Scale = 2.1,
		Colors = { C(60, 40, 90), C(240, 200, 120), C(255, 236, 170) },
		Material = "Marble",
		HP = 10,
		Speed = 11,
		Detect = 48,
		Attacks = { "Charge", "Strike", "Blink" },
		Damage = 20,
		Radius = 9,
		StaggerResist = true,
	},
	-- Corrupted Void.
	VoidCrawler = {
		Name = "Void Crawler",
		Realm = "Void",
		Tier = "Common",
		Plan = "Crawler",
		Scale = 1.1,
		Colors = { C(40, 30, 60), C(70, 50, 100), C(233, 99, 255) },
		Material = "Basalt",
		SpikeMat = "Neon",
		HP = 3,
		Speed = 15,
		Detect = 20,
		Attacks = { "Lunge" },
		Damage = 14,
		Ambush = true,
	},
	GlitchPhantom = {
		Name = "Glitch Phantom",
		Realm = "Void",
		Tier = "Elite",
		Plan = "Biped",
		Scale = 1.1,
		Colors = { C(30, 20, 46), C(80, 40, 120), C(233, 99, 255) },
		Material = "Neon",
		HP = 5,
		Speed = 12,
		Detect = 44,
		Attacks = { "Blink", "Lunge", "Blink" },
		Damage = 16,
		Radius = 9,
		Erratic = true,
	},
	Anomaly = {
		Name = "Deletion Sentinel",
		Realm = "Void",
		Tier = "Rare",
		Plan = "Colossus",
		Scale = 1.35,
		Colors = { C(30, 20, 46), C(60, 30, 90), C(233, 99, 255) },
		Material = "Basalt",
		SpikeMat = "Neon",
		HP = 12,
		Speed = 6,
		Detect = 50,
		Attacks = { "Blink", "Volley", "Slam" },
		Damage = 24,
		Radius = 13,
		StaggerResist = true,
		Armor = 4,
	},
}
-- World boss: the Realm Destroyer is catalogued here with the realm creatures, but it is never
-- spawned through Creatures/Ecology. Systems/RealmDestroyer drives it; the client renders it.
do
	local Dragon = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").DragonConfig)
	local entry = Dragon.Bestiary
	defs.RealmDestroyer = {
		Name = entry.Name,
		Realm = "Sky", -- Every realm (see Encounters); not part of any realm's ecology roster.
		Tier = "WorldBoss",
		Category = entry.Category,
		Rarity = entry.Rarity,
		Encounters = entry.Realms,
		Abilities = entry.Abilities,
		WeakPoints = entry.WeakPoints,
		RewardText = entry.RewardText,
		Discovery = Dragon.Discovery,
		Plan = "WorldBoss",
		Scale = 1,
		Colors = { C(150, 24, 20), C(60, 26, 24), C(255, 170, 60) },
		Material = "Slate",
		HP = Dragon.Tiers[1].HP,
		Speed = 0,
		Detect = 0,
		Attacks = { "FireBreath", "Dive", "WingGust", "GroundSlam", "EmberRain", "InfernoSweep" },
		Damage = Dragon.Attacks.FireBreath.Damage,
		Weakness = "WeakPoints",
	}
end
Bestiary.Defs = defs
for id, def in defs do
	def.Id = id
	def.Radius = def.Radius or 8
	def.Weakness = def.Weakness or "Dash"
	def.Glow = def.Colors[3]
	def.Attack = def.Attacks[1]
end
-- Realm roster: common, elite, rare.
Bestiary.Realms = {}
for id, def in defs do
	local roster = Bestiary.Realms[def.Realm] or {}
	Bestiary.Realms[def.Realm] = roster
	roster[def.Tier] = id
end
Bestiary.Rewards = {
	Common = { Coins = 6, XP = 15 },
	Elite = { Coins = 14, XP = 35, Relic = 1 },
	Rare = { Coins = 35, XP = 80, Relic = 2, Perk = true },
}
function Bestiary.get(id)
	return defs[id] or defs.BrambleStalker
end
function Bestiary.parts(def)
	local plan = plans[def.Plan]
	assert(plan, def.Id .. " has no creature body plan (world bosses are rendered by their own system)")
	return plan(def)
end
return Bestiary
