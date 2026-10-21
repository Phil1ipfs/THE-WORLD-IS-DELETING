--!nonstrict
-- Realm Destroyer + Sky Balloon regressions through the real server modules: realm staging,
-- balloon boarding/countdown/flight/arrival/turnaround, Dragonbane equipment, raids, a full
-- solo encounter (telegraphs, weak points, weapons, rewards, anti-farming), escape and raze.
-- Offline fixtures only: no Roblox physics, replication, rendering or player skill. The fixture
-- raycast ignores RaycastParams.Exclude, so line-of-sight/cover always reads as clear here.
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r = h.Roblox
local V = r.Vector3
local Config = h.Load(h.Shared.GameConfig)
local Rules = h.Load(h.Shared.Rules)
local Biomes = h.Load(h.Shared.BiomeConfig)
local Dragon = h.Load(h.Shared.DragonConfig)
local Rig = h.Load(h.Shared.DragonRig)
local BalloonConfig = h.Load(h.Shared.BalloonConfig)
local World = h.Load(h.Server.Systems.WorldManager)
local Players = h.Load(h.Server.Systems.PlayerManager)
local Adventure = h.Load(h.Server.Systems.AdventureService)
local Objectives = h.Load(h.Server.Systems.ObjectiveService)
local Rewards = h.Load(h.Server.Systems.RewardManager)
local Destroyer = h.Load(h.Server.Systems.RealmDestroyer)
local Generator = h.Load(h.Server.Systems.ExplorationGenerator)
local Cosmetics = h.Load(h.Server.Services.CosmeticService)
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	assert(ok, "FAIL " .. name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end
local profiles = {}
local data = {
	get = function(_, player)
		profiles[player] = profiles[player] or Rules.profile(nil)
		return profiles[player]
	end,
}
local nextId = 4000
local function join(s)
	nextId += 1
	local rec = s.P:add(h:player(nextId))
	rec.Ready = true
	s.P:transition(rec, "Queued")
	s.P:begin(rec)
	return rec
end
local function setup(seed)
	local w = World.new()
	local p = Players.new(w, h.Effects)
	local rewards = Rewards.new(data, h.Effects)
	local a = Adventure.new(w, p, h.Effects, rewards)
	local o = Objectives.new(w, p, h.Effects, rewards, data)
	a.Objectives, o.Adventure = o, a
	local d = Destroyer.new(w, p, h.Effects, o, data)
	a.Dragon = d
	w:reset(seed or 3489)
	local s = { W = w, P = p, A = a, O = o, D = d }
	s.Rec = join(s)
	return s
end
local function cleanup(s)
	for _, record in s.P:active() do
		s.A:cancel(record)
	end
	for player in table.clone(s.P.Records) do
		s.P:remove(player)
		player:Destroy()
	end
	for _, region in s.W.Islands do
		s.W:dispose(region)
	end
	s.D:reset()
	s.W.Root:Destroy()
end
local function region(s, index)
	local built = s.W.Islands[index]
	if not built then
		built = Generator.build(s.W.Root, index, s.W.Origin, s.W.Seed)
		s.W.Islands[index] = built
		s.W.OnRegionAdded(built)
	end
	return built
end
local function at(rec, position)
	local root = rec.Player.Character.HumanoidRootPart
	root.Position = position
	rec.LastPosition, rec.LastCheck = position, h.Time
	return root
end
local function find(built, kind)
	for _, spec in built.Interactions do
		if spec.Kind == kind then
			return spec
		end
	end
	return nil
end
local function use(s, rec, built, spec)
	at(rec, spec.Part.Position + V.new(0, 1.5, 0))
	h:advance(0.6)
	return s.A:interact(rec, built, spec)
end
local function events(player, name)
	local found = {}
	for _, event in h.Events do
		if event[1] == player and event[2] == name then
			table.insert(found, event[3])
		end
	end
	return found
end
local function heal(s)
	for _, record in s.P:active() do
		local hum = record.Player.Character:FindFirstChildOfClass("Humanoid")
		hum.Health = 100
	end
end
test("Dragon stages follow the existing realm order (omen, raid, first encounter in realm 3)", function()
	local rise = Config.RegionRise
	local expected = {
		[0] = "Omen",
		[1] = "Omen",
		[2] = "Omen",
		[3] = "Raid",
		[4] = "Raid",
		[5] = "Encounter",
		[6] = "Raid",
		[7] = "Raid",
		[8] = "Encounter",
		[9] = "Raid",
		[10] = "Encounter",
	}
	for index, stage in expected do
		assert(
			Dragon.stage(index, rise) == stage,
			"region " .. index .. " stage " .. tostring(Dragon.stage(index, rise))
		)
	end
	assert(Biomes.at(0).Id == "Grasslands" and Biomes.at(3 * rise).Id == "Crystal")
	assert(
		Biomes.at(5 * rise).Id == "Jungle" and Biomes.at(4 * rise).Id == "Crystal",
		"Jungle starts at region 5"
	)
	assert(select(2, Dragon.stage(5, rise)) == 1 and select(2, Dragon.stage(8, rise)) == 2)
	assert(select(2, Dragon.stage(13, rise)) == 3 and select(2, Dragon.stage(20, rise)) == 4)
	-- Rig spheres include every weak point named by the exposure groups.
	local spheres = Rig.spheres("Stunned")
	for _, group in Rig.WeakGroups do
		for _, name in group do
			assert(spheres[name] and spheres[name].R > 0, name .. " sphere missing")
		end
	end
	assert(spheres.Head.Y < Rig.spheres(nil).Head.Y, "Stunned head is lowered for melee")
end)
test("Profiles persist dragon materials, cosmetics and a bounded bestiary", function()
	local p = Rules.profile({
		DragonScales = 41.9,
		Emberhearts = 2,
		DragonKills = 3,
		DragonAt = 1000,
		DragonRolls = 2,
		Owned = { dragonwing = true },
		Achievements = { Dragonbane = true },
		Bestiary = { RealmDestroyer = 4, BrambleStalker = 1, ["bad key"] = 3, Lower = 9, junk = 1 },
	})
	assert(p.DragonScales == 41 and p.Emberhearts == 2 and p.DragonKills == 3 and p.DragonRolls == 2)
	assert(p.Owned.dragonwing and p.Achievements.Dragonbane)
	assert(p.Bestiary.RealmDestroyer == 4 and p.Bestiary.BrambleStalker == 1 and p.Bestiary.Lower == 4)
	assert(p.Bestiary["bad key"] == nil and p.Bestiary.junk == nil)
	local flood = {}
	for i = 1, 200 do
		flood["Creature" .. string.rep("a", i % 20) .. string.char(65 + i % 26)] = 1
	end
	local count = 0
	for _ in Rules.profile({ Bestiary = flood }).Bestiary do
		count += 1
	end
	assert(count <= 64, "Bestiary must stay bounded")
	assert(Rules.profile(nil).DragonScales == 0 and next(Rules.profile(nil).Bestiary) == nil)
end)
test("Sky Balloon: shared 5s countdown, multiplayer boarding, flight, arrival and turnaround", function()
	local s = setup()
	local home = s.W.Islands[0]
	local spec = find(home, "Balloon")
	assert(spec and home.Balloon and home.Balloon.Built.Model.Parent == home.Model, "Station missing")
	assert(not find(home, "Lift"), "The old elevator prompt must be gone")
	local model = home.Balloon.Built.Model
	local names = {}
	for _, part in model:GetDescendants() do
		names[part.Name] = true
	end
	for _, name in
		{
			"BalloonEnvelope",
			"EnvelopeStripe",
			"EnvelopeBand",
			"BalloonGondola",
			"BalloonRope",
			"Lantern",
			"BurnerFlame",
			"PropulsionRing",
		}
	do
		assert(names[name], "Balloon part missing: " .. name)
	end
	local second = join(s)
	second.Region = 0
	assert(use(s, s.Rec, home, spec), "First boarding failed")
	local station = s.A.Balloon.Stations[home]
	assert(station.State == "Boarding" and s.Rec.Transit and s.Rec.Player.Character.HumanoidRootPart.Anchored)
	assert(math.abs(station.DepartAt - h.Time - BalloonConfig.Countdown) < 0.01, "Countdown is not 5 seconds")
	-- Boarded riders cannot re-trigger anything (Transit blocks interactions).
	assert(not s.A:interact(s.Rec, home, spec))
	at(second, spec.Part.Position + V.new(0, 1.5, 0))
	h:advance(0.6)
	assert(s.A:interact(second, home, spec), "Second rider could not join the same departure")
	assert(#station.Riders == 2)
	-- The second boarding does not extend the countdown.
	local departs = station.DepartAt
	s.A:update()
	assert(station.DepartAt == departs and station.State == "Boarding")
	h:advance(departs - h.Time - 0.05)
	s.A:update()
	assert(station.State == "Boarding", "Departed early")
	h:advance(0.1)
	s.A:update()
	assert(station.State == "Flight", "Did not depart after the countdown")
	assert(station.Built.Model.Parent and station.Built.Model.Parent.Name == "BalloonFlights")
	assert(spec.Prompt.ActionText == "Balloon away")
	-- A third player arriving during the flight is turned away (no duplicate departure).
	local third = join(s)
	third.Region = 0
	at(third, spec.Part.Position + V.new(0, 1.5, 0))
	h:advance(0.6)
	assert(not s.A:interact(third, home, spec) and not third.Transit)
	s.A:update()
	local root = s.Rec.Player.Character.HumanoidRootPart
	assert(root.Position.Y > home.Center.Y + 10, "Riders did not rise with the balloon")
	-- Rebase mid-flight keeps riders on course.
	s.W:rebase(1024)
	s.P:rebase(1024)
	h:advance(BalloonConfig.Flight)
	s.A:update()
	for _, rec in { s.Rec, second } do
		assert(not rec.Transit and not rec.Player.Character.HumanoidRootPart.Anchored)
		assert(rec.Region == 1 and rec.Peak == Config.RegionRise, "Arrival did not update progression")
	end
	assert(station.State == "Returning" and third.Region == 0)
	h:advance(BalloonConfig.Turnaround + 0.1)
	s.A:update()
	assert(station.State == "Docked" and station.Built and station.Built.Model.Parent == home.Model)
	assert(spec.Prompt.ActionText == "Board the Sky Balloon")
	cleanup(s)
end)
test("Sky Balloon releases riders who die or leave during boarding and cancels an empty countdown", function()
	local s = setup()
	local home = s.W.Islands[0]
	local spec = find(home, "Balloon")
	assert(use(s, s.Rec, home, spec))
	local station = s.A.Balloon.Stations[home]
	s.P:eliminate(s.Rec, "test")
	s.A:update()
	assert(not s.Rec.Transit and #station.Riders == 0 and station.State == "Docked")
	assert(not s.Rec.Player.Character.HumanoidRootPart.Anchored)
	-- Boarding is refused for explorers whose progress is in another region.
	local other = join(s)
	other.Region = 1
	at(other, spec.Part.Position + V.new(0, 1.5, 0))
	h:advance(0.6)
	assert(not s.A:interact(other, home, spec) and not other.Transit)
	cleanup(s)
end)
test("Dragonbane weapons appear from the first island and battle gear in encounter regions", function()
	local s = setup()
	local first = s.W.Islands[0].Armory
	assert(first and first.Forge and first.HarpoonRack, "Weapons must be available from the first island")
	assert(not first.Ballista and not first.Cannon, "Realm 1 has no battle emplacements (no battle there)")
	local raid = region(s, 3)
	assert(raid.Armory and raid.Armory.Forge and not raid.Armory.Ballista, "Raid regions get only a forge")
	local battle = region(s, 5)
	local armory = battle.Armory
	assert(armory.Forge and armory.Ballista and armory.Cannon, "Encounter region lacks ballista/cannon")
	for _, kind in { "Forge", "Ballista", "Cannon" } do
		local entry = armory[kind]
		assert(entry.Spec.Dragonbane == kind and entry.Spec.Prompt.Enabled)
		local d = (entry.Spec.Part.Position - battle.Center)
		assert(V.new(d.X, 0, d.Z).Magnitude > 15, kind .. " placed on the landing")
	end
	assert(armory.Ballista.State == "Broken", "Ballista starts broken (repairable)")
	cleanup(s)
end)
test("Raids burn distant ground far from every explorer, after a telegraph", function()
	local s = setup()
	local raid = region(s, 3)
	s.Rec.Region = 3
	at(s.Rec, raid.Center + V.new(0, 3.2, 0))
	s.W:activate(3)
	local started
	for _ = 1, 400 do
		h:advance(0.1)
		heal(s)
		s.D:update(0.1)
		if s.D.Raid and not started then
			started = s.D.Raid
		end
		if started and started.Phase == "Depart" then
			break
		end
	end
	assert(started, "No raid started in the Crystal Kingdom")
	assert(h.Time - raid.Activated >= Dragon.Raid.First - 0.2, "Raid started too early")
	local root = s.Rec.Player.Character.HumanoidRootPart
	for _, cell in started.Targets do
		local d = cell.Part.Position - root.Position
		assert(V.new(d.X, 0, d.Z).Magnitude >= Dragon.Raid.SafeDistance, "Raid targeted ground near a player")
		assert(cell.State == "Cracking", "Raid target did not crack")
		assert(not cell.Late, "Raid burned a refuge or causeway")
	end
	assert((profiles[s.Rec.Player].Bestiary.RealmDestroyer or 0) >= 2, "Raid discovery not recorded")
	cleanup(s)
end)
-- Runs the dragon loop for up to `seconds`, calling `each` every tick; stops when it returns true.
local function run(s, seconds, each)
	for _ = 1, math.ceil(seconds / 0.1) do
		h:advance(0.1)
		heal(s)
		s.D:update(0.1)
		s.A:update()
		if each and each() then
			return true
		end
	end
	return false
end
local function exposedPoint(d)
	local spheres = Rig.spheres(d.Action)
	local name = (Rig.WeakGroups[d.Exposed] or {})[1]
	if not name then
		return nil
	end
	local sphere = spheres[name]
	return d.Pose * V.new(sphere.X, sphere.Y, sphere.Z)
end
test("Solo encounter: telegraphed attacks, weak points, Dragonbane weapons, repel and rewards", function()
	local s = setup()
	local battle = region(s, 5)
	s.Rec.Region = 5
	local rec = s.Rec
	rec.Bag.Timber, rec.Bag.Crystal = 12, 8
	s.W:activate(5)
	-- Forge a crossbow and repair the ballista before the dragon arrives.
	assert(use(s, rec, battle, battle.Armory.Forge.Spec), "Forge failed")
	assert(
		s.D.Crossbow[rec].Bolts == Dragon.Weapons.Crossbow.Bolts
			and rec.Bag.Timber == 10
			and rec.Bag.Crystal == 7
	)
	assert(
		use(s, rec, battle, battle.Armory.Forge.Spec) and s.D.Crossbow[rec].Bolts == 32,
		"Fletching failed"
	)
	local ballista = battle.Armory.Ballista
	assert(use(s, rec, battle, ballista.Spec) and ballista.State == "Broken" and ballista.Repair == 2)
	assert(use(s, rec, battle, ballista.Spec) and ballista.State == "Ready", "Ballista repair failed")
	-- Invalid fire payloads are ignored.
	assert(
		not s.D:fire(rec, V.new(0 / 0, 0, 0))
			and not s.D:fire(rec, "up")
			and not s.D:fire(rec, V.new(0, 5, 0))
	)
	local home = battle.Center + V.new(0, 3.2, 0)
	at(rec, home)
	assert(
		run(s, 30, function()
			return s.D.Encounter ~= nil
		end),
		"Encounter did not start in the Floating Jungle"
	)
	local e = s.D.Encounter
	assert(h.Time - battle.Activated >= Dragon.EncounterDelay - 0.2)
	assert(e.MaxHP == Dragon.Tiers[1].HP, "Solo HP should be the tier base")
	assert(#events(rec.Player, "Dragon") > 0 and profiles[rec.Player].Bestiary.RealmDestroyer == 3)
	local seen, telegraphs, exposures, hits = {}, 0, {}, 0
	local cannonShots = 0
	local fightStart, hurtBefore = h.Time, #events(rec.Player, "Hurt")
	local finished = run(s, 140, function()
		at(rec, home)
		local enc = s.D.Encounter
		if not enc then
			return true
		end
		if enc.Attack then
			seen[enc.Attack] = true
		end
		for _, part in battle.Model:GetChildren() do
			if part.Name == "DragonTelegraph" then
				telegraphs += 1
				break
			end
		end
		if s.D.Exposed ~= "" then
			exposures[s.D.Exposed] = true
			local point = exposedPoint(s.D)
			local root = rec.Player.Character.HumanoidRootPart
			local aim = (point - (root.Position + V.new(0, 1.5, 0))).Unit
			if s.D:fire(rec, aim) then
				hits += 1
			end
			if h.Time >= (ballista.ReadyAt or 0) and ballista.State == "Ready" then
				at(rec, ballista.Spec.Part.Position + V.new(0, 1.5, 0))
				h:advance(0.6)
				s.A:interact(rec, battle, ballista.Spec)
				at(rec, home)
			end
			local cannon = battle.Armory.Cannon
			if h.Time >= (cannon.ReadyAt or 0) and rec.Bag.Crystal > 0 then
				at(rec, cannon.Spec.Part.Position + V.new(0, 1.5, 0))
				h:advance(0.6)
				if s.A:interact(rec, battle, cannon.Spec) then
					cannonShots += 1
				end
				at(rec, home)
			end
		end
		return false
	end)
	assert(finished, "Solo player could not repel the dragon within 140 s (HP " .. tostring(e.HP) .. ")")
	local attackList = {}
	for kind in seen do
		table.insert(attackList, kind)
	end
	table.sort(attackList)
	print(
		string.format(
			"  solo repel took %.1fs (scripted perfect aim, never dodging: %d damage taken): %d crossbow hits, %d cannon shots, attacks: %s",
			h.Time - fightStart,
			(function()
				local total = 0
				for i, hurt in events(rec.Player, "Hurt") do
					if i > hurtBefore then
						total += hurt.Amount or 0
					end
				end
				return total
			end)(),
			hits,
			cannonShots,
			table.concat(attackList, ", ")
		)
	)
	assert(s.D.Regions[battle].Result == "Repelled", "Result " .. tostring(s.D.Regions[battle].Result))
	local kinds = 0
	for _ in seen do
		kinds += 1
	end
	assert(kinds >= 3, "Too few attack kinds used: " .. kinds)
	assert(telegraphs > 0, "Attacks were never telegraphed on the ground")
	assert(hits > 0 and cannonShots > 0, "Weapons never connected")
	assert(next(exposures), "No weak point was ever exposed")
	local profile = profiles[rec.Player]
	assert(profile.Achievements.Dragonbane, "Dragonbane achievement missing")
	assert(profile.DragonScales == Dragon.Rewards.Scales[1] and profile.DragonKills == 1)
	assert(profile.Bestiary.RealmDestroyer == 4)
	assert(#events(rec.Player, "DragonTrophy") == 1)
	-- Anti-farming: a second repel inside the trophy cooldown gives no scales, shards or rolls.
	local before = { profile.DragonScales, profile.Emberhearts, profile.DragonRolls }
	s.D.Encounter = {
		Region = battle,
		Tier = 1,
		Def = Dragon.Tiers[1],
		HP = 0,
		MaxHP = 1,
		Damage = { [rec] = 5 },
		Escaped = {},
		Markers = {},
	}
	s.D:repel(s.D.Encounter)
	assert(
		profile.DragonScales == before[1]
			and profile.Emberhearts == before[2]
			and profile.DragonRolls == before[3]
	)
	assert(profile.DragonKills == 2 and #events(rec.Player, "DragonTrophy") == 1)
	-- The encounter never restarts in the same region.
	assert(not run(s, 25, function()
		return s.D.Encounter ~= nil
	end), "The encounter restarted after being repelled")
	cleanup(s)
end)
test("Dragonbane Harpoon: rack, throw, pin, glance, refusal outside battle and visible gear", function()
	local s = setup(6611)
	local battle = region(s, 5)
	local rec = s.Rec
	rec.Region = 5
	rec.Bag.Timber, rec.Bag.Crystal = 12, 6
	s.W:activate(5)
	local rack = battle.Armory.HarpoonRack
	assert(rack and rack.Spec.Dragonbane == "HarpoonRack", "Encounter region lacks a harpoon rack")
	assert(region(s, 3).Armory.HarpoonRack, "Raid regions also get a harpoon rack beside the forge")
	-- World sound loops exist on the forge and the balloon burner (designed bundled sounds).
	local forgeFire = battle.Armory.Forge.Built.Ember:FindFirstChild("ForgeFire")
	assert(
		forgeFire
			and forgeFire:IsA("Sound")
			and forgeFire.Looped
			and string.find(forgeFire.SoundId, "rbxasset://sounds/", 1, true)
	)
	local burner = battle.Balloon.Built.Flame:FindFirstChild("BurnerSound")
	assert(burner and burner.Looped and burner.RollOffMaxDistance <= 80)
	assert(use(s, rec, battle, rack.Spec), "Harpoon rack failed")
	local cfg = Dragon.Weapons.Harpoon
	assert(s.D.Harpoons[rec].Count == cfg.Count and rec.Bag.Timber == 9 and rec.Bag.Crystal == 5)
	local gear = 0
	for _, child in rec.Player.Character:GetChildren() do
		if child.Name == "DragonbaneHarpoon" then
			gear += 1
		end
	end
	assert(gear == cfg.Count * 2, "Harpoons are not visible on the character")
	assert(use(s, rec, battle, rack.Spec) and s.D.Harpoons[rec].Count == cfg.Count + cfg.RefillCount)
	-- Outside a battle the throw is refused and nothing is spent.
	local root = rec.Player.Character.HumanoidRootPart
	at(rec, battle.Center + V.new(0, 3.2, 0))
	assert(not s.D:throw(rec, V.new(0, 1, 0)) and s.D.Harpoons[rec].Count == 5)
	assert(not s.D:throw(rec, V.new(0 / 0, 0, 0)) and not s.D:throw(rec, "up"))
	assert(run(s, 30, function()
		at(rec, battle.Center + V.new(0, 3.2, 0))
		return s.D.Encounter ~= nil
	end))
	local d, e = s.D, s.D.Encounter
	-- Force a weak-point window in range and throw at it.
	d.Pose = r.CFrame.new(battle.Center + V.new(0, 30, -60))
	d.Action, d.Exposed = "Hover", "Heart"
	e.State, e.StateAt, e.Attack = "Recover", h.Time, "FireBreath"
	local origin = root.Position + V.new(0, 2, 0)
	local heart = d.Pose * V.new(Rig.Heart.X, Rig.Heart.Y, Rig.Heart.Z)
	local before = e.HP
	assert(d:throw(rec, (heart - origin).Unit), "Harpoon throw at an exposed heart failed")
	assert(before - e.HP == cfg.Damage, "Exposed hit should deal full harpoon damage")
	assert(e.Pinned and e.StateAt > h.Time, "A weak-point hit should pin the window open")
	assert(s.D.Harpoons[rec].Count == 4 and not d:throw(rec, (heart - origin).Unit), "Cooldown not enforced")
	-- Scales: a smaller glance through an unexposed point.
	h:advance(cfg.Cooldown + 0.1)
	d.Exposed = ""
	before = e.HP
	assert(d:throw(rec, (heart - origin).Unit))
	assert(before - e.HP == cfg.Glance, "Unexposed harpoon hit should glance for reduced damage")
	-- Out of range throws are refused without spending a harpoon.
	h:advance(cfg.Cooldown + 0.1)
	d.Pose = r.CFrame.new(battle.Center + V.new(0, 30, -400))
	assert(not d:throw(rec, V.new(0, 0, -1)) and s.D.Harpoons[rec].Count == 3)
	assert(s.D:status(rec).Harpoons == 3)
	cleanup(s)
end)
test("Every attack telegraphs before damage, exposes its weak point, and shockwaves can be jumped", function()
	local expectedExposure = {
		FireBreath = "Heart",
		InfernoSweep = "Heart",
		EmberRain = "Heart",
		WingGust = "Wings",
		GroundSlam = "Wings",
		Dive = "Head",
	}
	for kind, exposure in expectedExposure do
		local s = setup(9000 + #kind)
		local battle = region(s, 5)
		local target = s.Rec
		target.Region = 5
		local center = battle.Center + V.new(0, 3.2, 0)
		local others = {}
		if kind == "GroundSlam" then
			-- Symmetric flankers keep the landing on the target; one jumps the shockwave.
			for i, offset in { V.new(24, 0, 0), V.new(-24, 0, 0) } do
				local rec = join(s)
				rec.Region = 5
				others[i] = { Rec = rec, Offset = offset }
			end
		end
		local function place()
			at(target, center)
			for _, o in others do
				at(o.Rec, center + o.Offset)
			end
		end
		place()
		s.W:activate(5)
		assert(run(s, 30, function()
			place()
			return s.D.Encounter ~= nil
		end))
		local d = s.D
		local e = d.Encounter
		d.nextAttack = function()
			return kind
		end
		d.pickTarget = function()
			return target, target.Player.Character.HumanoidRootPart
		end
		e.State, e.StateAt, e.OrbitFor = "Orbit", h.Time - 10, 0
		if others[1] then
			others[1].Rec.Player.Character.Humanoid:SetAttribute("Airborne", true)
		end
		local function hurtCount(rec)
			return #events(rec.Player, "Hurt")
		end
		local before = hurtCount(target)
		local sawWindup, sawMarkers, damagedEarly, sawExposure = false, false, false, false
		local done = run(s, 25, function()
			place()
			local enc = d.Encounter
			if not enc then
				return true
			end
			if enc.State == "Windup" then
				sawWindup = true
				if hurtCount(target) > before then
					damagedEarly = true
				end
				for _, part in battle.Model:GetChildren() do
					if part.Name == "DragonTelegraph" then
						sawMarkers = true
					end
				end
			end
			if enc.State == "Recover" and d.Exposed == exposure then
				sawExposure = true
			end
			return enc.State == "Orbit" and sawWindup
		end)
		assert(done, kind .. " never completed")
		assert(sawWindup and sawMarkers, kind .. " was not telegraphed with ground markers")
		assert(not damagedEarly, kind .. " dealt damage during its telegraph")
		assert(hurtCount(target) > before, kind .. " never hit a player who stood in the marked zone")
		assert(sawExposure, kind .. " did not expose " .. exposure)
		if kind == "GroundSlam" then
			local jumper, grounded = others[1].Rec, others[2].Rec
			local jumped = 0
			for _, hurt in events(jumper.Player, "Hurt") do
				if hurt.Source == "Shockwave" then
					jumped += 1
				end
			end
			local stood = 0
			for _, hurt in events(grounded.Player, "Hurt") do
				if hurt.Source == "Shockwave" then
					stood += 1
				end
			end
			assert(jumped == 0, "A jumping player was hit by the slam shockwave")
			assert(stood > 0, "A grounded player at the ring was not hit by the shockwave")
		end
		cleanup(s)
	end
end)
test(
	"Studio Dragon Preview: the first island becomes a battle that attacks the realm and the player",
	function()
		h.Workspace:SetAttribute("DragonPreview", true)
		local ok, err = pcall(function()
			assert(Dragon.stage(0, Config.RegionRise, true) == "Encounter")
			assert(
				Dragon.stage(1, Config.RegionRise, true) == "Raid"
					and Dragon.stage(3, Config.RegionRise, true) == "Raid"
			)
			local s = setup(4242)
			local home = s.W.Islands[0]
			assert(
				home.Armory.Ballista and home.Armory.Cannon and home.Armory.HarpoonRack,
				"Preview island lacks battle gear"
			)
			s.Rec.Region = 0
			at(s.Rec, home.Center + V.new(0, 3.2, 0))
			s.W:activate(0)
			local hurtBefore = #events(s.Rec.Player, "Hurt")
			assert(
				run(s, 30, function()
					at(s.Rec, home.Center + V.new(0, 3.2, 0))
					return s.D.Encounter ~= nil
				end),
				"Preview battle did not start on the first island"
			)
			local cracked = false
			run(s, 60, function()
				at(s.Rec, home.Center + V.new(0, 3.2, 0))
				for _, cell in home.Cells do
					if cell.Part:GetAttribute("CrackCause") == "Dragon" then
						cracked = true
					end
				end
				return cracked and #events(s.Rec.Player, "Hurt") > hurtBefore
			end)
			assert(#events(s.Rec.Player, "Hurt") > hurtBefore, "The dragon never hurt the standing player")
			assert(cracked, "The dragon never damaged the realm")
			cleanup(s)
		end)
		h.Workspace:SetAttribute("DragonPreview", false)
		assert(ok, err)
	end
)
test("Escape path: leaving forfeits rewards, then the abandoned realm is razed", function()
	local s = setup(5512)
	local battle = region(s, 5)
	local nextRegion = region(s, 6)
	s.Rec.Region = 5
	at(s.Rec, battle.Center + V.new(0, 3.2, 0))
	s.W:activate(5)
	assert(run(s, 30, function()
		return s.D.Encounter ~= nil
	end))
	-- Escape upward (as the Sky Balloon does on arrival).
	assert(s.P:transfer(s.Rec, 6))
	assert(nextRegion.Landing.Parent)
	assert(
		run(s, 10, function()
			return s.D.Encounter == nil
		end),
		"Encounter did not end after everyone escaped"
	)
	assert(s.D.Regions[battle].Result == "Escaped")
	assert(#events(s.Rec.Player, "Dragon") >= 2)
	local cracking = 0
	for _, cell in battle.Cells do
		if cell.State == "Cracking" then
			cracking += 1
		end
	end
	assert(cracking > 20, "The abandoned realm was not razed")
	for _, cell in battle.Cells do
		if cell.Part.Name == "SkyCauseway" then
			assert(cell.State == "Stable", "Raze must spare the sky causeway")
		end
	end
	local profile = profiles[s.Rec.Player]
	assert(
		not profile.Achievements.Dragonbane and (profile.DragonScales or 0) == 0,
		"Escapees got boss rewards"
	)
	cleanup(s)
end)
test("Raze timer destroys the realm if the dragon is neither repelled nor escaped", function()
	local s = setup(7781)
	local battle = region(s, 5)
	s.Rec.Region = 5
	at(s.Rec, battle.Center + V.new(0, 3.2, 0))
	s.W:activate(5)
	assert(run(s, 30, function()
		return s.D.Encounter ~= nil
	end))
	local e = s.D.Encounter
	assert(e.RazeAt - h.Time <= Dragon.Tiers[1].RazeAfter + 0.01)
	local status = s.D:status(s.Rec)
	assert(status.Encounter and status.HP == e.MaxHP and status.RazeIn > 0)
	h:advance(e.RazeAt - h.Time + 0.05)
	s.D:update(0.1)
	assert(s.D.Encounter == nil and s.D.Regions[battle].Result == "Razed")
	cleanup(s)
end)
test("Dragonwing Mantle: dragon drop, or crafted from persistent scales and shards", function()
	local s = setup()
	local profile = data:get(s.Rec.Player)
	local rewards = Rewards.new(data, h.Effects)
	local shop = Cosmetics.new(data, rewards, h.Effects)
	shop:purchase(s.Rec, "dragonwing")
	assert(not profile.Owned.dragonwing, "Locked drop was granted for free")
	profile.DragonScales, profile.Emberhearts = Dragon.Rewards.CraftCost.DragonScales, 2
	shop:purchase(s.Rec, "dragonwing")
	assert(profile.Owned.dragonwing and profile.Equipped == "dragonwing")
	assert(profile.DragonScales == 0 and profile.Emberhearts == 0)
	-- Coin purchase, emote purchase keeps the worn cosmetic, unequip, and insufficient coins.
	profile.Coins = 400
	shop:purchase(s.Rec, "galewings")
	assert(profile.Owned.galewings and profile.Equipped == "galewings" and profile.Coins == 50)
	shop:purchase(s.Rec, "wave")
	assert(profile.Owned.wave and profile.Equipped == "galewings", "Buying an emote stripped the cosmetic")
	shop:purchase(s.Rec, "golden")
	assert(not profile.Owned.golden and profile.Coins == 10, "Unaffordable item was granted")
	shop:purchase(s.Rec, "none")
	assert(profile.Equipped == "none")
	cleanup(s)
end)
print(passed .. " dragon/balloon tests passed (Lune fixtures; NOT Roblox Studio)")
