--!nonstrict
-- Client atmosphere: per-realm sky profiles (Sky, Atmosphere, Clouds, Bloom, SunRays, grading),
-- a cloud sea below the islands, an approaching storm front, rain/wind/lightning, the hurricane,
-- quake dust, local machinery animation and distance-based scenery culling.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Biomes = require(Shared.BiomeConfig)
local Config = require(Shared.GameConfig)
local Storm = require(Shared.StormConfig)
local Realms = require(Shared.RealmConfig)
local Hurricane = require(script.Parent.HurricaneController)
local Environment = {}
Environment.__index = Environment
local detailNames = {
	Trunk = true,
	Canopy = true,
	TreeCanopy = true,
	Crystal = true,
	Flower = true,
	Pillar = true,
	Waterfall = true,
	RockFoundation = true,
	GrassBlade = true,
	RealmFlora = true,
	TreeBranch = true,
	TreeCrown = true,
	HouseDetail = true,
}
local function color(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
local function visual(parent, name, size, cf, tint, material, class)
	local p = Instance.new(class or "Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, tint
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end
local function sequence(points)
	local keys = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end
local function lighting(class, name)
	local existing = Lighting:FindFirstChildOfClass(class)
	if existing then
		return existing
	end
	local object = Instance.new(class)
	object.Name = name
	object.Parent = Lighting
	return object
end
function Environment.new(settings)
	local self = setmetatable({
		Settings = settings,
		Accum = 0,
		Corruption = {},
		DetailCache = {},
		NextLightning = 0,
		Emotes = {},
		StormState = { Phase = "Clear", Intensity = 0, Gust = 0, LightningSerial = 0, Round = nil },
		RecoveryElapsed = Storm.Recovery,
		HadStorm = false,
		WeatherMode = nil,
		Spinners = {},
	}, Environment)
	self.Root = Instance.new("Folder")
	self.Root.Name = "LocalAtmosphere"
	self.Root.Parent = workspace
	-- Distant floating-island silhouettes: inverted wedge hulls read as islands through haze.
	self.Backdrop = Instance.new("Model")
	self.Backdrop.Name = "DistantRealms"
	self.Backdrop.Parent = self.Root
	for i = 1, 22 do
		local angle = i * 2.399
		local radius = 280 + i % 4 * 80
		local pos = Vector3.new(math.sin(angle) * radius, (i % 7 - 3) * 75, math.cos(angle) * radius)
		if i % 2 == 0 then
			local size = 1 + (i % 3) * 0.35
			local hull = visual(
				self.Backdrop,
				"Silhouette",
				Vector3.new(34, 16, 26) * size,
				CFrame.new(pos + Vector3.new(25, 18, 0)) * CFrame.Angles(math.pi, angle, 0),
				Color3.fromRGB(112, 130, 160),
				Enum.Material.Slate
			)
			hull.Shape = Enum.PartType.Wedge
		end
	end
	self.WeatherAnchor =
		visual(self.Root, "WeatherAnchor", Vector3.new(80, 1, 80), CFrame.new(0, 100, 0), Color3.new(1, 1, 1))
	self.WeatherAnchor.Transparency = 1
	self.Weather = Instance.new("ParticleEmitter")
	self.Weather.Texture = "rbxasset://textures/particles/SquareParticle.png"
	self.Weather.Rate, self.Weather.Lifetime = 0, NumberRange.new(1, 2)
	self.Weather.EmissionDirection = Enum.NormalId.Bottom
	self.Weather.SpreadAngle, self.Weather.Speed = Vector2.new(60, 60), NumberRange.new(10, 20)
	self.Weather.Size = NumberSequence.new(0.15)
	self.Weather.Parent = self.WeatherAnchor
	self.Weather.Shape = Enum.ParticleEmitterShape.Box
	self.Weather.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	-- Distant rain sheets: large faint streaks that add depth without obscuring routes.
	self.RainSheets = Instance.new("ParticleEmitter")
	self.RainSheets.Name, self.RainSheets.Texture =
		"RainSheets", "rbxasset://textures/particles/SquareParticle.png"
	self.RainSheets.Rate, self.RainSheets.Lifetime = 0, NumberRange.new(0.5, 0.7)
	self.RainSheets.Orientation = Enum.ParticleOrientation.VelocityParallel
	self.RainSheets.Size, self.RainSheets.Squash = NumberSequence.new(0.6), NumberSequence.new(6)
	self.RainSheets.Transparency = NumberSequence.new(0.86)
	self.RainSheets.EmissionDirection, self.RainSheets.SpreadAngle = Enum.NormalId.Bottom, Vector2.new(4, 4)
	self.RainSheets.Shape, self.RainSheets.ShapeStyle =
		Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
	self.RainSheets.Parent = self.WeatherAnchor
	self.ColorGrade = Lighting:FindFirstChild("RealmGrade") or Instance.new("ColorCorrectionEffect")
	self.ColorGrade.Name, self.ColorGrade.Saturation, self.ColorGrade.Parent = "RealmGrade", 0.08, Lighting
	self.Bloom = lighting("BloomEffect", "RealmBloom")
	self.SunRays = lighting("SunRaysEffect", "RealmSunRays")
	self.Sky = lighting("Sky", "RealmSky")
	pcall(function()
		self.Sky.CelestialBodiesShown = true
		Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 0.55, 0.5
		Lighting.ShadowSoftness = 0.3
	end)
	self.BaseWind = workspace.GlobalWind or Vector3.zero
	self.BaseBrightness, self.BaseExposure = Lighting.Brightness, Lighting.ExposureCompensation
	local terrain = workspace:WaitForChild("Terrain")
	self.Clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	if not self.Clouds.Parent then
		self.Clouds.Name, self.Clouds.Cover, self.Clouds.Density = "RealmSkyClouds", 0.32, 0.35
		self.Clouds.Color, self.Clouds.Parent = Color3.fromRGB(222, 228, 235), terrain
	end
	self.BaseCloud = { Cover = self.Clouds.Cover, Density = self.Clouds.Density, Color = self.Clouds.Color }
	self.Clouds.Enabled = true
	self.Atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	if not self.Atmosphere.Parent then
		self.Atmosphere.Density, self.Atmosphere.Offset, self.Atmosphere.Parent = 0.28, 0.1, Lighting
	end
	self.BaseAtmosphere =
		{ Density = self.Atmosphere.Density, Haze = self.Atmosphere.Haze, Decay = self.Atmosphere.Decay }
	self.CloudLayers = {}
	for i = 1, 3 do
		local anchor = visual(
			self.Root,
			"CloudLayer" .. i,
			Vector3.new(540 + i * 80, 1, 320 + i * 50),
			CFrame.new(0, Storm.CloudHeight + (i - 1) * 60, 0),
			Color3.new(1, 1, 1)
		)
		anchor.Transparency = 1
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name, emitter.Texture = "WindShearedCloud", "rbxasset://textures/particles/smoke_main.dds"
		emitter.Rate, emitter.Lifetime = 0, NumberRange.new(9, 12)
		emitter.Size = sequence({ { 0, 42 + i * 9 }, { 1, 72 + i * 10 } })
		emitter.Squash = NumberSequence.new(-0.6 - i * 0.12)
		emitter.Rotation, emitter.RotSpeed = NumberRange.new(-180, 180), NumberRange.new(-3, 3)
		emitter.Transparency = sequence({ { 0, 1 }, { 0.2, 0.66 + i * 0.04 }, { 0.75, 0.82 }, { 1, 1 } })
		emitter.Shape, emitter.ShapeStyle =
			Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
		emitter.EmissionDirection, emitter.SpreadAngle = Enum.NormalId.Front, Vector2.new(12, 6)
		emitter.LightEmission, emitter.LightInfluence, emitter.LockedToPart = 0, 0.65, true
		emitter.Parent = anchor
		table.insert(self.CloudLayers, { Anchor = anchor, Emitter = emitter })
	end
	-- Cloud sea: flat stratus far below the islands; rises with (and tints toward) the deletion.
	self.CloudSea =
		visual(self.Root, "CloudSea", Vector3.new(900, 1, 900), CFrame.new(0, -150, 0), Color3.new(1, 1, 1))
	self.CloudSea.Transparency = 1
	self.SeaEmitter = Instance.new("ParticleEmitter")
	self.SeaEmitter.Name, self.SeaEmitter.Texture = "CloudSea", "rbxasset://textures/particles/smoke_main.dds"
	self.SeaEmitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	self.SeaEmitter.EmissionDirection, self.SeaEmitter.SpreadAngle = Enum.NormalId.Top, Vector2.new(2, 2)
	self.SeaEmitter.Speed, self.SeaEmitter.Lifetime = NumberRange.new(0.4, 0.8), NumberRange.new(20, 26)
	self.SeaEmitter.Size = sequence({ { 0, 70 }, { 1, 110 } })
	self.SeaEmitter.Transparency = sequence({ { 0, 1 }, { 0.2, 0.6 }, { 0.8, 0.68 }, { 1, 1 } })
	self.SeaEmitter.Rotation, self.SeaEmitter.RotSpeed = NumberRange.new(-180, 180), NumberRange.new(-2, 2)
	self.SeaEmitter.LightInfluence, self.SeaEmitter.Rate = 0.85, 0
	self.SeaEmitter.Shape, self.SeaEmitter.ShapeStyle =
		Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
	self.SeaEmitter.Parent = self.CloudSea
	-- Storm front: a dark, irregular shelf cloud that rolls in from upwind during buildup.
	self.StormFront =
		visual(self.Root, "StormFront", Vector3.new(520, 70, 60), CFrame.new(0, 200, 0), Color3.new(1, 1, 1))
	self.StormFront.Transparency = 1
	self.FrontEmitter = Instance.new("ParticleEmitter")
	self.FrontEmitter.Name, self.FrontEmitter.Texture =
		"ShelfCloud", "rbxasset://textures/particles/smoke_main.dds"
	self.FrontEmitter.Size = sequence({ { 0, 80 }, { 1, 140 } })
	self.FrontEmitter.Squash = NumberSequence.new(-0.35)
	self.FrontEmitter.Lifetime, self.FrontEmitter.Speed = NumberRange.new(10, 14), NumberRange.new(4, 8)
	self.FrontEmitter.Transparency = sequence({ { 0, 1 }, { 0.2, 0.3 }, { 0.75, 0.42 }, { 1, 1 } })
	self.FrontEmitter.Rotation, self.FrontEmitter.RotSpeed =
		NumberRange.new(-180, 180), NumberRange.new(-4, 4)
	self.FrontEmitter.LightInfluence, self.FrontEmitter.Rate = 0.4, 0
	self.FrontEmitter.EmissionDirection = Enum.NormalId.Front
	self.FrontEmitter.Shape, self.FrontEmitter.ShapeStyle =
		Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
	self.FrontEmitter.Parent = self.StormFront
	self.WindAnchor =
		visual(self.Root, "WindAnchor", Vector3.new(55, 15, 55), CFrame.new(), Color3.new(1, 1, 1))
	self.WindAnchor.Transparency = 1
	self.WindParticles = Instance.new("ParticleEmitter")
	self.WindParticles.Name, self.WindParticles.Texture =
		"WindSpray", "rbxasset://textures/particles/smoke_main.dds"
	self.WindParticles.Rate, self.WindParticles.Lifetime = 0, NumberRange.new(0.6, 1)
	self.WindParticles.Size, self.WindParticles.Squash = NumberSequence.new(0.6), NumberSequence.new(-1.5)
	self.WindParticles.Transparency = NumberSequence.new(0.88)
	self.WindParticles.EmissionDirection, self.WindParticles.SpreadAngle =
		Enum.NormalId.Front, Vector2.new(8, 12)
	self.WindParticles.Parent = self.WindAnchor
	self.LightningAnchor =
		visual(self.Root, "DistantLightning", Vector3.one, CFrame.new(), Color3.new(1, 1, 1))
	self.LightningAnchor.Transparency = 1
	self.BoltPoints, self.Bolts, self.Forks = {}, {}, {}
	for i = 1, 7 do
		local point = Instance.new("Attachment")
		point.Parent = self.LightningAnchor
		table.insert(self.BoltPoints, point)
		if i > 1 then
			local beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1 = self.BoltPoints[i - 1], point
			beam.Width0, beam.Width1, beam.FaceCamera = 0.55, 0.25, true
			beam.Color, beam.LightEmission, beam.Transparency =
				ColorSequence.new(Color3.fromRGB(220, 228, 237)), 0.7, NumberSequence.new(0.15)
			beam.Enabled, beam.Parent = false, self.LightningAnchor
			table.insert(self.Bolts, beam)
		end
	end
	-- Branching forks: three short side beams from the main channel.
	for i = 1, 3 do
		local tip = Instance.new("Attachment")
		tip.Parent = self.LightningAnchor
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = self.BoltPoints[i + 2], tip
		beam.Width0, beam.Width1, beam.FaceCamera = 0.3, 0.08, true
		beam.Color, beam.LightEmission = ColorSequence.new(Color3.fromRGB(205, 214, 240)), 0.6
		beam.Transparency = NumberSequence.new(0.3)
		beam.Enabled, beam.Parent = false, self.LightningAnchor
		table.insert(self.Forks, { Beam = beam, Tip = tip })
	end
	self.FlashLight = Instance.new("PointLight")
	self.FlashLight.Color, self.FlashLight.Range, self.FlashLight.Brightness =
		Color3.fromRGB(215, 224, 237), 55, 0
	self.FlashLight.Shadows, self.FlashLight.Parent = true, self.WeatherAnchor
	self.PowerVisuals = {}
	self.Hurricane = Hurricane.new(self.Root, settings)
	self.QuakeAnchor =
		visual(self.Root, "EarthquakeDust", Vector3.new(12, 0.2, 12), CFrame.new(), Color3.new(1, 1, 1))
	self.QuakeAnchor.Transparency = 1
	self.QuakeDust = Instance.new("ParticleEmitter")
	self.QuakeDust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	self.QuakeDust.Rate, self.QuakeDust.Lifetime, self.QuakeDust.Speed =
		0, NumberRange.new(0.6, 1.2), NumberRange.new(2, 4)
	self.QuakeDust.Size = sequence({ { 0, 0.6 }, { 1, 3 } })
	self.QuakeDust.Transparency = sequence({ { 0, 0.8 }, { 0.4, 0.86 }, { 1, 1 } })
	self.QuakeDust.Color, self.QuakeDust.EmissionDirection =
		ColorSequence.new(Color3.fromRGB(165, 153, 136)), Enum.NormalId.Top
	self.QuakeDust.Shape, self.QuakeDust.ShapeStyle =
		Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Volume
	self.QuakeDust.Parent = self.QuakeAnchor
	-- Ocean horizon: streamed Terrain water renders near the player; this flat surface (3x3
	-- tiles of 2048 studs following the camera, just under the water line) carries the ocean
	-- to the horizon so no void or baseplate is ever visible below the realms.
	self.OceanFolder = Instance.new("Folder")
	self.OceanFolder.Name = "LocalOcean"
	self.OceanFolder.Parent = workspace
	self.OceanTiles = {}
	for i = 1, 9 do
		local tile = visual(
			self.OceanFolder,
			"OceanSurface",
			Vector3.new(2048, 1, 2048),
			CFrame.new(),
			Color3.fromRGB(30, 118, 138),
			Enum.Material.Glass
		)
		tile.Transparency, tile.Reflectance = 0.05, 0.12
		self.OceanTiles[i] = tile
	end
	return self
end
function Environment:lightning(camera)
	local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-look.Z, 0, look.X)
	local position = camera.CFrame.Position
		+ look * math.random(280, 420)
		+ right * math.random(-150, 150)
		+ Vector3.new(0, 210, 0)
	self.LightningAnchor.CFrame = CFrame.new(position)
	for i, point in self.BoltPoints do
		point.Position =
			Vector3.new(if i == 1 then 0 else math.random(-9, 9), -(i - 1) * 16, math.random(-3, 3))
	end
	for i, fork in self.Forks do
		local from = self.BoltPoints[i + 2].Position
		fork.Tip.Position = from + Vector3.new(math.random(-14, 14), -math.random(8, 16), math.random(-4, 4))
	end
	self.BoltUntil = os.clock() + 0.18
	local state = self.StormState
	state.LightningSerial += 1
	state.ThunderDelay = math.clamp((position - camera.CFrame.Position).Magnitude / 343, 0.8, 3)
	state.ThunderGain = 0.22 + state.Intensity * 0.3
	-- A faint rumble follows the strike (camera settings and shelter respected by CameraController).
	state.ShakeAt, state.ShakeAmount = os.clock() + state.ThunderDelay, 0.03 + state.Intensity * 0.04
end
-- Legacy hook kept for compatibility; PowerEffects now owns pickup feedback.
function Environment:pickup(position)
	if self.Effects then
		self.Effects:burst(position, Color3.fromRGB(255, 219, 128), 10)
	end
end
function Environment:ability(payload)
	if self.Effects then
		self.Effects:ability(payload)
	end
end
function Environment:emote(uid)
	local player = Players:GetPlayerByUserId(uid)
	local character = player and player.Character
	if not character then
		return
	end
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and (joint.Name == "RightShoulder" or joint.Name == "Right Shoulder") then
			if not self.Emotes[uid] then
				self.Emotes[uid] = { Joint = joint, Base = joint.C0, Start = os.clock() }
			end
			break
		end
	end
end
-- Smoothly blended realm sky profile for the camera's logical altitude.
function Environment:profile(dt, biome, nextBiome, blend)
	local target = Realms.blendSky(Realms.get(biome.Id).Sky, Realms.get(nextBiome.Id).Sky, blend)
	if not self.SkyProfile then
		self.SkyProfile = target
	else
		self.SkyProfile = Realms.blendSky(self.SkyProfile, target, 1 - math.exp(-dt * 0.8))
	end
	return self.SkyProfile
end
function Environment:updateWeather(dt, data, camera, biome, tint, sky)
	local state, now = self.StormState, os.clock()
	local viewing = data.State == "Alive" or data.State == "Spectating"
	if data.RoundNumber ~= nil and state.Round ~= data.RoundNumber then
		state.Round, state.Intensity, state.Phase = data.RoundNumber, 0, "Clear"
		self.HadStorm, self.RecoveryElapsed, self.NextLightning, self.BoltUntil = false, Storm.Recovery, 0, 0
		self.Weather:Clear()
		self.WindParticles:Clear()
		self.Weather.Rate, self.WindParticles.Rate = 0, 0
		for _, layer in self.CloudLayers do
			layer.Emitter:Clear()
		end
	end
	local phase, target = Storm.sample(data.Event, data.EventPhase, data.EventRemaining)
	if not viewing then
		phase, target = "Clear", 0
	end
	local starting = phase ~= "Clear" and not self.HadStorm
	if phase ~= "Clear" then
		self.HadStorm, self.RecoveryElapsed = true, 0
		state.Phase = phase
	elseif self.HadStorm then
		self.HadStorm, self.RecoveryFrom, self.RecoveryElapsed = false, state.Intensity, 0
	end
	if phase == "Clear" then
		self.RecoveryElapsed = math.min(Storm.Recovery, self.RecoveryElapsed + dt)
		if viewing and self.RecoveryElapsed < Storm.Recovery then
			state.Phase = "Recovery"
			target = (self.RecoveryFrom or 0) * (1 - Storm.smooth(self.RecoveryElapsed / Storm.Recovery))
		else
			state.Phase = "Clear"
		end
	end
	local alpha = 1 - math.exp(-dt * 1.8)
	state.Intensity += (target - state.Intensity) * alpha
	if state.Phase == "Clear" then
		state.Intensity = 0
	end
	state.Gust = if viewing and not data.Sheltered then Storm.gust(now, state.Intensity) else 0
	local intensity, gust = state.Intensity, state.Gust
	self.Hurricane:update(dt, data, state, camera)
	local windDirection = Vector3.new(0.92, 0, 0.38).Unit
	local speed = 8 + intensity * 42 + gust * 28
	state.Wind = windDirection * speed * intensity
	workspace.GlobalWind = self.BaseWind + windDirection * 4 + state.Wind
	self.BaseCloud.Cover, self.BaseCloud.Density, self.BaseCloud.Color =
		sky.Clouds.Cover, sky.Clouds.Density, color(sky.Clouds.Color)
	self.Clouds.Cover = self.BaseCloud.Cover + (0.93 - self.BaseCloud.Cover) * intensity
	self.Clouds.Density = self.BaseCloud.Density + (0.76 - self.BaseCloud.Density) * intensity
	self.Clouds.Color = self.BaseCloud.Color:Lerp(Color3.fromRGB(77, 84, 94), intensity)
	for i, layer in self.CloudLayers do
		local position = camera.CFrame.Position
			+ Vector3.new((i - 2) * 100, Storm.CloudHeight + (i - 1) * 60, -180 - i * 40)
		layer.Anchor.CFrame = CFrame.lookAt(position, position + windDirection)
		layer.Emitter.Rate = if i == 3 and not self.Settings.Detail then 0 else (0.35 + i * 0.08) * intensity
		layer.Emitter.LocalTransparencyModifier = 1 - intensity
		layer.Emitter.Speed = NumberRange.new(speed * (0.5 + i * 0.1), speed * (0.7 + i * 0.1))
		layer.Emitter.Color = ColorSequence.new(Color3.fromRGB(91 + i * 8, 99 + i * 8, 110 + i * 7))
		if starting and (i < 3 or self.Settings.Detail) then
			layer.Emitter:Emit(2)
		end
	end
	-- Cinematic buildup: the shelf cloud advances from 640 to 230 studs during the approach.
	local approach = math.clamp(intensity / 0.45, 0, 1)
	local frontPos = camera.CFrame.Position
		- windDirection * (640 - 410 * approach)
		+ Vector3.new(0, 70 + (1 - approach) * 50, 0)
	self.StormFront.CFrame = CFrame.lookAt(frontPos, frontPos + windDirection)
	self.FrontEmitter.Rate = if viewing and state.Phase ~= "Clear"
		then (if self.Settings.Detail then 1.6 else 0.7) * math.min(1, intensity * 2.2)
		else 0
	self.FrontEmitter.Color =
		ColorSequence.new(Color3.fromRGB(64, 68, 78):Lerp(color(sky.Sea), 0.2), Color3.fromRGB(96, 102, 114))
	local lightAlpha = 1 - math.exp(-dt * 2)
	local climate = if viewing and biome.Weather == "Storm" then 0.16 else 0
	local darkness = math.max(intensity, climate)
	local grade = sky.Grade
	self.ColorGrade.TintColor = self.ColorGrade.TintColor:Lerp(
		color(grade.Tint):Lerp(tint, 0.06):Lerp(Color3.fromRGB(211, 220, 232), darkness * 0.45),
		lightAlpha
	)
	self.ColorGrade.Saturation = grade.Saturation - darkness * 0.2
	self.ColorGrade.Contrast = grade.Contrast + darkness * 0.08
	Lighting.Ambient =
		Lighting.Ambient:Lerp(color(sky.Ambient):Lerp(Color3.fromRGB(70, 76, 90), darkness * 0.6), lightAlpha)
	Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(
		color(sky.Outdoor):Lerp(Color3.fromRGB(82, 90, 104), darkness),
		lightAlpha
	)
	Lighting.Brightness += (sky.Brightness * (1 - darkness * 0.35) - Lighting.Brightness) * lightAlpha
	Lighting.ExposureCompensation += (self.BaseExposure - darkness * 0.22 - Lighting.ExposureCompensation) * lightAlpha
	Lighting.ClockTime += (sky.ClockTime - Lighting.ClockTime) * (1 - math.exp(-dt * 0.5))
	Lighting.GeographicLatitude = sky.Latitude
	local atmos = sky.Atmos
	self.Atmosphere.Color = self.Atmosphere.Color:Lerp(
		color(atmos.Color):Lerp(Color3.fromRGB(153, 163, 178), darkness * 0.65),
		lightAlpha
	)
	self.Atmosphere.Density += (math.min(0.4, atmos.Density + (0.4 - atmos.Density) * darkness * 0.6) - self.Atmosphere.Density) * lightAlpha
	self.Atmosphere.Offset = atmos.Offset
	self.Atmosphere.Haze += (math.min(1.4, atmos.Haze + (1.4 - atmos.Haze) * darkness) - self.Atmosphere.Haze) * lightAlpha
	self.Atmosphere.Glare = atmos.Glare * (1 - darkness)
	self.Atmosphere.Decay = color(atmos.Decay):Lerp(Color3.fromRGB(103, 112, 126), darkness * 0.45)
	self.Bloom.Intensity = sky.Bloom.Intensity * (1 - darkness * 0.4)
	self.Bloom.Size, self.Bloom.Threshold = sky.Bloom.Size, sky.Bloom.Threshold
	self.SunRays.Intensity = sky.Rays.Intensity * (1 - darkness) * (if self.Settings.Detail then 1 else 0.5)
	self.SunRays.Spread = sky.Rays.Spread
	pcall(function()
		self.Sky.StarCount = math.floor(sky.Stars)
		self.Sky.SunAngularSize, self.Sky.MoonAngularSize = sky.SunSize, sky.MoonSize
	end)
	local wet = intensity > 0.01 or biome.Weather == "Rain" or biome.Weather == "Storm"
	local mode = if wet then "Rain" elseif biome.Weather == "Snow" then "Snow" else "Ambient"
	if self.WeatherMode ~= mode then
		self.WeatherMode = mode
		self.Weather:Clear()
		self.Weather.Texture = if wet
			then "rbxasset://textures/particles/SquareParticle.png"
			else "rbxasset://textures/particles/sparkles_main.dds"
		self.Weather.Squash = NumberSequence.new(if wet then 4 else 0)
		self.Weather.Orientation = if wet
			then Enum.ParticleOrientation.VelocityParallel
			else Enum.ParticleOrientation.FacingCamera
		self.Weather.Lifetime = if wet then NumberRange.new(0.35, 0.55) else NumberRange.new(1, 2)
		self.Weather.Transparency = NumberSequence.new(if wet then 0.65 else 0.3)
		self.Weather.SpreadAngle = if wet then Vector2.new(6, 6) else Vector2.new(60, 60)
	end
	local rainCap = if self.Settings.Detail then Storm.RainRate else Storm.LowRainRate
	local biomeRain = if biome.Weather == "Rain" or biome.Weather == "Storm"
		then (if self.Settings.Detail then 22 else 0)
		else 0
	local rate = if wet
		then math.max(biomeRain, rainCap * intensity + gust * 8)
		elseif not self.Settings.Detail then 0
		elseif mode == "Snow" then 35
		else 10
	self.Weather.Rate += (math.min(rainCap, rate) - self.Weather.Rate) * alpha
	self.RainSheets.Rate = if wet
			and self.Settings.Detail
			and viewing
			and not data.Sheltered
		then 30 * intensity
		else 0
	if data.Sheltered or not viewing then
		self.Weather.Rate = 0
		if not self.WasSheltered then
			self.Weather:Clear()
			self.WindParticles:Clear()
		end
	end
	self.WasSheltered = data.Sheltered or not viewing
	self.WeatherAnchor.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 24, 0) - state.Wind * 0.12)
	self.Weather.Color = ColorSequence.new(if wet then Color3.fromRGB(178, 190, 208) else tint)
	self.Weather.Speed = if wet
		then NumberRange.new(65 + intensity * 15, 80 + intensity * 20)
		elseif mode == "Snow" then NumberRange.new(3, 6)
		else NumberRange.new(1, 3)
	self.Weather.Acceleration = if wet
		then state.Wind * 1.8 + Vector3.new(0, -35, 0)
		else Vector3.new(1, -1, 0)
	self.RainSheets.Speed = NumberRange.new(90, 110)
	self.RainSheets.Acceleration = state.Wind * 2
	self.Weather.Size = NumberSequence.new(if wet then 0.32 else 0.2)
	self.WindAnchor.CFrame = CFrame.lookAt(
		camera.CFrame.Position + Vector3.new(0, 6, 0),
		camera.CFrame.Position + Vector3.new(0, 6, 0) + windDirection
	)
	self.WindParticles.Rate = if self.Settings.Detail
			and viewing
			and not data.Sheltered
		then Storm.WindRate * gust
		else 0
	self.WindParticles.Speed = NumberRange.new(speed, speed * 1.3)
	self.WindParticles.Color = ColorSequence.new(Color3.fromRGB(177, 186, 196))
	if starting then
		self.NextLightning = now + (if phase == "Approaching" then 3 else 1.5)
	end
	if self.HadStorm and now >= self.NextLightning then
		self.NextLightning = now
			+ (if phase == "Extreme" then 5 + math.random() * 3 else 9 + math.random() * 5)
		self:lightning(camera)
	end
	local flashing = now < (self.BoltUntil or 0) and viewing
	for _, beam in self.Bolts do
		beam.Enabled = flashing
	end
	for _, fork in self.Forks do
		fork.Beam.Enabled = flashing and self.Settings.Detail
	end
	self.FrontEmitter.LightEmission = if flashing then 0.35 else 0
	local flash = if flashing and self.Settings.Camera then 0.075 else 0
	self.ColorGrade.Brightness = -darkness * 0.08 + flash
	self.FlashLight.Brightness = if flashing and self.Settings.Camera and self.Settings.Detail then 1.4 else 0
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local shaking = data.State == "Alive"
		and data.Event == "Earthquake"
		and data.EventPhase == "Active"
		and root
		and hum
		and hum.Health > 0
		and hum.FloorMaterial ~= Enum.Material.Air
		and not data.Transit
	if root then
		self.QuakeAnchor.CFrame =
			CFrame.new(root.Position - Vector3.new(0, hum and hum.HipHeight + root.Size.Y / 2 - 0.1 or 3))
	end
	self.QuakeDust.Rate = if shaking and self.Settings.Detail then (if data.Sheltered then 5 else 14) else 0
	if not shaking and self.WasQuaking then
		self.QuakeDust:Clear()
	end
	self.WasQuaking = shaking
