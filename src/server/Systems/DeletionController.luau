--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Rules = require(Shared.Rules)
local G = require(script.Parent.Parent.Services.Geometry)
local Deletion = {}
Deletion.__index = Deletion
function Deletion.new()
	local self = setmetatable({ Height = Config.WaveStart }, Deletion)
	self.Part = G.part(
		workspace,
		"DeletionWave",
		Vector3.new(1350, 5, 1350),
		CFrame.new(0, self.Height, 0),
		Color3.fromRGB(182, 58, 255),
		Enum.Material.Neon,
		false
	)
	self.Part.Transparency = 0.3
	return self
end
function Deletion:reset()
	self.Height, self.Surge = Config.WaveStart, 1
	self.Part.CFrame = CFrame.new(0, self.Height, 0)
end
function Deletion:update(dt, elapsed, origin, leaderY)
	self.Height = Rules.wave(self.Height, dt * (self.Surge or 1), elapsed, Config, leaderY)
	self.Part.CFrame = CFrame.new(0, self.Height - origin - 2.5, 0)
	self.Part:SetAttribute("LogicalY", self.Height)
end
return Deletion
