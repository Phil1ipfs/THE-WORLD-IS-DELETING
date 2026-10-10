--!nonstrict
-- Local visual feedback for powers, items, pickups, creatures and rewards. Visual only:
-- every effect follows a server-authorized event. Effects are bounded, pooled where they
-- repeat, and lighter when the Detail setting is off.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Effects = {}
Effects.__index = Effects
local C = Color3.fromRGB
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
Effects.Colors = {
	Dash = C(200, 240, 255),
	DoubleJump = C(170, 230, 255),
	Shield = C(115, 215, 255),
	Glide = C(170, 240, 230),
	Heal = C(120, 240, 140),
	Overcharge = C(200, 140, 255),
	Brace = C(240, 180, 100),
	Timber = C(196, 150, 96),
	Crystal = C(139, 210, 255),
	Herb = C(120, 220, 110),
	Relic = C(255, 214, 120),
}
local function tween(object, seconds, goal, style)
	TweenService
		:Create(
			object,
			TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goal
		)
		:Play()
end
function Effects.new(settings)
	local self = setmetatable({ Settings = settings, Active = {}, LastShield = 0, LastHealth = nil }, Effects)
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "LocalEffects"
	self.Folder.Parent = workspace
	return self
end
local function rootOf(userId)
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart"), character
end
local function near(position)
	local camera = workspace.CurrentCamera
	return camera and (camera.CFrame.Position - position).Magnitude < 160
