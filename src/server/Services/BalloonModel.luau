--!nonstrict
-- Sky Balloon visuals built from native parts (no mesh assets exist yet): a striped envelope
-- with gold bands, crown and medallions, a wicker-and-timber gondola, rope rigging, hanging
-- lanterns and a magical burner/propulsion rig. Every part is anchored and non-colliding; the
-- SkyBalloon system moves the whole model with PivotTo (pivot = gondola base on the ground).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local BalloonConfig = require(Shared.BalloonConfig)
local SoundBank = require(Shared.SoundBank)
local G = require(script.Parent.Geometry)
local Model = {}
local C = Color3.fromRGB
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local ENVELOPE_Y, ENVELOPE = 27, Vector3.new(22, 26, 22)
local function color(rgb)
	return C(rgb[1], rgb[2], rgb[3])
end
-- Builds a balloon whose gondola base sits at `base` (CFrame on the ground). Returns
-- { Model, Burner, Propulsion, Label, Variant }.
function Model.build(parent, base, variantName)
	local variant = BalloonConfig.Variants[variantName] or BalloonConfig.Variants.Navy
	local fabric, stripe, trim = color(variant.Envelope), color(variant.Stripe), color(variant.Trim)
	local wood, wicker, rope = C(112, 78, 48), C(176, 136, 84), C(196, 172, 128)
	local model = Instance.new("Model")
	model.Name = "SkyBalloon"
	model:SetAttribute("Variant", variantName)
	local function part(name, size, offset, tint, material, shape, mesh)
		local p = G.part(model, name, size, base * offset, tint, material, false)
		p.CanQuery = false
		if shape then
			p.Shape = Enum.PartType[shape]
		end
		if mesh then
			local m = Instance.new("SpecialMesh")
			m.MeshType, m.Parent = Enum.MeshType[mesh], p
		end
		return p
	end
	-- Vertical cylinder (Roblox cylinders run along X).
	local function disc(name, height, diameter, offset, tint, material)
		return part(
			name,
			Vector3.new(height, diameter, diameter),
			offset * CFrame.Angles(0, 0, math.pi / 2),
			tint,
			material,
			"Cylinder"
		)
	end
	local function line(name, a, b, thickness, tint, material)
		local p = part(
			name,
			Vector3.new(thickness, thickness, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b),
			tint,
			material or Enum.Material.Fabric
		)
		p.CastShadow = false
		return p
	end
	-- Gondola: plank floor, wicker walls with timber corner posts and a gold rim.
	local deck = part(
		"BalloonGondola",
		Vector3.new(7.6, 0.6, 7.6),
		CFrame.new(0, 0.9, 0),
		wood,
		Enum.Material.WoodPlanks
	)
	model.PrimaryPart = deck
	for _, side in
		{ { 0, 3.65, 7.6, 0.5 }, { 0, -3.65, 7.6, 0.5 }, { 3.65, 0, 0.5, 7.6 }, { -3.65, 0, 0.5, 7.6 } }
	do
		part(
			"GondolaWall",
			Vector3.new(side[3], 2.8, side[4]),
			CFrame.new(side[1], 2.5, side[2]),
			wicker,
			Enum.Material.Fabric
		)
		part(
			"GondolaRim",
			Vector3.new(side[3] + 0.3, 0.35, side[4] + 0.3),
			CFrame.new(side[1], 4, side[2]),
			trim,
			Enum.Material.Metal
		)
	end
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local cx, cz = corner[1] * 3.75, corner[2] * 3.75
		part("GondolaPost", Vector3.new(0.6, 3.6, 0.6), CFrame.new(cx, 2.4, cz), wood, Enum.Material.Wood)
		-- Load ropes up to the burner ring, then the envelope rigging.
		line("BalloonRope", Vector3.new(cx, 4.1, cz), Vector3.new(cx * 0.55, 10.2, cz * 0.55), 0.18, rope)
		line(
			"BalloonRope",
			Vector3.new(cx * 0.55, 10.2, cz * 0.55),
			Vector3.new(cx * 2.05, 17.5, cz * 2.05),
			0.16,
			rope
		)
		-- Hanging lantern on each outside corner.
		local hang = Vector3.new(corner[1] * 4.4, 3.6, corner[2] * 4.4)
		line(
			"LanternCord",
			Vector3.new(corner[1] * 3.9, 4.1, corner[2] * 3.9),
			hang + Vector3.new(0, 0.6, 0),
			0.08,
			rope
		)
		part("Lantern", Vector3.new(0.7, 0.9, 0.7), CFrame.new(hang), trim, Enum.Material.Metal)
		part(
			"LanternGlow",
			Vector3.new(0.5, 0.6, 0.5),
			CFrame.new(hang),
			C(255, 196, 110),
			Enum.Material.Neon
		)
	end
	-- Burner ring and magical flame.
	disc("BurnerRing", 0.4, 5.6, CFrame.new(0, 10.2, 0), trim, Enum.Material.Metal)
	local burner = disc("Burner", 1.6, 2.4, CFrame.new(0, 9.2, 0), C(120, 96, 60), Enum.Material.Metal)
	local flame = part(
		"BurnerFlame",
		Vector3.new(1.6, 2.2, 1.6),
		CFrame.new(0, 10.9, 0),
		C(255, 214, 120),
		Enum.Material.Neon,
		nil,
		"Sphere"
	)
	flame.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Parent = C(255, 196, 120), 20, 1.4, flame
	local fire = Instance.new("ParticleEmitter")
	fire.Name, fire.Texture = "MagicFlame", SPARK
	fire.Color = ColorSequence.new(C(255, 220, 140), C(140, 210, 255))
	fire.LightEmission, fire.Rate = 0.9, 10
	fire.Lifetime, fire.Speed = NumberRange.new(0.5, 0.9), NumberRange.new(3, 6)
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Parent = flame
	-- Low burner roar (3D, tagged so clients route it through their SFX volume).
	local burnerSound = SoundBank.make(function(class)
		return Instance.new(class)
	end, SoundBank.Loops.BalloonBurner, flame, "BurnerSound")
	pcall(function()
		game:GetService("CollectionService"):AddTag(burnerSound, "RealmSound")
	end)
	burnerSound:Play()
	-- Envelope: fabric ellipsoid with cream gores (thin ellipsoids that surface as vertical stripes).
	local envelope = part(
		"BalloonEnvelope",
		ENVELOPE,
		CFrame.new(0, ENVELOPE_Y, 0),
		fabric,
		Enum.Material.Fabric,
		nil,
		"Sphere"
	)
	envelope.CastShadow = true
	for k = 0, 3 do
		part(
			"EnvelopeStripe",
			Vector3.new(3.2, ENVELOPE.Y + 0.25, ENVELOPE.Z + 0.7),
			CFrame.new(0, ENVELOPE_Y, 0) * CFrame.Angles(0, k * math.pi / 4, 0),
			stripe,
			Enum.Material.Fabric,
			nil,
			"Sphere"
		)
	end
	-- Gold equator band, crown band, finial and four medallions.
	disc("EnvelopeBand", 0.7, ENVELOPE.X + 0.5, CFrame.new(0, ENVELOPE_Y, 0), trim, Enum.Material.Metal)
	disc("EnvelopeBand", 0.5, 19.2, CFrame.new(0, ENVELOPE_Y + 7, 0), trim, Enum.Material.Metal)
	part(
		"EnvelopeFinial",
		Vector3.new(2.2, 2.2, 2.2),
		CFrame.new(0, ENVELOPE_Y + 13.6, 0),
		trim,
		Enum.Material.Metal,
		"Ball"
	)
	disc("EnvelopeFinial", 2.4, 0.5, CFrame.new(0, ENVELOPE_Y + 15.6, 0), trim, Enum.Material.Metal)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local face = CFrame.new(0, ENVELOPE_Y, 0)
			* CFrame.Angles(0, a, 0)
			* CFrame.new(0, 0, -ENVELOPE.X / 2 - 0.15)
		part(
			"Medallion",
			Vector3.new(0.35, 3.4, 3.4),
			face * CFrame.Angles(0, math.pi / 2, 0),
			trim,
			Enum.Material.Metal,
			"Cylinder"
		)
		part(
			"MedallionSigil",
			Vector3.new(0.4, 1.4, 1.4),
			face * CFrame.Angles(0, math.pi / 2, 0),
			C(140, 220, 255),
			Enum.Material.Neon,
			"Cylinder"
		)
	end
	-- Skirt (throat) under the envelope.
	disc("EnvelopeSkirt", 4, 8.4, CFrame.new(0, ENVELOPE_Y - 14.4, 0), stripe, Enum.Material.Fabric)
	disc("EnvelopeBand", 0.4, 8.8, CFrame.new(0, ENVELOPE_Y - 16.3, 0), trim, Enum.Material.Metal)
	-- Magical propulsion: rune ring under the gondola, a rear propeller and a sparkle trail.
	local ring =
		disc("PropulsionRing", 0.2, 6.4, CFrame.new(0, 0.45, 0), C(140, 220, 255), Enum.Material.Neon)
	ring.Transparency = 0.45
	local trail = Instance.new("ParticleEmitter")
	trail.Name, trail.Texture = "Propulsion", SPARK
	trail.Color = ColorSequence.new(C(160, 230, 255), C(255, 220, 150))
	trail.LightEmission, trail.Rate, trail.Enabled = 0.8, 18, false
	trail.Lifetime, trail.Speed = NumberRange.new(0.8, 1.6), NumberRange.new(2, 5)
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	trail.EmissionDirection = Enum.NormalId.Bottom
	trail.Parent = ring
	-- Cylinder axis along local Z so the spinner (X-axis rotation) turns the blades in the XY plane.
	local hub = part(
		"PropellerHub",
		Vector3.new(0.8, 1, 1),
		CFrame.new(0, 2.4, 4.6) * CFrame.Angles(0, math.pi / 2, 0),
		trim,
		Enum.Material.Metal,
		"Cylinder"
	)
	local key = "Propeller"
		.. tostring(math.floor(base.Position.X))
		.. ":"
		.. tostring(math.floor(base.Position.Z))
	hub:SetAttribute("Spin", 2.4)
	hub:SetAttribute("SpinKey", key)
	for k = 0, 2 do
		local blade = part(
			"PropellerBlade",
			Vector3.new(0.2, 3, 0.7),
			CFrame.new(0, 2.4, 4.75) * CFrame.Angles(0, 0, k * math.pi * 2 / 3) * CFrame.new(0, 1.5, 0),
			wood,
			Enum.Material.Wood
		)
		blade:SetAttribute("SpinKey", key)
	end
	-- Floating station sign; the SkyBalloon system rewrites it with the live countdown.
	local sign = part("BalloonSign", Vector3.one, CFrame.new(0, 6.5, 0), trim, nil)
	sign.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.MaxDistance, gui.AlwaysOnTop = UDim2.fromOffset(260, 64), 90, false
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Font, label.TextSize, label.TextColor3 = Enum.Font.GothamBold, 17, C(255, 222, 150)
	label.TextStrokeTransparency, label.Text = 0.35, "SKY BALLOON\nBoard for the next realm"
	label.Parent = gui
	model.Parent = parent
	return {
		Model = model,
		Burner = burner,
		Flame = flame,
		Propulsion = trail,
		Label = label,
		Variant = variantName,
	}
end
-- Mooring dock that stays with the region (pivot = gondola base on the ground).
function Model.dock(make, base, gold)
	local wood = C(112, 78, 48)
	local parts = {}
	local platform = make(
		"BalloonDock",
		Vector3.new(0.6, 12, 12),
		base * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		wood,
		Enum.Material.WoodPlanks
	)
	platform.Shape = Enum.PartType.Cylinder
	table.insert(parts, platform)
	for _, side in { -1, 1 } do
		local post = make(
			"MooringPost",
			Vector3.new(0.9, 6, 0.9),
			base * CFrame.new(side * 6.4, 3, 0),
			wood,
			Enum.Material.Wood
		)
		table.insert(parts, post)
		local cap = make(
			"MooringPost",
			Vector3.new(1.3, 0.5, 1.3),
			base * CFrame.new(side * 6.4, 6.2, 0),
			gold,
			Enum.Material.Metal
		)
		table.insert(parts, cap)
	end
	return parts
end
return Model
