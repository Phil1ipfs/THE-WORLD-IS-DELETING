--!nonstrict
-- Realm objective regressions: every activity type through the real validated interaction
-- path, plus events, storm breaches, hazards, perks, relics and achievements.
-- Offline fixtures only: no Roblox physics, replication, rendering or player skill.
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r = h.Roblox
local V = r.Vector3
local Config = h.Load(h.Shared.GameConfig)
local Rules = h.Load(h.Shared.Rules)
local RealmConfig = h.Load(h.Shared.RealmConfig)
local ObjectiveConfig = h.Load(h.Shared.ObjectiveConfig)
local World = h.Load(h.Server.Systems.WorldManager)
local Players = h.Load(h.Server.Systems.PlayerManager)
local Adventure = h.Load(h.Server.Systems.AdventureService)
local Objectives = h.Load(h.Server.Systems.ObjectiveService)
local Rewards = h.Load(h.Server.Systems.RewardManager)
local Powers = h.Load(h.Server.Systems.AbilityService)
local Generator = h.Load(h.Server.Systems.ExplorationGenerator)
local Builder = h.Load(h.Server.Systems.Activities.Builder)
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
-- Fresh world with every pool activity built (Count = 5) so each type is present.
local function setup()
	Builder.Count = 5
	local w = World.new()
	local p = Players.new(w, h.Effects)
	local rewards = Rewards.new(data, h.Effects)
	local a = Adventure.new(w, p, h.Effects, rewards)
	local o = Objectives.new(w, p, h.Effects, rewards, data)
	a.Objectives, o.Adventure = o, a
	w:reset(3489)
	local rec = p:add(h:player(900 + passed))
	rec.Ready = true
	p:transition(rec, "Queued")
	p:begin(rec)
	return { W = w, P = p, A = a, O = o, Rec = rec, Rewards = rewards }
end
local function cleanup(s)
	s.A:cancel(s.Rec)
	s.P:remove(s.Rec.Player)
	s.Rec.Player:Destroy()
	for _, region in s.W.Islands do
		s.W:dispose(region)
	end
	s.W.Root:Destroy()
	Builder.Count = 4
end
-- Builds a specific region index into the live world (any realm) and activates it.
local function realm(s, index)
	local region = s.W.Islands[index]
	if not region then
		region = Generator.build(s.W.Root, index, s.W.Origin, s.W.Seed)
		s.W.Islands[index] = region
		s.W.OnRegionAdded(region)
	end
	s.W:activate(index)
	s.Rec.Region = index
	return region
end
local function activity(region, kind)
	for _, act in region.Activities do
		if act.Type == kind then
			return act
		end
	end
	error("Region " .. region.Index .. " has no " .. kind)
end
local function at(s, position)
	local root = s.Rec.Player.Character.HumanoidRootPart
	root.Position = position
	s.Rec.LastPosition, s.Rec.LastCheck = position, h.Time
	return root
end
local function use(s, region, spec)
	at(s, spec.Part.Position + V.new(0, 1.5, 0))
	h:advance(0.6)
	return s.A:interact(s.Rec, region, spec)
