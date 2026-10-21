--!nonstrict
-- Apply only server-authorized impulses locally, where the avatar's simulation runs.
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").GameConfig)
local Power = {}
Power.__index = Power
function Power.new()
	return setmetatable({ DashUntil = 0 }, Power)
end
function Power:activate(payload)
	if payload.UserId ~= Players.LocalPlayer.UserId then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if payload.Name == "Dash" or payload.Name == "DoubleJump" then
		root.AssemblyLinearVelocity = payload.Velocity
	end
	if payload.Name == "Dash" then
		self.DashUntil = os.clock() + payload.Duration
		self.DashVelocity = Vector3.new(payload.Velocity.X, 0, payload.Velocity.Z)
	end
end
-- Server-authorized air current: lift is applied where the avatar is simulated.
function Power:updraft(payload)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and type(payload.Lift) == "number" then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, math.min(payload.Lift, 110), v.Z)
	end
end
-- Server-authorized dragon wing gust: pushback applied where the avatar is simulated.
function Power:knockback(payload)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and typeof(payload.Velocity) == "Vector3" and payload.Velocity.Magnitude < 140 then
		self.DashUntil = 0
		root.AssemblyLinearVelocity = payload.Velocity
	end
end
function Power:update(data)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if data.State ~= "Alive" or data.Transit or not root or not hum or hum.Health <= 0 then
		self.DashUntil = 0
		return
	end
	if os.clock() < self.DashUntil then
		root.AssemblyLinearVelocity = self.DashVelocity + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
	if data.PowerStatus and data.PowerStatus.Glide > 0 and hum.FloorMaterial == Enum.Material.Air then
		local horizontal = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
		if os.clock() >= self.DashUntil then
			local speed = data.PowerStatus.GlideSpeed or Config.Ability.Glide.Speed
			local direction = hum.MoveDirection
			if direction.Magnitude > 0.1 then
				horizontal = direction.Unit * speed
			end
		end
		root.AssemblyLinearVelocity = horizontal
			+ Vector3.new(0, math.max(root.AssemblyLinearVelocity.Y, -Config.Ability.Glide.FallSpeed), 0)
	end
end
return Power
