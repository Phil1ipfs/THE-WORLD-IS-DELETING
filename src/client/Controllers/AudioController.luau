--!nonstrict
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AudioConfig = require(Shared.AudioConfig)
local SoundBank = require(Shared.SoundBank)
local CollectionService = game:GetService("CollectionService")
local Audio = {}
Audio.__index = Audio
local function valid(id)
	return type(id) == "string" and id:match("^rbxassetid://%d+$") ~= nil
end
local function new(class)
	return Instance.new(class)
end
-- Permissioned asset in AudioConfig first, otherwise the designed SoundBank recipe.
function Audio.resolve(key, group)
	if valid(AudioConfig[key]) then
		return { Sound = AudioConfig[key], Speed = 1, Volume = 0.5, Looped = group ~= nil }
	end
	if AudioConfig.UseBuiltinCues == false then
		return nil
	end
	return (group or SoundBank.Cues)[key]
end
local function sound(name, parent, looped, group)
	local s = Instance.new("Sound")
	s.Name, s.Looped, s.Volume, s.SoundGroup = name, looped, 0, group
	s.RollOffMinDistance, s.RollOffMaxDistance = 8, 100
	s.Parent = parent
	return s
end
function Audio.new(settings)
	local self = setmetatable(
		{ Settings = settings, Pool = {}, Index = 0, CharacterConnection = nil, LastDanger = false },
		Audio
	)
	self.MusicGroup = Instance.new("SoundGroup")
	self.MusicGroup.Name = "RealmMusic"
	self.MusicGroup.Parent = SoundService
	self.SFXGroup = Instance.new("SoundGroup")
	self.SFXGroup.Name = "RealmSFX"
	self.SFXGroup.Parent = SoundService
	self.Music = sound("Ascent", SoundService, true, self.MusicGroup)
	self.Danger = sound("Danger", SoundService, true, self.MusicGroup)
	self.Ambient = sound("Biome", SoundService, true, self.SFXGroup)
	self.Wildlife = sound("Wildlife", SoundService, true, self.SFXGroup)
	self.StormWind = sound("StormWind", SoundService, true, self.SFXGroup)
	self.StormRain = sound("StormRain", SoundService, true, self.SFXGroup)
	self.Thunder = sound("Thunder", SoundService, false, self.SFXGroup)
	self.ThunderQueue, self.LastLightning, self.LastStormPhase = {}, 0, "Clear"
	-- Looping beds: permissioned assets when configured, designed SoundBank beds otherwise.
	for _, pair in
		{ { self.StormWind, "StormWind" }, { self.StormRain, "StormRain" }, { self.Danger, "Danger" } }
	do
		self:bed(pair[1], pair[2])
	end
	if valid(AudioConfig.Wildlife) then
		self.Wildlife.SoundId = AudioConfig.Wildlife
		self.Wildlife:Play()
	end
	-- Music has no designed substitute: it stays silent until a permissioned track is set.
	if valid(AudioConfig.Music) then
		self.Music.SoundId = AudioConfig.Music
		self.Music:Play()
	end
	-- World sounds created by the server (balloon burners, forge fire) follow the SFX setting.
	pcall(function()
		for _, s in CollectionService:GetTagged("RealmSound") do
			s.SoundGroup = self.SFXGroup
		end
		CollectionService:GetInstanceAddedSignal("RealmSound"):Connect(function(s)
			s.SoundGroup = self.SFXGroup
		end)
	end)
	for i = 1, 16 do
		local anchor = Instance.new("Part")
		anchor.Name, anchor.Size, anchor.Transparency = "AudioAnchor", Vector3.one, 1
		anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
		anchor.Parent = workspace
		self.Pool[i] = { Anchor = anchor, Sound = sound("OneShot", anchor, false, self.SFXGroup) }
	end
	local function characterAdded(character)
		if self.CharacterConnection then
			self.CharacterConnection:Disconnect()
		end
		local hum = character:WaitForChild("Humanoid", 10)
		if not hum then
			return
		end
		self.CharacterConnection = hum.StateChanged:Connect(function(_, state)
			if state == Enum.HumanoidStateType.Jumping then
				self:play("Jump")
			elseif state == Enum.HumanoidStateType.Landed then
				self:play("Land")
			end
		end)
	end
	Players.LocalPlayer.CharacterAdded:Connect(characterAdded)
	if Players.LocalPlayer.Character then
		task.spawn(characterAdded, Players.LocalPlayer.Character)
	end
	return self
end
function Audio:bed(target, key)
	local recipe = Audio.resolve(key, SoundBank.Beds)
	if recipe and recipe.Sound then
		target.SoundId, target.PlaybackSpeed = recipe.Sound, recipe.Speed or 1
		SoundBank.effects(new, recipe, target)
		target:Play()
	end
	return recipe
end
-- Plays one recipe layer on a pooled positioned source (Start window, Length cut-off).
function Audio:layer(recipe, position)
	self.Index = self.Index % #self.Pool + 1
	local item = self.Pool[self.Index]
	local token = (item.Token or 0) + 1
	item.Token = token
	local s = item.Sound
	s:Stop()
	item.Anchor.Position = position
	s.SoundId, s.Volume, s.PlaybackSpeed = recipe.Sound, recipe.Volume or 0.5, recipe.Speed or 1
	s.RollOffMaxDistance = math.max(100, recipe.Range or 100)
	SoundBank.effects(new, recipe, s)
	s.TimePosition = recipe.Start or 0
	s:Play()
	if recipe.Length then
		task.delay(recipe.Length / math.max(0.05, recipe.Speed or 1), function()
			if item.Token == token then
				s:Stop()
			end
		end)
	end
	self.Played = (self.Played or 0) + 1
