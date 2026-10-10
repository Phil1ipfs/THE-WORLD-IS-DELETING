--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Abilities = {}
Abilities.__index = Abilities
function Abilities.new(effects)
	return setmetatable({ Effects = effects }, Abilities)
end
function Abilities:deny(record, message)
	if os.clock() > (record.AbilityNoticeAt or 0) then
		record.AbilityNoticeAt = os.clock() + 0.5
		self.Effects:FireClient(record.Player, "Notice", message)
	end
	return false
end
function Abilities:request(record, name)
	if record.State ~= "Alive" or record.Transit or type(name) ~= "string" or #name > 20 then
		return
	end
	local ability = Config.Ability[name]
	local now = os.clock()
	if not ability then
		return false
	end
	if name == "Glide" and now < (record.GlideUntil or 0) then
		record.GlideUntil = 0
		self.Effects:FireClient(record.Player, "Notice", "Wind sail folded.")
		return true
	end
	if now < (record.Cooldowns[name] or 0) then
		return self:deny(
			record,
			string.format("%s ready in %.1fs", ability.Label, record.Cooldowns[name] - now)
		)
	end
	local character = record.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	local airborne = hum.FloorMaterial == Enum.Material.Air
	if (name == "DoubleJump" or name == "Glide") and not airborne then
		return self:deny(record, "Jump first, then activate " .. ability.Label .. ".")
	end
	local perks = record.Perks or {}
	if name == "DoubleJump" and (record.AirJumps or 0) >= (if perks.Feather then 2 else 1) then
		return self:deny(record, "Land before using Sky Leap again.")
	end
	local boosted = now < (record.OverchargeUntil or 0)
	local strength = if boosted then 1.25 else 1
	local duration = ability.Duration * (if boosted then 1.3 else 1)
		+ (if name == "Glide" and perks.Silk then 2 else 0)
	local cooldown = ability.Cooldown
		* (if boosted then 0.75 else 1)
		* (if name == "Dash" and perks.Gale then 0.75 else 1)
	record.Cooldowns[name] = now + cooldown
	record.MovementUntil = math.max(record.MovementUntil or 0, now + duration + 0.6)
	if name == "Dash" then
		local look = root.CFrame.LookVector
		local direction = Vector3.new(look.X, 0, look.Z)
		if direction.Magnitude < 0.1 then
			direction = Vector3.new(0, 0, -1)
		end
		record.DashDirection, record.DashUntil = direction.Unit, now + duration
		record.DashSpeed = ability.Speed * strength
		record.DashSerial = (record.DashSerial or 0) + 1
		root.AssemblyLinearVelocity = direction.Unit * record.DashSpeed
			+ Vector3.new(0, math.max(root.AssemblyLinearVelocity.Y, 3), 0)
	elseif name == "DoubleJump" then
		record.AirJumpUsed = true
		record.AirJumps = (record.AirJumps or 0) + 1
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, ability.Lift * strength, velocity.Z)
	elseif name == "Shield" then
		record.ShieldUntil = now + duration
		record.ShieldHealth = ability.Health * strength + (if perks.AegisCore then 30 else 0)
	elseif name == "Glide" then
		record.GlideUntil = now + duration
		record.GlideSpeed = ability.Speed * strength
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, -ability.FallSpeed), v.Z)
	end
	self.Effects:FireAllClients("Ability", {
		UserId = record.Player.UserId,
		Name = name,
		Duration = duration,
		Velocity = root.AssemblyLinearVelocity,
		Speed = record.DashSpeed,
		Boosted = boosted,
		Cooldown = cooldown,
	})
	return true
end
function Abilities:coyote(record)
	local now = os.clock()
	if
		record.State ~= "Alive"
		or record.Transit
		or record.CoyoteUsed
		or now - (record.LastGrounded or -100) > 0.18
	then
		return
	end
	local character = record.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if
		not root
		or not hum
		or hum.Health <= 0
		or hum.FloorMaterial ~= Enum.Material.Air
		or root.AssemblyLinearVelocity.Y > 1
	then
		return
	end
	record.CoyoteUsed = true
	record.MovementUntil = math.max(record.MovementUntil or 0, now + 0.6)
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, Config.JumpPower, velocity.Z)
end
function Abilities:update(players)
	local now = os.clock()
	for _, record in players:active() do
		local character = record.Player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not hum or record.Transit then
			continue
		end
		if hum.FloorMaterial ~= Enum.Material.Air then
			record.AirJumpUsed = false
			record.AirJumps = 0
		end
		if now < (record.DashUntil or 0) then
			root.AssemblyLinearVelocity = record.DashDirection * record.DashSpeed
				+ Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
		if now < (record.GlideUntil or 0) and hum.FloorMaterial ~= Enum.Material.Air then
			record.GlideUntil = 0
		end
		if
			now < (record.GlideUntil or 0)
			and root.AssemblyLinearVelocity.Y < -Config.Ability.Glide.FallSpeed
		then
			local velocity = root.AssemblyLinearVelocity
			local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
			if now >= (record.DashUntil or 0) and horizontal.Magnitude > (record.GlideSpeed or 25) then
				horizontal = horizontal.Unit * record.GlideSpeed
			end
			root.AssemblyLinearVelocity = horizontal + Vector3.new(0, -Config.Ability.Glide.FallSpeed, 0)
		end
	end
end
return Abilities
