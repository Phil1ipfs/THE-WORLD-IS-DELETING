--!nonstrict
-- One invisible anchor, pooled textured ribbons and smoke; no physical cloud spheres.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Layout = require(Shared.RegionLayout)
local Settings = require(Shared.DisasterConfig).Hurricane
local Hurricane = {}
Hurricane.__index = Hurricane
function Hurricane.new(parent, options)
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Transparency = "HurricaneFunnel", Vector3.one, 1
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.CastShadow =
		true, false, false, false, false
	anchor.Parent = parent
	local self = setmetatable(
		{ Anchor = anchor, Options = options, Strands = {}, Emitters = {}, Intensity = 0, Time = 0 },
		Hurricane
	)
	for _ = 1, 2 do
		local points, beams = {}, {}
		for i = 0, Settings.Segments do
			local point = Instance.new("Attachment")
			point.Parent = anchor
			table.insert(points, point)
			if i > 0 then
				local beam = Instance.new("Beam")
				beam.Attachment0, beam.Attachment1 = points[i], point
				beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
				beam.TextureMode, beam.TextureLength, beam.TextureSpeed = Enum.TextureMode.Wrap, 12, 1.2
				beam.FaceCamera, beam.Segments, beam.LightEmission, beam.LightInfluence = true, 4, 0, 0.65
				beam.Color = ColorSequence.new(Color3.fromRGB(77, 83, 91), Color3.fromRGB(119, 126, 136))
				beam.Enabled, beam.Parent = false, anchor
				table.insert(beams, beam)
			end
		end
		table.insert(self.Strands, { Points = points, Beams = beams })
	end
	for i = 0, 6 do
		local attachment = Instance.new("Attachment")
		attachment.Parent = anchor
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name, emitter.Texture = "SpiralCloudWisps", "rbxasset://textures/particles/smoke_main.dds"
		emitter.Rate, emitter.Lifetime, emitter.Speed = 0, NumberRange.new(2, 3.5), NumberRange.new(1, 3)
		emitter.Rotation, emitter.RotSpeed = NumberRange.new(-180, 180), NumberRange.new(30, 65)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.6),
			NumberSequenceKeypoint.new(0.7, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Color, emitter.LightInfluence, emitter.LockedToPart =
			ColorSequence.new(Color3.fromRGB(104, 113, 125)), 0.7, true
		emitter.Parent = attachment
		table.insert(self.Emitters, { Attachment = attachment, Emitter = emitter, Height = i / 6 })
	end
	return self
end
function Hurricane:clear()
	self.Intensity = 0
	for _, strand in self.Strands do
		for _, beam in strand.Beams do
			beam.Enabled = false
		end
	end
	for _, layer in self.Emitters do
		layer.Emitter.Rate = 0
		layer.Emitter:Clear()
	end
end
function Hurricane:update(dt, data, weather, camera)
	local viewing = data.State == "Alive" or data.State == "Spectating"
	local inferred = math.max(
		0,
		math.floor((camera.CFrame.Position.Y + (data.Origin or 0) - Config.StartY) / Config.RegionRise)
	)
	local index = if data.State == "Spectating" then inferred else data.RegionIndex or inferred
	local reset = self.Round ~= data.RoundNumber or self.Region ~= index
	if reset then
		self:clear()
		self.Round, self.Region, self.Origin = data.RoundNumber, index, data.Origin or 0
	end
	self.Origin = data.Origin or 0
	if not viewing then
		self:clear()
		weather.Hurricane = 0
		return
	end
	local target = math.clamp((weather.Intensity - 0.3) / 0.7, 0, 1)
	self.Intensity += (target - self.Intensity) * (1 - math.exp(-dt * 2))
	local serverAge = if data.EventPhase == "Warning"
		then 8 - (data.EventRemaining or 8)
		else 24 - (data.EventRemaining or 16)
	if data.Event == "Storm" then
		if reset or not self.WasStorm then
			self.Time = serverAge
		end
		self.Time += dt + (serverAge - self.Time) * math.min(dt * 0.5, 1)
	else
		self.Time += dt
	end
	self.WasStorm = data.Event == "Storm"
	local position = Layout.center(index, Config.RegionRadius, Config.RegionRise, Config.StartY)
	local center = Vector3.new(position.X, position.Y - self.Origin - 24, position.Z)
	local outward = Vector3.new(position.X, 0, position.Z).Unit
	local sideways = Vector3.new(-outward.Z, 0, outward.X)
	center += outward * Settings.Orbit + sideways * math.sin(self.Time * 0.16) * 32
	self.Anchor.CFrame = CFrame.new(center)
	local strength, spin = self.Intensity, self.Time * 1.7
	weather.Hurricane, weather.HurricaneDistance = strength, (center - camera.CFrame.Position).Magnitude
	for strandIndex, strand in self.Strands do
		for i, point in strand.Points do
			local t = (i - 1) / Settings.Segments
			local radius = Settings.BaseRadius + Settings.TopRadius * t ^ 1.35
			local angle = spin + (strandIndex - 1) * math.pi + t * math.pi * 7
			local drift = Vector3.new(math.sin(t * 4 + self.Time * 0.3) * t * 13, 0, math.cos(t * 5) * t * 9)
			local pointPosition = Vector3.new(
				math.cos(angle) * radius,
				t * Settings.Height,
				math.sin(angle) * radius
			) + drift
			point.CFrame = CFrame.fromMatrix(
				pointPosition,
				Vector3.new(-math.sin(angle), 0, math.cos(angle)),
				Vector3.yAxis
			)
			if i > 1 then
				local beam = strand.Beams[i - 1]
				beam.Enabled = strength > 0.02 and (self.Options.Detail or strandIndex == 1)
				beam.Width0, beam.Width1 = 4 + t * 26, 5 + t * 28
				beam.CurveSize0, beam.CurveSize1 = radius * 0.2, radius * 0.2
				beam.Transparency = NumberSequence.new(1 - strength * 0.48)
			end
		end
	end
	for i, layer in self.Emitters do
		local t = layer.Height
		local radius = Settings.BaseRadius + Settings.TopRadius * t ^ 1.35
		local angle = spin + t * math.pi * 7
		layer.Attachment.Position =
			Vector3.new(math.cos(angle) * radius * 0.6, t * Settings.Height, math.sin(angle) * radius * 0.6)
		layer.Emitter.Size = NumberSequence.new(10 + t * 32)
		layer.Emitter.LocalTransparencyModifier = 1 - strength
		layer.Emitter.Rate = if self.Options.Detail
			then strength * 1.2
			elseif i % 3 == 1 then strength * 0.5
			else 0
	end
	if strength < 0.005 then
		self:clear()
	end
end
return Hurricane