end
-- One-shot particle burst at a world position (attachment in Terrain; no parts).
function Effects:burst(position, color, count, texture, speed, size)
	if not position or not near(position) then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace:FindFirstChildOfClass("Terrain") or workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture or SPARK
	emitter.Color, emitter.LightEmission = ColorSequence.new(color), 0.7
	emitter.Rate, emitter.Lifetime = 0, NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(speed and speed[1] or 6, speed and speed[2] or 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Drag = 4
	emitter.Parent = attachment
	emitter:Emit(if self.Settings.Detail then count else math.ceil(count / 3))
	Debris:AddItem(attachment, 1.2)
	return emitter
end
-- Expanding neon ring (ground shockwave or vertical gust ring).
function Effects:ring(position, color, radius, seconds, vertical, facing)
	if not position or not near(position) then
		return
	end
	local ring = Instance.new("Part")
	ring.Name, ring.Shape, ring.Material, ring.Color =
		"FXRing", Enum.PartType.Cylinder, Enum.Material.Neon, color
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow =
		true, false, false, false, false
	ring.Size, ring.Transparency = Vector3.new(0.15, 1, 1), 0.35
	local base = if vertical and facing
		then CFrame.lookAt(position, position + facing) * CFrame.Angles(0, math.pi / 2, 0)
		else CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.CFrame = base
	ring.Parent = self.Folder
	tween(ring, seconds or 0.45, { Size = Vector3.new(0.05, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(ring, (seconds or 0.45) + 0.1)
	return ring
end
-- Floating world text such as "+1 Herb" or "+40".
function Effects:text(position, text, color, size)
	if not position or not near(position) then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace:FindFirstChildOfClass("Terrain") or workspace
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.AlwaysOnTop, gui.LightInfluence = UDim2.fromOffset(160, 40), true, 0
	gui.StudsOffset, gui.Adornee, gui.Parent = Vector3.new(0, 1, 0), attachment, attachment
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Font, label.TextSize, label.Text = Enum.Font.GothamBlack, size or 20, text
	label.TextColor3, label.TextStrokeTransparency, label.TextStrokeColor3 = color, 0.2, C(20, 22, 34)
	label.Parent = gui
	tween(gui, 1.1, { StudsOffset = Vector3.new(0, 4.2, 0) })
	tween(label, 1.1, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(attachment, 1.2)
	return label
end
local function weld(part, root, offset)
	part.Anchored, part.Massless, part.CanCollide, part.CanQuery, part.CanTouch =
		false, true, false, false, false
	part.CFrame = root.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = root, part, offset
	w.Parent = part
	return w
end
local function shape(parent, name, size, color, material, transparency, class)
	local p = Instance.new(class or "Part")
	p.Name, p.Size, p.Color, p.Material = name, size, color, material
	p.Transparency, p.CastShadow = transparency or 0, false
	p.Parent = parent
	return p
end
function Effects:clear(character, name)
	local key = character and (character:GetFullName() .. name)
	local active = key and self.Active[key]
	if active then
		self.Active[key] = nil
		if active.Folder and active.Folder.Parent then
			active.Folder:Destroy()
		end
	end
end
local function trail(parent, root, color, lifetime, width)
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, width or 1.2, 0.6)
	a:SetAttribute("PowerFX", true)
	a.Parent = root
	local b = Instance.new("Attachment")
	b.Position = Vector3.new(0, -(width or 1.2), 0.6)
	b:SetAttribute("PowerFX", true)
	b.Parent = root
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a, b
	t.Lifetime, t.LightEmission, t.FaceCamera = lifetime or 0.35, 0.6, true
	t.Color = ColorSequence.new(color, C(255, 255, 255))
	t.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	t.Parent = parent
	return { a, b, t }
end
function Effects:ability(payload)
	local root, character = rootOf(payload.UserId)
	if not root or not near(root.Position) then
		return
	end
	local name = payload.Name
	local color = self.Colors[name] or C(255, 221, 150)
	local duration = if payload.Name == "DoubleJump" then 3 else payload.Duration or 1
	local detail = self.Settings.Detail
	self:clear(character, name)
	local folder = Instance.new("Folder")
	folder.Name = "Power_" .. name
	folder.Parent = character
	local key = character:GetFullName() .. name
	local active = {
		Folder = folder,
		Character = character,
		Root = root,
		Name = name,
		Until = os.clock() + duration,
		Start = os.clock(),
	}
	self.Active[key] = active
	if name == "Dash" then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
		self:ring(root.Position, color, 7, 0.35, true, look)
		self:burst(root.Position - look * 2, color, 18, SMOKE, { 4, 10 }, 1.2)
		trail(folder, root, color, 0.4, 1.3)
		local streaks = Instance.new("Attachment")
		streaks.Parent = root
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture, emitter.Color = SQUARE, ColorSequence.new(C(235, 248, 255))
		emitter.Orientation, emitter.Squash = Enum.ParticleOrientation.VelocityParallel, NumberSequence.new(5)
		emitter.Rate, emitter.Lifetime = if detail then 70 else 20, NumberRange.new(0.15, 0.25)
		emitter.Speed, emitter.EmissionDirection = NumberRange.new(30, 45), Enum.NormalId.Back
		emitter.SpreadAngle, emitter.Size = Vector2.new(25, 25), NumberSequence.new(0.12)
		emitter.Transparency, emitter.LightEmission = NumberSequence.new(0.4), 0.6
		emitter.Parent = streaks
		active.Attachments = { streaks }
	elseif name == "DoubleJump" then
		local feet = root.Position - Vector3.new(0, 3, 0)
		self:ring(feet, color, 6, 0.4)
		self:ring(feet - Vector3.new(0, 0.6, 0), C(255, 255, 255), 4, 0.3)
		self:burst(feet, color, 22, SMOKE, { 6, 14 }, 1)
		active.Leap = true
	elseif name == "Shield" then
		local shell =
			shape(folder, "AegisShell", Vector3.new(7.4, 7.4, 7.4), color, Enum.Material.ForceField, 0.15)
		shell.Shape = Enum.PartType.Ball
		weld(shell, root, CFrame.new())
		local glow = shape(folder, "AegisGlow", Vector3.new(7, 7, 7), color, Enum.Material.Neon, 0.92)
		glow.Shape = Enum.PartType.Ball
		weld(glow, root, CFrame.new())
		active.Pulse = glow
		self:ring(root.Position, color, 6, 0.4)
	elseif name == "Glide" then
		for _, side in { -1, 1 } do
			local wing = shape(
				folder,
				"SailWing",
				Vector3.new(0.12, 2.6, 4.6),
				C(236, 248, 246),
				Enum.Material.Fabric,
				0.2,
				"WedgePart"
			)
			weld(
				wing,
				root,
				CFrame.new(side * 2.6, 1.3, 0.4) * CFrame.Angles(0, side * math.pi / 2, side * -1.35)
			)
			local spar =
				shape(folder, "SailSpar", Vector3.new(5, 0.2, 0.2), C(150, 120, 80), Enum.Material.Wood)
			weld(spar, root, CFrame.new(side * 2.6, 1.9, 0.6) * CFrame.Angles(0, 0, side * 0.18))
			local tip = Instance.new("Attachment")
			tip.Parent = spar
			tip.Position = Vector3.new(side * 2.5, 0, 0)
			local tip2 = Instance.new("Attachment")
			tip2.Parent = spar
			tip2.Position = Vector3.new(side * 2.5, -0.5, 0)
			local t = Instance.new("Trail")
			t.Attachment0, t.Attachment1, t.Lifetime = tip, tip2, 0.6
			t.Color, t.LightEmission = ColorSequence.new(color), 0.5
			t.Transparency =
				NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
			t.Parent = spar
		end
		local wind = Instance.new("ParticleEmitter")
		wind.Texture, wind.Color = SMOKE, ColorSequence.new(C(230, 245, 255))
		wind.Rate, wind.Lifetime = if detail then 8 else 2, NumberRange.new(0.4, 0.7)
		wind.Speed, wind.EmissionDirection = NumberRange.new(6, 10), Enum.NormalId.Back
		wind.Size, wind.Transparency = NumberSequence.new(0.8, 2), NumberSequence.new(0.75, 1)
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		wind.Parent = attachment
		active.Attachments = { attachment }
		self:burst(root.Position + Vector3.new(0, 1.5, 0), color, 12, SMOKE, { 3, 6 }, 1)
	end
	if payload.Boosted then
		self:burst(root.Position, self.Colors.Overcharge, 12)
	end
end
function Effects:item(payload)
	local root, character = rootOf(payload.UserId)
	if not root or not near(root.Position) then
		return
	end
	local kind = payload.Kind
	if kind == "Herb" then
		self:burst(root.Position, self.Colors.Heal, 26, SPARK, { 2, 5 }, 0.45)
		self:text(root.Position + Vector3.new(0, 3, 0), "+40 HP", self.Colors.Heal, 22)
		local highlight = Instance.new("Highlight")
		highlight.FillColor, highlight.FillTransparency, highlight.OutlineTransparency =
			self.Colors.Heal, 0.6, 0.4
		highlight.DepthMode, highlight.Parent = Enum.HighlightDepthMode.Occluded, character
		tween(highlight, 0.9, { FillTransparency = 1, OutlineTransparency = 1 })
		Debris:AddItem(highlight, 1)
	elseif kind == "Crystal" then
		self:clear(character, "Overcharge")
		local folder = Instance.new("Folder")
		folder.Name = "Power_Overcharge"
		folder.Parent = character
		local welds = {}
		for k = 1, 3 do
			local shard = shape(
				folder,
				"OverchargeShard",
				Vector3.new(0.5, 1.2, 0.5),
				self.Colors.Overcharge,
				Enum.Material.Neon,
				0.1
			)
			table.insert(welds, weld(shard, root, CFrame.Angles(0, k * 2.09, 0) * CFrame.new(0, 0, -2.6)))
		end
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local energy = Instance.new("ParticleEmitter")
		energy.Texture, energy.Color = SPARK, ColorSequence.new(self.Colors.Overcharge, C(140, 230, 255))
		energy.Rate, energy.Lifetime = if self.Settings.Detail then 12 else 4, NumberRange.new(0.6, 1)
		energy.Speed, energy.EmissionDirection = NumberRange.new(2, 4), Enum.NormalId.Top
		energy.Size, energy.LightEmission = NumberSequence.new(0.3, 0), 0.8
		energy.Parent = attachment
		local key = character:GetFullName() .. "Overcharge"
		self.Active[key] = {
			Folder = folder,
			Character = character,
			Root = root,
			Name = "Overcharge",
			Until = os.clock() + (payload.Duration or 12),
			Start = os.clock(),
			Welds = welds,
			Attachments = { attachment },
		}
		self:ring(root.Position, self.Colors.Overcharge, 7, 0.5)
		self:text(root.Position + Vector3.new(0, 3, 0), "OVERCHARGED", self.Colors.Overcharge, 18)
	elseif kind == "Timber" then
		self:burst(root.Position - Vector3.new(0, 2.5, 0), self.Colors.Brace, 24, SQUARE, { 6, 12 }, 0.4)
		self:ring(root.Position - Vector3.new(0, 2.8, 0), self.Colors.Brace, 18, 0.6)
		self:text(root.Position + Vector3.new(0, 3, 0), "GROUND BRACED 18s", self.Colors.Brace, 18)
	end
end
-- Pickup feedback: a ghost of the item lifts toward the player and dissolves.
function Effects:pickup(node, position, kind)
	local color = self.Colors[kind] or C(255, 219, 128)
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if node and node.Parent and position and near(position) then
		local ghost = node:Clone()
		for _, child in ghost:GetDescendants() do
			if
				child:IsA("ProximityPrompt")
				or child:IsA("BillboardGui")
				or child:IsA("Script")
				or child:IsA("LocalScript")
			then
				child:Destroy()
			end
		end
		ghost.Name = "PickupGhost"
		ghost.Parent = self.Folder
		local goal = if root then root.Position + Vector3.new(0, 1.5, 0) else position + Vector3.new(0, 4, 0)
		for _, part in { ghost, table.unpack(ghost:GetDescendants()) } do
			if part:IsA("BasePart") then
				part.Anchored, part.CanCollide, part.CanQuery = true, false, false
				part.LocalTransparencyModifier = 0
				local offset = part.Position - position
				tween(
					part,
					0.45,
					{ Position = goal + offset * 0.3, Size = part.Size * 0.35, Transparency = 1 },
					Enum.EasingStyle.Back
				)
			end
		end
		Debris:AddItem(ghost, 0.55)
	end
	self:burst(position, color, 16)
	local label = if kind == "Timber"
		then "+1 Timber"
		elseif kind == "Crystal" then "+1 Crystal"
		elseif kind == "Herb" then "+1 Herb"
		else "+1 " .. tostring(kind) .. " Key"
	self:text((position or Vector3.zero) + Vector3.new(0, 2.5, 0), label, color)
end
function Effects:creatureHit(payload)
	self:burst(
		payload.Position,
		if payload.Defeated then C(255, 230, 150) else C(255, 255, 255),
		if payload.Defeated then 40 else 14,
		SPARK,
		{ 8, 18 },
		0.5
	)
	self:ring(payload.Position, C(255, 240, 200), if payload.Defeated then 12 else 5, 0.35)
	if payload.Defeated then
		self:text(payload.Position + Vector3.new(0, 4, 0), "DEFEATED!", C(255, 220, 130), 22)
	end
end
function Effects:creatureAttack(payload)
	self:ring(payload.Position, C(255, 90, 80), payload.Radius or 10, 0.5)
	self:burst(payload.Position, C(255, 150, 110), 18, SMOKE, { 6, 14 }, 1.5)
end
function Effects:updraft(payload)
	if payload.Position then
		for k = 0, 2 do
			self:ring(payload.Position + Vector3.new(0, k * 5, 0), C(220, 245, 255), 4 + k, 0.5)
		end
	end
end
-- Ocean impact: spray and spreading rings at the water line.
function Effects:splash(position)
	if not position then
		return
	end
	local surface = Vector3.new(position.X, math.max(position.Y, -40), position.Z)
	self:burst(surface, C(220, 245, 255), 34, SMOKE, { 10, 22 }, 1.6)
	self:ring(surface, C(200, 240, 250), 10, 0.6)
	self:ring(surface, C(160, 220, 235), 18, 1.1)
end
function Effects:chest(position)
	self:burst(position, C(255, 214, 120), 30, SPARK, { 6, 14 }, 0.5)
	self:ring(position, C(255, 214, 120), 6, 0.5)
end
-- Per-frame animation: Aegis pulse and break, overcharge orbit, leap landing and expiry.
function Effects:update(_dt, data)
	local now = os.clock()
	for key, active in self.Active do
		local alive = active.Folder.Parent and active.Root.Parent and now < active.Until
		if
			active.Name == "Shield"
			and active.Character == Players.LocalPlayer.Character
			and data
			and data.PowerStatus
		then
			-- The server's shield state is authoritative for the local player: absorbed or expired.
			if (data.PowerStatus.Shield or 0) <= 0 and now - active.Start > 0.5 then
				alive = false
			end
		end
		if not alive then
			if active.Name == "Shield" and active.Root.Parent then
				self:burst(active.Root.Position, self.Colors.Shield, 30, SPARK, { 10, 20 }, 0.5)
				self:ring(active.Root.Position, self.Colors.Shield, 9, 0.4)
				if self.OnShieldBreak and active.Character == Players.LocalPlayer.Character then
					self.OnShieldBreak()
				end
			end
			if active.Folder.Parent then
				active.Folder:Destroy()
			end
			for _, attachment in active.Attachments or {} do
				if attachment.Parent then
					attachment:Destroy()
				end
			end
			if active.Root.Parent then
				for _, child in active.Root:GetChildren() do
					if child:GetAttribute("PowerFX") then
						child:Destroy()
					end
				end
			end
			self.Active[key] = nil
		else
			if active.Pulse then
				active.Pulse.Transparency = 0.86 + math.sin(now * 6) * 0.06
			end
			if active.Welds then
				for k, w in active.Welds do
					w.C0 = CFrame.Angles(0, now * 3 + k * 2.09, 0)
						* CFrame.new(0, math.sin(now * 4 + k) * 0.6, -2.6)
				end
			end
			if active.Leap and now - active.Start > 0.35 then
				local hum = active.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.FloorMaterial ~= Enum.Material.Air then
					active.Leap = false
					active.Until = now
					self:burst(
						active.Root.Position - Vector3.new(0, 3, 0),
						C(220, 220, 210),
						14,
						SMOKE,
						{ 3, 6 },
						1
					)
				end
			end
		end
	end
end
return Effects