end
-- Cloud sea below the islands; rises toward the deletion wave and tints violet as it nears.
function Environment:updateSea(data, camera, sky)
	local physicalWave = if data.Wave and data.Origin then data.Wave - data.Origin else -math.huge
	-- Sea mist hugs the ocean surface, then rides the rising deletion wave once it is higher.
	local y = math.max(Config.OceanY + 10, physicalWave + 6)
	local snap = 512
	local cx = math.floor(camera.CFrame.Position.X / snap + 0.5) * snap
	local cz = math.floor(camera.CFrame.Position.Z / snap + 0.5) * snap
	for i, tile in self.OceanTiles do
		local gx, gz = (i - 1) % 3 - 1, math.floor((i - 1) / 3) - 1
		tile.CFrame = CFrame.new(cx + gx * 2048, Config.OceanY - 1.2, cz + gz * 2048)
		tile.Color = Color3.fromRGB(30, 118, 138):Lerp(color(sky.Atmos.Color), 0.15)
	end
	local horizontal = camera.CFrame.Position
	self.CloudSea.CFrame = CFrame.new(horizontal.X, y, horizontal.Z)
	local danger = if data.State == "Alive" then math.clamp(1 - (data.Distance or 999) / 160, 0, 1) else 0
	self.SeaEmitter.Color = ColorSequence.new(color(sky.Sea):Lerp(Color3.fromRGB(150, 70, 220), danger * 0.7))
	self.SeaEmitter.Rate = if self.Settings.Detail then 2 else 0.8
