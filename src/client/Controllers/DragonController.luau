--!nonstrict
-- Client renderer for the Realm Destroyer. The server publishes only state (attributes on
-- ReplicatedStorage.RealmDestroyer); this controller builds a local procedural rig from native
-- parts and animates it every frame: smoothed flight, a curved neck that ends at the server's
-- head point, jaw, horns, four limbs, articulated wings (bones + triangulated membranes), a
-- swaying spiked tail, layered scales, glowing eyes and weak-point glows. It also renders fire
-- breath, roars (camera shake), impacts, meteors and Dragonbane shot tracers.
-- PROTOTYPE ART: this is a part-built stand-in for a rigged MeshPart dragon (none exists yet).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rig = require(Shared.DragonRig)
local SoundBank = require(Shared.SoundBank)
local Audio = require(script.Parent.AudioController)
local Dragon = {}
Dragon.__index = Dragon
local C = Color3.fromRGB
local SCALE, SCALE_DARK, BELLY, PLATE = C(150, 24, 20), C(104, 14, 12), C(196, 112, 54), C(214, 146, 78)
local HORN, MEMBRANE, CLAW, EYE = C(52, 34, 30), C(118, 20, 18), C(232, 220, 196), C(255, 176, 40)
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local function v3(p)
	return Vector3.new(p.X, p.Y, p.Z)
end
function Dragon.new(settings, fx)
	local self = setmetatable({
		Settings = settings,
		Fx = fx,
		Parts = {},
		Built = false,
		Visible = false,
		Time = 0,
		Smooth = nil,
		Params = { Flap = 0.5, Speed = 2.2, Fold = 0.2, Sweep = 0.1, Spread = 1, Jaw = 0.05, Legs = 1 },
		HeadOffset = v3(Rig.head(nil)),
		Frame = 0,
		Shake = 0,
	}, Dragon)
	return self
