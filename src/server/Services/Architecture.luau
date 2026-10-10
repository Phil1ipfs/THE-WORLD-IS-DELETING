--!nonstrict
-- Realm-styled shelter houses. The collidable shell keeps the established shelter
-- footprint (VillageWall / VillageRoof / GabledRoof); everything else is HouseDetail.
local Props = require(script.Parent.Props)
local Architecture = {}
local C = Color3.fromRGB
local styles = {
	Cottage = {
		Wall = C(232, 220, 196),
		WallMat = "Plaster",
		Frame = C(84, 58, 40),
		Roof = C(150, 72, 52),
		RoofMat = "RoofShingles",
		Base = C(128, 124, 118),
		BaseMat = "Cobblestone",
		Window = C(255, 214, 140),
		Chimney = "Brick",
		Timbered = true,
		Shutters = C(76, 116, 92),
		Flowers = true,
	},
	Pavilion = {
		Wall = C(222, 230, 242),
		WallMat = "Marble",
		Frame = C(150, 186, 232),
		Roof = C(122, 160, 214),
		RoofMat = "Glass",
		Base = C(200, 210, 228),
		BaseMat = "Marble",
		Window = C(150, 236, 255),
		Crystals = true,
	},
	Stilt = {
		Wall = C(150, 110, 70),
		WallMat = "WoodPlanks",
		Frame = C(96, 72, 44),
		Roof = C(190, 160, 92),
		RoofMat = "Grass",
		Base = C(96, 80, 60),
		BaseMat = "Wood",
		Window = C(255, 200, 120),
		Poles = true,
		Timbered = true,
	},
	Bunker = {
		Wall = C(64, 56, 54),
		WallMat = "Basalt",
		Frame = C(40, 34, 34),
		Roof = C(54, 48, 48),
		RoofMat = "Slate",
		Base = C(44, 38, 38),
		BaseMat = "Basalt",
		Window = C(255, 140, 60),
		Chimney = "Basalt",
		Seams = C(255, 110, 40),
	},
	Lodge = {
		Wall = C(120, 86, 60),
		WallMat = "Wood",
		Frame = C(84, 60, 42),
		Roof = C(236, 242, 248),
		RoofMat = "Snow",
		Base = C(140, 146, 154),
		BaseMat = "Slate",
		Window = C(255, 214, 150),
		Chimney = "Slate",
		Logs = true,
		Icicles = true,
	},
	Stone = {
		Wall = C(198, 182, 150),
		WallMat = "Sandstone",
		Frame = C(160, 144, 116),
		Roof = C(176, 92, 62),
		RoofMat = "ClayRoofTiles",
		Base = C(150, 138, 116),
		BaseMat = "Sandstone",
		Window = C(255, 206, 140),
		Columns = true,
	},
	Watch = {
		Wall = C(102, 110, 128),
		WallMat = "Slate",
		Frame = C(64, 70, 84),
		Roof = C(70, 76, 92),
		RoofMat = "Metal",
		Base = C(84, 90, 104),
		BaseMat = "Slate",
		Window = C(200, 220, 255),
		Rod = true,
		Shutters = C(60, 66, 80),
	},
	Workshop = {
		Wall = C(132, 122, 112),
		WallMat = "CorrodedMetal",
		Frame = C(96, 100, 108),
		Roof = C(140, 146, 152),
		RoofMat = "DiamondPlate",
		Base = C(90, 92, 96),
		BaseMat = "Metal",
		Window = C(255, 200, 100),
		Chimney = "Metal",
		Pipes = true,
	},
	Pagoda = {
		Wall = C(244, 238, 248),
		WallMat = "Plaster",
		Frame = C(176, 64, 72),
		Roof = C(150, 112, 184),
		RoofMat = "ClayRoofTiles",
		Base = C(226, 218, 232),
		BaseMat = "Marble",
		Window = C(255, 236, 170),
		Eaves = C(255, 214, 120),
	},
	Obelisk = {
		Wall = C(46, 38, 62),
		WallMat = "Basalt",
		Frame = C(28, 22, 40),
		Roof = C(32, 26, 48),
		RoofMat = "Slate",
		Base = C(36, 30, 50),
		BaseMat = "Basalt",
		Window = C(233, 99, 255),
		Seams = C(200, 90, 255),
	},
}
Architecture.Styles = styles
-- shell(name, size, position, color, material) builds collidable shell parts.
function Architecture.house(B, base, style, shell, accent)
	local s = styles[style] or styles.Cottage
	local function at(x, y, z)
		return base + Vector3.new(x, y, z)
	end
	local function d(size, cf, color, mat, o)
		return B.part("HouseDetail", size, cf, color, mat, o)
	end
	-- Collidable shell: identical footprint to the original shelter.
	for _, wall in
		{
			{ -13, 6, 0, 1, 12, 22 },
			{ 13, 6, 0, 1, 12, 22 },
			{ 0, 6, -11, 26, 12, 1 },
			{ -9, 6, 11, 8, 12, 1 },
			{ 9, 6, 11, 8, 12, 1 },
			{ 0, 11, 11, 10, 2, 1 },
		}
	do
		shell(
			"VillageWall",
			Vector3.new(wall[4], wall[5], wall[6]),
			at(wall[1], wall[2], wall[3]),
			s.Wall,
			s.WallMat
		)
	end
	shell("VillageRoof", Vector3.new(28, 2, 24), at(0, 13, 0), s.Frame, "WoodPlanks")
	for _, side in { -1, 1 } do
		local roof = shell("GabledRoof", Vector3.new(15, 1, 26), at(side * 7, 17, 0), s.Roof, s.RoofMat)
		roof.CFrame *= CFrame.Angles(0, 0, -side * 0.35)
		if s.RoofMat == "Glass" then
			roof.Transparency = 0.2
		end
	end
	-- Gable end triangles and ridge beam.
	for _, z in { -11.6, 11.6 } do
		for _, side in { -1, 1 } do
			d(
				Vector3.new(0.6, 5.2, 13.2),
				CFrame.new(at(0, 14, z)) * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, 2.6, -6.6),
				s.Wall,
				s.WallMat,
				{ Class = "WedgePart" }
			)
		end
	end
	d(Vector3.new(0.9, 0.9, 27), CFrame.new(at(0, 19.6, 0)), s.Frame, "Wood")
	-- Foundation skirt.
	for _, f in { { 0, -12, 28, 1.6 }, { 0, 12, 28, 1.6 } } do
		d(Vector3.new(f[3], 1.2, f[4]), CFrame.new(at(f[1], 0.5, f[2])), s.Base, s.BaseMat)
	end
	for _, x in { -14, 14 } do
		d(Vector3.new(1.6, 1.2, 25.6), CFrame.new(at(x, 0.5, 0)), s.Base, s.BaseMat)
	end
	-- Corner posts and beams.
	for _, x in { -13.3, 13.3 } do
		for _, z in { -11.3, 11.3 } do
			d(Vector3.new(1.3, 13, 1.3), CFrame.new(at(x, 6.5, z)), s.Frame, "Wood")
		end
	end
	for _, y in { 2, 9 } do
		for _, z in { -11.6, 11.6 } do
			d(Vector3.new(27, 0.9, 0.5), CFrame.new(at(0, y, z)), s.Frame, "Wood")
		end
	end
	if s.Timbered then
		for _, x in { -13.6, 13.6 } do
			for _, dir in { -1, 1 } do
				d(
					Vector3.new(0.4, 0.6, 9.5),
					CFrame.new(at(x, 5.5, dir * 5)) * CFrame.Angles(dir * 0.62, 0, 0),
					s.Frame,
					"Wood"
				)
			end
		end
	end
	if s.Logs then
		for y = 1.5, 11, 1.6 do
			for _, z in { -11.7, 11.7 } do
				if z < 0 or y > 10 then
					d(
						Vector3.new(27.4, 1.3, 1.3),
						CFrame.new(at(0, y, z)) * CFrame.Angles(0, 0, 0),
						s.Wall,
						"Wood",
						{ Shape = "Cylinder" }
					)
				end
			end
		end
	end
	-- Windows: side and back walls, framed and lit. Breach anchors reuse the windows.
	local breaches = {}
	local windows = {
		{ CFrame.new(at(-13.6, 6.5, 0)) * CFrame.Angles(0, math.pi / 2, 0), -1 },
		{ CFrame.new(at(13.6, 6.5, 0)) * CFrame.Angles(0, -math.pi / 2, 0), 1 },
		{ CFrame.new(at(-6, 6.5, -11.6)), 0 },
		{ CFrame.new(at(6, 6.5, -11.6)), 0 },
	}
	for _, w in windows do
		local cf = w[1]
		d(Vector3.new(3.6, 3.8, 0.2), cf, s.Window, "Neon", { Transparency = 0.45 })
		for _, frame in
			{
				{ 0, 2.1, 4.4, 0.4 },
				{ 0, -2.1, 4.4, 0.6 },
				{ -2.1, 0, 0.4, 4.2 },
				{ 2.1, 0, 0.4, 4.2 },
				{ 0, 0, 0.25, 3.8 },
			}
		do
			d(
				Vector3.new(frame[3], frame[4], 0.4),
				cf * CFrame.new(frame[1], frame[2], -0.15),
				s.Frame,
				"Wood"
			)
		end
		if s.Shutters then
			for _, side in { -1, 1 } do
				d(Vector3.new(1.8, 3.8, 0.2), cf * CFrame.new(side * 3.2, 0, -0.25), s.Shutters, "WoodPlanks")
			end
		end
		if s.Flowers then
			d(Vector3.new(4, 0.8, 1), cf * CFrame.new(0, -2.6, -0.6), s.Frame, "WoodPlanks")
			for k = -1, 1 do
				d(
					Vector3.new(0.9, 0.7, 0.8),
					cf * CFrame.new(k * 1.2, -2, -0.6),
					if k == 0 then C(240, 120, 150) else C(250, 214, 92),
					"SmoothPlastic",
					{ Mesh = "Sphere" }
				)
			end
		end
		table.insert(breaches, cf)
	end
	-- Door frame, open door, porch and awning.
	for _, x in { -5.3, 5.3 } do
		d(Vector3.new(0.7, 10.4, 1.4), CFrame.new(at(x, 5.2, 11.2)), s.Frame, "Wood")
	end
	d(Vector3.new(11.4, 0.8, 1.4), CFrame.new(at(0, 10.2, 11.2)), s.Frame, "Wood")
	d(Vector3.new(0.35, 9.6, 4.6), CFrame.new(at(-5.6, 4.9, 8.6)), s.Frame:Lerp(s.Wall, 0.2), "WoodPlanks")
	d(
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(at(-5.3, 4.8, 6.6)),
		C(200, 170, 90),
		"Metal",
		{ Shape = "Ball" }
	)
	d(
		Vector3.new(14, 0.35, 5),
		CFrame.new(at(0, 0.45, 13.8)),
		s.Frame:Lerp(C(150, 110, 70), 0.4),
		"WoodPlanks"
	)
	for _, x in { -6.6, 6.6 } do
		d(Vector3.new(0.6, 9, 0.6), CFrame.new(at(x, 4.6, 15.8)), s.Frame, "Wood")
	end
	d(Vector3.new(14.4, 0.5, 6), CFrame.new(at(0, 9.6, 13.9)) * CFrame.Angles(0.22, 0, 0), s.Roof, s.RoofMat)
	Props.lantern(B, at(7.6, 0.6, 15.2), s.Window, 6.4)
	-- Chimney with smoke.
	if s.Chimney then
		d(Vector3.new(3.4, 8, 3.4), CFrame.new(at(8, 19, -5)), s.Base, s.Chimney)
		local cap = d(Vector3.new(4.2, 0.7, 4.2), CFrame.new(at(8, 23.2, -5)), s.Frame, s.Chimney)
		B.emitter(
			cap,
			"rbxasset://textures/particles/smoke_main.dds",
			C(200, 200, 205),
			1.6,
			{ 4, 6 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) }),
			{ 2, 3 },
			{
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.6),
					NumberSequenceKeypoint.new(1, 1),
				}),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(10, 10),
			}
		)
	end
	-- Style signatures.
	if s.Rod then
		d(Vector3.new(0.4, 12, 0.4), CFrame.new(at(0, 26, -2)), C(180, 186, 196), "Metal")
		d(Vector3.new(1, 1, 1), CFrame.new(at(0, 32.3, -2)), C(200, 210, 255), "Neon", { Shape = "Ball" })
	end
	if s.Pipes then
		B.limb("HouseDetail", at(14, 2, -8), at(14, 16, -8), 1.2, C(110, 104, 96), "CorrodedMetal")
		B.limb("HouseDetail", at(14, 16, -8), at(10, 16, -8), 1.2, C(110, 104, 96), "CorrodedMetal")
		Props.gear(
			B,
			CFrame.new(at(-14.2, 8, -6)) * CFrame.Angles(0, 0, 0),
			2.4,
			C(176, 140, 76),
			"HouseDetail"
		)
	end
	if s.Seams then
		for _, x in { -13.6, 13.6 } do
			d(Vector3.new(0.15, 11, 0.3), CFrame.new(at(x, 6, -6)), s.Seams, "Neon")
			d(Vector3.new(0.15, 0.3, 10), CFrame.new(at(x, 10.5, 0)), s.Seams, "Neon")
		end
	end
	if s.Columns then
		for _, x in { -6.6, 6.6 } do
			d(Vector3.new(2, 9, 2), CFrame.new(at(x, 4.6, 15.8)), s.Wall, s.WallMat, { Shape = "Cylinder" }).CFrame = CFrame.new(
				at(x, 4.6, 15.8)
			) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end
	if s.Eaves then
		for _, side in { -1, 1 } do
			d(
				Vector3.new(4, 0.6, 27),
				CFrame.new(at(side * 14.6, 14.6, 0)) * CFrame.Angles(0, 0, side * 0.45),
				s.Roof,
				s.RoofMat
			)
			d(
				Vector3.new(0.4, 0.4, 27),
				CFrame.new(at(side * 16.2, 15.4, 0)),
				s.Eaves,
				"Neon",
				{ Transparency = 0.3 }
			)
		end
	end
	if s.Icicles then
		for k = -6, 6 do
			d(
				Vector3.new(0.3, B.Rng:range(0.8, 2.2), 0.3),
				CFrame.new(at(k * 2, 13.4, 12.6)),
				C(210, 236, 255),
				"Ice",
				{ Transparency = 0.2 }
			)
		end
	end
	if s.Poles then
		for _, x in { -15, 15 } do
			for _, z in { -13, 13 } do
				B.limb("HouseDetail", at(x, -0.5, z), at(x, 16, z), 0.7, C(170, 150, 90), "Wood")
			end
		end
	end
	if s.Crystals then
		for _, x in { -15, 15 } do
			Props.shard(B, CFrame.new(at(x, 0, 12)), Vector3.new(1.6, 6, 1.6), accent, true, "HouseDetail")
		end
	end
	-- Interior: floorboards, rug, bed, table, chairs, shelf, chest and lamp.
	d(
		Vector3.new(25, 0.1, 21),
		CFrame.new(at(0, 0.3, 0)),
		s.Frame:Lerp(C(160, 120, 80), 0.5),
		"WoodPlanks",
		{ Shadow = false }
	)
	d(
		Vector3.new(9, 0.08, 6),
		CFrame.new(at(0, 0.38, 2)),
		accent:Lerp(C(150, 60, 50), 0.5),
		"Fabric",
		{ Shadow = false }
	)
	d(Vector3.new(5, 1.4, 8), CFrame.new(at(-9.5, 1.1, -5)), s.Frame, "WoodPlanks")
	d(Vector3.new(4.6, 0.8, 7.4), CFrame.new(at(-9.5, 2.1, -5)), C(236, 232, 220), "Fabric")
	d(
		Vector3.new(4.7, 0.5, 4.4),
		CFrame.new(at(-9.5, 2.5, -3.4)),
		accent:Lerp(C(90, 110, 160), 0.6),
		"Fabric"
	)
	d(Vector3.new(3.6, 0.6, 1.4), CFrame.new(at(-9.5, 2.6, -8.2)), C(250, 248, 240), "Fabric")
	d(Vector3.new(5.5, 0.5, 3.5), CFrame.new(at(5, 3, -4)), s.Frame, "WoodPlanks")
	for _, x in { 3, 7 } do
		d(Vector3.new(0.4, 2.8, 0.4), CFrame.new(at(x, 1.6, -4)), s.Frame, "Wood")
	end
	for _, z in { -6.5, -1.5 } do
		d(Vector3.new(2, 0.4, 2), CFrame.new(at(5, 1.9, z)), s.Frame, "WoodPlanks")
		d(
			Vector3.new(2, 2.4, 0.3),
			CFrame.new(at(5, 3.1, z + (if z < -4 then -0.9 else 0.9))),
			s.Frame,
			"WoodPlanks"
		)
	end
	local lamp =
		d(Vector3.new(0.8, 1.2, 0.8), CFrame.new(at(5, 3.9, -4)), s.Window, "Neon", { Transparency = 0.2 })
	B.light(lamp, s.Window, 14, 0.7)
	d(Vector3.new(6, 7, 1.6), CFrame.new(at(9, 3.8, -10)), s.Frame, "WoodPlanks")
	for k, y in { 2.2, 4.4, 6.6 } do
		for j = -2, 2 do
			d(
				Vector3.new(0.7, 1.4, 1),
				CFrame.new(at(9 + j * 1.05, y + 0.4, -9.6)),
				C(120 + k * 30, 70 + j * 20, 60 + k * 20),
				"Fabric"
			)
		end
	end
	Props.crate(B, CFrame.new(at(11, 1.6, 6)), 2.4)
	Props.barrel(B, CFrame.new(at(-11, 1.6, 7)), 2.2)
	-- Exterior storytelling clutter.
	Props.barrel(B, CFrame.new(at(-15.5, 1.4, 9)), 2)
	Props.crate(B, CFrame.new(at(15.6, 1.4, 6)) * CFrame.Angles(0, 0.4, 0), 2.2)
	return breaches
end
return Architecture