end
-- Visual-only bridge sway: planks and ropes drift sideways (strongest mid-span), more in
-- storms and while the local player is on the bridge. Collision segments never move.
function Environment:sway()
	local now = os.clock()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local storm = self.StormState.Intensity or 0
	for _, detail in self.DetailCache do
		if
			detail.Sway
			and #detail.Sway > 0
			and (detail.Distance or math.huge) < 420
			and self.Settings.Detail
		then
			local amp = 0.14 + storm * 0.35 + (if detail.Occupied then 0.12 else 0)
			local occupied = false
			for _, entry in detail.Sway do
				local part = entry.Part
				if part.Parent and part.Transparency < 1 then
					if entry.Last == nil or part.CFrame ~= entry.Last then
						entry.Base = part.CFrame
					end
					local wave = math.sin(now * 1.3 + entry.T * 2.4) * math.sin(math.pi * entry.T)
					local cf = entry.Base
						+ entry.Dir * (wave * amp)
						- Vector3.new(0, math.abs(wave) * amp * 0.2, 0)
					part.CFrame, entry.Last = cf, cf
					if root and not occupied and (entry.Base.Position - root.Position).Magnitude < 6 then
						occupied = true
					end
				end
			end
			detail.Occupied = occupied
		end
	end
end
-- Local machinery animation: parts tagged Spin rotate with their SpinKey group.
function Environment:spin(dt)
	for _, group in self.Spinners do
		local hub = group.Hub
		if hub.Parent and hub.Transparency == 0 then
			local speed = hub:GetAttribute("Spin")
			if speed then
				if
					group.LastSet == nil
					or (hub.CFrame.Position - group.LastSet.Position).Magnitude > 0.05
				then
					group.Base, group.Angle, group.Offsets = hub.CFrame, 0, {}
					for _, member in group.Members do
						if member.Parent then
							group.Offsets[member] = hub.CFrame:ToObjectSpace(member.CFrame)
						end
					end
				end
				group.Angle += speed * dt
				local axis = hub:GetAttribute("SpinAxis")
				local rotation = if axis == "Y"
					then CFrame.Angles(0, group.Angle, 0)
					else CFrame.Angles(group.Angle, 0, 0)
				local cf = group.Base * rotation
				hub.CFrame, group.LastSet = cf, cf
				for member, offset in group.Offsets do
					if member.Parent and member.Transparency == 0 then
						member.CFrame = cf * offset
					end
				end
			end
		end
	end
