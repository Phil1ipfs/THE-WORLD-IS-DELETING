--!nonstrict
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").GameConfig)
local Scene = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").MenuScene)
local Camera = {}
Camera.__index = Camera
function Camera.new(settings, request)
	return setmetatable({
		Settings = settings,
		Request = request,
		TargetIndex = 1,
		Target = nil,
		DashUntil = 0,
		LastState = nil,
	}, Camera)
end
function Camera:next(roster)
	local targets = {}
	for _, record in roster or {} do
		if record.State == "Alive" then
			table.insert(targets, record)
		end
	end
	if #targets == 0 then
		self.Target = nil
		return
	end
	self.TargetIndex = self.TargetIndex % #targets + 1
	self.Target = targets[self.TargetIndex].UserId
	self.Request:FireServer("SpectateTarget", self.Target)
end
function Camera:rebase(amount)
	local camera = workspace.CurrentCamera
	camera.CFrame -= Vector3.new(0, amount, 0)
	camera.Focus -= Vector3.new(0, amount, 0)
end
function Camera:update(dt, data, weather)
	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer
	if data.State ~= self.LastState then
		self.LastState = data.State
		if data.State == "Spectating" then
			self.TargetIndex = 0
			self:next(data.Roster)
		end
	end
	if data.State == "Spectating" then
		local record
		for _, candidate in data.Roster do
			if candidate.UserId == self.Target and candidate.State == "Alive" then
				record = candidate
			end
		end
		if not record then
			self:next(data.Roster)
		end
		local target = self.Target and Players:GetPlayerByUserId(self.Target)
		local hum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			camera.CameraType, camera.CameraSubject = Enum.CameraType.Custom, hum
		end
		return target and target.DisplayName or "Waiting for survivors"
	elseif data.State == "Lobby" or data.State == "Queued" then
		-- Cinematic menu orbit around the sanctuary vista (a fixed shot when motion is disabled).
		camera.CameraType = Enum.CameraType.Scriptable
		local t = if self.Settings.Camera then os.clock() else 0
		local p, f = Scene.camera(t, Config.LobbyX)
		local goal = CFrame.lookAt(Vector3.new(p.X, p.Y, p.Z), Vector3.new(f.X, f.Y, f.Z))
		camera.CFrame = if self.MenuShot then camera.CFrame:Lerp(goal, 1 - math.exp(-dt * 3)) else goal
		self.MenuShot = true
		camera.FieldOfView += (64 - camera.FieldOfView) * (1 - math.exp(-dt * 3))
		return
	end
	self.MenuShot = nil
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraType, camera.CameraSubject = Enum.CameraType.Custom, hum
		local danger = if data.State == "Alive" then math.clamp(1 - data.Distance / 40, 0, 1) else 0
		local shake = if self.Settings.Camera then danger * 0.08 else 0
		if self.Settings.Camera and data.EventPhase == "Active" and data.Event == "Earthquake" then
			shake = math.max(shake, 0.22)
		end
		if self.Settings.Camera and weather and weather.Phase == "Extreme" and not data.Sheltered then
			shake = math.max(shake, math.min(0.055, weather.Gust * 0.055))
		elseif self.Settings.Camera and weather and weather.Phase == "Heavy" and not data.Sheltered then
			shake = math.max(shake, math.min(0.03, weather.Gust * 0.03))
		end
		-- Thunder rumble arrives with the delayed thunder and decays within 0.4 seconds.
		local since = weather and weather.ShakeAt and os.clock() - weather.ShakeAt
		if self.Settings.Camera and since and since >= 0 and since < 0.4 and not data.Sheltered then
			shake = math.max(shake, (weather.ShakeAmount or 0) * (1 - since / 0.4))
		end
		hum.CameraOffset =
			Vector3.new(math.sin(os.clock() * 24) * shake, math.cos(os.clock() * 19) * shake, 0)
	end
	local targetFov = if self.Settings.Camera and os.clock() < self.DashUntil then 83 else 72
	camera.FieldOfView += (targetFov - camera.FieldOfView) * (1 - math.exp(-dt * 7))
end
return Camera
