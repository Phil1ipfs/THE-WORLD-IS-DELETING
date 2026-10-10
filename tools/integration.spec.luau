--!nonstrict
local Harness = require("./OfflineHarness")
local h = Harness.new()
local rbx = h.Roblox
local V3 = rbx.Vector3
local Config = h.Load(h.Shared.GameConfig)
local Route = h.Load(h.Shared.Route)
local Catalog = h.Load(h.Shared.ObstacleCatalog)
local Generator = h.Load(h.Server.Systems.IslandGenerator)
local Obstacles = h.Load(h.Server.Systems.ObstacleGenerator)
local World = h.Load(h.Server.Systems.WorldManager)
local PlayerManager = h.Load(h.Server.Systems.PlayerManager)
local DataManager = h.Load(h.Server.Systems.DataManager)
local Rewards = h.Load(h.Server.Systems.RewardManager)
local Abilities = h.Load(h.Server.Systems.AbilityService)
local Round = h.Load(h.Server.Systems.RoundManager)
local Deletion = h.Load(h.Server.Systems.DeletionController)
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		error("FAIL " .. name .. ": " .. tostring(err), 0)
	end
	passed += 1
	print("PASS " .. name)
end
local function system()
	local obstacles = Obstacles.new(h.Effects)
	local world = World.new(obstacles)
	local players = PlayerManager.new(world, h.Effects)
	obstacles.Players = players
	world:reset(Config.Seed)
	return world, obstacles, players
