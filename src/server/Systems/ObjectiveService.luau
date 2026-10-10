--!nonstrict
-- Realm objectives: runs activity logic, rewards, run perks, achievements, hidden discoveries,
-- environmental hazards, dynamic realm events and active storm shelters.
-- All state is server-owned; clients only send intent through validated prompts.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Items = require(Shared.ItemConfig)
local Objectives = require(Shared.ObjectiveConfig)
local Random = require(Shared.Random)
local Activities = script.Parent.Activities
local Common = require(Activities.Common)
local Creatures = require(Activities.Creatures)
local G = require(script.Parent.Parent.Services.Geometry)
local Service = {}
Service.__index = Service
local C = Color3.fromRGB
local modules = {}
local function module(kind)
	if modules[kind] == nil then
		local script = Activities:FindFirstChild(kind)
		modules[kind] = if script then require(script) else false
	end
	return modules[kind] or nil
end
function Service.new(world, players, effects, rewards, data)
	local self = setmetatable({
		World = world,
		Players = players,
		Effects = effects,
		Rewards = rewards,
		Data = data,
		Accum = 0,
		HazardAccum = 0,
		Round = 0,
	}, Service)
	return self
end
-- Called by AdventureService when a region is attached (after its interactions are registered).
function Service:attach(region)
	region.EventState = { Count = 0, Rng = Random.new((self.World.Seed or 0) + region.Index * 977 + 5) }
	for _, act in region.Activities do
		act.Participants = act.Participants or {}
	end
end
function Service:detach(region)
	for _, act in region.Activities or {} do
		local m = module(act.Type)
		if m and m.cleanup then
			m.cleanup(act)
		end
	end
	local event = region.EventState and region.EventState.Active
	if event and event.Creature then
		Creatures.remove(event.Creature)
	end
end
function Service:notice(record, text)
	self.Effects:FireClient(record.Player, "Notice", text)
end
function Service:inRegion(region)
	local list = {}
	for _, record in self.Players:active() do
		if record.Region == region.Index or record.Region == region.Index - 1 then
			local root = Common.root(record)
			if root and (root.Position - region.Center).Magnitude < 300 then
				table.insert(list, record)
			end
		end
	end
	return list
end
function Service:announce(act, text, kind)
	for _, record in self:inRegion(act.Region) do
		self.Effects:FireClient(
			record.Player,
			"Objective",
			{ Kind = kind or "Progress", Title = act.Title, Text = text }
		)
	end
end
function Service:update(act)
	act.Dirty = true
end
function Service:participate(act, record)
	act.Participants[record] = true
end
function Service:hurt(record, amount, source)
	self.Players:damage(record, amount)
	self.Effects:FireClient(record.Player, "Hurt", { Amount = amount, Source = source })
end
function Service:cap(record, kind)
	if kind == "Relic" then
		return Objectives.RelicCap
	end
	local item = Items[kind]
	return (item and item.Cap or 0) + (if record.Perks and record.Perks.Pack then 3 else 0)
end
-- Adds inventory within caps; returns the amount actually granted.
function Service:grant(record, kind, amount)
	record.Bag = record.Bag or { Timber = 0, Crystal = 0, Herb = 0 }
	local have = record.Bag[kind] or 0
	local granted = math.max(0, math.min(amount, self:cap(record, kind) - have))
	record.Bag[kind] = have + granted
	return granted
end
function Service:profile(record)
	return self.Data and self.Data:get(record.Player)
end
function Service:achieve(records, id)
	local list = if records.Player then { records } else records
	for key, value in list do
		local record = if type(key) == "table" and key.Player then key else value
		if type(record) == "table" and record.Player then
			local profile = self:profile(record)
			if profile then
				profile.Achievements = profile.Achievements or {}
				if not profile.Achievements[id] then
					profile.Achievements[id] = true
					local info = Objectives.Achievements[id]
					self.Effects:FireClient(
						record.Player,
						"Achievement",
						{ Id = id, Name = info.Name, Text = info.Text, Unlock = info.Unlock }
					)
				end
			end
		end
	end