end
function Environment:register(island, detail, node)
	if node:IsA("BasePart") then
		if not node.CanCollide and (detailNames[node.Name] or node:GetAttribute("Detail")) then
			table.insert(detail.Parts, node)
			if detail.Hidden then
				node.LocalTransparencyModifier = 1
			end
		end
		local key = node:GetAttribute("SpinKey")
		local speed = node:GetAttribute("Spin")
		if key or speed then
			-- Groups share a SpinKey: the cylinder hub rotates about its axis and carries members.
			local id = (key or node:GetFullName()) .. "@" .. island.Name
			local group = self.Spinners[id]
			if not group then
				group = { Members = {} }
				self.Spinners[id] = group
			end
			local cylinder = node:IsA("Part") and node.Shape == Enum.PartType.Cylinder
			if not key or (cylinder and not group.Hub) then
				group.Hub = node
			else
				table.insert(group.Members, node)
			end
			group.LastSet = nil
		end
		if node:GetAttribute("Sway") and node:GetAttribute("SwayDir") then
			table.insert(
				detail.Sway,
				{ Part = node, T = node:GetAttribute("Sway"), Dir = node:GetAttribute("SwayDir") }
			)
		end
	elseif node:IsA("PointLight") then
		table.insert(detail.Lights, node)
	end