end
-- Construction -----------------------------------------------------------------------------
function Dragon:part(name, size, color, material, o)
	o = o or {}
	local p = Instance.new(o.Class or "Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size, p.Color = size, color
	p.Material = material or Enum.Material.Slate
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = o.Shadow == true
	p.Transparency = o.Transparency or 0
	if o.Shape then
		p.Shape = Enum.PartType[o.Shape]
	end
	if o.Mesh then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType, mesh.Parent = Enum.MeshType[o.Mesh], p
	end
	p:SetAttribute("Detail", o.Detail == true)
	p.Parent = self.Model
	table.insert(self.Parts, p)
	return p
end
-- A body-space attachment: the part follows root * offset every frame.
function Dragon:fixed(name, size, offset, color, material, o)
	local p = self:part(name, size, color, material, o)
	table.insert(self.Fixed, { Part = p, Offset = offset })
	return p
end
function Dragon:build()
	self.Built = true
	self.Model = Instance.new("Model")
	self.Model.Name = "RealmDestroyerVisual"
	self.Fixed = {}
	-- Torso: chest, hips, belly and shoulder mass.
	self:fixed(
		"Chest",
		Vector3.new(15, 13, 17),
		CFrame.new(0, 0.5, -9),
		SCALE,
		nil,
		{ Mesh = "Sphere", Shadow = true }
	)
	self:fixed(
		"Hips",
		Vector3.new(13, 11, 15),
		CFrame.new(0, 0.5, 9),
		SCALE,
		nil,
		{ Mesh = "Sphere", Shadow = true }
	)
	self:fixed("Belly", Vector3.new(11, 9, 26), CFrame.new(0, -2.6, 0), BELLY, nil, { Mesh = "Sphere" })
	for _, s in { -1, 1 } do
		self:fixed(
			"Shoulder",
			Vector3.new(6, 6.5, 8),
			CFrame.new(s * 6.4, 3, -9),
			SCALE_DARK,
			nil,
			{ Mesh = "Sphere" }
		)
	end
	for k = 0, 5 do
		local z = -12 + k * 4.8
		self:fixed(
			"BellyPlate",
			Vector3.new(8.4 - math.abs(k - 2.5) * 0.6, 0.6, 3.6),
			CFrame.new(0, -7 + math.abs(k - 2.5) * 0.25, z) * CFrame.Angles((k - 2.5) * 0.05, 0, 0),
			PLATE
		)
	end
	-- Spine spikes and layered flank scales (shingled wedges, detail-culled).
	for k = 0, 8 do
		local z = -15 + k * 3.7
		local h = 4 - math.abs(k - 4) * 0.35
		self:fixed(
			"SpineSpike",
			Vector3.new(0.9, h, 3.2),
			CFrame.new(0, 6.4 + h / 2 - math.abs(k - 3) * 0.2, z) * CFrame.Angles(0, math.pi, 0),
			HORN,
			nil,
			{ Class = "WedgePart" }
		)
	end
	for _, s in { -1, 1 } do
		for row, y in { 3.2, -0.6 } do
			for k = 0, 6 do
				local z = -14 + k * 4.6 + (row - 1) * 2.3
				local width = 6.6 - math.abs(z) * 0.04
				self:fixed(
					"FlankScale",
					Vector3.new(0.5, 3, 4.4),
					CFrame.new(s * width, y, z)
						* CFrame.Angles(0, 0, s * (0.25 + row * 0.15))
						* CFrame.Angles(math.pi, 0, 0),
					if (k + row) % 2 == 0 then SCALE_DARK else SCALE,
					nil,
					{ Class = "WedgePart", Detail = true }
				)
			end
		end
	end
	-- Weak-point glows (shown only while exposed).
	self.HeartGlow = self:fixed(
		"HeartGlow",
		Vector3.new(7, 5.5, 5),
		CFrame.new(v3(Rig.Heart)),
		C(255, 150, 40),
		Enum.Material.Neon,
		{ Mesh = "Sphere", Transparency = 1 }
	)
	self.WingGlows = {}
	for _, s in { -1, 1 } do
		local w = Rig.WingRoot
		table.insert(
			self.WingGlows,
			self:fixed(
				"WingGlow",
				Vector3.new(5, 5, 5),
				CFrame.new(s * w.X, w.Y, w.Z),
				C(255, 150, 40),
				Enum.Material.Neon,
				{ Shape = "Ball", Transparency = 1 }
			)
		)
	end
	-- Neck (curve segments with crest spikes and throat plates).
	self.Neck = {}
	for i = 1, 7 do
		local size = 6.6 - i * 0.22
		table.insert(self.Neck, {
			Body = self:part("Neck", Vector3.new(size, size, 6.4), SCALE, nil, { Mesh = "Sphere" }),
			Spike = self:part(
				"NeckSpike",
				Vector3.new(0.7, 2.4 - i * 0.12, 2.4),
				HORN,
				nil,
				{ Class = "WedgePart" }
			),
			Throat = self:part("Throat", Vector3.new(size * 0.6, 0.5, 4.6), PLATE, nil, { Detail = true }),
		})
	end
	-- Head.
	local h = {}
	h.Skull = self:part("Skull", Vector3.new(6.5, 5.6, 8.6), SCALE, nil, { Mesh = "Sphere", Shadow = true })
	h.Snout = self:part("Snout", Vector3.new(5, 3.2, 9), SCALE, nil, { Class = "WedgePart" })
	h.SnoutBase = self:part("Snout", Vector3.new(5, 1.6, 9), SCALE_DARK)
	h.Jaw = self:part("Jaw", Vector3.new(4.4, 2, 9), SCALE_DARK, nil, { Class = "WedgePart" })
	h.Tongue = self:part("Tongue", Vector3.new(2.6, 0.4, 6.5), C(170, 40, 50), Enum.Material.SmoothPlastic)
	h.Eyes = {}
	h.Brows = {}
	h.Horns = {}
	h.Nostrils = {}
	for _ = 1, 2 do -- One set per side (left, right); placed per frame.
		table.insert(
			h.Eyes,
			self:part("Eye", Vector3.new(1.7, 0.9, 1.9), EYE, Enum.Material.Neon, { Mesh = "Sphere" })
		)
		table.insert(
			h.Brows,
			self:part("Brow", Vector3.new(1.4, 1.2, 3.4), HORN, nil, { Class = "WedgePart" })
		)
		table.insert(
			h.Nostrils,
			self:part(
				"Nostril",
				Vector3.new(0.7, 0.5, 0.7),
				C(60, 20, 16),
				Enum.Material.Neon,
				{ Shape = "Ball" }
			)
		)
		local horn = {}
		for k, d in { 1.8, 1.3, 0.8 } do
			table.insert(
				horn,
				self:part("Horn", Vector3.new(4.2 - k * 0.5, d, d), HORN, nil, { Shape = "Cylinder" })
			)
		end
		table.insert(h.Horns, horn)
		table.insert(
			h.Horns,
			{ self:part("CheekHorn", Vector3.new(0.8, 1.4, 3.6), HORN, nil, { Class = "WedgePart" }) }
		)
	end
	h.Crest = {}
	for _ = 1, 3 do
		table.insert(
			h.Crest,
			self:part("Crest", Vector3.new(0.6, 1.6, 2), HORN, nil, { Class = "WedgePart" })
		)
	end
	h.Teeth = {}
	for k = 1, 8 do
		table.insert(
			h.Teeth,
			self:part(
				"Tooth",
				Vector3.new(0.45, 0.9, 0.45),
				CLAW,
				Enum.Material.SmoothPlastic,
				{ Detail = true, Class = if k % 2 == 0 then "WedgePart" else "Part" }
			)
		)
	end
	h.Glow = self:part(
		"HeadGlow",
		Vector3.new(2.6, 2.6, 2.6),
		C(255, 150, 40),
		Enum.Material.Neon,
		{ Shape = "Ball", Transparency = 1 }
	)
	self.Head = h
	-- Fire breath emitter at the mouth.
	self.Mouth = Instance.new("Attachment")
	self.Mouth.Parent = h.Skull
	local fire = Instance.new("ParticleEmitter")
	fire.Name, fire.Texture = "DragonFire", FIRE_TEXTURE
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C(255, 240, 160)),
		ColorSequenceKeypoint.new(0.35, C(255, 140, 40)),
		ColorSequenceKeypoint.new(1, C(120, 30, 20)),
	})
	fire.LightEmission, fire.LightInfluence = 1, 0
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 12) })
	fire.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime, fire.Speed = NumberRange.new(0.6, 0.85), NumberRange.new(62, 78)
	fire.SpreadAngle, fire.Rate, fire.Enabled = Vector2.new(16, 16), 0, true
	fire.EmissionDirection = Enum.NormalId.Front
	fire.Drag = 1.2
	fire.Parent = self.Mouth
	self.Fire = fire
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name, smoke.Texture = "DragonSmoke", SMOKE
	smoke.Color = ColorSequence.new(C(70, 60, 60))
	smoke.Size = NumberSequence.new(1.5, 5)
	smoke.Transparency = NumberSequence.new(0.6, 1)
	smoke.Lifetime, smoke.Speed, smoke.Rate = NumberRange.new(1, 1.6), NumberRange.new(2, 5), 0
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = self.Mouth
	self.Smoke = smoke
	-- Looping breath roar on the head (designed SoundBank cue unless an asset is configured).
	local fireRecipe = Audio.resolve("DragonFire") or SoundBank.Cues.DragonFire
	self.FireSound = SoundBank.make(function(class)
		return Instance.new(class)
	end, fireRecipe, h.Skull, "BreathSound")
	self.FireSound.Looped = true
	self.FireSound.RollOffMaxDistance = 350
	self.FireVolume = self.FireSound.Volume
	self.FireLight = Instance.new("PointLight")
	self.FireLight.Color, self.FireLight.Range, self.FireLight.Brightness = C(255, 140, 50), 40, 0
	self.FireLight.Parent = h.Skull
	-- Limbs: thigh, shin, foot and three claws each.
	self.Legs = {}
	for _, spec in { { -1, -10.5, -3 }, { 1, -10.5, -3 }, { -1, 9.5, -2.6 }, { 1, 9.5, -2.6 } } do
		local leg = {
			Side = spec[1],
			Hip = Vector3.new(spec[1] * 5.6, spec[3], spec[2]),
			Front = spec[2] < 0,
			Thigh = self:part("Thigh", Vector3.new(4.2, 7.2, 4.6), SCALE, nil, { Mesh = "Sphere" }),
			Shin = self:part("Shin", Vector3.new(7, 2.4, 2.4), SCALE_DARK, nil, { Shape = "Cylinder" }),
			Foot = self:part("Foot", Vector3.new(3, 1.2, 4.4), SCALE_DARK),
			Claws = {},
		}
		for _ = 1, 3 do
			table.insert(
				leg.Claws,
				self:part(
					"Claw",
					Vector3.new(0.5, 0.6, 2),
					CLAW,
					Enum.Material.SmoothPlastic,
					{ Class = "WedgePart", Detail = true }
				)
			)
		end
		table.insert(self.Legs, leg)
	end
	-- Wings: humerus, forearm, four fingers, wrist claw and six membrane triangles each.
	self.Wings = {}
	for _, s in { -1, 1 } do
		local wing = { Side = s, Bones = {}, Membranes = {} }
		wing.Bones.Humerus = self:part("WingBone", Vector3.new(2.2, 2.2, 16), SCALE_DARK)
		wing.Bones.Forearm = self:part("WingBone", Vector3.new(1.8, 1.8, 20), SCALE_DARK)
		for k = 1, 4 do
			wing.Bones["Finger" .. k] = self:part("WingFinger", Vector3.new(0.9, 0.9, 20), SCALE_DARK)
		end
		wing.Claw = self:part(
			"WingClaw",
			Vector3.new(0.6, 0.9, 2.2),
			CLAW,
			Enum.Material.SmoothPlastic,
			{ Class = "WedgePart" }
		)
		for k = 1, 6 do
			wing.Membranes[k] = {
				self:part(
					"WingMembrane",
					Vector3.new(0.3, 1, 1),
					MEMBRANE,
					Enum.Material.Fabric,
					{ Class = "WedgePart" }
				),
				self:part(
					"WingMembrane",
					Vector3.new(0.3, 1, 1),
					MEMBRANE,
					Enum.Material.Fabric,
					{ Class = "WedgePart" }
				),
			}
		end
		table.insert(self.Wings, wing)
	end
	-- Tail: tapering segments with spikes and a spade blade.
	self.Tail = {}
	for i = 1, 10 do
		local size = 7 - i * 0.55
		table.insert(self.Tail, {
			Body = self:part("Tail", Vector3.new(size, size * 0.9, 6), SCALE, nil, { Mesh = "Sphere" }),
			Spike = self:part(
				"TailSpike",
				Vector3.new(0.6, 2.6 - i * 0.16, 2.2),
				HORN,
				nil,
				{ Class = "WedgePart" }
			),
		})
	end
	self.Blade = {
		self:part("TailBlade", Vector3.new(0.5, 3, 5), HORN, nil, { Class = "WedgePart" }),
		self:part("TailBlade", Vector3.new(0.5, 3, 5), HORN, nil, { Class = "WedgePart" }),
	}
	-- Weak-point markers (screen-readable "aim here" labels).
	self.Markers = {}
	for _, name in { "Heart", "Head", "WingL", "WingR" } do
		local anchor = self:part("WeakPointAnchor", Vector3.one, C(255, 255, 255), nil, { Transparency = 1 })
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.AlwaysOnTop, gui.MaxDistance, gui.Enabled = UDim2.fromOffset(120, 46), true, 320, false
		gui.LightInfluence = 0
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Font, label.TextSize, label.TextColor3 = Enum.Font.GothamBlack, 15, C(255, 210, 90)
		label.TextStrokeTransparency, label.Text = 0.2, "◎\nWEAK POINT"
		label.Parent = gui
		self.Markers[name] = { Anchor = anchor, Gui = gui, Label = label }
	end
	self.Model.Parent = workspace