end
local function tick(s, seconds, step)
	step = step or 0.1
	for _ = 1, math.ceil(seconds / step) do
		h:advance(step)
		s.O:tick(step)
	end
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
test("Every realm has a distinct activity pool and rounds draw different subsets", function()
	local signatures = {}
	for id, realmDef in RealmConfig.Realms do
		local types = {}
		for _, def in realmDef.Activities do
			assert(ObjectiveConfig.Hints[def.Type], "Unknown activity type " .. def.Type)
			table.insert(types, def.Type)
		end
		assert(#types >= 4 and #realmDef.Events >= 3, id .. " pool too small")
		table.sort(types)
		local signature = table.concat(types, ",") .. "|" .. realmDef.Creature .. "|" .. realmDef.Landmark
		assert(not signatures[signature], id .. " repeats another realm's identity")
		signatures[signature] = true
	end
	Builder.Count = 4
	local folder = r.Instance.new("Folder")
	folder.Parent = h.Workspace
	local seen = {}
	for round = 0, 5 do
		local region = Generator.build(folder, 1, 0, Config.Seed + round * 1709)
		local ids = {}
		for _, act in region.Activities do
			if act.Type ~= "Survey" then
				table.insert(ids, act.Def.Id)
			end
		end
		assert(#ids == 4, "Region did not receive four pool activities")
		table.sort(ids)
		seen[table.concat(ids, ",")] = true
		region.Model:Destroy()
	end
	local variants = 0
	for _ in seen do
		variants += 1
	end
	assert(variants >= 2, "Rounds always draw the same optional activities")
	folder:Destroy()
end)
test("Cooperative windmill repair consumes shared supplies, rewards and opens mill stores", function()
	local s = setup()
	local region = realm(s, 0)
	local act = activity(region, "Repair")
	assert(act.Def.Id == "Windmill" and not act.Done)
	local spec = act.Prompts.Contribute
	assert(not use(s, region, spec), "Repair accepted an empty pack")
	s.Rec.Bag.Timber = 6
	for _ = 1, 3 do
		assert(use(s, region, spec))
	end
	assert(act.Done and s.Rec.Bag.Timber == 0)
	local spinning = false
	for _, part in act.Moving do
		spinning = spinning or part:GetAttribute("Spin") ~= nil
	end
	assert(spinning, "Repaired windmill does not turn")
	assert(#events(s.Rec.Player, "Reward") >= 1)
	assert(data:get(s.Rec.Player).Achievements.Engineer)
	assert(use(s, region, spec) and s.Rec.Bag.Herb == 2 and s.Rec.Bag.Timber == 2, "Mill stores missing")
	assert(not use(s, region, spec), "Mill stores claimed twice")
	cleanup(s)
end)
test("Coolant pump repair disables lava hazards; generators fortify shelters and speed the lift", function()
	local s = setup()
	local volcanic = realm(s, 8)
	assert(volcanic.Biome.Id == "Volcanic")
	local lava
	for _, hazard in volcanic.Hazards do
		if hazard.Kind == "Lava" then
			lava = hazard
		end
	end
	assert(lava, "Volcanic realm has no lava hazard")
	at(s, lava.Part.Position + V.new(0, 2.5, 0))
	local hum = s.Rec.Player.Character.Humanoid
	hum.Health = 100
	tick(s, 1)
	assert(hum.Health < 100, "Lava did not burn")
	local pump = activity(volcanic, "Repair")
	s.Rec.Bag.Timber, s.Rec.Bag.Crystal = 4, 2
	hum.Health = 100
	for _ = 1, 3 do
		use(s, volcanic, pump.Prompts.Contribute)
	end
	assert(pump.Done and lava.Disabled)
	at(s, lava.Part.Position + V.new(0, 2.5, 0))
	tick(s, 1)
	assert(hum.Health == 100, "Cooled lava still burns")
	local mechanical = realm(s, 18)
	local generator = activity(mechanical, "Repair")
	s.Rec.Bag.Timber, s.Rec.Bag.Crystal = 4, 2
	for _ = 1, 3 do
		use(s, mechanical, generator.Prompts.Contribute)
	end
	assert(generator.Done and mechanical.ShelterPowered and mechanical.ExpressLift)
	cleanup(s)
end)
test(
	"Survivor rescue: free, escort across intact ground, deliver, and fail when ground is deleted",
	function()
		local s = setup()
		local region = realm(s, 13) -- Ruins survivor (Havenwood now runs the Lost Shepherd flock quest)
		local act = activity(region, "Rescue")
		assert(act.State == "Trapped" or act.State == "Waiting")
		assert(use(s, region, act.Spec))
		assert(act.State == "Following" and act.Escort == s.Rec)
		-- Walk to the region center, then to the beacon; the survivor follows on supported ground.
		local function walk(target)
			local root = s.Rec.Player.Character.HumanoidRootPart
			for _ = 1, 400 do
				local delta = target - root.Position
				if V.new(delta.X, 0, delta.Z).Magnitude < 1 then
					break
				end
				local stepVector = V.new(delta.X, 0, delta.Z)
				at(s, root.Position + stepVector.Unit * math.min(stepVector.Magnitude, 1.8))
				tick(s, 0.1)
			end
		end
		walk(region.Center + V.new(0, 3, 0))
		walk(region.Beacon + V.new(-3, 3, 0))
		tick(s, 3)
		assert(
			act.Done and act.State == "Saved",
			"Survivor did not reach the beacon: " .. tostring(act.State)
		)
		assert(data:get(s.Rec.Player).Achievements.Rescuer)
		cleanup(s)
		-- Failure path: the survivor's ground is deleted.
		s = setup()
		region = realm(s, 13)
		act = activity(region, "Rescue")
		local entry = region.Sites:at(act.Local.X, act.Local.Z)
		entry.Cell.Part.CanCollide = false
		tick(s, 0.2)
		assert(act.State == "Lost" and act.Failed and not act.Done)
		cleanup(s)
	end
)
test("Frozen scout needs an herb to thaw; jungle botanist needs vines cut", function()
	local s = setup()
	local frozen = realm(s, 10)
	local scout = activity(frozen, "Rescue")
	assert(scout.Thaw and scout.State == "Trapped")
	s.Rec.Bag.Herb = 0
	assert(not use(s, frozen, scout.Spec))
	s.Rec.Bag.Herb = 1
	assert(use(s, frozen, scout.Spec) and scout.State == "Waiting" and s.Rec.Bag.Herb == 0)
	local jungle = realm(s, 5)
	local botanist = activity(jungle, "Rescue")
	assert(botanist.Bound == 3)
	for _ = 1, 3 do
		assert(use(s, jungle, botanist.Spec))
	end
	assert(botanist.State == "Waiting" and #botanist.Bonds == 0)
	cleanup(s)
end)
test(
	"Creature lair: telegraphed attacks hurt, Aegis reflects, dash strikes defeat, spoils chest unlocks",
	function()
		local s = setup()
		local region = realm(s, 0)
		local act = activity(region, "Hunt")
		local hum = s.Rec.Player.Character.Humanoid
		local creature = act.Creatures[1]
		local function creaturePosition()
			return region.Center + creature.Local
		end
		-- Stand within lunge range and let the creature wind up and attack.
		at(s, creaturePosition() + V.new(6, 3, 0))
		hum.Health = 100
		local sawWindup = false
		for _ = 1, 40 do
			tick(s, 0.1)
			sawWindup = sawWindup or creature.State == "Windup"
			at(s, creaturePosition() + V.new(2, 3, 0))
		end
		assert(sawWindup, "Creature never telegraphed")
		assert(hum.Health < 100, "Creature attack did not damage")
		-- Dash strikes: each new dash serial can land one hit.
		hum.Health = 100
		for _, c in act.Creatures do
			creature = c
			for serial = 1, 20 do
				if c.State == "Gone" then
					break
				end
				s.Rec.DashUntil, s.Rec.DashSerial = h.Time + 1, (s.Rec.DashSerial or 0) + 1
				at(s, creaturePosition() + V.new(1, 2, 0))
				tick(s, 0.4)
				local _ = serial
			end
			assert(c.State == "Gone", "Creature survived repeated dash strikes")
		end
		tick(s, 0.2)
		assert(act.Done and act.Chest.Prompt.Enabled, "Lair did not complete")
		assert(use(s, region, act.Chest), "Spoils chest did not open")
		assert(not use(s, region, act.Chest), "Spoils chest opened twice for one player")
		assert(data:get(s.Rec.Player).Achievements.Hunter)
		cleanup(s)
	end
)
test("Pressure plates latch briefly; one player can chain them to open the vault", function()
	local s = setup()
	local region = realm(s, 0)
	local act = activity(region, "Plates")
	local plates = act.Plates
	at(s, region.Center + V.new(plates[1].X, 3, plates[1].Z))
	tick(s, 0.2)
	assert(act.Progress == 1)
	at(s, region.Center + V.new(0, 30, 0))
	tick(s, 7)
	assert(act.Progress == 0, "Plate stayed latched forever")
	for _, plate in plates do
		at(s, region.Center + V.new(plate.X, 3, plate.Z))
		tick(s, 0.5)
	end
	assert(act.Done and not act.Vault.Door.CanCollide and act.Vault.Chest.Prompt.Enabled)
	assert(use(s, region, act.Vault.Chest))
	cleanup(s)
end)
test("Symbol dials, light mirrors and crystal veins are solvable through prompts", function()
	local s = setup()
	local jungle = realm(s, 5)
	local dials = activity(jungle, "Dials")
	local Dials = h.Load(h.Server.Systems.Activities.Dials)
	for k, dial in dials.Dials do
		local guard = 0
		while Dials.Symbols[dial.Face + 1] ~= dials.Target[k] and guard < 4 do
			assert(use(s, jungle, dials.Prompts["Turn" .. k]))
			guard += 1
		end
	end
	assert(dials.Done and dials.Progress == 3, "Dials not solved")
	local crystal = realm(s, 3)
	local beams = activity(crystal, "Beams")
	for k, mirror in beams.Mirrors do
		while mirror.Turn ~= 0 do
			assert(use(s, crystal, beams.Prompts["Rotate" .. k]))
		end
	end
	assert(beams.Done and beams.Chest.Prompt.Enabled and beams.Receiver.Material == r.Enum.Material.Neon)
	local mining = activity(crystal, "Mining")
	s.Rec.Bag.Crystal = 0
	for k = 1, #mining.Veins do
		for _ = 1, 4 do
			assert(use(s, crystal, mining.Prompts["Mine" .. k]))
		end
		assert(not use(s, crystal, mining.Prompts["Mine" .. k]), "Depleted vein still mined")
	end
	assert(
		mining.Done and s.Rec.Bag.Crystal == 8,
		"Veins (3 x 2) plus completion reward (2) should fill the pack"
	)
	cleanup(s)
end)
test("Caches: ledge loot once per player, hidden until found, storm hoard only during storms", function()
	local s = setup()
	local region = realm(s, 0)
	local cache = activity(region, "Cache")
	assert(cache.Hidden and cache.Access == "Ledge")
	local status = s.O:status(s.Rec)
	local masked = false
	for _, row in status.Activities do
		masked = masked or (row.Hidden and row.Title == "Hidden secret")
	end
	assert(masked, "Hidden cache was listed before discovery")
	assert(use(s, region, cache.Chest), "Ledge cache could not be opened from its ledge")
	assert(cache.Discovered and cache.Done)
	assert(not use(s, region, cache.Chest), "Cache looted twice")
	assert(s.Rec.Perks and next(s.Rec.Perks), "Cache did not grant a perk")
	local storm = realm(s, 15)
	local hoard
	for _, act in storm.Activities do
		if act.Type == "Cache" then
			hoard = act
		end
	end
	assert(hoard and hoard.Access == "Storm")
	tick(s, 0.2)
	assert(not hoard.Chest.Prompt.Enabled, "Storm hoard open in calm weather")
	s.O.Events = { Name = "Storm", Phase = "Active" }
	tick(s, 0.2)
	assert(hoard.Chest.Prompt.Enabled, "Storm hoard closed during a storm")
	s.O.Events = nil
	cleanup(s)
end)
test("Air-current course: updraft is authorized, rings count in order and reset on timeout", function()
	local s = setup()
	local region = realm(s, 5)
	local act = activity(region, "Rings")
	at(s, region.Center + V.new(act.Vent.X, 2, act.Vent.Z))
	tick(s, 0.2)
	assert(#events(s.Rec.Player, "Updraft") >= 1 and s.Rec.MovementUntil > h.Time)
	local first = act.Rings[1]
	at(s, region.Center + first.Local)
	tick(s, 0.2)
	assert(act.Next == 2 and act.Runner == s.Rec)
	at(s, region.Center + V.new(0, 40, 0))
	tick(s, 16)
	assert(act.Next == 1 and act.Runner == nil, "Course did not reset after timeout")
	for _, ring in act.Rings do
		at(s, region.Center + ring.Local)
		tick(s, 0.2)
	end
	assert(act.Done, "Course not completed in order")
	cleanup(s)
end)
test("Artifacts return home when a carrier dies; three deliveries complete the pedestal", function()
	local s = setup()
	local region = realm(s, 13)
	local act = activity(region, "Artifacts")
	assert(use(s, region, act.Prompts.Take1))
	assert(act.Items[1].State == "Carried" and not use(s, region, act.Prompts.Take2), "Carried two artifacts")
	s.Rec.Player.Character.Humanoid.Health = 0
	tick(s, 0.2)
	assert(act.Items[1].State == "Resting" and act.Prompts.Take1.Prompt.Enabled)
	s.Rec.Player.Character.Humanoid.Health = 100
	for k = 1, 3 do
		assert(use(s, region, act.Prompts["Take" .. k]))
		assert(use(s, region, act.Prompts.Place))
	end
	assert(act.Done and act.Progress == 3)
	cleanup(s)
end)
test("Timed vault: lever opens the door briefly, loot requires being inside, door shuts again", function()
	local s = setup()
	local region = realm(s, 13)
	local act = activity(region, "Gate")
	tick(s, 0.2)
	assert(act.Vault.Door.CanCollide)
	assert(use(s, region, act.Prompts.Lever))
	tick(s, 0.2)
	assert(not act.Vault.Door.CanCollide and act.Vault.Chest.Prompt.Enabled)
	local inside = act.Vault.LocalBase + region.Center
	at(s, (inside * r.CFrame.new(0, 3, -7.5)).Position)
	h:advance(0.6)
	assert(not s.A:interact(s.Rec, region, act.Vault.Chest), "Vault looted through the back wall")
	at(s, (inside * r.CFrame.new(0, 3, -2)).Position)
	h:advance(0.6)
	assert(s.A:interact(s.Rec, region, act.Vault.Chest), "Vault chest rejected from inside")
	assert(act.Done)
	tick(s, 8)
	assert(act.Vault.Door.CanCollide, "Vault door never closed")
	cleanup(s)
end)
test("Dynamic events respect remaining region time, avoid repeats and pay out", function()
	local s = setup()
	local region = realm(s, 0)
	at(s, region.Center + V.new(0, 3, 0))
	region.Activated = h.Time - (Config.RegionLifetime - 50)
	region.EventState.Next = 0
	for _ = 1, 30 do
		s.O:schedule(region, h.Time)
		local active = region.EventState.Active
		if active then
			assert(
				active.Kind ~= "Boss" and active.Kind ~= "LostTraveler",
				"Long event scheduled near deletion"
			)
			active.Finished = true
			s.O:schedule(region, h.Time)
		end
		region.EventState.Next = 0
	end
	region.Activated = h.Time
	local drop = s.O:startEvent(region, "SupplyDrop", h.Time)
	region.EventState.Active = drop
	local crate = drop.Specs[1]
	assert(not crate.Prompt.Enabled)
	tick(s, 6.5)
	assert(drop.Landed and crate.Prompt.Enabled, "Supply crate did not land")
	s.Rec.Bag.Timber = 0
	assert(use(s, region, crate) and s.Rec.Bag.Timber == 2)
	assert(not use(s, region, crate), "Supply crate claimed twice")
	local relic = s.O:startEvent(region, "RareRelic", h.Time)
	if relic then
		assert(use(s, region, relic.Specs[1]) and s.Rec.Bag.Relic >= 1)
		assert(data:get(s.Rec.Player).Achievements.Daredevil)
	end
	local boss = s.O:startEvent(region, "Boss", h.Time)
	assert(boss and boss.Creature.Elite and boss.Creature.MaxHP >= 7)
	cleanup(s)
end)
test("Storms breach shelters: leaks hurt occupants, patching seals, fortified shelters heal", function()
	local s = setup()
	local region = realm(s, 0)
	local house
	for _, zone in region.Shelters do
		if zone.Name == "House" then
			house = zone
			break
		end
	end
	at(s, house.Anchor.Position + V.new(0, 4, 0))
	s.O.Events = { Name = "Storm", Phase = "Active" }
	tick(s, 0.2)
	assert(house.Leaking and #house.Open >= 1, "Storm created no breach")
	assert(s.O:shelterDamage(s.Rec, house.Anchor.Position + V.new(0, 4, 0)) == 3)
	for _, spec in house.Open do
		h:advance(0.6)
		local inward = spec.Part.Position - spec.Part.CFrame.LookVector * 3
		at(s, V.new(inward.X, house.Anchor.Position.Y + 3.5, inward.Z))
		assert(s.A:interact(s.Rec, region, spec), "Breach could not be patched from inside")
	end
	assert(not house.Leaking)
	assert(s.O:shelterDamage(s.Rec, house.Anchor.Position + V.new(0, 4, 0)) == 0)
	region.ShelterPowered = true
	local hum = s.Rec.Player.Character.Humanoid
	hum.Health = 50
	assert(s.O:shelterDamage(s.Rec, house.Anchor.Position + V.new(0, 4, 0)) == 0 and hum.Health > 50)
	s.O.Events = { Name = "Calm", Phase = "Calm" }
	tick(s, 0.2)
	assert(house.Open == nil, "Breaches survived the storm")
	cleanup(s)
end)
test("Timber Brace boards up a breached shelter; overcharged levers hold vaults open longer", function()
	local s = setup()
	local region = realm(s, 0)
	local house
	for _, zone in region.Shelters do
		if zone.Name == "House" then
			house = zone
			break
		end
	end
	local inside = house.Anchor.Position + V.new(4, 4, 2)
	at(s, inside)
	s.O.Events = { Name = "Storm", Phase = "Active" }
	tick(s, 0.2)
	assert(house.Leaking)
	s.Rec.Bag.Timber = 2
	at(s, inside)
	assert(s.A:use(s.Rec, "Timber"), "Brace failed inside the shelter")
	assert(not house.Leaking and s.Rec.Bag.Timber == 0, "Brace did not seal the breaches")
	s.O.Events = nil
	tick(s, 0.2)
	local ruins = realm(s, 13)
	local gate = activity(ruins, "Gate")
	s.Rec.OverchargeUntil = h.Time + 30
	assert(use(s, ruins, gate.Prompts.Lever))
	assert(math.abs(gate.OpenUntil - h.Time - 10) < 0.01, "Overcharge did not extend the vault door")
	cleanup(s)
end)
test("Run perks change abilities and capacity without stacking; relics bless or cash out", function()
	local s = setup()
	local rec = s.Rec
	local powers = Powers.new(h.Effects)
	rec.Perks = { Gale = true, Feather = true, AegisCore = true, Silk = true, Pack = true }
	assert(powers:request(rec, "Dash"))
	assert(math.abs(rec.Cooldowns.Dash - h.Time - Config.Ability.Dash.Cooldown * 0.75) < 0.01)
	local hum = rec.Player.Character.Humanoid
	hum:SetAttribute("Airborne", true)
	assert(powers:request(rec, "DoubleJump"))
	rec.Cooldowns.DoubleJump = 0
	assert(powers:request(rec, "DoubleJump"), "Feather Cloak did not allow a second leap")
	rec.Cooldowns.DoubleJump = 0
	assert(not powers:request(rec, "DoubleJump"), "Leap stacked beyond two")
	assert(powers:request(rec, "Glide") and math.abs(rec.GlideUntil - h.Time - 8) < 0.01)
	hum:SetAttribute("Airborne", false)
	assert(powers:request(rec, "Shield") and rec.ShieldHealth == 90)
	assert(s.O:grant(rec, "Timber", 99) == 15, "Explorer's Pack capacity wrong")
	rec.Perks = {}
	for _ = 1, #ObjectiveConfig.PerkOrder do
		s.O:perk(rec, "test")
	end
	local count = 0
	for _ in rec.Perks do
		count += 1
	end
	assert(count == #ObjectiveConfig.PerkOrder, "Perks duplicated instead of filling the set")
	assert(hum.MaxHealth == 125, "Heartstone did not raise max health")
	-- Relic blessing at an already discovered shrine.
	rec.Perks = {}
	local region = realm(s, 0)
	local shrine
	for _, spec in region.Interactions do
		if spec.Kind == "Discover" then
			shrine = spec
		end
	end
	assert(use(s, region, shrine))
	rec.Bag.Relic = 2
	assert(use(s, region, shrine) and rec.Bag.Relic == 0 and next(rec.Perks), "Shrine blessing failed")
	rec.Bag.Relic = 3
	local profile = data:get(rec.Player)
	local coins = profile.Coins
	s.O:finish(rec)
	assert(profile.Coins == coins + 18 and profile.Relics >= 3 and rec.Bag.Relic == 0)
	cleanup(s)
end)
test("Achievements persist and unlock their cosmetics; locked cosmetics cannot be bought", function()
	local s = setup()
	local cosmetics = Cosmetics.new(data, s.Rewards, h.Effects)
	local profile = data:get(s.Rec.Player)
	profile.Coins = 1000
	cosmetics:purchase(s.Rec, "halo")
	assert(not profile.Owned.halo and profile.Coins == 1000, "Unlock-only cosmetic was purchasable")
	s.O:achieve(s.Rec, "Treasure")
	cosmetics:purchase(s.Rec, "halo")
	assert(profile.Owned.halo and profile.Equipped == "halo" and profile.Coins == 1000)
	local migrated =
		Rules.profile({ Achievements = { Treasure = true, Bogus = true }, Owned = { halo = true } })
	assert(migrated.Achievements.Treasure and not migrated.Achievements.Bogus and migrated.Owned.halo)
	cleanup(s)
end)
test("Objective snapshot lists the realm, activities with progress and distance, and live events", function()
	local s = setup()
	local region = realm(s, 0)
	at(s, region.Center + V.new(0, 3, 0))
	local status = s.O:status(s.Rec)
	assert(status.Region == region.Model:GetAttribute("RegionName") and status.Main)
	assert(#status.Activities == #region.Activities and status.TimeLeft > 0)
	for _, row in status.Activities do
		assert(row.Title and row.Progress and row.Hint)
		if not row.Hidden then
			assert(row.Distance, "Visible activity lacks a distance")
		end
	end
	s.Rec.Perks = { Compass = true }
	for _, row in s.O:status(s.Rec).Activities do
		assert(not row.Hidden, "Relic Compass did not reveal hidden caches")
	end
	cleanup(s)
end)
print(
	string.format("%d gameplay regressions passed (offline; Studio feel/physics/multiplayer pending)", passed)
)
