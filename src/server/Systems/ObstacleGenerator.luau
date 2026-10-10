--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.ObstacleCatalog)
local RNG = require(Shared.Random)
local Difficulty = require(Shared.DifficultyConfig)
local G = require(script.Parent.Parent.Services.Geometry)
local Obstacles = {}
Obstacles.__index = Obstacles
local function inside(root, part, padding)
	local localPoint = part.CFrame:PointToObjectSpace(root.Position)
	local half = part.Size / 2 + (padding or Vector3.new(1.5, 3, 1.5))
	return math.abs(localPoint.X) < half.X
		and math.abs(localPoint.Y) < half.Y
		and math.abs(localPoint.Z) < half.Z
end
function Obstacles.new(effects)
	return setmetatable(
		{ Records = {}, Previous = nil, Effects = effects, Players = nil, OnBonus = nil },
		Obstacles
	)
end
function Obstacles:add(island, seed)
	local rng = RNG.new(seed + island.Index * 101)
	local name = Catalog.choose(rng, self.Previous, island.Biome.Obstacles)
	self.Previous = name
	local model = Instance.new("Model")
	model.Name = "Challenge_" .. name
	model.Parent = island.Model
	local outward = Vector3.new(island.Side.X, 0, island.Side.Z).Unit
	local base = CFrame.lookAt(island.Side + outward * 25, island.Side + outward * 40)
	local accent = G.color(island.Biome.Accent)
	local record = {
		Index = island.Index,
		Name = name,
		Model = model,
		Base = base,
		Nodes = {},
		Claimed = {},
		Timers = {},
		Difficulty = Difficulty.at(island.Y),
		Phase = rng:range(0, 6),
		Extra = island.Biome.Hazard,
	}
	local function part(label, size, offset, color, material, collision)
		local p = G.part(
			model,
			label,
			size,
			base * CFrame.new(offset),
			color or accent,
			material or Enum.Material.Slate,
			collision
		)
		table.insert(record.Nodes, { Part = p, Home = p.CFrame, Offset = offset })
		return p
	end
	part("EntryBridge", Vector3.new(9, 1, 18), Vector3.new(0, -0.5, 19), G.color(island.Biome.Top))
	part("Entry", Vector3.new(12, 1, 8), Vector3.new(0, -0.5, 8))
	part("Exit", Vector3.new(12, 1, 8), Vector3.new(0, -0.5, -14))
	G.label(model, "OPTIONAL • " .. name, (base * CFrame.new(0, 7, 9)).Position, accent)
	record.Bonus = part(
		"BonusRune",
		Vector3.new(2.5, 2.5, 2.5),
		Vector3.new(0, 3, -14),
		accent,
		Enum.Material.Neon,
		false
	)
	record.Bonus.Shape = Enum.PartType.Ball
	if
		name == "MovingPlatforms"
		or name == "SlidingPlatforms"
		or name == "FloatingElevator"
		or name == "TiltingPlatform"
	then
		record.Mover = part("Mover", Vector3.new(10, 1, 12), Vector3.new(0, -0.5, -3))
	elseif name == "CollapsingBridge" or name == "DisappearingPlatforms" or name == "CrumblingStairs" then
		record.Plates = {}
		for i = 1, 4 do
			local rise = if name == "CrumblingStairs" then (i % 3) * 1.5 else 0
			table.insert(
				record.Plates,
				part("Fragile_" .. i, Vector3.new(10, 1, 4), Vector3.new(0, rise - 0.5, 6 - i * 4))
			)
		end
	elseif name == "SpiralTower" then
		for i = 0, 7 do
			local a = i * 0.7
			part(
				"SpiralStep",
				Vector3.new(7, 1, 7),
				Vector3.new(math.sin(a) * 5, i * 1.4 - 0.5, -3 + math.cos(a) * 5)
			)
		end
		record.Bonus.CFrame = base * CFrame.new(math.sin(4.9) * 5, 13, -3 + math.cos(4.9) * 5)
	elseif name == "LavaStones" then
		record.Hazard = part(
			"Lava",
			Vector3.new(14, 1, 17),
			Vector3.new(0, -1.5, -3),
			Color3.fromRGB(255, 90, 40),
			Enum.Material.Neon,
			false
		)
		for i = 1, 4 do
			part("SafeStone", Vector3.new(5, 1, 4), Vector3.new(if i % 2 == 0 then -2 else 2, 0, 6 - i * 4))
		end
	else
		record.Floor = part("ChallengeFloor", Vector3.new(12, 1, 18), Vector3.new(0, -0.5, -3))
		if name == "RotatingBeams" then
			record.Hazard = part(
				"RotatingBeam",
				Vector3.new(16, 0.8, 1),
				Vector3.new(0, 1.4, -3),
				accent,
				Enum.Material.Neon,
				false
			)
		elseif name == "SwingingObstacles" then
			record.Hazard = part(
				"Pendulum",
				Vector3.new(3, 3, 3),
				Vector3.new(0, 2, -3),
				accent,
				Enum.Material.Metal,
				false
			)
			record.Hazard.Shape = Enum.PartType.Ball
			part("Arch", Vector3.new(16, 1, 1), Vector3.new(0, 12, -3))
		elseif name == "FallingRocks" then
			record.Hazard = part(
				"FallingRock",
				Vector3.new(4, 4, 4),
				Vector3.new(0, 18, -3),
				G.color(island.Biome.Rock),
				Enum.Material.Slate,
				false
			)
		elseif name == "TimedGate" or name == "LaserBarrier" or name == "MovingWall" then
			record.Hazard = part(
				"Barrier",
				Vector3.new(11, 6, 1),
				Vector3.new(0, 3, -3),
				accent,
				Enum.Material.Neon,
				name ~= "LaserBarrier"
			)
		elseif name == "JumpPad" then
			record.Pad =
				part("LaunchRune", Vector3.new(6, 0.3, 6), Vector3.new(0, 0.2, 2), accent, Enum.Material.Neon)
			record.Bonus.CFrame = base * CFrame.new(0, 10, -10)
		elseif name == "Portal" then
			record.Portal = part(
				"Portal",
				Vector3.new(5, 7, 1),
				Vector3.new(0, 3.5, 3),
				accent,
				Enum.Material.Neon,
				false
			)
		elseif name == "WindTunnel" or name == "GravityZone" then
			record.Zone = part(
				"Field",
				Vector3.new(12, 8, 16),
				Vector3.new(0, 4, -3),
				accent,
				Enum.Material.ForceField,
				false
			)
			record.Zone.Transparency = 0.7
		elseif name == "IceSurface" then
			record.Floor.Material = Enum.Material.Ice
			record.Floor.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.02, 0, 1, 1)
		end
	end
	-- Higher bands add a separately telegraphed lateral pulse inside the optional arena.
	if record.Difficulty.Combinations > 1 then
		record.Pulse = part(
			"BiomePulse",
			Vector3.new(2, 5, 16),
			Vector3.new(8, 2.5, -3),
			accent,
			Enum.Material.Neon,
			false
		)
	end
	if record.Difficulty.Combinations > 2 then
		record.SecondPulse = part(
			"CrossPulse",
			Vector3.new(12, 3, 1),
			Vector3.new(0, 1.5, -3),
			accent,
			Enum.Material.Neon,
			false
		)
	end
	for _, node in record.Nodes do
		if node.Part.Name == "Mover" or node.Part.Name:match("^Fragile_") then
			local size = node.Part.Size
			node.Part.Size = Vector3.new(size.X * record.Difficulty.LandingScale, size.Y, size.Z)
		end
	end
	self.Records[island.Index] = record