end
function Environment:update(dt, data)
	local camera = workspace.CurrentCamera
	local logicalY = camera.CFrame.Position.Y
		+ (if data.State == "Alive" or data.State == "Spectating" then data.Origin else 0)
	local biome, nextBiome, blend = Biomes.at(math.max(0, logicalY - Config.StartY))
	local tint = color(biome.Accent):Lerp(color(nextBiome.Accent), blend)
	local sky = self:profile(dt, biome, nextBiome, blend)
	self:updateWeather(dt, data, camera, biome, tint, sky)
	self:updateSea(data, camera, sky)
	if self.Settings.Detail then
		self:spin(dt)
	end
	self:sway()
	for uid, emote in self.Emotes do
		local elapsed = os.clock() - emote.Start
		if not emote.Joint.Parent or elapsed > 2 then
			if emote.Joint.Parent then
				emote.Joint.C0 = emote.Base
			end
			self.Emotes[uid] = nil
		else
			emote.Joint.C0 = emote.Base * CFrame.Angles(0, 0, -1.6 + math.sin(elapsed * 12) * 0.25)
		end
	end
	self.Accum += dt
	if self.Accum < 0.25 then
		return
	end
	self.Accum = 0
	self.Backdrop:PivotTo(CFrame.new(0, math.floor(camera.CFrame.Position.Y / 32) * 32, 0))
	for _, p in self.Backdrop:GetChildren() do
		p.LocalTransparencyModifier = if self.Settings.Detail then 0 else 1
		p.Color = color(sky.Atmos.Color):Lerp(Color3.fromRGB(96, 110, 136), 0.55)
	end
	local world = workspace:FindFirstChild("FloatingRealms")
	if not world then
		return
	end
	for model, entry in self.Corruption do
		if not model.Parent then
			entry.Effect:Destroy()
			self.Corruption[model] = nil
		end
	end
	for model, detail in self.DetailCache do
		if not model.Parent then
			if detail.Connection then
				detail.Connection:Disconnect()
			end
			self.DetailCache[model] = nil
		end
	end
	for key, group in self.Spinners do
		if not group.Hub or not group.Hub.Parent then
			self.Spinners[key] = nil
		end
	end
	local islands = world:GetChildren()
	local sanctuary = workspace:FindFirstChild("SkySanctuary")
	if sanctuary then
		table.insert(islands, sanctuary)
	end
	for _, island in islands do
		local detail = self.DetailCache[island]
		if not detail then
			detail = { Parts = {}, Lights = {}, Sway = {}, Hidden = nil }
			for _, node in island:GetDescendants() do
				self:register(island, detail, node)
			end
			-- Streaming delivers scenery after the model; register late arrivals too.
			detail.Connection = island.DescendantAdded:Connect(function(node)
				self:register(island, detail, node)
			end)
			self.DetailCache[island] = detail
		end
		local distance = (island:GetPivot().Position - camera.CFrame.Position).Magnitude
		detail.Distance = distance
		local hidden = not self.Settings.Detail or distance > 360
		if detail.Hidden ~= hidden then
			detail.Hidden = hidden
			for _, part in detail.Parts do
				if part.Parent then
					part.LocalTransparencyModifier = if hidden then 1 else 0
				end
			end
		end
		local lit = not hidden and distance < 140
		if detail.Lit ~= lit then
			detail.Lit = lit
			for _, light in detail.Lights do
				if light.Parent then
					light.Enabled = lit
				end
			end
		end
	end
end
return Environment
