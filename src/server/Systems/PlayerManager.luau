--!nonstrict
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Rules = require(Shared.Rules)
local Ground = require(script.Parent.Parent.Services.GroundProbe)
local Ocean = require(script.Parent.Parent.Services.Ocean)
local PlayerManager = {}
PlayerManager.__index = PlayerManager
function PlayerManager.new(world, effects)
	Players.CharacterAutoLoads = false
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Climbers")
	end)
	PhysicsService:CollisionGroupSetCollidable("Climbers", "Climbers", false)
	return setmetatable({ Records = {}, World = world, Effects = effects, OnEliminated = nil }, PlayerManager)
end
function PlayerManager:add(player)
	local record = {
		Player = player,
		State = "Lobby",
		Step = 0,
		Region = 0,
		Peak = 0,
		Started = 0,
		LastPosition = nil,
		LastCheck = os.clock(),
		LastStepTime = os.clock(),
		Cooldowns = {},
		ShieldUntil = 0,
		MovementUntil = 0,
		Strikes = 0,
		Ready = false,
		Connections = {},
		Rewarded = false,
	}
	self.Records[player] = record
	player:SetAttribute("State", "Lobby")
	self:spawn(record, false)
	return record
end
function PlayerManager:transition(record, state)
	if not Rules.canTransition(record.State, state) then
		return false
	end
	record.State = state
	record.Player:SetAttribute("State", state)
	return true
end
function PlayerManager:spawn(record, _active)
	if record.Spawning then
		return
	end
	record.Spawning = true
	task.spawn(function()
		local ok, err = pcall(function()
			record.Player:LoadCharacterAsync()
		end)
		if not ok then
			record.Spawning = false
			warn("Character load failed", err)
			if record.State == "Alive" then
				self:eliminate(record, "Character could not be loaded")
			end
			return
		end
		if self.Records[record.Player] ~= record then
			record.Spawning = false
			return
		end
		local character = record.Player.Character
		if not character then
			record.Spawning = false
			return
		end
		local hum = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not hum or not root then
			record.Spawning = false
			if record.State == "Alive" then
				self:eliminate(record, "Character initialization failed")
			end
			return
		end
		for _, connection in record.Connections do
			connection:Disconnect()
		end
		table.clear(record.Connections)
		local function configure(part)
			if part:IsA("BasePart") then
				part.CollisionGroup = "Climbers"
			end
		end
		for _, part in character:GetDescendants() do
			configure(part)
		end
		table.insert(record.Connections, character.DescendantAdded:Connect(configure))
		hum.WalkSpeed, hum.UseJumpPower, hum.JumpPower = Config.WalkSpeed, true, Config.JumpPower
		local position = if record.State == "Alive"
			then self.World:point(0) + Vector3.new(0, 4, 0)
			else Vector3.new(Config.LobbyX - 5 + record.Player.UserId % 4 * 4, 85, 0)
		character:PivotTo(CFrame.new(position))
		root.AssemblyLinearVelocity = Vector3.zero
		record.LastPosition, record.LastCheck = position, os.clock()
		record.LastStepTime, record.SpawnGrace = os.clock(), os.clock() + 3
		table.insert(
			record.Connections,
			hum.Died:Connect(function()
				if record.State == "Alive" then
					self:eliminate(record, "The sky claimed you")
				else
					task.delay(2, function()
						if
							self.Records[record.Player] == record
							and record.Player.Character == character
							and record.State ~= "Alive"
						then
							self:spawn(record, false)
						end
					end)
				end
			end)
		)
		if self.OnSpawn then
			self.OnSpawn(record)
		end
		record.Spawning = false
	end)
end
function PlayerManager:begin(record)
	if record.State ~= "Queued" or not record.Ready then
		return false
	end
	self:transition(record, "Alive")
	record.Step, record.Peak, record.Started, record.Rewarded = 0, 0, os.clock(), false
	record.Region, record.Bag, record.Discoveries = 0, { Timber = 0, Crystal = 0, Herb = 0 }, {}
	record.Glyphs = {}
	record.Perks, record.Chests, record.Patches, record.RunXP = {}, 0, 0, 0
	record.Bag.Relic = 0
	record.AirJumps, record.DashSerial = 0, 0
	record.Transit, record.InteractAt = nil, 0
	record.ItemCooldowns, record.OverchargeUntil, record.DashUntil, record.ShieldHealth = {}, 0, 0, 0
	self.World:activate(0)
	record.Cooldowns, record.ShieldUntil, record.MovementUntil = {}, 0, 0
	record.BonusCoins, record.Result, record.GlideUntil, record.AirJumpUsed = 0, nil, 0, false
	record.Player.ReplicationFocus = nil
	record.LastStepTime, record.Strikes = os.clock(), 0
	self:spawn(record, true)
	return true
end
function PlayerManager:eliminate(record, reason)
	if record.State ~= "Alive" then
		return
	end
	self:transition(record, "Eliminated")
	record.Finished = os.clock() - record.Started
	record.Reason = reason
	if self.OnEliminated then
		self.OnEliminated(record)
	end
	local character = record.Player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = 0
	end
end
function PlayerManager:damage(record, amount)
	if record.State ~= "Alive" then
		return
	end
	if os.clock() < record.ShieldUntil and (record.ShieldHealth or 0) > 0 then
		local absorbed = math.min(record.ShieldHealth, amount)
		record.ShieldHealth -= absorbed
		amount -= absorbed
		if record.ShieldHealth <= 0 then
			record.ShieldUntil = 0
		end
	end
	local hum = record.Player.Character and record.Player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:TakeDamage(amount)
	end
