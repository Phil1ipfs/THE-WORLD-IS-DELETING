--!nonstrict
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AudioConfig = require(Shared.AudioConfig)
local Audio = {}
Audio.__index = Audio
local function valid(id)
	return type(id) == "string" and id:match("^rbxassetid://%d+$") ~= nil
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
	for _, pair in { { self.StormWind, AudioConfig.StormWind }, { self.StormRain, AudioConfig.StormRain } } do
		if valid(pair[2]) then
			pair[1].SoundId = pair[2]
			pair[1]:Play()
		end
	end
	if valid(AudioConfig.Wildlife) then
		self.Wildlife.SoundId = AudioConfig.Wildlife
		self.Wildlife:Play()
	end
	for _, pair in { { self.Music, AudioConfig.Music }, { self.Danger, AudioConfig.Danger } } do
		if valid(pair[2]) then
			pair[1].SoundId = pair[2]
			pair[1]:Play()
		end
	end
	for i = 1, 8 do
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
function Audio:play(key, position)
	local id, speed, volume = AudioConfig[key], 1, 0.5
	local builtin = AudioConfig.UseBuiltinCues and AudioConfig.Builtin and AudioConfig.Builtin[key]
	if not valid(id) and builtin then
		id, speed, volume = builtin[1], builtin[2], builtin[3]
	elseif not valid(id) then
		return
	end
	if not self.Settings.SFX then
		return
	end
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	position = position or root and root.Position or workspace.CurrentCamera.CFrame.Position
	if (workspace.CurrentCamera.CFrame.Position - position).Magnitude > 120 then
		return
	end
	self.Index = self.Index % #self.Pool + 1
	local item = self.Pool[self.Index]
	item.Sound:Stop()
	item.Anchor.Position, item.Sound.SoundId, item.Sound.Volume = position, id, volume
	item.Sound.PlaybackSpeed = speed
	item.Sound:Play()
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
			local id = if cue.Distant and valid(AudioConfig.DistantThunder)
				then AudioConfig.DistantThunder
				elseif valid(AudioConfig.Thunder) then AudioConfig.Thunder
				else AudioConfig.Storm
			if valid(id) and self.Settings.SFX and weather.Phase ~= "Clear" then
				self.Thunder:Stop()
				self.Thunder.SoundId, self.Thunder.Volume = id, cue.Gain * shelter
				self.Thunder:Play()
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
	self.Ambient.Volume += (0.3 - self.Ambient.Volume) * alpha
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
	local ambientId = AudioConfig.Biomes[data.Biome]
	if ambientId ~= self.AmbientId then
		self.AmbientId = ambientId
		self.Ambient:Stop()
		if valid(ambientId) then
			self.Ambient.SoundId = ambientId
			self.Ambient:Play()
		end
	end
	if danger > 0.6 and not self.LastDanger then
		self:play("Deletion")
	end
	self.LastDanger = danger > 0.6
end
return Audio