end
-- Geometry helpers ------------------------------------------------------------------------
local function between(a, b)
	local mid = (a + b) / 2
	if (b - a).Magnitude < 1e-3 then
		return CFrame.new(mid)
	end
	return CFrame.lookAt(mid, b)
end
-- Two wedges forming triangle abc (membrane panel).
local function triangle(w1, w2, a, b, c, thickness)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab)
	if right.Magnitude < 1e-4 or bc.Magnitude < 1e-4 then
		w1.Transparency, w2.Transparency = 1, 1
		return nil
	end
	right = right.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	w1.Size = Vector3.new(thickness, math.max(0.05, height), math.max(0.05, math.abs(ab:Dot(back))))
	w2.Size = Vector3.new(thickness, math.max(0.05, height), math.max(0.05, math.abs(ac:Dot(back))))
	w1.Transparency, w2.Transparency = 0.04, 0.04
	return CFrame.fromMatrix((a + b) / 2, right, up, back), CFrame.fromMatrix((a + c) / 2, -right, up, -back)
end
local function approach(current, target, rate, dt)
	return current + (target - current) * math.min(1, dt * rate)
end
-- Animation targets per server action/phase.
local poses = {
	Fly = { Flap = 0.55, Speed = 2.3, Fold = 0.2, Sweep = 0.12, Spread = 1, Jaw = 0.05, Legs = 1 },
	Hover = { Flap = 0.75, Speed = 3.6, Fold = 0.1, Sweep = 0, Spread = 1, Jaw = 0.12, Legs = 0.6 },
	Breath = { Flap = 0.6, Speed = 3.2, Fold = 0.1, Sweep = 0, Spread = 1, Jaw = 0.55, Legs = 0.6 },
	Sweep = { Flap = 0.6, Speed = 3.2, Fold = 0.1, Sweep = 0, Spread = 1, Jaw = 0.6, Legs = 0.6 },
	Gust = { Flap = 0.95, Speed = 0, Fold = -0.1, Sweep = -0.35, Spread = 1.1, Jaw = 0.3, Legs = 0.5 },
	Roar = { Flap = 0.7, Speed = 0, Fold = -0.05, Sweep = -0.2, Spread = 1.15, Jaw = 0.75, Legs = 0.6 },
	Dive = { Flap = 0.85, Speed = 0, Fold = 1.4, Sweep = 0.7, Spread = 0.35, Jaw = 0.45, Legs = 1 },
	Land = { Flap = 0.6, Speed = 4.2, Fold = 0.05, Sweep = -0.1, Spread = 1, Jaw = 0.3, Legs = 0 },
	Landed = { Flap = 1.0, Speed = 0, Fold = 1.9, Sweep = 0.75, Spread = 0.3, Jaw = 0.2, Legs = 0 },
	Stunned = { Flap = -0.25, Speed = 0, Fold = 1.2, Sweep = 0.4, Spread = 0.5, Jaw = 0.35, Legs = 0 },
	Stagger = { Flap = 0.3, Speed = 6, Fold = 0.4, Sweep = 0.2, Spread = 0.8, Jaw = 0.5, Legs = 0.4 },
}
-- Per-frame update -------------------------------------------------------------------------
function Dragon:state()
	self.StateFolder = self.StateFolder or ReplicatedStorage:FindFirstChild("RealmDestroyer")
	return self.StateFolder