end
test("Every server ModuleScript loads without missing or circular references", function()
	for _, module in h.Server:GetDescendants() do
		if module:IsA("ModuleScript") then
			assert(h.Load(module))
		end
	end
end)
test("Legacy obstacle geometry is deterministic and includes its route checkpoints", function()
	local parent = rbx.Instance.new("Model")
	local a = Generator.build(parent, 11, 0, 42)
	local b = Generator.build(parent, 11, 0, 42)
	local aParts, bParts = a.Model:GetDescendants(), b.Model:GetDescendants()
	assert(#aParts == #bParts)
	for i, part in aParts do
		if part:IsA("BasePart") then
			assert((part.Position - bParts[i].Position).Magnitude < 1e-5)
			assert(part.Color == bParts[i].Color)
		end
	end
	local count = 0
	for _, part in aParts do
		if part:GetAttribute("Step") then
			count += 1
		end
	end
	assert(count == Config.StepsPerIsland)
	parent:Destroy()
end)
test("Legacy obstacle route centers have no structural headroom obstructions", function()
	local parent = rbx.Instance.new("Model")
	for index = 0, 44 do
		Generator.build(parent, index, 0, 666)
	end
	local parts = {}
	for _, part in parent:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			table.insert(parts, part)
		end
	end
	for step = 0, 351 do
		local point = Route.point(step, Config)
		for _, part in parts do
			local p = part.CFrame:PointToObjectSpace(V3.new(point.X, point.Y + 3, point.Z))
			-- Conservative humanoid body box at the platform center.
			if math.abs(p.X) < part.Size.X / 2 + 0.9 and math.abs(p.Z) < part.Size.Z / 2 + 0.9 then
				local bottom, top = part.Position.Y - part.Size.Y / 2, part.Position.Y + part.Size.Y / 2
				assert(
					top <= point.Y + 0.05 or bottom >= point.Y + 6,
					string.format("Step %d intersects %s", step, part:GetFullName())
				)
			end
		end
	end
	parent:Destroy()
end)
test("All 20 production obstacle builders and updates execute", function()
	local world, obstacles = system()
	local seen = {}
	for index = 1, 160 do
		local island = Generator.build(world.Root, index, 0, 9182)
		obstacles:add(island, 9182)
		local record = obstacles.Records[index]
		seen[record.Name] = true
		for t = 0, 12, 0.4 do
			obstacles:update(0.1, t)
		end
		obstacles:remove(index)
		island.Model:Destroy()
	end
	for _, name in Catalog.Names do
		assert(seen[name], "Builder not covered: " .. name)
	end
	world.Root:Destroy()
end)
test("Legacy obstacle jump arcs clear generated collision geometry", function()
	local parent = rbx.Instance.new("Model")
	for index = 0, 44 do
		Generator.build(parent, index, 0, 317)
	end
	local parts = {}
	for _, part in parent:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			table.insert(
				parts,
				{ CF = part.CFrame, Size = part.Size, Position = part.Position, Name = part.Name }
			)
		end
	end
	for step = 0, 350 do
		local a, b = Route.point(step, Config), Route.point(step + 1, Config)
		local duration = (
			Config.JumpPower + math.sqrt(Config.JumpPower ^ 2 - 2 * Config.Gravity * (b.Y - a.Y))
		) / Config.Gravity
		local nearby = {}
		for _, part in parts do
			if
				math.abs(part.Position.Y - a.Y) < 25
				and math.abs(part.Position.X - a.X) < 24
				and math.abs(part.Position.Z - a.Z) < 24
			then
				table.insert(nearby, part)
			end
		end
		for sample = 1, 29 do
			local t = duration * sample / 30
			local progress = math.clamp((t - 0.1) / (duration - 0.1), 0, 1)
			local foot = V3.new(
				a.X + (b.X - a.X) * progress,
				a.Y + Config.JumpPower * t - Config.Gravity * t * t / 2,
				a.Z + (b.Z - a.Z) * progress
			)
			for _, part in nearby do
				local p = part.CF:PointToObjectSpace(foot + V3.new(0, 3, 0))
				if math.abs(p.X) < part.Size.X / 2 + 0.8 and math.abs(p.Z) < part.Size.Z / 2 + 0.8 then
					assert(
						part.Position.Y + part.Size.Y / 2 <= foot.Y + 0.05
							or part.Position.Y - part.Size.Y / 2 >= foot.Y + 6,
						string.format("Jump %d hits %s at %.2fs", step, part.Name, t)
					)
				end
			end
		end
	end
	parent:Destroy()
end)
test("Obstacle contact logic applies its actual gameplay effects", function()
	local world, obstacles, players = system()
	local player = h:player(55)
	local rec = players:add(player)
	rec.Ready = true
	players:transition(rec, "Queued")
	players:begin(rec)
	local root, hum = player.Character.HumanoidRootPart, player.Character.Humanoid
	local covered = {}
	for index = 1, 160 do
		local island = Generator.build(world.Root, index, 0, 9182)
		obstacles:add(island, 9182)
		local r = obstacles.Records[index]
		if not covered[r.Name] then
			covered[r.Name] = true
			hum.Health, root.AssemblyLinearVelocity = 100, V3.zero
			rec.ShieldUntil, rec.Step = 0, index * Config.StepsPerIsland
			root.Position = V3.new(400, 0, 400)
			local now = (20 - r.Phase) / r.Difficulty.Speed
			obstacles:update(0.1, now)
			if r.Mover then
				root.Position = r.Mover.Position + V3.new(0, 3, 0)
				local before = r.Mover.CFrame
				obstacles:update(0.1, now + 0.2)
				assert(r.Mover.CFrame ~= before)
			elseif r.Plates then
				if r.Name == "DisappearingPlatforms" then
					local before = r.Plates[1].CanCollide
					obstacles:update(0.1, now + 4 / r.Difficulty.Speed)
					assert(r.Plates[1].CanCollide ~= before)
				else
					root.Position = r.Plates[1].Position + V3.new(0, 3, 0)
					obstacles:update(0.1, now)
					assert(r.Timers[r.Plates[1]])
					obstacles:update(0.1, now + 1)
					assert(not r.Plates[1].CanCollide)
				end
			elseif r.Zone then
				root.Position = r.Zone.Position
				obstacles:update(0.1, now)
				assert(root.AssemblyLinearVelocity.Magnitude > 0)
			elseif r.Pad then
				root.Position = r.Pad.Position + V3.new(0, 2, 0)
				obstacles:update(0.1, now)
				assert(root.AssemblyLinearVelocity.Y == 68)
			elseif r.Portal then
				root.Position = r.Portal.Position
				local before = root.Position
				obstacles:update(0.1, now)
				assert((root.Position - before).Magnitude > 8)
			elseif r.Name == "TimedGate" then
				assert(r.Hazard.CanCollide)
				obstacles:update(0.1, now + 4 / r.Difficulty.Speed)
				assert(not r.Hazard.CanCollide)
			elseif r.Hazard then
				root.Position = r.Hazard.Position
				obstacles:update(0.1, now)
				assert(hum.Health < 100, r.Name .. " did not damage on contact")
			elseif r.Name == "IceSurface" then
				root.Position = r.Floor.Position + V3.new(0, 3, 0)
				obstacles:update(0.1, now)
				assert(
					root.AssemblyLinearVelocity.Magnitude > 0
						and r.Floor.CustomPhysicalProperties.Friction < 0.03
				)
			elseif r.Name == "SpiralTower" then
				local steps = 0
				for _, part in r.Model:GetChildren() do
					if part.Name == "SpiralStep" then
						steps += 1
					end
				end
				assert(steps == 8)
			end
			root.Position = r.Bonus.Position
			obstacles:update(0.1, now + 5)
			assert(r.Claimed[player.UserId], "Bonus not awarded")
		end
		obstacles:remove(index)
		island.Model:Destroy()
	end
	for _, name in Catalog.Names do
		assert(covered[name])
	end
	players:remove(player)
	player:Destroy()
	world.Root:Destroy()
end)
test("Round lifecycle waits, starts, admits late join and resets after elimination", function()
	local world, _, players = system()
	local wave = Deletion.new()
	local round = Round.new(world, wave, players, h.Effects)
	local p = h:player(21)
	local record = players:add(p)
	record.Ready = true
	round:queue(record)
	round:update(0.1)
	assert(round.State == "Intermission")
	h:advance(Config.Intermission + 0.1)
	round:update(0.1)
	assert(round.State == "Running" and record.State == "Alive")
	local p2 = h:player(22)
	local late = players:add(p2)
	late.Ready = true
	round:queue(late)
	assert(late.State == "Alive")
	players:eliminate(record, "test")
	players:eliminate(late, "test")
	round:update(0.1)
	assert(round.State == "Waiting")
	round:queue(record)
	round:update(0.1)
	h:advance(Config.Intermission + 0.1)
	round:update(0.1)
	assert(round.Number == 2 and record.State == "Alive" and world.Origin == 0)
	players:remove(p)
	players:remove(p2)
	p:Destroy()
	p2:Destroy()
	world.Root:Destroy()
	wave.Part:Destroy()
end)
test("DataStore acquire, bounded retry, save, release, conflict and lock loss", function()
	h.Persistent = true
	local data = DataManager.new()
	local p = h:player(31)
	h.Failures = 2
	local profile = assert(data:load(p))
	profile.Coins = 87
	profile.Best = 120
	assert(data:save(p, false))
	local saved = h.Stores.FloatingRealms_v1.p_31
	assert(saved.Profile.Coins == 87 and saved.Lock.Owner == data.Owner)
	local second = DataManager.new()
	second.Owner = "another-server"
	assert(second:load(p) == nil, "Live lock stolen")
	assert(data:save(p, true))
	assert(h.Stores.FloatingRealms_v1.p_31.Lock == nil)
	local restored = assert(second:load(p))
	assert(restored.Coins == 87)
	h.Stores.FloatingRealms_v1.p_31.Lock.Owner = "stolen"
	assert(not second:save(p, false))
	assert(p:GetAttribute("Kicked"))
	local failed = h:player(32)
	h.Failures = 3
	assert(data:load(failed) == nil and data.Entries[failed] == nil)
	local expired = h:player(33)
	assert(data:load(expired))
	h:advance(Config.SessionLease + 1)
	assert(data:get(expired) == nil and expired:GetAttribute("Kicked"), "Expired lease remained writable")
	data:save(expired, true)
	assert(data.Entries[expired] == nil)
	local departed = h:player(34)
	local departingProfile = assert(data:load(departed))
	departingProfile.Coins = 99
	h.Failures = 3
	assert(not data:save(departed, true) and data.Entries[departed])
	departed.Parent = nil
	data.LastSave = h.Time - Config.AutosaveInterval
	data:update()
	assert(
		data.Entries[departed] == nil and h.Stores.FloatingRealms_v1.p_34.Profile.Coins == 99,
		"Departure save was not retried"
	)
	expired:Destroy()
	departed:Destroy()
	p:Destroy()
	failed:Destroy()
	h.Persistent = false
end)
print(string.format("%d offline integration tests passed (Lune fixtures; NOT Roblox Studio)", passed))