end
function PlayerManager:transfer(record, index)
	local region = self.World.Islands[index]
	local root = record.Player.Character and record.Player.Character:FindFirstChild("HumanoidRootPart")
	if
		record.State ~= "Alive"
		or not root
		or index ~= record.Region + 1
		or not region
		or not region.Landing.Parent
		or not region.Landing.CanCollide
	then
		return false
	end
	root.CFrame = CFrame.new(self.World:point(index) + Vector3.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	record.Region, record.LastPosition, record.LastCheck = index, root.Position, os.clock()
	record.Peak = math.max(record.Peak, index * Config.RegionRise)
	record.SpawnGrace, record.LastStepTime = os.clock() + 1, os.clock()
	self.World:activate(index)
	return true
end
function PlayerManager:active()
	local active = {}
	for _, record in self.Records do
		if record.State == "Alive" then
			table.insert(active, record)
		end
	end
	return active
end
function PlayerManager:update(waveY)
	local highest = Config.StartY
	local now = os.clock()
	for _, record in self:active() do
		local character = record.Player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not hum or record.Spawning then
			continue
		end
		if record.Transit then
			highest = math.max(highest, Config.StartY + record.Peak)
			continue
		end
		local position = root.Position
		if
			position.X ~= position.X
			or position.Y ~= position.Y
			or position.Z ~= position.Z
			or math.abs(position.X) > 1400
			or math.abs(position.Z) > 1400
			or math.abs(position.Y) > 10000
		then
			self:eliminate(record, "Invalid movement")
			continue
		end
		-- Ocean death: a server height boundary at the water surface (not Touched on Terrain water).
		if not record.Transit and Ocean.reached(position) then
			if self.Effects then
				self.Effects:FireAllClients(
					"OceanDeath",
					{ UserId = record.Player.UserId, Position = position }
				)
			end
			self:eliminate(record, "Fell into the ocean")
			continue
		end
		local y = position.Y + self.World.Origin
		if y - 2.5 <= waveY then
			self:eliminate(record, "Consumed by deletion")
			continue
		end
		local dt = math.clamp(now - record.LastCheck, 0.05, 1)
		local previous = record.LastPosition or position
		local delta = position - previous
		local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
		local allowed = if now < record.MovementUntil then 100 else Config.WalkSpeed * 1.7
		if
			now > (record.SpawnGrace or 0)
			and (
				horizontal > allowed * dt + 7
				or delta.Y > 85 * dt + 7
				or y > Config.StartY + (record.Region + 1) * Config.RegionRise + 28
			)
		then
			character:PivotTo(CFrame.new(previous))
			root.AssemblyLinearVelocity = Vector3.zero
			record.Strikes += 1
			if record.Strikes > 6 then
				self:eliminate(record, "Movement validation failed")
			end
			continue
		end
		record.LastPosition, record.LastCheck = position, now
		hum.WalkSpeed, hum.JumpPower = Config.WalkSpeed, Config.JumpPower
		-- Credit actual supported exploration, including continuous causeways. No rune sequence.
		local params = record.RaycastParams or RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { self.World.Root }
		record.RaycastParams = params
		local hit = Ground.cast(self.World, root, hum)
		local groundRegion = hit and hit.Instance:GetAttribute("Region")
		if
			hum.FloorMaterial ~= Enum.Material.Air
			and hit
			and position.Y - hit.Position.Y < math.clamp(hum.HipHeight + root.Size.Y / 2 + 3, 7, 12)
			and hit.Instance:GetAttribute("Ground")
			and hit.Instance.CanCollide
			and type(groundRegion) == "number"
			and groundRegion >= record.Region - 1
			and groundRegion <= record.Region + 1
		then
			record.LastGrounded, record.CoyoteUsed = now, false
			record.LastStepTime = now
			record.Peak = math.max(
				record.Peak,
				math.max(0, math.floor(hit.Position.Y + self.World.Origin - Config.StartY))
			)
			if groundRegion > record.Region then
				record.Region = groundRegion
				self.World:activate(groundRegion)
			end
		end
		if now - record.LastStepTime > 45 and hum.FloorMaterial == Enum.Material.Air then
			self:eliminate(record, "No safe landing")
		end
		highest = math.max(highest, Config.StartY + record.Peak)
	end
	return highest
end
-- Lobby, queued and spectating characters that reach the ocean also die, then respawn at
-- the sanctuary once (alive players are handled in update through elimination).
function PlayerManager:oceanSweep()
	for _, record in self.Records do
		if record.State ~= "Alive" and not record.Spawning and not record.OceanRespawn then
			local character = record.Player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and Ocean.reached(root.Position) then
				record.OceanRespawn = true
				hum.Health = 0
				if self.Effects then
					self.Effects:FireAllClients(
						"OceanDeath",
						{ UserId = record.Player.UserId, Position = root.Position }
					)
				end
				task.delay(1.5, function()
					record.OceanRespawn = nil
					if self.Records[record.Player] == record and record.State ~= "Alive" then
						self:spawn(record, false)
					end
				end)
			end
		end
	end
end
function PlayerManager:rebase(amount)
	local shift = Vector3.new(0, amount, 0)
	for _, record in self:active() do
		local character = record.Player.Character
		if character then
			character:PivotTo(character:GetPivot() - shift)
		end
		if record.LastPosition then
			record.LastPosition -= shift
		end
	end
end
function PlayerManager:remove(player)
	local record = self.Records[player]
	if not record then
		return
	end
	if record.State == "Alive" then
		self:eliminate(record, "Left the realm")
	end
	for _, connection in record.Connections do
		connection:Disconnect()
	end
	self.Records[player] = nil
end
return PlayerManager