end
-- Random run perk the player does not own yet; coins when every perk is owned.
function Service:perk(record, source)
	record.Perks = record.Perks or {}
	local options = {}
	for _, id in Objectives.PerkOrder do
		if not record.Perks[id] then
			table.insert(options, id)
		end
	end
	if #options == 0 then
		self:pay(record, 15, 20)
		return nil
	end
	local rng = self.PerkRng or Random.new((self.World.Seed or 1) + 4243)
	self.PerkRng = rng
	local id = options[rng:integer(1, #options)]
	record.Perks[id] = true
	if id == "Heart" then
		local _, hum = Common.root(record)
		if hum then
			hum.MaxHealth += 25
			hum.Health = math.min(hum.MaxHealth, hum.Health + 25)
		end
	end
	local perk = Objectives.Perks[id]
	self.Effects:FireClient(
		record.Player,
		"Perk",
		{ Id = id, Name = perk.Name, Text = perk.Text, Source = source }
	)
	return id
end
function Service:pay(record, coins, xp)
	if coins > 0 and self.Rewards then
		self.Rewards:bonus(record, coins)
	end
	local profile = self:profile(record)
	if profile and xp > 0 then
		profile.XP += xp
		if self.Rewards then
			self.Rewards:refresh(record.Player)
		end
	end
	record.RunXP = (record.RunXP or 0) + xp
end
function Service:reward(record, spec, reason)
	local granted = { Coins = spec.Coins or 0, XP = spec.XP or 0, Reason = reason }
	self:pay(record, granted.Coins, granted.XP)
	if spec.Relic then
		granted.Relic = self:grant(record, "Relic", spec.Relic)
	end
	if spec.Crystal then
		granted.Crystal = self:grant(record, "Crystal", spec.Crystal)
	end
	for _, kind in { "Timber", "Herb" } do
		if spec[kind] then
			granted[kind] = self:grant(record, kind, spec[kind])
		end
	end
	if spec.Perk then
		granted.Perk = self:perk(record, reason)
	end
	self.Effects:FireClient(record.Player, "Reward", granted)
	return granted
end
function Service:complete(act, text, achievement)
	if act.Done then
		return
	end
	act.Done, act.Dirty = true, true
	act.CompletedAt = os.clock()
	if act.Type ~= "Cache" then
		local spec = Objectives.Rewards[act.Type] or { Coins = 10, XP = 20 }
		for record in act.Participants do
			if record.State == "Alive" then
				self:reward(record, spec, act.Title)
			end
		end
	end
	if act.Type == "Repair" then
		self:achieve(act.Participants, "Engineer")
	end
	if achievement then
		self:achieve(act.Participants, achievement)
	end
	for _, record in self:inRegion(act.Region) do
		self.Effects:FireClient(
			record.Player,
			"Objective",
			{ Kind = "Complete", Title = act.Title, Text = text }
		)
	end
	-- Completing every activity in a region is a secret achievement.
	local region, all = act.Region, true
	for _, other in region.Activities do
		if not other.Done and not other.Dynamic then
			all = false
		end
	end
	if all and not region.Completed then
		region.Completed = true
		local everyone = {}
		for _, other in region.Activities do
			for record in other.Participants do
				everyone[record] = true
			end
		end
		self:achieve(everyone, "Completionist")
	end
end
function Service:fail(act, text)
	act.Failed, act.Dirty = true, true
	for _, record in self:inRegion(act.Region) do
		self.Effects:FireClient(
			record.Player,
			"Objective",
			{ Kind = "Failed", Title = act.Title, Text = text }
		)
	end
end
-- Personal chest loot (each player once per chest).
function Service:openChest(act, record)
	local id = record.Player.UserId
	act.Claims = act.Claims or {}
	if act.Claims[id] then
		self:notice(record, "You already looted this.")
		return false
	end
	act.Claims[id] = true
	record.Chests = (record.Chests or 0) + 1
	local base = Objectives.Rewards[act.Type] or {}
	local loot = {
		Coins = if act.Type == "Cache" then base.Coins else 8,
		XP = if act.Type == "Cache" then base.XP else 15,
		Relic = 1,
		Timber = 1,
		Herb = if (record.Chests % 2) == 0 then 1 else nil,
		Perk = act.Type == "Cache",
	}
	self:reward(record, loot, act.Title)
	self.Effects:FireAllClients(
		"ChestOpened",
		{ Position = act.Prompts and act.Prompts.Open and act.Prompts.Open.Part.Position or nil, UserId = id }
	)
	if record.Chests >= 5 then
		self:achieve(record, "Treasure")
	end
	return true
end
function Service:interact(record, region, spec)
	local act = spec.Activity
	if spec.Event then
		return self:eventInteract(record, region, spec)
	end
	if spec.Breach then
		return self:patch(record, region, spec)
	end
	if not act or act.Region ~= region or act.Failed then
		return false
	end
	local m = module(act.Type)
	return m and m.interact(self, act, record, spec) or false
end
local function remaining(region)
	if not region.Activated then
		return Config.RegionLifetime
	end
	return Config.RegionLifetime - (os.clock() - region.Activated)
end
Service.remaining = remaining
-- Dynamic events: seeded per round and region, spaced by cooldowns, never scheduled when the
-- region would be deleted before players could reasonably finish them.
local requirements =
	{ SupplyDrop = 55, RareRelic = 45, Boss = 100, LostTraveler = 95, SecretVault = 50, AncientMachine = 45 }
function Service:schedule(region, now)
	local state = region.EventState
	if not state or not region.Activated then
		return
	end
	state.Next = state.Next or region.Activated + 22 + state.Rng:range(0, 14)
	if state.Active then
		if now >= state.Active.Until or state.Active.Finished then
			self:endEvent(region, state.Active)
			state.Active = nil
			state.Next = now + 40 + state.Rng:range(0, 25)
		end
		return
	end
	if now < state.Next or #self:inRegion(region) == 0 then
		return
	end
	local pool = {}
	for _, name in region.Design.Events or {} do
		if name ~= state.Last and remaining(region) >= (requirements[name] or 60) then
			table.insert(pool, name)
		end
	end
	if #pool == 0 then
		state.Next = now + 20
		return
	end
	local name = pool[state.Rng:integer(1, #pool)]
	state.Count += 1
	state.Last = name
	state.Active = self:startEvent(region, name, now)
	if not state.Active then
		state.Next = now + 15
	end
end
local function eventPrompt(self, region, x, z, y, text, event)
	local spec = region.Prompt("Event", x, z, text, nil, y)
	spec = region.Interactions[#region.Interactions]
	spec.Event, spec.Prompt.HoldDuration = event, 0.3
	spec.Prompt.ObjectText = Objectives.EventText[event.Kind] and event.Title or "Event"
	if self.Adventure then
		self.Adventure:register(region, spec)
	end
	table.insert(event.Specs, spec)
	return spec
end
local function ctxFor(region)
	return {
		Region = region,
		B = region.Props,
		S = region.Sites,
		Rng = region.EventState.Rng,
		Accent = G.color(region.Biome.Accent),
		Design = region.Design,
		World = function(x, z, y)
			return region.Center + Vector3.new(x, (y or 0) + region.Sites:height(x, z), z)
		end,
		Land = require(script.Parent.Parent.Services.Sites).Core,
		Ground = function(x, z)
			local entry = region.Sites:at(x, z)
			return if entry then entry.Cell.Part else region.Landing
		end,
	}
end
local titles = {
	SupplyDrop = "Supply drop",
	RareRelic = "Rare relic",
	Boss = "Roaming guardian",
	LostTraveler = "Lost traveler",
	SecretVault = "Secret cave vault",
	AncientMachine = "Ancient machine",
}
local function direction(_region, x, z)
	local names = { "east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast" }
	local a = math.atan2(z, x)
	return names[(math.floor((a / (math.pi * 2)) * 8 + 0.5) % 8) + 1]
end
function Service:startEvent(region, name, now)
	local ctx = ctxFor(region)
	local rng = ctx.Rng
	local event = {
		Kind = name,
		Title = titles[name],
		Specs = {},
		Parts = {},
		Claims = {},
		Started = now,
		Region = region,
	}
	local S = region.Sites
	-- Event sites never persist reservations; they retry with smaller footprints when crowded.
	local function find(radius, edgeMin)
		for _, size in { radius, radius * 0.6, 2 } do
			local saved = S.Circles
			S.Circles = table.clone(saved)
			local site = S:find(rng, size, { Mainland = true, Outskirts = true }, 80, function(_, _, entry)
				local edge = entry.Cell.Edge
				if edgeMin then
					return if edge >= edgeMin then edge else -1
				end
				return -edge + rng:range(0, 0.4)
			end)
			S.Circles = saved
			if
				site
				and Common.support(region, site.X, site.Z)
				and (not edgeMin or site.Entry.Cell.Edge >= edgeMin)
			then
				return site
			end
		end
		return nil
	end
	if name == "SupplyDrop" then
		local site = find(4)
		if not site then
			return nil
		end
		local spec = eventPrompt(self, region, site.X, site.Z, 1.6, "Open supply crate", event)
		local crate = spec.Part
		crate.Transparency, crate.Size, crate.Color, crate.Material =
			0, Vector3.new(3, 3, 3), C(150, 112, 70), Enum.Material.WoodPlanks
		local chute = G.part(
			crate,
			"Parachute",
			Vector3.new(9, 3.5, 9),
			crate.CFrame * CFrame.new(0, 9, 0),
			C(230, 80, 70),
			Enum.Material.Fabric,
			false
		)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, chute
		event.Ground = ctx.Ground(site.X, site.Z)
		event.Drop, event.Landed = { Local = Vector3.new(site.X, 1.6, site.Z), From = 90 }, false
		spec.Prompt.Enabled = false
		event.Until = now + 70
		event.Text = Objectives.EventText.SupplyDrop
			.. " It lands to the "
			.. direction(region, site.X, site.Z)
			.. "."
	elseif name == "RareRelic" then
		local site = find(3, 0.75)
		if not site then
			return nil
		end
		local spec = eventPrompt(self, region, site.X, site.Z, 2.4, "Claim rare relic", event)
		spec.Part.Transparency, spec.Part.Color, spec.Part.Material = 0, C(255, 220, 120), Enum.Material.Neon
		spec.Part.Size = Vector3.new(1.2, 2.4, 1.2)
		spec.Part:SetAttribute("Spin", 1.5)
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Parent = C(255, 220, 140), 16, 1, spec.Part
		event.Until = now + 40
		event.Text = Objectives.EventText.RareRelic .. " Look " .. direction(region, site.X, site.Z) .. "."
		event.Ground = ctx.Ground(site.X, site.Z)
	elseif name == "Boss" then
		local site = find(6)
		if not site then
			return nil
		end
		event.Creature = Creatures.spawn(ctx, region.Design.Creature, site.X, site.Z, true)
		event.Creature.Label.TextColor3 = C(255, 120, 120)
		event.Until = now + 100
		event.Text = Objectives.EventText.Boss
			.. " It prowls to the "
			.. direction(region, site.X, site.Z)
			.. "."
	elseif name == "LostTraveler" then
		local rescue = module("Rescue")
		local act = {
			Id = region.Index .. ":Traveler" .. region.EventState.Count,
			Type = "Rescue",
			Def = { Id = "Traveler", Type = "Rescue", Title = "Rescue the lost traveler" },
			Title = "Rescue the lost traveler",
			Hint = Objectives.Hints.Rescue,
			Done = false,
			Progress = 0,
			Goal = 1,
			Prompts = {},
			Participants = {},
			Claims = {},
			Region = region,
			Dynamic = true,
		}
		local before = #region.Interactions
		if rescue.build(ctx, act) == false then
			return nil
		end
		for i = before + 1, #region.Interactions do
			if self.Adventure then
				self.Adventure:register(region, region.Interactions[i])
			end
		end
		table.insert(region.Activities, act)
		event.Activity = act
		event.Until = now + 150
		event.Text = Objectives.EventText.LostTraveler
	elseif name == "SecretVault" then
		local act = {
			Title = "Secret cave vault",
			Type = "Cache",
			Prompts = {},
			Claims = {},
			Region = region,
			Participants = {},
		}
		event.Act = act
		local spec = eventPrompt(self, region, -112, -40, 1.6, "Loot secret vault", event)
		spec.Part.Transparency, spec.Part.Size, spec.Part.Color, spec.Part.Material =
			0, Vector3.new(3.4, 2, 2.2), C(124, 84, 50), Enum.Material.WoodPlanks
		event.Until = now + 45
		event.Text = Objectives.EventText.SecretVault
		event.Ground = region.Landing
		for _, c in region.Cells do
			if c.Part.Name == "CaveFloor" then
				event.Ground = c.Part
			end
		end
	elseif name == "AncientMachine" then
		local spec = eventPrompt(self, region, 132, 12, 2.4, "Accept ancient blessing", event)
		spec.Part.Transparency, spec.Part.Color, spec.Part.Material =
			0.2, C(160, 240, 255), Enum.Material.Neon
		spec.Part.Shape = Enum.PartType.Ball
		spec.Part.Size = Vector3.new(2.4, 2.4, 2.4)
		event.Until = now + 45
		event.Text = Objectives.EventText.AncientMachine
		event.Ground = region.Landing
	end
	for _, spec in event.Specs do
		table.insert(region.Structures, { Part = spec.Part, Ground = event.Ground or region.Landing })
	end
	for _, record in self:inRegion(region) do
		self.Effects:FireClient(
			record.Player,
			"Objective",
			{ Kind = "Event", Title = event.Title, Text = event.Text }
		)
	end
	return event
end
function Service:endEvent(_region, event)
	for _, spec in event.Specs do
		spec.Prompt.Enabled = false
		if spec.Part.Parent then
			spec.Part.Parent = nil
		end
	end
	if event.Creature then
		Creatures.remove(event.Creature)
	end
	if
		event.Activity
		and not event.Activity.Done
		and event.Activity.Model
		and event.Activity.Model.Parent
	then
		-- An unrescued traveler stays until deleted; the event slot simply frees up.
		event.Activity.Dynamic = true
	end
end
function Service:eventInteract(record, _region, spec)
	local event = spec.Event
	local id = record.Player.UserId
	if event.Claims[id] then
		self:notice(record, "You already claimed this.")
		return false
	end
	if event.Kind == "SupplyDrop" then
		if not event.Landed then
			return false
		end
		event.Claims[id] = true
		self:reward(record, { Timber = 2, Crystal = 1, Herb = 1, Coins = 5, XP = 10 }, "Supply drop")
	elseif event.Kind == "RareRelic" then
		event.Claims[id] = true
		self:reward(record, { Relic = 1, Coins = 25, XP = 30 }, "Rare relic")
		self:achieve(record, "Daredevil")
	elseif event.Kind == "SecretVault" then
		return self:openChest(event.Act, record)
	elseif event.Kind == "AncientMachine" then
		event.Claims[id] = true
		self:reward(record, { XP = 20, Perk = true }, "Ancient machine")
	else
		return false
	end
	return true
end
function Service:updateEvent(region, event, dt, now)
	if event.Drop and not event.Landed then
		local t = math.clamp((now - event.Started) / 6, 0, 1)
		local spec = event.Specs[1]
		if not spec.Part.Parent then
			event.Finished = true
			return
		end
		local height = event.Drop.From * (1 - t)
		local cf = CFrame.new(region.Center + event.Drop.Local + Vector3.new(0, height, 0))
			* CFrame.Angles(0, now * 0.6, 0)
		spec.Part.CFrame = cf
		local chute = spec.Part:FindFirstChild("Parachute")
		if chute then
			chute.CFrame = cf * CFrame.new(0, 9, 0)
			chute.Transparency = if t >= 1 then 1 else 0
		end
		if t >= 1 then
			event.Landed = true
			spec.Prompt.Enabled = true
		end
	end
	if event.Creature and event.Creature.State ~= "Gone" then
		Creatures.scale(event.Creature, #self:inRegion(region))
		local result = Creatures.update(self, event.Creature, dt, now)
		if result == "Defeated" then
			for record in event.Creature.Hitters do
				self:reward(record, { Coins = 40, XP = 80, Relic = 2, Perk = true }, "Roaming guardian")
			end
			self:achieve(event.Creature.Hitters, "Bossbane")
			self:achieve(event.Creature.Hitters, "Hunter")
			event.Finished = true
			for _, record in self:inRegion(region) do
				self.Effects:FireClient(
					record.Player,
					"Objective",
					{ Kind = "Complete", Title = event.Title, Text = "The guardian is defeated!" }
				)
			end
		elseif result == "Fell" then
			event.Finished = true
		end
	end
	if event.Activity and (event.Activity.Done or event.Activity.Failed) then
		event.Finished = true
	end
end
-- Storm shelters: storms tear breaches in house windows. Unpatched breaches leak storm damage
-- to occupants. Generators (realm repairs) fortify shelters and heal those inside.
function Service:stormStart(now)
	for _, region in self.World.Islands do
		if #self:inRegion(region) > 0 and not region.ShelterPowered then
			local rng = region.EventState and region.EventState.Rng or Random.new(region.Index)
			for _, zone in region.Shelters do
				if zone.Name == "House" and zone.Anchor.Parent and #(zone.Breaches or {}) > 0 then
					zone.Open = {}
					local first = rng:integer(1, #zone.Breaches)
					for k = 0, rng:integer(0, 1) do
						local cf = zone.Breaches[(first + k * 2 - 1) % #zone.Breaches + 1]
						local local_ = cf.Position - region.Center
						local spec =
							region.Prompt("Breach", local_.X, local_.Z, "Patch storm breach", nil, local_.Y)
						spec = region.Interactions[#region.Interactions]
						spec.Breach, spec.Zone = true, zone
						spec.Prompt.HoldDuration, spec.Prompt.ObjectText = 0.8, "Shelter breach"
						spec.Prompt.MaxActivationDistance = 10
						local hole = spec.Part
						hole.Transparency, hole.Size, hole.Color, hole.Material =
							0, Vector3.new(3.4, 3.6, 0.3), C(30, 30, 36), Enum.Material.Slate
						hole.CFrame = cf * CFrame.new(0, 0, 0.2)
						local gust = Instance.new("ParticleEmitter")
						gust.Texture, gust.Rate = "rbxasset://textures/particles/smoke_main.dds", 6
						gust.Lifetime, gust.Speed = NumberRange.new(0.5, 0.9), NumberRange.new(8, 12)
						gust.Size = NumberSequence.new(0.8, 2)
						gust.Transparency = NumberSequence.new(0.7, 1)
						gust.EmissionDirection, gust.Parent = Enum.NormalId.Back, hole
						if self.Adventure then
							self.Adventure:register(region, spec)
						end
						table.insert(zone.Open, spec)
					end
					zone.Leaking = true
				end
			end
		end
	end
	for _, record in self.Players:active() do
		self.Effects:FireClient(record.Player, "Objective", {
			Kind = "Event",
			Title = "Storm breaches",
			Text = "Gusts tore open shelter windows! Patch breaches (E / X) to keep the storm out.",
		})
	end
	local _ = now
end
function Service:stormEnd()
	for _, region in self.World.Islands do
		for _, zone in region.Shelters do
			for _, spec in zone.Open or {} do
				spec.Prompt.Enabled = false
				if spec.Part.Parent then
					spec.Part.Parent = nil
				end
			end
			zone.Open, zone.Leaking = nil, false
		end
	end
end
function Service:patch(record, region, spec)
	local zone = spec.Zone
	if not spec.Prompt.Enabled then
		return false
	end
	spec.Prompt.Enabled = false
	if spec.Part.Parent then
		spec.Part.Parent = nil
	end
	local open = 0
	for _, other in zone.Open or {} do
		if other.Prompt.Enabled then
			open += 1
		end
	end
	zone.Leaking = open > 0
	record.Patches = (record.Patches or 0) + 1
	self:reward(record, { Coins = 4, XP = 10 }, "Shelter repair")
	self:notice(
		record,
		if open > 0
			then "Breach patched. " .. open .. " more in this shelter."
			else "Shelter sealed! The storm stays outside."
	)
	if record.Patches >= 3 then
		self:achieve(record, "Keeper")
	end
	local _ = region
	return true
end
-- Timber Brace used inside a breached shelter seals all of its breaches at once.
function Service:braceShelter(record, position)
	local sealed = 0
	for _, region in self.World.Islands do
		for _, zone in region.Shelters do
			local d = position - zone.Anchor.Position
			if
				zone.Open
				and math.abs(d.X) < zone.Half.X
				and d.Y > 0
				and d.Y < zone.Half.Y
				and math.abs(d.Z) < zone.Half.Z
			then
				for _, spec in zone.Open do
					if spec.Prompt.Enabled then
						spec.Prompt.Enabled = false
						spec.Part.Parent = nil
						sealed += 1
					end
				end
				zone.Leaking = false
			end
		end
	end
	if sealed > 0 then
		record.Patches = (record.Patches or 0) + sealed
		self:reward(record, { Coins = 3 * sealed, XP = 8 * sealed }, "Timber reinforcement")
		self:notice(
			record,
			"Timber reinforcement sealed " .. sealed .. " breach" .. (if sealed > 1 then "es" else "") .. "."
		)
		if record.Patches >= 3 then
			self:achieve(record, "Keeper")
		end
	end
	return sealed
end
-- Storm damage hook used by WorldEventDirector for sheltered players.
-- Returns damage for a sheltered position: leaks hurt, fortified shelters heal.
function Service:shelterDamage(record, position)
	for _, region in self.World.Islands do
		for _, zone in region.Shelters do
			if zone.Anchor.Parent and zone.Anchor.CanCollide then
				local d = position - zone.Anchor.Position
				if
					math.abs(d.X) < zone.Half.X
					and d.Y > 0
					and d.Y < zone.Half.Y
					and math.abs(d.Z) < zone.Half.Z
				then
					if region.ShelterPowered then
						local _, hum = Common.root(record)
						if hum and hum.Health > 0 then
							hum.Health = math.min(hum.MaxHealth, hum.Health + 4)
						end
						return 0
					end
					return if zone.Leaking then 3 else 0
				end
			end
		end
	end
	return 0
end
function Service:hazards(dt)
	for _, region in self.World.Islands do
		for _, hazard in region.Hazards or {} do
			if not hazard.Disabled and hazard.Part.Parent then
				for _, record in Common.near(self, hazard.Part.Position, hazard.Radius + 3) do
					local root = Common.root(record)
					local d = root.Position - hazard.Part.Position
					if Vector3.new(d.X, 0, d.Z).Magnitude < hazard.Radius and d.Y < 4.5 and d.Y > -1 then
						self:hurt(record, hazard.Damage * dt, hazard.Kind)
						if os.clock() > (record.HazardNotice or 0) then
							record.HazardNotice = os.clock() + 3
							self:notice(
								record,
								if hazard.Kind == "Lava"
									then "Magma burns! Get out (Aegis absorbs the heat)."
									else "The void pool drains you! Step away."
							)
						end
					end
				end
			end
		end
	end
end
function Service:discover(region)
	for _, act in region.Activities do
		if act.Hidden and not act.Discovered and act.Site then
			local site = region.Center + Vector3.new(act.Site.X, 0, act.Site.Z)
			for _, record in Common.near(self, site, act.RevealRadius or 40) do
				act.Discovered = true
				for _, other in self:inRegion(region) do
					self.Effects:FireClient(other.Player, "Objective", {
						Kind = "Discovered",
						Title = act.Title,
						Text = "Secret discovered by " .. record.Player.DisplayName .. "!",
					})
				end
				break
			end
		end
	end
end
function Service:tick(dt)
	local now = os.clock()
	local events = self.Events
	local storming = events and events.Name == "Storm" and events.Phase == "Active"
	if storming and not self.Storming then
		self:stormStart(now)
	elseif not storming and self.Storming then
		self:stormEnd()
	end
	self.Storming = storming
	self.HazardAccum += dt
	if self.HazardAccum >= 0.5 then
		self:hazards(self.HazardAccum)
		self.HazardAccum = 0
	end
	for _, region in self.World.Islands do
		if region.Activated then
			for _, act in region.Activities or {} do
				if not act.Failed then
					local m = module(act.Type)
					if m and m.update then
						m.update(self, act, dt, now)
					end
				end
			end
			self:discover(region)
			self:schedule(region, now)
			local active = region.EventState and region.EventState.Active
			if active then
				self:updateEvent(region, active, dt, now)
			end
		end
	end
end
function Service:reset()
	self.Storming = false
end
-- Run end: unspent relics convert to coins/XP and count toward the lifetime relic total.
function Service:finish(record)
	local relics = record.Bag and record.Bag.Relic or 0
	if relics > 0 then
		local profile = self:profile(record)
		if profile then
			profile.Coins += relics * Objectives.RelicValue.Coins
			profile.XP += relics * Objectives.RelicValue.XP
			profile.Relics = (profile.Relics or 0) + relics
		end
		record.BonusCoins = (record.BonusCoins or 0) + relics * Objectives.RelicValue.Coins
		record.Bag.Relic = 0
	end
end
-- Shrine blessing: spend relics for a random perk (a real choice versus cashing them out).
function Service:blessing(record)
	local cost = Objectives.RelicBlessing
	if not record.Bag or (record.Bag.Relic or 0) < cost then
		return false
	end
	record.Bag.Relic -= cost
	self:perk(record, "Shrine blessing")
	return true
end
-- Snapshot view of the player's current realm objectives.
function Service:status(record)
	local region = self.World.Islands[record.Region]
	if not region or record.State ~= "Alive" then
		return nil
	end
	local root = Common.root(record)
	local list = {}
	local compass = record.Perks and record.Perks.Compass
	for _, act in region.Activities do
		local hidden = act.Hidden and not act.Discovered and not compass
		local m = module(act.Type)
		local distance
		if root and act.Site and not hidden then
			distance = math.floor(
				(root.Position - (region.Center + Vector3.new(act.Site.X, 0, act.Site.Z))).Magnitude
			)
		elseif root and act.Model and act.Model.Parent then
			distance = math.floor((root.Position - act.Model:GetPivot().Position).Magnitude)
		end
		local mine = (act.Type == "Cache" or act.Type == "Survey")
			and act.Claims
			and act.Claims[record.Player.UserId]
		table.insert(list, {
			Id = act.Id,
			Type = act.Type,
			Title = if hidden then "Hidden secret" else act.Title,
			Hint = if hidden
				then "Something valuable is hidden in this realm. Explore its edges."
				else act.Hint,
			Progress = if hidden then "?" else (m and m.status(act, record) or ""),
			Done = if act.Type == "Cache" or act.Type == "Survey" then mine == true else act.Done,
			Failed = act.Failed == true,
			Hidden = hidden,
			Distance = distance,
			Mine = act.Participants[record] == true,
		})
	end
	local event = region.EventState and region.EventState.Active
	local perks = {}
	for _, id in Objectives.PerkOrder do
		if record.Perks and record.Perks[id] then
			table.insert(perks, Objectives.Perks[id].Name)
		end
	end
	local carrying = false
	for _, act in region.Activities do
		if act.Type == "Artifacts" and module("Artifacts").carrying(act, record) then
			carrying = true
		end
	end
	return {
		Region = region.Model:GetAttribute("RegionName"),
		Main = Objectives.Main,
		TimeLeft = math.max(0, math.floor(remaining(region))),
		Activities = list,
		Event = if event
			then {
				Title = event.Title,
				Text = event.Text,
				Remaining = math.max(0, math.floor(event.Until - os.clock())),
			}
			else nil,
		Perks = perks,
		Relics = record.Bag and record.Bag.Relic or 0,
		Carrying = carrying,
		Breaches = self.Storming == true,
	}
end
return Service