end
function Dragon:update(dt)
	local state = self:state()
	local visible = state ~= nil and state:GetAttribute("Visible") == true
	if not visible then
		if self.Visible and self.Model then
			self.Model.Parent = nil
		end
		self.Visible = false
		return
	end
	if not self.Built then
		self:build()
	end
	if not self.Visible then
		self.Model.Parent = workspace
		self.Smooth = nil
	end
	self.Visible = true
	local target = state:GetAttribute("Pose")
	if typeof(target) ~= "CFrame" then
		return
	end
	-- Smooth toward the 10 Hz server pose; snap on rebasing or long jumps.
	if not self.Smooth or (self.Smooth.Position - target.Position).Magnitude > 260 then
		self.Smooth = target
	else
		self.Smooth = self.Smooth:Lerp(target, math.min(1, dt * 10))
	end
	local camera = workspace.CurrentCamera
	local distance = camera and (camera.CFrame.Position - self.Smooth.Position).Magnitude or 0
	local far = distance > 380 or not self.Settings.Detail
	-- Distant silhouettes update at a reduced rate (mobile budget).
	self.Frame += 1
	self.Time += dt
	self.Accum = (self.Accum or 0) + dt
	if distance > 380 and self.Frame % 3 ~= 0 then
		return
	end
	local step = self.Accum
	self.Accum = 0
	local action = state:GetAttribute("Action") or "Fly"
	local phase = state:GetAttribute("Phase") or ""
	local exposed = state:GetAttribute("Exposed") or ""
	local aim = state:GetAttribute("Aim")
	local goal = poses[action] or poses.Fly
	if action == "Gust" and phase == "Active" then
		goal = { Flap = -0.6, Speed = 0, Fold = -0.15, Sweep = 0.35, Spread = 1.1, Jaw = 0.3, Legs = 0.5 }
	end
	local p = self.Params
	for key, value in goal do
		p[key] = approach(p[key], value, if action == "Gust" and phase == "Active" then 14 else 4, step)
	end
	self.HeadOffset = self.HeadOffset:Lerp(v3(Rig.head(action)), math.min(1, step * 5))
	if far ~= self.Far then
		self.Far = far
		for _, part in self.Parts do
			if part:GetAttribute("Detail") then
				part.LocalTransparencyModifier = if far then 1 else 0
			end
		end
	end
	local frames = {}
	local parts = {}
	local function put(part, cf)
		table.insert(parts, part)
		table.insert(frames, cf)
	end
	local root = self.Smooth
	local t = self.Time
	local breathe = math.sin(t * 1.4) * 0.15
	for _, entry in self.Fixed do
		put(entry.Part, root * CFrame.new(0, breathe, 0) * entry.Offset)
	end
	self:neck(root, put, t, aim, action)
	self:legs(root, put, t, p)
	self:wings(root, put, t, p)
	-- A heavy whomp on every wing downstroke (heard only near the dragon).
	local stroke = if p.Speed > 0 then math.sin(t * p.Speed) else 0
	if self.Audio and self.PrevStroke and self.PrevStroke > 0 and stroke <= 0 and p.Flap > 0.3 then
		self.Audio:play("DragonWings", root.Position)
	end
	self.PrevStroke = stroke
	self:tail(root, put, t, action)
	self:glows(root, put, exposed, t)
	self:breath(action, phase, aim, step)
	local ok = pcall(function()
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	if not ok then
		for i, part in parts do
			part.CFrame = frames[i]
		end
	end
end
function Dragon:neck(root, put, t, aim, action)
	local base = root * v3(Rig.NeckBase)
	local headPoint = root * (self.HeadOffset + Vector3.new(0, math.sin(t * 1.1) * 0.5, 0))
	local control = root
		* Vector3.new(0, 12 + self.HeadOffset.Y * 0.4, (Rig.NeckBase.Z + self.HeadOffset.Z) / 2)
	local previous = base
	for i, seg in self.Neck do
		local u = i / (#self.Neck + 1)
		local point = base * (1 - u) ^ 2 + control * 2 * u * (1 - u) + headPoint * u * u
		local cf = between(previous, point)
		cf = CFrame.new(point) * (cf - cf.Position)
		put(seg.Body, cf)
		put(
			seg.Spike,
			cf
				* CFrame.new(0, seg.Body.Size.Y / 2 + seg.Spike.Size.Y / 2 - 0.4, 0)
				* CFrame.Angles(0, math.pi, 0)
		)
		put(seg.Throat, cf * CFrame.new(0, -seg.Body.Size.Y / 2 + 0.3, 0))
		previous = point
	end
	-- Head faces its breath target, otherwise along the neck and body.
	local forward = root.LookVector
	if aim and (action == "Breath" or action == "Sweep" or action == "Gust") then
		local d = aim - headPoint
		if d.Magnitude > 1 then
			forward = d.Unit
		end
	elseif action == "Stunned" then
		forward = (root.LookVector - root.UpVector * 0.3).Unit
	end
	local headCF = CFrame.lookAt(headPoint, headPoint + forward)
	local h = self.Head
	local skullCF = headCF * CFrame.new(0, 0.6, 0.6)
	put(h.Skull, skullCF)
	put(h.Snout, headCF * CFrame.new(0, 0.9, -6.6))
	put(h.SnoutBase, headCF * CFrame.new(0, -0.6, -6.4))
	local jaw = self.Params.Jaw + math.max(0, math.sin(t * 2.3)) * 0.03
	local hinge = headCF * CFrame.new(0, -1.4, -1.2) * CFrame.Angles(-jaw, 0, 0)
	put(h.Jaw, hinge * CFrame.new(0, -1.1, -4.4) * CFrame.Angles(0, 0, math.pi))
	put(h.Tongue, hinge * CFrame.new(0, -0.3, -3.6))
	for i, s in { -1, 1 } do
		put(h.Eyes[i], headCF * CFrame.new(s * 2.7, 1.3, -2.6) * CFrame.Angles(0, s * 0.35, 0))
		put(h.Brows[i], headCF * CFrame.new(s * 2.6, 2.3, -2.2) * CFrame.Angles(0, math.pi, s * 0.25))
		put(h.Nostrils[i], headCF * CFrame.new(s * 1.1, 1.2, -10.6))
		local horn = h.Horns[(i - 1) * 2 + 1]
		local anchor = headCF * CFrame.new(s * 2.2, 2.4, 2.6)
		local dir = CFrame.Angles(0.55, 0, 0) * CFrame.Angles(0, -s * 0.35, 0)
		for k, piece in horn do
			local length = piece.Size.X
			local seg = anchor * dir * CFrame.Angles(0.18 * (k - 1), 0, 0)
			put(piece, seg * CFrame.new(0, 0, length / 2) * CFrame.Angles(0, math.pi / 2, 0))
			anchor = seg * CFrame.new(0, 0, length - 0.3)
		end
		put(
			h.Horns[(i - 1) * 2 + 2][1],
			headCF * CFrame.new(s * 3.1, -1, 2.4) * CFrame.Angles(0, math.pi + s * 0.3, 0)
		)
	end
	for k, crest in h.Crest do
		put(crest, headCF * CFrame.new(0, 3.2 - k * 0.2, -0.5 + k * 1.6) * CFrame.Angles(0, math.pi, 0))
	end
	for k, tooth in h.Teeth do
		local s = if k % 2 == 0 then 1 else -1
		local row = math.ceil(k / 2)
		put(tooth, headCF * CFrame.new(s * 1.9, -1.4, -4 - row * 1.6) * CFrame.Angles(math.pi, 0, 0))
	end
	put(h.Glow, headCF * CFrame.new(0, 2.6, -1.5))
	self.HeadCF = headCF
	-- The skull moves in this frame's BulkMoveTo, so place the mouth relative to its new frame.
	local m = headCF * Vector3.new(0, -0.2, -10.5)
	local mouth = CFrame.lookAt(m, headCF * Vector3.new(0, -0.2, -20))
	if aim and self.Params.Jaw > 0.4 and (aim - m).Magnitude > 1 then
		mouth = CFrame.lookAt(m, aim)
	end
	self.Mouth.CFrame = skullCF:ToObjectSpace(mouth)
end
function Dragon:legs(root, put, t, p)
	for _, leg in self.Legs do
		-- Legs = 1 tucked for flight, 0 planted for landing.
		local tuck = p.Legs
		local swing = math.sin(t * 1.3 + (if leg.Front then 0 else 1.5)) * 0.05
		local hipAngle = (if leg.Front then 0.9 else 1.25) * tuck + swing
		local hip = root * CFrame.new(leg.Hip) * CFrame.Angles(hipAngle, 0, leg.Side * 0.08)
		put(leg.Thigh, hip * CFrame.new(0, -2.8, 0))
		local knee = hip * CFrame.new(0, -5.8, 0)
		local bend = (if leg.Front then -0.5 else 0.6) * (0.4 + tuck * 0.8)
		local shin = knee * CFrame.Angles(bend, 0, 0)
		put(leg.Shin, shin * CFrame.new(0, -3.3, 0) * CFrame.Angles(0, 0, math.pi / 2))
		local ankle = shin * CFrame.new(0, -6.6, 0)
		local foot = CFrame.new(ankle.Position) * (root - root.Position) * CFrame.Angles(tuck * 0.9, 0, 0)
		put(leg.Foot, foot * CFrame.new(0, -0.4, -1))
		for k, claw in leg.Claws do
			put(claw, foot * CFrame.new((k - 2) * 0.95, -0.5, -3.8) * CFrame.Angles(0, 0, 0))
		end
	end
end
function Dragon:wings(root, put, t, p)
	local fingers = { { 0.12, 28 }, { 0.55, 30 }, { 0.98, 27 }, { 1.38, 21 } }
	for _, wing in self.Wings do
		local s = wing.Side
		local wave = if p.Speed > 0 then math.sin(t * p.Speed) else 0
		local flap = p.Flap * (if p.Speed > 0 then wave * 0.85 + 0.2 else 1)
		local lag = if p.Speed > 0 then math.sin(t * p.Speed - 0.9) * p.Flap * 0.5 else 0
		local w = Rig.WingRoot
		local shoulderPos = root * Vector3.new(s * w.X, w.Y, w.Z)
		local shoulder = root
			* CFrame.new(s * w.X, w.Y, w.Z)
			* CFrame.Angles(0, -s * p.Sweep, 0)
			* CFrame.Angles(0, 0, s * flap)
		local elbowCF = shoulder * CFrame.new(s * 16, 0, 1)
		local forearm = elbowCF * CFrame.Angles(0, -s * p.Fold, 0) * CFrame.Angles(0, 0, -s * lag * 0.5)
		local wristCF = forearm * CFrame.new(s * 20, 0, -2)
		local elbow, wrist = elbowCF.Position, wristCF.Position
		put(wing.Bones.Humerus, between(shoulderPos, elbow))
		put(wing.Bones.Forearm, between(elbow, wrist))
		put(wing.Claw, wristCF * CFrame.new(0, 0.6, -1.4))
		local tips = {}
		for k, f in fingers do
			local angle = f[1] * p.Spread + p.Fold * 0.25
			local finger = wristCF
				* CFrame.Angles(0, -s * angle, 0)
				* CFrame.Angles(0, 0, -s * lag * (0.2 + k * 0.08))
			local tip = (finger * CFrame.new(s * f[2] * (0.75 + 0.25 * p.Spread), 0, 0)).Position
			tips[k] = tip
			local bone = wing.Bones["Finger" .. k]
			bone.Size = Vector3.new(0.9 - k * 0.1, 0.9 - k * 0.1, (tip - wrist).Magnitude)
			put(bone, between(wrist, tip))
		end
		local trail = root * Vector3.new(s * 5, 2, 15)
		local panels = {
			{ wrist, tips[1], tips[2] },
			{ wrist, tips[2], tips[3] },
			{ wrist, tips[3], tips[4] },
			{ wrist, tips[4], trail },
			{ shoulderPos, wrist, trail },
			{ shoulderPos, elbow, wrist },
		}
		for k, tri in panels do
			local pair = wing.Membranes[k]
			local a, b = triangle(pair[1], pair[2], tri[1], tri[2], tri[3], 0.3)
			if a then
				put(pair[1], a)
				put(pair[2], b)
			end
		end
	end
end
function Dragon:tail(root, put, t, action)
	local landed = action == "Landed" or action == "Stunned"
	local cf = root * CFrame.new(v3(Rig.TailBase)) * CFrame.Angles(if landed then 0.25 else 0.05, 0, 0)
	for i, seg in self.Tail do
		local sway = math.sin(t * 1.6 - i * 0.55) * (0.06 + i * 0.012)
		local droop = if landed then -0.04 * i * 0.3 else 0.01
		cf = cf * CFrame.Angles(droop, sway, 0)
		local length = 5.6 - i * 0.2
		local center = cf * CFrame.new(0, 0, length / 2)
		put(seg.Body, center)
		put(
			seg.Spike,
			center
				* CFrame.new(0, seg.Body.Size.Y / 2 + seg.Spike.Size.Y / 2 - 0.3, 0)
				* CFrame.Angles(0, math.pi, 0)
		)
		cf = cf * CFrame.new(0, 0, length)
	end
	put(self.Blade[1], cf * CFrame.new(1.2, 0, 1.6) * CFrame.Angles(0, -0.6, math.pi / 2))
	put(self.Blade[2], cf * CFrame.new(-1.2, 0, 1.6) * CFrame.Angles(0, 0.6, -math.pi / 2))
end
function Dragon:glows(root, put, exposed, t)
	local pulse = 0.25 + (math.sin(t * 7) + 1) * 0.15
	self.HeartGlow.Transparency = if exposed == "Heart" then pulse else 1
	for _, glow in self.WingGlows do
		glow.Transparency = if exposed == "Wings" then pulse else 1
	end
	self.Head.Glow.Transparency = if exposed == "Head" then pulse else 1
	for _, eye in self.Head.Eyes do
		eye.Color = if exposed == "Head" then C(255, 250, 200) else EYE
	end
	local spheres = Rig.spheres(nil)
	local w = Rig.WingRoot
	local positions = {
		Heart = root * v3(spheres.Heart),
		Head = if self.HeadCF then self.HeadCF.Position else root * v3(spheres.Head),
		WingL = root * Vector3.new(-w.X, w.Y + 3, w.Z),
		WingR = root * Vector3.new(w.X, w.Y + 3, w.Z),
	}
	for name, marker in self.Markers do
		local on = (exposed == "Heart" and name == "Heart")
			or (exposed == "Head" and name == "Head")
			or (exposed == "Wings" and (name == "WingL" or name == "WingR"))
		marker.Gui.Enabled = on
		put(marker.Anchor, CFrame.new(positions[name]))
	end
end
function Dragon:breath(action, phase, aim, dt)
	local breathing = (action == "Breath" or action == "Sweep") and phase == "Active" and aim ~= nil
	local windup = (action == "Breath" or action == "Sweep") and phase == "Windup"
	local detail = self.Settings.Detail
	self.Fire.Rate = if breathing then (if detail then 110 else 45) else 0
	if self.FireSound then
		local on = breathing and self.Settings.SFX ~= false
		if on and not self.FireOn then
			self.FireSound:Play()
		elseif not on and self.FireOn then
			self.FireSound:Stop()
		end
		self.FireOn = on
		self.FireSound.Volume = self.FireVolume
	end
	self.Smoke.Rate = if windup then (if detail then 14 else 5) else 0
	self.FireLight.Brightness =
		approach(self.FireLight.Brightness, if breathing then 3 elseif windup then 1 else 0, 6, dt)
	for _, nostril in self.Head.Nostrils do
		nostril.Color = if breathing or windup then C(255, 150, 50) else C(60, 20, 16)
	end
end
-- Server events ----------------------------------------------------------------------------
function Dragon:shake(amount, weather)
	if not self.Settings.Camera or not weather then
		return
	end
	weather.ShakeAt = os.clock()
	weather.ShakeAmount = math.max(amount, (weather.ShakeAmount or 0) * 0.5)
end
function Dragon:event(payload, weather)
	local fx = self.Fx
	local kind = payload.Kind
	if kind == "Roar" then
		local camera = workspace.CurrentCamera
		local d = if camera and payload.Position
			then (camera.CFrame.Position - payload.Position).Magnitude
			else 999
		self:shake(if d < 200 then 0.35 elseif d < 500 then 0.15 else 0.06, weather)
	elseif kind == "Impact" or kind == "Slam" then
		local radius = payload.Radius or 20
		fx:ring(payload.Position + Vector3.new(0, 0.5, 0), C(255, 150, 70), radius, payload.Duration or 0.7)
		fx:ring(payload.Position + Vector3.new(0, 0.6, 0), C(255, 230, 190), radius * 0.6, 0.4)
		fx:burst(payload.Position + Vector3.new(0, 2, 0), C(150, 120, 100), 40, SMOKE, { 10, 26 }, 3)
		self:shake(0.4, weather)
	elseif kind == "Gust" then
		local dir = payload.Direction or Vector3.new(0, 0, -1)
		for k = 0, 4 do
			local at = payload.Position + dir * (k * (payload.Length or 70) / 5) + Vector3.new(0, 4, 0)
			fx:ring(at, C(220, 240, 255), (payload.Width or 26) / 2, 0.5 + k * 0.08, true, dir)
		end
		self:shake(0.2, weather)
	elseif kind == "Strike" then
		fx:burst(payload.Position + Vector3.new(0, 3, 0), C(255, 140, 50), 50, FIRE_TEXTURE, { 8, 20 }, 3)
		self:shake(0.18, weather)
	elseif kind == "Meteors" then
		self:meteors(payload.Points or {}, payload.Delay or 2)
	elseif kind == "Raze" then
		self:shake(0.5, weather)
	end
end
function Dragon:meteors(points, delay)
	for _, point in points do
		local ball = Instance.new("Part")
		ball.Name, ball.Shape, ball.Material = "DragonMeteor", Enum.PartType.Ball, Enum.Material.Neon
		ball.Color, ball.Size = C(255, 140, 50), Vector3.new(3.4, 3.4, 3.4)
		ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
		ball.CFrame = CFrame.new(point + Vector3.new(math.random(-20, 20), 160, math.random(-20, 20)))
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 6, 15
		fire.Parent = ball
		ball.Parent = self.Fx.Folder
		TweenService
			:Create(
				ball,
				TweenInfo.new(math.max(0.3, delay), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					CFrame = CFrame.new(point + Vector3.new(0, 1, 0)),
				}
			)
			:Play()
		Debris:AddItem(ball, delay + 0.2)
		task.delay(delay, function()
			self.Fx:burst(point + Vector3.new(0, 1, 0), C(255, 150, 60), 30, FIRE_TEXTURE, { 8, 18 }, 2)
			self.Fx:ring(point + Vector3.new(0, 0.4, 0), C(255, 120, 40), 9, 0.5)
		end)
	end
end
-- Dragonbane shot tracer and floating damage text.
function Dragon:shot(payload)
	if not payload.From or not payload.To then
		return
	end
	local fx = self.Fx
	local colors = {
		Crossbow = C(255, 230, 160),
		Ballista = C(255, 200, 110),
		Cannon = C(140, 220, 255),
		Dash = C(200, 240, 255),
		Harpoon = C(130, 220, 255),
	}
	local color = colors[payload.Weapon] or C(255, 230, 160)
	if payload.Weapon == "Harpoon" then
		-- A visible crystal-tipped harpoon flies to its target.
		local spear = Instance.new("Part")
		spear.Name, spear.Material, spear.Color = "DragonbaneHarpoonFlight", Enum.Material.Wood, C(96, 70, 46)
		spear.Anchored, spear.CanCollide, spear.CanQuery, spear.CanTouch = true, false, false, false
		spear.Size = Vector3.new(0.3, 0.3, 5)
		spear.CFrame = CFrame.lookAt(payload.From, payload.To)
		local tip = Instance.new("Part")
		tip.Name, tip.Material, tip.Color = "HarpoonTip", Enum.Material.Neon, C(130, 220, 255)
		tip.Anchored, tip.CanCollide, tip.CanQuery, tip.CanTouch = true, false, false, false
		tip.Size, tip.CFrame = Vector3.new(0.5, 0.5, 1), spear.CFrame * CFrame.new(0, 0, -3)
		spear.Parent, tip.Parent = fx.Folder, fx.Folder
		local flight = math.clamp((payload.To - payload.From).Magnitude / 140, 0.15, 0.6)
		local goal = CFrame.lookAt(payload.To, payload.To + (payload.To - payload.From).Unit)
		TweenService:Create(spear, TweenInfo.new(flight), { CFrame = goal }):Play()
		TweenService:Create(tip, TweenInfo.new(flight), { CFrame = goal * CFrame.new(0, 0, -3) }):Play()
		Debris:AddItem(spear, flight + 0.6)
		Debris:AddItem(tip, flight + 0.6)
	elseif payload.Weapon ~= "Dash" then
		local length = (payload.To - payload.From).Magnitude
		local tracer = Instance.new("Part")
		tracer.Name, tracer.Material, tracer.Color = "DragonbaneTracer", Enum.Material.Neon, color
		tracer.Anchored, tracer.CanCollide, tracer.CanQuery, tracer.CanTouch = true, false, false, false
		local thickness = if payload.Weapon == "Crossbow" then 0.25 else 0.6
		tracer.Size = Vector3.new(thickness, thickness, length)
		tracer.CFrame = CFrame.lookAt((payload.From + payload.To) / 2, payload.To)
		tracer.Parent = fx.Folder
		TweenService:Create(tracer, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		Debris:AddItem(tracer, 0.4)
	end
	if (payload.Damage or 0) > 0 then
		fx:burst(payload.To, color, 18, nil, { 8, 16 }, 0.8)
		fx:text(payload.To + Vector3.new(0, 4, 0), "-" .. payload.Damage, C(255, 214, 120), 24)
	else
		fx:text(payload.To + Vector3.new(0, 3, 0), "GLANCE", C(190, 190, 200), 16)
	end
end
return Dragon