end
function Audio:play(key, position)
	local recipe = Audio.resolve(key)
	if not recipe or not self.Settings.SFX then
		return false
	end
	local camera = workspace.CurrentCamera.CFrame.Position
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	-- Unpositioned cues are the local player's own: never range-culled.
	local positioned = position ~= nil
	position = position or root and root.Position or camera
	if positioned and (camera - position).Magnitude > (recipe.Range or 120) then
		return false
	end
	-- Very distant cues (thunder, roars) are placed near the listener so they stay audible.
	if (camera - position).Magnitude > 90 then
		position = camera + (position - camera).Unit * 60
	end
	for _, layer in recipe.Layers or { recipe } do
		if layer.Sound then
			if (layer.Delay or 0) > 0 then
				task.delay(layer.Delay, function()
					self:layer(layer, position)
				end)
			else
				self:layer(layer, position)
			end
		end
	end
	return true
end
function Audio:updateStorm(dt, data, weather)
	if not weather then
		return
	end
	if self.StormRound ~= weather.Round or (data.State ~= "Alive" and data.State ~= "Spectating") then
		self.StormRound, self.ThunderQueue, self.LastLightning = weather.Round, {}, weather.LightningSerial
		self.LastStormPhase = "Clear"
	end
	local intensity = if data.State == "Alive" or data.State == "Spectating" then weather.Intensity else 0
	local shelter = if data.Sheltered then 0.2 else 1
	local alpha = 1 - math.exp(-dt * 2)
	self.StormWind.Volume += ((0.35 * intensity + weather.Gust * 0.15) * shelter - self.StormWind.Volume) * alpha
	self.StormRain.Volume += (0.4 * intensity * shelter - self.StormRain.Volume) * alpha
	if intensity > 0 and self.LastStormPhase ~= weather.Phase and weather.Phase == "Approaching" then
		table.insert(self.ThunderQueue, { At = os.clock() + 2, Gain = 0.16, Distant = true })
	end
	self.LastStormPhase = weather.Phase
	if weather.LightningSerial ~= self.LastLightning then
		self.LastLightning = weather.LightningSerial
		if #self.ThunderQueue < 3 then
			table.insert(
				self.ThunderQueue,
				{ At = os.clock() + (weather.ThunderDelay or 1), Gain = weather.ThunderGain or 0.3 }
			)
		end
	end
	for i = #self.ThunderQueue, 1, -1 do
		local cue = self.ThunderQueue[i]
		if os.clock() >= cue.At then
			table.remove(self.ThunderQueue, i)
			if weather.Phase ~= "Clear" and (shelter >= 1 or cue.Gain > 0.2) then
				self:play(if cue.Distant then "DistantThunder" else "Thunder")
			end
		end
	end
end
function Audio:update(dt, data, weather)
	self:updateStorm(dt, data, weather)
	self.MusicGroup.Volume = if self.Settings.Music then 0.65 else 0
	self.SFXGroup.Volume = if self.Settings.SFX then 0.65 else 0
	local danger = if data.State == "Alive" then math.clamp(1 - data.Distance / 80, 0, 1) else 0
	if data.State == "Alive" then
		danger = math.max(
			danger,
			math.clamp(1 - (data.Stability or 180) / 100, 0, 1),
			if data.EventPhase == "Active" then 0.65 else 0
		)
	end
	local alpha = 1 - math.exp(-dt * 2)
	self.Music.Volume += ((0.45 * (1 - danger * 0.75)) - self.Music.Volume) * alpha
	self.Danger.Volume += (danger * 0.65 - self.Danger.Volume) * alpha
	local ambientLevel = if self.AmbientId == "Designed" then 0.12 else 0.3
	self.Ambient.Volume += (ambientLevel - self.Ambient.Volume) * alpha
	self.Wildlife.Volume += ((if data.EventPhase == "Active" then 0.04 else 0.2) - self.Wildlife.Volume) * alpha
	local musicId = AudioConfig.BiomeMusic[data.Biome] or AudioConfig.Music
	if musicId ~= self.MusicId then
		self.MusicId = musicId
		self.Music:Stop()
		if valid(musicId) then
			self.Music.SoundId = musicId
			self.Music:Play()
		end
	end
	-- Biome ambience: a permissioned per-biome bed when configured, else the designed air bed.
	local ambientId = AudioConfig.Biomes[data.Biome]
	local ambientKey = if valid(ambientId) then ambientId else "Designed"
	if ambientKey ~= self.AmbientId then
		self.AmbientId = ambientKey
		self.Ambient:Stop()
		if valid(ambientId) then
			self.Ambient.SoundId = ambientId
			SoundBank.effects(new, {}, self.Ambient)
			self.Ambient:Play()
		else
			self:bed(self.Ambient, "Biome")
		end
	end
	if danger > 0.6 and not self.LastDanger then
		self:play("Deletion")
	end
	self.LastDanger = danger > 0.6
end
return Audio