end
function Obstacles:update(dt, now)
	if not self.Players then
		return
	end
	local active = self.Players:active()
	for _, r in self.Records do
		local t = now * r.Difficulty.Speed + r.Phase
		local name = r.Name
		local oldMover = r.Mover and r.Mover.CFrame
		if r.Mover then
			local cf = r.Base * CFrame.new(0, -0.5, -3)
			if name == "MovingPlatforms" then
				cf *= CFrame.new(math.sin(t) * 3, 0, 0)
			elseif name == "SlidingPlatforms" then
				cf *= CFrame.new(0, 0, math.sin(t) * 4)
			elseif name == "FloatingElevator" then
				cf *= CFrame.new(0, (math.sin(t) + 1) * 3, 0)
			else
				cf *= CFrame.Angles(0, 0, math.sin(t) * 0.22)
			end
			r.Mover.CFrame = cf
		end
		if r.Hazard then
			if name == "RotatingBeams" then
				r.Hazard.CFrame = r.Base * CFrame.new(0, 1.4, -3) * CFrame.Angles(0, t, 0)
			elseif name == "SwingingObstacles" then
				r.Hazard.CFrame = r.Base
					* CFrame.new(math.sin(t * 1.4) * 6, 2 + (1 - math.cos(t * 1.4)) * 2, -3)
			elseif name == "FallingRocks" then
				local phase = t % 4
				r.Hazard.CFrame = r.Base
					* CFrame.new(math.sin(math.floor(t / 4)) * 3, 18 - math.min(phase, 2) * 10, -3)
				r.Hazard.Transparency = if phase > 2 then 1 else 0
			elseif name == "TimedGate" or name == "LaserBarrier" then
				local open = t % 5 > 2.8
				r.Hazard.CanCollide = not open and name == "TimedGate"
				r.Hazard.Transparency = if open then 0.88 else 0.15
			elseif name == "MovingWall" then
				r.Hazard.CFrame = r.Base * CFrame.new(math.sin(t) * 8, 3, -3)
			end
		end
		if r.Pulse then
			r.Pulse.CFrame = r.Base * CFrame.new(math.sin(t * 0.65) * 9, 2.5, -3)
			r.Pulse.Transparency = if t % 6 > 4 then 0.2 else 0.85
		end
		if r.SecondPulse then
			r.SecondPulse.CFrame = r.Base * CFrame.new(0, 1.5 + math.sin(t * 0.5), -3 + math.cos(t * 0.6) * 6)
			r.SecondPulse.Transparency = if (t + 1.5) % 6 > 4 then 0.2 else 0.85
		end
		if r.Plates then
			for i, plate in r.Plates do
				local expiry = r.Timers[plate] or 0
				local visible = if name == "DisappearingPlatforms"
					then (t + i * 0.35) % 5 < 3.5
					else now > expiry or now < expiry - 3
				plate.CanCollide = visible
				plate.Transparency = if visible then 0 else 0.85
				if expiry > now and now < expiry - 3 then
					plate.Color = Color3.fromRGB(255, 160, 80)
				end
			end
		end
		for _, playerRecord in active do
			local root = playerRecord.Player.Character
				and playerRecord.Player.Character:FindFirstChild("HumanoidRootPart")
			if not root or (root.Position - r.Base.Position).Magnitude > 45 then
				continue
			end
			local uid = playerRecord.Player.UserId
			if
				inside(root, r.Bonus, Vector3.new(1.5, 1.5, 1.5))
				and not r.Claimed[uid]
				and math.abs(playerRecord.Step - r.Index * 8) <= 10
			then
				r.Claimed[uid] = true
				if self.OnBonus then
					self.OnBonus(playerRecord, 5)
				end
				self.Effects:FireClient(playerRecord.Player, "Bonus", 5)
			end
			if r.Mover and oldMover then
				local oldPoint = oldMover:PointToObjectSpace(root.Position)
				if
					math.abs(oldPoint.X) < 5.5
					and math.abs(oldPoint.Z) < 6.5
					and oldPoint.Y > 1.8
					and oldPoint.Y < 4.5
				then
					root.CFrame += r.Mover.Position - oldMover.Position
				end
			end
			if r.Plates then
				for _, plate in r.Plates do
					if
						name ~= "DisappearingPlatforms"
						and inside(root, plate)
						and now > (r.Timers[plate] or 0)
					then
						r.Timers[plate] = now + 3.8
						self.Effects:FireAllClients("Collapse", plate.Position)
					end
				end
			end
			local cooldownKey = "p" .. uid
			if now < (r.Timers[cooldownKey] or 0) then
				continue
			end
			local hazardActive = r.Hazard and r.Hazard.Transparency < 0.7
			if hazardActive and inside(root, r.Hazard) and name ~= "TimedGate" then
				self.Players:damage(playerRecord, if name == "LavaStones" then 35 else 20)
				root.AssemblyLinearVelocity += r.Base.RightVector * 12
				r.Timers[cooldownKey] = now + 0.8
			elseif r.Pulse and r.Pulse.Transparency < 0.5 and inside(root, r.Pulse) then
				self.Players:damage(playerRecord, 12)
				r.Timers[cooldownKey] = now + 0.8
			elseif r.SecondPulse and r.SecondPulse.Transparency < 0.5 and inside(root, r.SecondPulse) then
				self.Players:damage(playerRecord, 10)
				r.Timers[cooldownKey] = now + 0.8
			elseif r.Pad and inside(root, r.Pad) then
				root.AssemblyLinearVelocity =
					Vector3.new(root.AssemblyLinearVelocity.X, 68, root.AssemblyLinearVelocity.Z)
				playerRecord.MovementUntil = now + 1.5
				r.Timers[cooldownKey] = now + 2
			elseif r.Portal and inside(root, r.Portal) then
				local target = (r.Base * CFrame.new(0, 4, -14)).Position
				playerRecord.Player.Character:PivotTo(CFrame.new(target))
				playerRecord.LastPosition = target
				playerRecord.SpawnGrace = now + 0.5
				r.Timers[cooldownKey] = now + 3
			elseif r.Zone and inside(root, r.Zone, Vector3.zero) then
				if name == "WindTunnel" then
					root.AssemblyLinearVelocity += r.Base.RightVector * dt * 16
				else
					root.AssemblyLinearVelocity += Vector3.new(0, dt * 120, 0)
				end
				playerRecord.MovementUntil = now + 0.4
			elseif name == "IceSurface" and r.Floor and inside(root, r.Floor) then
				root.AssemblyLinearVelocity += r.Base.LookVector * dt * 12
			end
		end
	end
end
function Obstacles:rebase(shift)
	for _, record in self.Records do
		record.Base -= shift
		for _, node in record.Nodes do
			node.Home -= shift
		end
	end
end
function Obstacles:remove(index)
	self.Records[index] = nil
end
function Obstacles:clear()
	table.clear(self.Records)
	self.Previous = nil
end
return Obstacles
