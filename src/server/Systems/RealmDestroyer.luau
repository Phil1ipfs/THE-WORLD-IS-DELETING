--!nonstrict
-- The Realm Destroyer: one server-owned world boss shared by every player in the round.
--   Omen      (Sky Grasslands)   a distant silhouette circling the frontier, with roars.
--   Raid      (Crystal Kingdom, and later non-encounter regions) it flies in, marks ground far
--             from every player, then burns it away (cells crack and fall; flames linger).
--   Encounter (first region of the Floating Jungle and every later realm) fight or escape:
--             telegraphed Fire Breath, Dive, Wing Gust and Ground Slam (+ Ember Rain and Inferno
--             Sweep in later tiers). Weak points glow during attack windows; Dragonbane weapons
--             (crossbow, ballista, crystal cannon) and dashes into its stunned head deal damage.
--             Repel it for rewards, or reach the Sky Balloon/causeway before the realm is razed.
-- All damage, cooldowns, targeting and rewards are server-side. Clients only render the state
-- published on ReplicatedStorage.RealmDestroyer (attributes) and the telegraph parts below.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dragon = require(Shared.DragonConfig)
local Rig = require(Shared.DragonRig)
local Game = require(Shared.GameConfig)
local Random = require(Shared.Random)
local Common = require(script.Parent.Activities.Common)
local Armory = require(script.Parent.Parent.Services.DragonArmory)
local G = require(script.Parent.Parent.Services.Geometry)
local Director = {}
Director.__index = Director
local C = Color3.fromRGB
local FIRE, WARN, WIND = C(255, 96, 40), C(255, 60, 50), C(200, 235, 255)
local causeway = { SkyCauseway = true, CausewayApproach = true, CausewayArrival = true }
local function v3(p)
	return Vector3.new(p.X, p.Y, p.Z)
end
-- World-space hit spheres { [name] = { position, radius } } for a pose and action.
local function points(pose, action)
	local out = {}
	for name, s in Rig.spheres(action) do
		out[name] = { pose * Vector3.new(s.X, s.Y, s.Z), s.R }
	end
	return out
end
local function mouth(pose, action)
	return pose * v3(Rig.mouth(action))
end
function Director.new(world, players, effects, objectives, data)
	local self = setmetatable({
		World = world,
		Players = players,
		Effects = effects,
		Svc = objectives,
		Data = data,
		Regions = {},
		Patches = {},
		Burning = {},
		Crossbow = {},
		Harpoons = {},
		Pose = CFrame.new(0, 2000, 0),
		Yaw = 0,
		Pitch = 0,
		Roll = 0,
		Mode = "Hidden",
		Action = "Fly",
		Phase = "",
		Exposed = "",
		Aim = Vector3.zero,
		Orbit = 0,
		BurnAccum = 0,
		StatusAccum = 0,
	}, Director)
	local state = ReplicatedStorage:FindFirstChild("RealmDestroyer") or Instance.new("Folder")
	state.Name = "RealmDestroyer"
	state.Parent = ReplicatedStorage
	self.State = state
	self:reset()
	return self
end
-- Helpers --------------------------------------------------------------------------------
local function horizontal(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function unitFlat(v, fallback)
	local h = horizontal(v)
	return if h.Magnitude > 1e-3 then h.Unit else (fallback or Vector3.new(0, 0, -1))
end
function Director:groundY(region, position)
	local offset = position - region.Center
	return region.Center.Y + Common.height(region, offset.X, offset.Z)
end
function Director:notice(record, text)
	self.Effects:FireClient(record.Player, "Notice", text)
end
function Director:present(region)
	local list = {}
	for _, record in self.Players:active() do
		if record.Region == region.Index and not record.Transit then
			local root, hum = Common.root(record)
			if root and hum and hum.Health > 0 and (root.Position - region.Center).Magnitude < 320 then
				table.insert(list, record)
			end
		end
	end
	return list
end
function Director:profile(record)
	return self.Data and self.Data:get(record.Player)
end
-- Persistent bestiary discovery for the Realm Destroyer (1 sighted .. 4 repelled).
function Director:discover(record, stage)
	local profile = self:profile(record)
	if not profile then
		return
	end
	profile.Bestiary = profile.Bestiary or {}
	if (profile.Bestiary[Dragon.Id] or 0) < stage then
		profile.Bestiary[Dragon.Id] = stage
		self.Effects:FireClient(record.Player, "Bestiary", {
			Id = Dragon.Id,
			Name = Dragon.Name,
			Stage = stage,
			Of = #Dragon.Discovery,
			Text = Dragon.Discovery[stage],
		})
	end
end
-- Region bookkeeping ---------------------------------------------------------------------
function Director:attach(region)
	local stage, tier = Dragon.stage(region.Index, Game.RegionRise, Armory.preview())
	local st = { Stage = stage, Tier = tier, Raids = 0, Armory = region.Armory }
	self.Regions[region] = st
	local armory = region.Armory
	if armory and armory.Ballista then
		armory.Ballista.State, armory.Ballista.Repair = "Broken", 0
	end
	if armory and armory.Cannon then
		armory.Cannon.State = "Ready"
	end
	self:labels(region)
end
function Director:detach(region)
	local e = self.Encounter
	if e and e.Region == region then
		self:finish("Lost")
	end
	if self.Raid and self.Raid.Region == region then
		self:clearMarkers(self.Raid)
		self.Raid = nil
	end
	for i = #self.Patches, 1, -1 do
		if self.Patches[i].Region == region then
			table.remove(self.Patches, i)
		end
	end
	self.Regions[region] = nil
end
function Director:reset()
	if self.Encounter then
		self:clearMarkers(self.Encounter)
	end
	if self.Raid then
		self:clearMarkers(self.Raid)
	end
	for _, patch in self.Patches do
		if patch.Part.Parent then
			patch.Part:Destroy()
		end
	end
	self.Encounter, self.Raid, self.Departing = nil, nil, nil
	table.clear(self.Patches)
	table.clear(self.Burning)
	table.clear(self.Crossbow)
	table.clear(self.Harpoons)
	table.clear(self.Regions)
	self.Mode, self.Action, self.Phase, self.Exposed = "Hidden", "Fly", "", ""
	self.Pose = CFrame.new(0, 2000, 0)
	self.Rng = Random.new((self.World.Seed or 0) + 9311)
	self.NextRoar, self.Pause = os.clock() + 12, 0
	self:publish()
end
function Director:rebase(amount)
	local shift = Vector3.new(0, amount, 0)
	self.Pose -= shift
	self.Aim -= shift
end
-- Telegraph markers (server parts in the region model; non-colliding, non-queryable) --------
local function markerPart(region, cf, size, color, transparency, shape)
	local p = G.part(region.Model, "DragonTelegraph", size, cf, color, Enum.Material.Neon, false)
	p.CanQuery, p.CastShadow = false, false
	p.Transparency = transparency or 0.6
	if shape then
		p.Shape = Enum.PartType[shape]
	end
	return p
end
function Director:clearMarkers(holder)
	for _, p in holder.Markers or {} do
		if p.Parent then
			p:Destroy()
		end
	end
	holder.Markers = {}
end
-- Flat disc at a world position (ground height supplied).
function Director:disc(holder, region, position, radius, color, transparency)
	local p = markerPart(
		region,
		CFrame.new(position.X, position.Y + 0.25, position.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.2, radius * 2, radius * 2),
		color,
		transparency,
		"Cylinder"
	)
	holder.Markers = holder.Markers or {}
	table.insert(holder.Markers, p)
	return p
end
-- Flat strip from a to b (ground plane) of a given width.
function Director:strip(holder, region, a, b, width, color, transparency)
	local length = (horizontal(b - a)).Magnitude
	if length < 0.5 then
		return nil
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, a.Y + 0.3, mid.Z), Vector3.new(b.X, a.Y + 0.3, b.Z))
	local p = markerPart(region, cf, Vector3.new(width, 0.2, length), color, transparency)
	holder.Markers = holder.Markers or {}
	table.insert(holder.Markers, p)
	return p
end
-- Cone (or arc) on the ground: stepped slabs plus bright edge lines.
function Director:fan(holder, region, apex, axis, length, halfAngle, color)
	local steps = 4
	for k = 0, steps - 1 do
		local d0, d1 = length * k / steps, length * (k + 1) / steps
		local mid = (d0 + d1) / 2
		local width = math.max(2, 2 * math.tan(halfAngle) * mid)
		self:strip(holder, region, apex + axis * d0, apex + axis * d1, width, color, 0.62)
	end
	for _, side in { -1, 1 } do
		local dir = CFrame.Angles(0, side * halfAngle, 0):VectorToWorldSpace(axis)
		self:strip(holder, region, apex, apex + dir * length, 0.6, color, 0.2)
	end
end
-- Damage helpers -------------------------------------------------------------------------
local rayParams
-- First solid obstruction between two points, or nil when clear. Characters never block;
-- prompt anchors and other non-colliding parts are skipped. Ground blocks only when asked
-- (shots through islands), never for cover (walls, rock and roofs are cover; floors are not).
function Director:obstruction(from, to, extraIgnore, groundBlocks)
	local delta = to - from
	if delta.Magnitude < 0.5 then
		return nil
	end
	rayParams = rayParams or RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local characters = {}
	for _, other in self.Players.Records do
		if other.Player.Character then
			table.insert(characters, other.Player.Character)
		end
	end
	local ignore = table.clone(characters)
	for _, p in extraIgnore or {} do
		table.insert(ignore, p)
	end
	for _ = 1, 4 do
		rayParams.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(from, delta, rayParams)
		if not hit then
			return nil
		end
		local part = hit.Instance
		for _, character in characters do
			if part:IsDescendantOf(character) then
				return nil
			end
		end
		if part.CanCollide and (groundBlocks or not part:GetAttribute("Ground")) then
			return part
		end
		table.insert(ignore, part)
	end
	return nil
end
function Director:covered(from, record)
	local root = Common.root(record)
	if not root then
		return true
	end
	local delta = root.Position - from
	return self:obstruction(from, root.Position - delta.Unit * 1.5, nil, false) ~= nil
end
function Director:hurt(record, amount, source, burn)
	local e = self.Encounter
	local scale = if e then e.Def.Damage else 1
	self.Svc:hurt(record, math.floor(amount * scale + 0.5), source)
	if burn then
		self.Burning[record] = os.clock() + Dragon.Burning.Duration
	end
end
function Director:grounded(record)
	local _, hum = Common.root(record)
	return hum ~= nil and hum.FloorMaterial ~= Enum.Material.Air
end
function Director:patch(region, position)
	if not Common.support(region, position.X - region.Center.X, position.Z - region.Center.Z) then
		return
	end
	local cfg = Dragon.FirePatch
	while #self.Patches >= cfg.Max do
		local old = table.remove(self.Patches, 1)
		if old.Part.Parent then
			old.Part:Destroy()
		end
	end
	local y = self:groundY(region, position)
	local p = markerPart(
		region,
		CFrame.new(position.X, y + 0.2, position.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Vector3.new(0.3, cfg.Radius * 2, cfg.Radius * 2),
		C(255, 120, 40),
		0.35,
		"Cylinder"
	)
	p.Name = "DragonFire"
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 9, 12, C(255, 120, 40), C(255, 210, 90)
	fire.Parent = p
	table.insert(self.Patches, {
		Part = p,
		Region = region,
		Local = Vector3.new(position.X, y, position.Z) - region.Center,
		Until = os.clock() + cfg.Lifetime,
	})
end
-- Ground the dragon never burns directly: Dragonbane equipment and the Sky Balloon station.
function Director:protected(region)
	local protected = {}
	for _, entry in pairs(region.Armory or {}) do
		if type(entry) == "table" and entry.Ground then
			protected[entry.Ground] = true
		end
	end
	if region.Balloon and region.Sites then
		local p = region.Balloon.Local.Position
		for _, offset in
			{
				Vector3.zero,
				Vector3.new(8, 0, 0),
				Vector3.new(-8, 0, 0),
				Vector3.new(0, 0, 8),
				Vector3.new(0, 0, -8),
			}
		do
			local entry = region.Sites:at(p.X + offset.X, p.Z + offset.Z)
			if entry then
				protected[entry.Cell.Part] = true
			end
		end
	end
	return protected
end
-- Cells cracked by dragon attacks (never refuges, the causeway, the landing or equipment).
function Director:scorch(region, position, count, minDistance)
	if count <= 0 then
		return 0
	end
	local protected = self:protected(region)
	local candidates = {}
	for _, cell in region.Cells do
		local p = cell.Part
		if
			cell.State == "Stable"
			and not cell.Late
			and p.Parent
			and p.CanCollide
			and not causeway[p.Name]
			and not protected[p]
		then
			local d = horizontal(p.Position - position).Magnitude
			if d >= (minDistance or 0) then
				table.insert(candidates, { Cell = cell, D = d })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.D < b.D
	end)
	local now = os.clock()
	for i = 1, math.min(count, #candidates) do
		self.World:warnCell(region, candidates[i].Cell, now, "Dragon")
	end
	return math.min(count, #candidates)
end
-- Pose control ---------------------------------------------------------------------------
function Director:steer(goal, face, speed, dt, turn)
	local position = self.Pose.Position
	local delta = goal - position
	local step = math.min(delta.Magnitude, speed * dt)
	if delta.Magnitude > 1e-3 then
		position += delta.Unit * step
	end
	local look = (face or goal) - position
	local flat = horizontal(look)
	if flat.Magnitude > 0.5 then
		local yaw = math.atan2(-flat.X, -flat.Z)
		local diff = (yaw - self.Yaw + math.pi) % (2 * math.pi) - math.pi
		local rate = (turn or 2.4) * dt
		local change = math.clamp(diff, -rate, rate)
		self.Yaw += change
		self.Roll += (math.clamp(-change / math.max(dt, 1e-3) * 0.35, -0.55, 0.55) - self.Roll) * math.min(
			1,
			dt * 4
		)
	end
	local pitch = if look.Magnitude > 1 then math.asin(math.clamp(look.Unit.Y, -1, 1)) else 0
	self.Pitch += (math.clamp(pitch, -1.05, 0.5) - self.Pitch) * math.min(1, dt * 5)
	self.Pose = CFrame.new(position) * CFrame.Angles(0, self.Yaw, 0) * CFrame.Angles(self.Pitch, 0, self.Roll)
	return delta.Magnitude - step
end
function Director:snapFace(point)
	local flat = horizontal(point - self.Pose.Position)
	if flat.Magnitude > 0.5 then
		self.Yaw = math.atan2(-flat.X, -flat.Z)
	end
	self.Pose = CFrame.new(self.Pose.Position)
		* CFrame.Angles(0, self.Yaw, 0)
		* CFrame.Angles(self.Pitch, 0, 0)
end
function Director:publish()
	local s = self.State
	local e = self.Encounter
	s:SetAttribute("Visible", self.Mode ~= "Hidden")
	s:SetAttribute("Mode", self.Mode)
	s:SetAttribute("Action", self.Action)
	s:SetAttribute("Phase", self.Phase)
	s:SetAttribute("Exposed", self.Exposed)
	s:SetAttribute("Pose", self.Pose)
	s:SetAttribute("Aim", self.Aim)
	s:SetAttribute("HP", if e then math.max(0, math.ceil(e.HP)) else 0)
	s:SetAttribute("MaxHP", if e then e.MaxHP else 0)
	s:SetAttribute("Tier", if e then e.Tier else 0)
	s:SetAttribute("Region", if e then e.Region.Index elseif self.Raid then self.Raid.Region.Index else -1)
	s:SetAttribute("Attack", if e and e.Attack then Dragon.Attacks[e.Attack].Label else "")
end
-- Focus: the highest region with a living explorer.
function Director:focus()
	local best
	for _, record in self.Players:active() do
		local region = self.World.Islands[record.Region]
		if region and (not best or region.Index > best.Index) then
			best = region
		end
	end
	return best
end
-- Ambient flight (omen silhouette, or between raids) --------------------------------------
function Director:ambient(region, dt, now)
	local st = self.Regions[region]
	local omen = not st or st.Stage == "Omen"
	local cfg = Dragon.Omen
	local radius = if omen then cfg.Radius else cfg.Radius * 0.8
	local height = if omen then cfg.Height else cfg.Height * 0.75
	if self.Mode == "Hidden" then
		self.Orbit = self.Rng:range(0, math.pi * 2)
		local start = region.Center
			+ Vector3.new(math.cos(self.Orbit) * radius, height, math.sin(self.Orbit) * radius)
		self.Pose = CFrame.new(start)
	end
	self.Mode, self.Action, self.Phase, self.Exposed = "Ambient", "Fly", "", ""
	self.Orbit += cfg.Speed / radius * dt
	local a = self.Orbit
	local goal = region.Center
		+ Vector3.new(math.cos(a) * radius, height + math.sin(now * 0.3) * 18, math.sin(a) * radius)
	local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
	self:steer(goal, goal + tangent * 40, cfg.Speed * 3, dt, 1.2)
	if now >= self.NextRoar then
		self.NextRoar = now + self.Rng:range(cfg.RoarMin, cfg.RoarMax)
		self.Effects:FireAllClients(
			"Dragon",
			{ Kind = "Roar", Position = self.Pose.Position, Distant = true }
		)
		for _, record in self.Players:active() do
			self:discover(record, 1)
		end
	end
end
-- Raids ----------------------------------------------------------------------------------
function Director:startRaid(region, st, now)
	local cfg = Dragon.Raid
	local positions = {}
	for _, record in self.Players:active() do
		local root = Common.root(record)
		if root then
			table.insert(positions, root.Position)
		end
	end
	local function safe(p)
		for _, q in positions do
			if horizontal(p - q).Magnitude < cfg.SafeDistance then
				return false
			end
		end
		return true
	end
	local protected = self:protected(region)
	local best, bestScore
	for _, cell in region.Cells do
		local p = cell.Part
		if
			cell.State == "Stable"
			and not cell.Late
			and p.Parent
			and p.CanCollide
			and string.sub(p.Name, 1, 6) == "Earth_"
			and not protected[p]
			and safe(p.Position)
		then
			local score = cell.Edge + (if p.Name ~= "Earth_Mainland" then 0.5 else 0) + self.Rng:range(0, 0.3)
			if not best or score > bestScore then
				best, bestScore = cell, score
			end
		end
	end
	if not best then
		st.NextRaid = now + 15
		return
	end
	local count = cfg.Cells[math.clamp(st.Tier, 1, #cfg.Cells)]
	local targets = { best }
	local list = {}
	for _, cell in region.Cells do
		local p = cell.Part
		if
			cell ~= best
			and cell.State == "Stable"
			and not cell.Late
			and p.Parent
			and p.CanCollide
			and string.sub(p.Name, 1, 6) == "Earth_"
			and not protected[p]
			and safe(p.Position)
		then
			local d = horizontal(p.Position - best.Part.Position).Magnitude
			if d < 40 then
				table.insert(list, { Cell = cell, D = d })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.D < b.D
	end)
	for i = 1, math.min(count - 1, #list) do
		table.insert(targets, list[i].Cell)
	end
	local center = Vector3.zero
	for _, cell in targets do
		center += cell.Part.Position
	end
	center /= #targets
	local away = unitFlat(center - region.Center, Vector3.new(1, 0, 0))
	st.Raids += 1
	st.NextRaid = now + self.Rng:range(cfg.IntervalMin, cfg.IntervalMax)
	self.Raid = {
		Region = region,
		Targets = targets,
		Local = center - region.Center,
		Hover = center - region.Center + away * 40 + Vector3.new(0, 52, 0),
		Exit = away,
		Phase = "Approach",
		PhaseAt = now,
		Markers = {},
	}
end
function Director:raid(dt, now)
	local raid = self.Raid
	local region = raid.Region
	local center = region.Center + raid.Local
	local hover = region.Center + raid.Hover
	self.Mode = "Raid"
	self.Aim = center
	if raid.Phase == "Approach" then
		self.Action, self.Phase, self.Exposed = "Fly", "", ""
		local left = self:steer(hover, center, 120, dt, 2)
		if left < 4 or now - raid.PhaseAt > 12 then
			raid.Phase, raid.PhaseAt = "Telegraph", now
			for _, cell in raid.Targets do
				if cell.Part.Parent then
					local top = cell.Part.Position + Vector3.new(0, cell.Part.Size.Y / 2, 0)
					self:disc(raid, region, top, 12, FIRE, 0.45)
				end
			end
			self.Effects:FireAllClients("Dragon", { Kind = "Roar", Position = self.Pose.Position })
			for _, record in self:present(region) do
				self:notice(
					record,
					"The Realm Destroyer is about to burn distant ground. Stay clear of the glow!"
				)
			end
		end
	elseif raid.Phase == "Telegraph" then
		self.Action, self.Phase = "Breath", "Windup"
		self:steer(hover, center, 20, dt, 3)
		if now - raid.PhaseAt >= Dragon.Raid.Telegraph then
			raid.Phase, raid.PhaseAt = "Strike", now
			self:clearMarkers(raid)
			for _, cell in raid.Targets do
				if cell.State == "Stable" and cell.Part.Parent then
					self.World:warnCell(region, cell, now, "Dragon")
				end
			end
			for i, cell in raid.Targets do
				if i <= 2 and cell.Part.Parent then
					self:patch(region, cell.Part.Position)
				end
			end
			self.Effects:FireAllClients("Dragon", { Kind = "Strike", Position = center, Radius = 26 })
			for _, record in self:present(region) do
				self:discover(record, 2)
			end
		end
	elseif raid.Phase == "Strike" then
		self.Action, self.Phase = "Breath", "Active"
		self:steer(hover, center, 10, dt, 3)
		if now - raid.PhaseAt >= 1.6 then
			raid.Phase, raid.PhaseAt = "Depart", now
		end
	else
		self.Action, self.Phase = "Fly", ""
		local exit = hover + raid.Exit * 500 + Vector3.new(0, 140, 0)
		local left = self:steer(exit, exit, Dragon.Raid.Speed * 1.4, dt, 1.5)
		if left < 10 or now - raid.PhaseAt > 9 then
			self:clearMarkers(raid)
			self.Raid = nil
		end
	end
end
-- Encounters -----------------------------------------------------------------------------
function Director:startEncounter(region, st, now)
	st.Done = true
	local def = Dragon.Tiers[math.clamp(st.Tier, 1, #Dragon.Tiers)]
	local fighters = self:present(region)
	local scale = 1 + Dragon.PlayerScaling * (math.clamp(#fighters, 1, Dragon.MaxScaledPlayers) - 1)
	local hp = math.floor(def.HP * scale)
	if self.Raid then
		self:clearMarkers(self.Raid)
		self.Raid = nil
	end
	self.Encounter = {
		Region = region,
		Tier = st.Tier,
		Def = def,
		HP = hp,
		MaxHP = hp,
		RazeAt = now + def.RazeAfter,
		State = "Approach",
		StateAt = now,
		Damage = {},
		Seen = {},
		Escaped = {},
		Markers = {},
		LastDash = {},
		Order = 0,
		TargetTurn = 0,
		EmptySince = nil,
	}
	local name = region.Model:GetAttribute("RegionName")
	for _, record in fighters do
		self.Encounter.Seen[record] = true
		self:discover(record, 3)
		self.Effects:FireClient(record.Player, "Dragon", {
			Kind = "Encounter",
			Tier = st.Tier,
			Region = name,
			RazeIn = def.RazeAfter,
		})
		self:notice(
			record,
			"THE REALM DESTROYER descends! Fight with Dragonbane weapons, or board the Sky Balloon before "
				.. name
				.. " burns."
		)
	end
end
function Director:pickTarget(e)
	local list = self:present(e.Region)
	if #list == 0 then
		return nil
	end
	e.TargetTurn += 1
	local record = list[(e.TargetTurn - 1) % #list + 1]
	return record, Common.root(record)
end
function Director:nextAttack(e)
	local attacks = e.Def.Attacks
	e.Order = e.Order % #attacks + 1
	local kind = attacks[e.Order]
	-- Shuffle lightly so the order is learnable but not fixed.
	if self.Rng:next() < 0.35 then
		e.Order = e.Order % #attacks + 1
		kind = attacks[e.Order]
	end
	return kind
end
function Director:telegraph(e, kind)
	return math.max(Dragon.MinTelegraph, Dragon.Attacks[kind].Windup * e.Def.Telegraph)
end
function Director:setState(e, state, now)
	e.State, e.StateAt = state, now
end
function Director:beginAttack(e, now)
	local record, root = self:pickTarget(e)
	if not record then
		return false
	end
	local kind = self:nextAttack(e)
	local region = e.Region
	local cfg = Dragon.Attacks[kind]
	local target = root.Position
	local ground = Vector3.new(target.X, self:groundY(region, target), target.Z)
	local away = unitFlat(target - region.Center, unitFlat(self.Pose.Position - target))
	e.Attack, e.Target, e.Hits = kind, record, {}
	e.ApexLocal, e.Axis, e.Interrupted, e.Stunned, e.Impacted = nil, nil, false, false, false
	e.Pinned = false
	self:clearMarkers(e)
	if kind == "FireBreath" or kind == "InfernoSweep" then
		e.Hover = ground - region.Center + away * 68 + Vector3.new(0, 26, 0)
		e.AimLocal = ground - region.Center
		self:setState(e, "Move", now)
	elseif kind == "WingGust" then
		e.Hover = ground - region.Center + away * 52 + Vector3.new(0, 14, 0)
		e.AimLocal = ground - region.Center
		self:setState(e, "Move", now)
	elseif kind == "Dive" then
		e.Hover = ground - region.Center + Vector3.new(0, 72, 0)
		self:setState(e, "Climb", now)
	elseif kind == "GroundSlam" then
		-- Land where the fighters are, on intact supported ground.
		local sum, n = Vector3.zero, 0
		for _, other in self:present(region) do
			local r = Common.root(other)
			if r then
				sum += r.Position - region.Center
				n += 1
			end
		end
		local mean = if n > 0 then sum / n else Vector3.zero
		local best
		for ring = 0, 4 do
			for k = 0, 7 do
				local a = k * math.pi / 4
				local x, z = mean.X + math.cos(a) * ring * 10, mean.Z + math.sin(a) * ring * 10
				local ok = Common.support(region, x, z) ~= nil
				for j = 0, 3 do
					local b = j * math.pi / 2
					ok = ok and Common.support(region, x + math.cos(b) * 10, z + math.sin(b) * 10) ~= nil
				end
				if ok then
					best = Vector3.new(x, Common.height(region, x, z), z)
					break
				end
			end
			if best then
				break
			end
		end
		best = best or Vector3.new(0, 0, 0)
		e.Land = best
		local world = region.Center + best
		self:disc(e, region, world, cfg.Radius, FIRE, 0.75)
		self:disc(e, region, world + Vector3.new(0, 0.05, 0), cfg.Crush, WARN, 0.45)
		self:setState(e, "Windup", now)
	elseif kind == "EmberRain" then
		e.Hover = Vector3.new(0, 74, 0)
		e.Points = {}
		local fighters = self:present(region)
		for i = 1, cfg.Count do
			local anchor = fighters[(i - 1) % math.max(1, #fighters) + 1]
			local r = anchor and Common.root(anchor)
			local base = if r then r.Position else region.Center
			local offset = if i <= #fighters
				then Vector3.zero
				else Vector3.new(self.Rng:range(-16, 16), 0, self.Rng:range(-16, 16))
			local p = base + offset
			p = Vector3.new(p.X, self:groundY(region, p), p.Z)
			table.insert(e.Points, p - region.Center)
			self:disc(e, region, p, cfg.Radius, FIRE, 0.5)
		end
		self.Effects:FireAllClients("Dragon", {
			Kind = "Meteors",
			Points = (function()
				local list = {}
				for _, p in e.Points do
					table.insert(list, region.Center + p)
				end
				return list
			end)(),
			Delay = self:telegraph(e, kind) + cfg.Active,
		})
		self:setState(e, "Windup", now)
	end
	return true
end
-- Apex/axis for breath attacks in world space (ground plane at the aim height).
function Director:breathFrame(e)
	local region = e.Region
	local aim = region.Center + e.AimLocal
	if e.ApexLocal then
		return region.Center + e.ApexLocal, e.Axis, aim
	end
	local breath = mouth(self.Pose, "Breath")
	local apex = Vector3.new(breath.X, aim.Y, breath.Z)
	return apex, unitFlat(aim - apex), aim
end
function Director:armorySmash(e, position, radius)
	local ballista = e.Region.Armory and e.Region.Armory.Ballista
	if ballista and ballista.State ~= "Broken" and ballista.State ~= "Smashed" then
		local p = ballista.Spec.Part.Position
		if horizontal(p - position).Magnitude <= radius then
			ballista.State, ballista.Repair = "Smashed", 0
			self:labels(e.Region)
			for _, record in self:present(e.Region) do
				self:notice(record, "The Realm Destroyer smashed the ballista! Mend it with 2 timber.")
			end
		end
	end
end
function Director:fight(dt, now)
	local e = self.Encounter
	local region = e.Region
	local present = self:present(region)
	self.Mode = "Encounter"
	-- Escapes: fighters who left for a higher region forfeit rewards (and are told so).
	for record in e.Seen do
		if not e.Escaped[record] and record.State == "Alive" and record.Region > region.Index then
			e.Escaped[record] = true
			self.Effects:FireClient(record.Player, "Dragon", { Kind = "Escaped" })
			self:notice(record, "You escaped the Realm Destroyer. No boss rewards this time.")
		end
	end
	for _, record in present do
		if not e.Seen[record] then
			e.Seen[record] = true
			self:discover(record, 3)
		end
	end
	if #present == 0 then
		e.EmptySince = e.EmptySince or now
		if now - e.EmptySince > 6 then
			self:raze(e, "Escaped")
			return
		end
	else
		e.EmptySince = nil
	end
	if now >= e.RazeAt then
		self:raze(e, "Razed")
		return
	end
	-- Gust Dash into the stunned head (the only melee that works).
	if self.Exposed == "Head" then
		local head = points(self.Pose, self.Action).Head[1]
		for _, record in present do
			local root = Common.root(record)
			local dashing = now < (record.DashUntil or 0) and record.DashSerial ~= e.LastDash[record]
			if
				root
				and dashing
				and horizontal(root.Position - head).Magnitude < 10
				and math.abs(root.Position.Y - head.Y) < 8
			then
				e.LastDash[record] = record.DashSerial
				local boosted = now < (record.OverchargeUntil or 0)
				self:damage(
					record,
					if boosted then Dragon.Weapons.Dash.Boosted else Dragon.Weapons.Dash.Damage,
					"Dash",
					"Head",
					root.Position
				)
				if not self.Encounter then
					return
				end
			end
		end
	end
	local state = e.State
	local orbitCenter = region.Center + Vector3.new(0, Dragon.Orbit.Height, 0)
	local cfg = e.Attack and Dragon.Attacks[e.Attack]
	if state == "Approach" then
		self.Action, self.Phase, self.Exposed = "Fly", "", ""
		local goal = orbitCenter + Vector3.new(Dragon.Orbit.Radius, 0, 0)
		local left = self:steer(goal, region.Center, 150, dt, 2)
		if left < 6 or now - e.StateAt > 8 then
			self:setState(e, "Roar", now)
			self.Effects:FireAllClients("Dragon", { Kind = "Roar", Position = self.Pose.Position })
		end
	elseif state == "Roar" then
		self.Action, self.Phase = "Roar", ""
		self:steer(self.Pose.Position, region.Center, 0, dt, 3)
		if now - e.StateAt >= 1.6 then
			self:setState(e, "Orbit", now)
			e.OrbitFor = self.Rng:range(Dragon.Orbit.Min, Dragon.Orbit.Max) * e.Def.Cadence
		end
	elseif state == "Orbit" then
		self.Action, self.Phase, self.Exposed, e.Attack = "Fly", "", "", nil
		self:clearMarkers(e)
		self.Orbit += 0.42 * dt
		local goal = orbitCenter
			+ Vector3.new(
				math.cos(self.Orbit) * Dragon.Orbit.Radius,
				0,
				math.sin(self.Orbit) * Dragon.Orbit.Radius
			)
		self:steer(goal, goal + Vector3.new(-math.sin(self.Orbit), 0, math.cos(self.Orbit)) * 30, 90, dt, 2)
		if now - e.StateAt >= (e.OrbitFor or 3) then
			if not self:beginAttack(e, now) then
				e.StateAt = now
			end
		end
	elseif state == "Move" then
		self.Action, self.Phase, self.Exposed = "Fly", "", ""
		local hover = region.Center + e.Hover
		local aim = region.Center + e.AimLocal
		-- Fast enough to arrive in under two seconds from anywhere, so cones start where drawn.
		local speed = math.max(95, (hover - self.Pose.Position).Magnitude / 1.6)
		local left = self:steer(hover, aim, speed, dt, 3)
		if left < 4 or now - e.StateAt > 4 then
			self.Pose = CFrame.new(hover) * CFrame.Angles(0, self.Yaw, 0)
			self.Pitch, self.Roll = 0, 0
			self:snapFace(aim)
			self:setState(e, "Windup", now)
			local apex, axis = self:breathFrame(e)
			-- Lock the cone/lane to the drawn telegraph for the rest of the attack.
			e.ApexLocal, e.Axis = apex - region.Center, axis
			if e.Attack == "FireBreath" then
				self:fan(e, region, apex, axis, cfg.Length, cfg.HalfAngle, WARN)
			elseif e.Attack == "InfernoSweep" then
				self:fan(e, region, apex, axis, cfg.Length, cfg.Arc / 2, WARN)
			elseif e.Attack == "WingGust" then
				self:strip(e, region, apex, apex + axis * cfg.Length, cfg.Width, WIND, 0.6)
			end
		end
	elseif state == "Climb" then
		self.Action, self.Phase, self.Exposed = "Fly", "", ""
		local hover = region.Center + e.Hover
		self:steer(hover, hover + Vector3.new(0, -10, 0) + self.Pose.LookVector * 20, 110, dt, 3)
		if now - e.StateAt >= cfg.Climb then
			-- Lock the dive onto the target's current position.
			local root = e.Target and Common.root(e.Target)
			local p = if root then root.Position else region.Center
			local ground = Vector3.new(p.X, self:groundY(region, p), p.Z)
			e.Mark = ground - region.Center
			self:disc(e, region, ground, cfg.Shockwave, FIRE, 0.75)
			self:disc(e, region, ground + Vector3.new(0, 0.05, 0), cfg.Radius, WARN, 0.4)
			self:setState(e, "Windup", now)
		end
	elseif state == "Windup" then
		local windup = self:telegraph(e, e.Attack)
		self.Phase = "Windup"
		local aim = region.Center + (e.AimLocal or Vector3.zero)
		if e.Attack == "FireBreath" then
			self.Action, self.Exposed, self.Aim = "Breath", cfg.Exposes, aim
			self:steer(self.Pose.Position, aim, 0, dt, 3)
		elseif e.Attack == "InfernoSweep" then
			self.Action, self.Exposed = "Sweep", cfg.Exposes
			local apex, axis = self:breathFrame(e)
			self.Aim = apex + CFrame.Angles(0, -cfg.Arc / 2, 0):VectorToWorldSpace(axis) * 40
			self:steer(self.Pose.Position, aim, 0, dt, 3)
		elseif e.Attack == "WingGust" then
			self.Action, self.Exposed, self.Aim = "Gust", cfg.Exposes, aim
			self:steer(self.Pose.Position, aim, 0, dt, 3)
		elseif e.Attack == "Dive" then
			self.Action, self.Exposed = "Dive", ""
			local mark = region.Center + e.Mark
			self.Aim = mark
			self:steer(mark + Vector3.new(0, 70, 0), mark, 30, dt, 4)
		elseif e.Attack == "GroundSlam" then
			self.Action, self.Exposed = "Land", ""
			local land = region.Center + e.Land
			local above = land + Vector3.new(0, Rig.LandHeight + 22, 0)
			self.Aim = land
			self:steer(
				above,
				land + self.Pose.LookVector * 30,
				math.max(60, (above - self.Pose.Position).Magnitude / 1.2),
				dt,
				2
			)
		elseif e.Attack == "EmberRain" then
			self.Action, self.Exposed = "Roar", ""
			self.Aim = region.Center
			self:steer(region.Center + e.Hover, region.Center, 60, dt, 2)
		end
		-- Final warning flash: markers brighten just before the hit.
		if now - e.StateAt >= windup - 0.4 and not e.Flashed then
			e.Flashed = true
			for _, p in e.Markers do
				if p.Parent then
					p.Transparency = math.max(0.15, p.Transparency - 0.3)
				end
			end
		end
		if now - e.StateAt >= windup then
			e.Flashed = false
			self:setState(e, "Active", now)
			e.TickAt = now
			self:activate(e, now)
		end
	elseif state == "Active" then
		self.Phase = "Active"
		self:active(e, dt, now)
		if self.Encounter and now - e.StateAt >= cfg.Active then
			self:clearMarkers(e)
			self:setState(e, "Recover", now)
			self:recoverStart(e, now)
		end
	elseif state == "Recover" then
		self.Phase = "Recover"
		local recover = cfg and cfg.Recover or 2
		if e.Interrupted then
			recover = 2.5
		end
		if e.Attack == "Dive" and e.Stunned then
			self.Action, self.Exposed = "Stunned", "Head"
			self:steer(self.Pose.Position, self.Pose.Position + self.Pose.LookVector * 10, 0, dt, 1)
		elseif e.Attack == "GroundSlam" then
			self.Action, self.Exposed = "Landed", "Wings"
			self:steer(self.Pose.Position, self.Pose.Position + self.Pose.LookVector * 10, 0, dt, 1)
		else
			self.Action = if e.Interrupted then "Stagger" else "Hover"
			self.Exposed = if e.Interrupted then "Heart" elseif cfg then cfg.Exposes else "Heart"
			if e.Attack == "Dive" and not e.Interrupted then
				self.Exposed = ""
			end
			local hover = self.Pose.Position
			self:steer(hover - Vector3.new(0, 6 * dt, 0), self.Aim, 2, dt, 1)
		end
		if now - e.StateAt >= recover then
			e.Interrupted, e.Stunned = false, false
			self:setState(e, "Orbit", now)
			e.OrbitFor = self.Rng:range(Dragon.Orbit.Min, Dragon.Orbit.Max) * e.Def.Cadence
		end
	end
	self:aimTurrets(e)
end
-- One-shot effects when an attack's Active phase begins.
function Director:activate(e, now)
	local region = e.Region
	local kind = e.Attack
	local cfg = Dragon.Attacks[kind]
	if kind == "FireBreath" then
		local apex, axis = self:breathFrame(e)
		for _, d in { 18, 36, 54 } do
			self:patch(region, apex + axis * d)
		end
		self:armorySmash(e, apex + axis * 36, 22)
	elseif kind == "WingGust" then
		local apex, axis = self:breathFrame(e)
		local chest = self.Pose * v3(Rig.Heart)
		self.Effects:FireAllClients("Dragon", {
			Kind = "Gust",
			Position = apex,
			Direction = axis,
			Length = cfg.Length,
			Width = cfg.Width,
		})
		for _, record in self:present(region) do
			local root = Common.root(record)
			local rel = horizontal(root.Position - apex)
			local along = rel:Dot(axis)
			local lateral = math.abs(rel:Dot(Vector3.new(-axis.Z, 0, axis.X)))
			if
				along >= -4
				and along <= cfg.Length
				and lateral <= cfg.Width / 2
				and not self:covered(chest, record)
				and not self.World:sheltered(root.Position)
			then
				record.MovementUntil = now + 1.8
				self.Effects:FireClient(
					record.Player,
					"Knockback",
					{ Velocity = axis * cfg.Push + Vector3.new(0, cfg.Lift, 0) }
				)
				self:hurt(record, cfg.Damage, "Wing Gust")
			end
		end
	elseif kind == "Dive" then
		e.DiveFrom = self.Pose.Position
	elseif kind == "GroundSlam" then
		local land = region.Center + e.Land
		self.Pose = CFrame.new(land + Vector3.new(0, Rig.LandHeight, 0)) * CFrame.Angles(0, self.Yaw, 0)
		self.Pitch, self.Roll = 0, 0
		self.Action = "Landed"
		self.Effects:FireAllClients("Dragon", {
			Kind = "Slam",
			Position = land,
			Radius = cfg.Radius,
			Duration = cfg.Active,
		})
		for _, record in self:present(region) do
			local root = Common.root(record)
			if
				horizontal(root.Position - land).Magnitude <= cfg.Crush
				and math.abs(root.Position.Y - land.Y) < 12
			then
				e.Hits[record] = true
				self:hurt(record, cfg.Damage, "Ground Slam")
			end
		end
		e.Ring = cfg.Crush
		self:armorySmash(e, land, Dragon.Weapons.Ballista.BreakRadius)
		self:scorch(region, land, e.Def.Destruction, cfg.Radius * 0.6)
	elseif kind == "EmberRain" then
		for _, p in e.Points do
			local world = region.Center + p
			for _, record in self:present(region) do
				local root = Common.root(record)
				if
					horizontal(root.Position - world).Magnitude <= cfg.Radius
					and math.abs(root.Position.Y - world.Y) < 10
				then
					self:hurt(record, cfg.Damage, "Ember Rain", true)
				end
			end
			self:patch(region, world)
			self:armorySmash(e, world, cfg.Radius)
		end
		self.Effects:FireAllClients(
			"Dragon",
			{ Kind = "Impact", Position = region.Center + e.Points[1], Radius = cfg.Radius }
		)
	elseif kind == "InfernoSweep" then
		local apex, axis = self:breathFrame(e)
		e.SweepApex, e.SweepAxis = apex - region.Center, axis
	end
	local _ = now
end
-- Continuous damage during Active phases.
function Director:active(e, dt, now)
	local region = e.Region
	local kind = e.Attack
	local cfg = Dragon.Attacks[kind]
	local t = now - e.StateAt
	if kind == "FireBreath" then
		self.Action = "Breath"
		local apex, axis, aim = self:breathFrame(e)
		self.Aim = aim
		if now >= e.TickAt then
			e.TickAt = now + cfg.Tick
			local breath = mouth(self.Pose, "Breath")
			for _, record in self:present(region) do
				local root = Common.root(record)
				local rel = horizontal(root.Position - apex)
				local d = rel.Magnitude
				local inside = d <= cfg.Length
					and (d < 2 or math.acos(math.clamp(rel.Unit:Dot(axis), -1, 1)) <= cfg.HalfAngle)
					and root.Position.Y > aim.Y - 5
					and root.Position.Y < aim.Y + 24
				if inside and not self:covered(breath, record) then
					self:hurt(record, cfg.Damage, "Fire Breath", true)
				end
			end
		end
	elseif kind == "InfernoSweep" then
		self.Action = "Sweep"
		local apex = region.Center + e.SweepApex
		local angle = -cfg.Arc / 2 + cfg.Arc * math.clamp(t / cfg.Active, 0, 1)
		local dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(e.SweepAxis)
		self.Aim = apex + dir * 40
		if now >= e.TickAt then
			e.TickAt = now + cfg.Tick
			local breath = mouth(self.Pose, "Sweep")
			for _, record in self:present(region) do
				local root = Common.root(record)
				local rel = horizontal(root.Position - apex)
				local d = rel.Magnitude
				if
					d <= cfg.Length
					and d > 1
					and math.acos(math.clamp(rel.Unit:Dot(dir), -1, 1)) <= cfg.Width
					and root.Position.Y < apex.Y + 24
					and not self:covered(breath, record)
				then
					self:hurt(record, cfg.Damage, "Inferno Sweep", true)
				end
			end
			if self.Rng:next() < 0.5 then
				self:patch(region, apex + dir * self.Rng:range(18, 50))
			end
		end
	elseif kind == "Dive" then
		self.Action = "Dive"
		local mark = region.Center + e.Mark
		local alpha = math.clamp(t / cfg.Active, 0, 1)
		local from = e.DiveFrom or self.Pose.Position
		local position = from:Lerp(mark + Vector3.new(0, Rig.LandHeight, 0), alpha * alpha)
		self:snapFace(mark)
		self.Pitch = -0.9 * (1 - alpha)
		self.Pose = CFrame.new(position) * CFrame.Angles(0, self.Yaw, 0) * CFrame.Angles(self.Pitch, 0, 0)
		if alpha >= 1 and not e.Impacted then
			e.Impacted = true
			self.Effects:FireAllClients(
				"Dragon",
				{ Kind = "Impact", Position = mark, Radius = cfg.Shockwave }
			)
			for _, record in self:present(region) do
				local root = Common.root(record)
				local d = horizontal(root.Position - mark).Magnitude
				if d <= cfg.Radius and math.abs(root.Position.Y - mark.Y) < 12 then
					self:hurt(record, cfg.Damage, "Dive")
				elseif
					d <= cfg.Shockwave
					and self:grounded(record)
					and math.abs(root.Position.Y - mark.Y) < 8
				then
					self:hurt(record, cfg.ShockDamage, "Shockwave")
				end
			end
			self:armorySmash(e, mark, Dragon.Weapons.Ballista.BreakRadius)
			self:scorch(region, mark, e.Def.Destruction, cfg.Radius)
			e.Stunned = Common.support(region, e.Mark.X, e.Mark.Z) ~= nil
			self.Pitch = 0
		end
	elseif kind == "GroundSlam" then
		self.Action = "Landed"
		local land = region.Center + e.Land
		local radius = cfg.Crush + (cfg.Radius - cfg.Crush) * math.clamp(t / cfg.Active, 0, 1)
		for _, record in self:present(region) do
			if not e.Hits[record] then
				local root = Common.root(record)
				local d = horizontal(root.Position - land).Magnitude
				if
					d <= radius + 1.5
					and d >= (e.Ring or 0) - 3
					and self:grounded(record)
					and math.abs(root.Position.Y - land.Y) < 8
				then
					e.Hits[record] = true
					self:hurt(record, cfg.ShockDamage, "Shockwave")
				end
			end
		end
		e.Ring = radius
	end
	local _ = dt
end
function Director:recoverStart(e, now)
	e.Impacted = false
	if e.Attack == "WingGust" or e.Attack == "FireBreath" or e.Attack == "InfernoSweep" then
		-- Breathing fire leaves a 14-second scar at the cone's far end.
		if e.Attack ~= "WingGust" then
			local apex, axis = self:breathFrame(e)
			self:scorch(e.Region, apex + axis * 52, e.Def.Destruction, 0)
		end
	end
	local _ = now
end
-- Player damage to the dragon ---------------------------------------------------------------
function Director:damage(record, amount, weapon, part, from)
	local e = self.Encounter
	if not e or e.HP <= 0 or amount <= 0 then
		return false
	end
	e.HP -= amount
	e.Damage[record] = (e.Damage[record] or 0) + amount
	local sphere = points(self.Pose, self.Action)[part]
	self.Effects:FireAllClients("DragonShot", {
		Weapon = weapon,
		From = from,
		To = if sphere then sphere[1] else self.Pose.Position,
		Part = part,
		Damage = amount,
		Weak = true,
	})
	if e.HP <= 0 then
		self:repel(e)
	end
	return true
end
-- Picks the best sphere for a shot from origin along a desired direction (aim assist cone).
-- Prefers exposed weak points; returns name, center, isWeak.
function Director:target(origin, direction, range, cone)
	local spheres = points(self.Pose, self.Action)
	local exposed = {}
	for _, name in Rig.WeakGroups[self.Exposed] or {} do
		exposed[name] = true
	end
	local best, bestScore
	for name, sphere in spheres do
		local delta = sphere[1] - origin
		local distance = delta.Magnitude
		if distance - sphere[2] <= range and distance > 0.1 then
			local angle = math.acos(math.clamp(delta.Unit:Dot(direction), -1, 1))
			local allowance = cone + math.atan(sphere[2] / distance)
			if angle <= allowance then
				local score = angle - (if exposed[name] then 1 else 0)
				if not best or score < bestScore then
					best, bestScore = name, score
				end
			end
		end
	end
	if not best then
		return nil
	end
	return best, spheres[best][1], exposed[best] == true
end
-- Shots stop a few studs short of the target sphere and are blocked by any solid geometry.
function Director:lineOfSight(origin, target, extraIgnore)
	local delta = target - origin
	local stop = target - delta.Unit * math.min(8, delta.Magnitude * 0.5)
	return self:obstruction(origin, stop, extraIgnore, true) == nil
end
-- Crossbow fire request (intent only: an aim direction). Returns true when a bolt was loosed.
function Director:fire(record, aim)
	local now = os.clock()
	local bow = self.Crossbow[record]
	local root, hum = Common.root(record)
	if
		record.State ~= "Alive"
		or record.Transit
		or not bow
		or not root
		or not hum
		or hum.Health <= 0
		or typeof(aim) ~= "Vector3"
		or aim.X ~= aim.X
		or aim.Y ~= aim.Y
		or aim.Z ~= aim.Z
		or aim.Magnitude < 0.5
		or aim.Magnitude > 1.5
	then
		return false
	end
	local cfg = Dragon.Weapons.Crossbow
	if now < (bow.ReadyAt or 0) then
		return false
	end
	if bow.Bolts <= 0 then
		self:notice(record, "Out of bolts. Fletch more at a Dragonbane Forge (1 timber = 12 bolts).")
		return false
	end
	if self.Mode == "Hidden" then
		self:notice(record, "Nothing to shoot. Save your bolts for the Realm Destroyer.")
		return false
	end
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local name, center, weak = self:target(origin, aim.Unit, cfg.Range, cfg.AimCone)
	if not name then
		self:notice(record, "Aim at the Realm Destroyer (it must be within " .. cfg.Range .. " studs).")
		return false
	end
	if not self:lineOfSight(origin, center) then
		self:notice(record, "No clear shot from here.")
		return false
	end
	bow.Bolts -= 1
	bow.ReadyAt = now + cfg.Cooldown
	local e = self.Encounter
	local fighting = e and e.Region.Index == record.Region
	if not fighting then
		self.Effects:FireAllClients(
			"DragonShot",
			{ Weapon = "Crossbow", From = origin, To = center, Part = name, Damage = 0 }
		)
		self:notice(record, "The bolt glances off. The Realm Destroyer can only be fought in battle.")
		return true
	end
	if weak then
		self:damage(record, cfg.Damage, "Crossbow", name, origin)
	else
		self.Effects:FireAllClients(
			"DragonShot",
			{ Weapon = "Crossbow", From = origin, To = center, Part = name, Damage = 0, Weak = false }
		)
		if now > (bow.WarnAt or 0) then
			bow.WarnAt = now + 4
			self:notice(record, "Its scales deflect bolts. Shoot the GLOWING weak point during an attack.")
		end
	end
	return true
end
-- Dragonbane Harpoon throw (intent only: an aim direction). Heavier and slower than bolts:
-- full damage on an exposed weak point (and pins that window open longer), a small amount
-- through unexposed scales.
function Director:throw(record, aim)
	local now = os.clock()
	local quiver = self.Harpoons[record]
	local root, hum = Common.root(record)
	if
		record.State ~= "Alive"
		or record.Transit
		or not quiver
		or not root
		or not hum
		or hum.Health <= 0
		or typeof(aim) ~= "Vector3"
		or aim.X ~= aim.X
		or aim.Y ~= aim.Y
		or aim.Z ~= aim.Z
		or aim.Magnitude < 0.5
		or aim.Magnitude > 1.5
	then
		return false
	end
	local cfg = Dragon.Weapons.Harpoon
	if now < (quiver.ReadyAt or 0) then
		return false
	end
	if quiver.Count <= 0 then
		self:notice(record, "No harpoons left. Restock at a Harpoon Rack (1 timber = 2).")
		return false
	end
	local e = self.Encounter
	if not e or e.Region.Index ~= record.Region then
		self:notice(record, "Save your harpoons for a battle with the Realm Destroyer.")
		return false
	end
	local origin = root.Position + Vector3.new(0, 2, 0)
	local name, center, weak = self:target(origin, aim.Unit, cfg.Range, cfg.AimCone)
	if not name then
		self:notice(record, "Too far to throw: get within " .. cfg.Range .. " studs and aim at the dragon.")
		return false
	end
	if not self:lineOfSight(origin, center) then
		self:notice(record, "No clear throw from here.")
		return false
	end
	quiver.Count -= 1
	quiver.ReadyAt = now + cfg.Cooldown
	self:gear(record)
	if weak and e.State == "Recover" and not e.Pinned then
		e.Pinned = true
		e.StateAt += cfg.Pin
		for _, other in self:present(e.Region) do
			self:notice(other, "Harpoon pinned it! The weak point stays open longer.")
		end
	end
	self:damage(record, if weak then cfg.Damage else cfg.Glance, "Harpoon", name, origin)
	return true
end
-- Visible Dragonbane gear on the character (replicated): crossbow in hand, harpoons on the back.
function Director:gear(record)
	local character = record.Player.Character
	if not character then
		return
	end
	for _, child in character:GetChildren() do
		if child:GetAttribute("DragonbaneGear") then
			child:Destroy()
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm") or root
	local back = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or root
	if not hand or not back then
		return
	end
	local function piece(name, size, anchor, offset, color, material)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Color, p.Material = name, size, color, material or Enum.Material.Wood
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
		p.CFrame = anchor.CFrame * offset
		p:SetAttribute("DragonbaneGear", true)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = anchor, p, p
		p.Parent = character
		return p
	end
	if self.Crossbow[record] then
		local grip = CFrame.new(0, -0.9, -0.6)
		piece("DragonbaneCrossbow", Vector3.new(0.35, 0.35, 2.4), hand, grip, C(70, 46, 30))
		piece(
			"DragonbaneCrossbow",
			Vector3.new(2.6, 0.2, 0.3),
			hand,
			grip * CFrame.new(0, 0.05, -0.9),
			C(150, 30, 26)
		)
		piece(
			"DragonbaneCrossbow",
			Vector3.new(0.25, 0.25, 0.5),
			hand,
			grip * CFrame.new(0, 0.2, -1.3),
			C(255, 214, 120),
			Enum.Material.Neon
		)
	end
	local quiver = self.Harpoons[record]
	if quiver and quiver.Count > 0 then
		for k = 1, math.min(quiver.Count, 6) do
			local offset = CFrame.new((k - 3.5) * 0.28, 0.4, 0.75)
				* CFrame.Angles(0, 0, 0.5 + (k - 3.5) * 0.06)
			piece("DragonbaneHarpoon", Vector3.new(0.2, 4.4, 0.2), back, offset, C(96, 70, 46))
			piece(
				"DragonbaneHarpoon",
				Vector3.new(0.35, 0.8, 0.35),
				back,
				offset * CFrame.new(0, 2.5, 0),
				C(130, 220, 255),
				Enum.Material.Neon
			)
		end
	end
end
-- Fixed emplacements (auto-aimed at the best exposed weak point).
function Director:emplacement(record, region, entry, weapon)
	local e = self.Encounter
	local cfg = Dragon.Weapons[weapon]
	local now = os.clock()
	if not e or e.Region ~= region then
		self:notice(record, "Ready. It fires once the Realm Destroyer attacks this realm.")
		return false
	end
	if now < (entry.ReadyAt or 0) then
		self:notice(record, cfg.Name .. " reloading: " .. math.ceil(entry.ReadyAt - now) .. "s.")
		return false
	end
	local pivot = if entry.Built and entry.Built.Local then Armory.pivot(entry.Built, region.Center) else nil
	local origin = (if pivot then pivot.Position else entry.Spec.Part.Position) + Vector3.new(0, 1.5, 0)
	local aimAt = self.Pose.Position
	local name, center, weak = self:target(origin, (aimAt - origin).Unit, cfg.Range, math.rad(70))
	if not name then
		self:notice(record, "The Realm Destroyer is out of range (" .. cfg.Range .. " studs).")
		return false
	end
	if not self:lineOfSight(origin, center, entry.Built and entry.Built.Parts or nil) then
		self:notice(record, "Something blocks the shot.")
		return false
	end
	if weapon == "Cannon" then
		local bag = record.Bag
		if not bag or (bag.Crystal or 0) < cfg.Crystal then
			self:notice(record, "Load the Crystal Cannon with 1 crystal (gather them near caves).")
			return false
		end
		bag.Crystal -= cfg.Crystal
	end
	entry.ReadyAt = now + cfg.Cooldown
	local amount = if weak then cfg.Damage else cfg.Glance
	-- A crystal blast during a wind-up interrupts the attack and opens a counterattack window.
	if weapon == "Cannon" and e.State == "Windup" and e.Attack ~= "GroundSlam" and e.Attack ~= "Dive" then
		e.Interrupted = true
		self:clearMarkers(e)
		self:setState(e, "Recover", now)
		self.Exposed = "Heart"
		self.Effects:FireAllClients("Dragon", { Kind = "Interrupted", Position = self.Pose.Position })
		for _, other in self:present(region) do
			self:notice(other, "Crystal blast! The Realm Destroyer reels: its heart is exposed!")
		end
	end
	if not self:damage(record, amount, weapon, name, origin) then
		return false
	end
	self:labels(region)
	return true
end
function Director:interact(record, region, spec)
	local armory = region.Armory
	local kind = spec.Dragonbane
	local entry = armory and armory[kind]
	if not entry or entry.Spec ~= spec then
		return false
	end
	local bag = record.Bag or {}
	if kind == "Forge" then
		local cfg = Dragon.Weapons.Crossbow
		local bow = self.Crossbow[record]
		if not bow then
			if (bag.Timber or 0) < cfg.Craft.Timber or (bag.Crystal or 0) < cfg.Craft.Crystal then
				self:notice(record, "Forging a Dragonbane Crossbow needs 2 timber and 1 crystal.")
				return false
			end
			bag.Timber -= cfg.Craft.Timber
			bag.Crystal -= cfg.Craft.Crystal
			self.Crossbow[record] = { Bolts = cfg.Bolts, ReadyAt = 0 }
			self:notice(
				record,
				"Dragonbane Crossbow forged ("
					.. cfg.Bolts
					.. " bolts). G / R1 / FIRE shoots glowing weak points."
			)
			self.Effects:FireClient(record.Player, "Dragon", { Kind = "Crossbow", Bolts = cfg.Bolts })
			self:gear(record)
			return true
		end
		if bow.Bolts >= cfg.MaxBolts then
			self:notice(record, "Your quiver is full (" .. cfg.MaxBolts .. " bolts).")
			return false
		end
		if (bag.Timber or 0) < cfg.Fletch.Timber then
			self:notice(record, "Fletching 12 bolts needs 1 timber.")
			return false
		end
		bag.Timber -= cfg.Fletch.Timber
		bow.Bolts = math.min(cfg.MaxBolts, bow.Bolts + cfg.FletchBolts)
		self:notice(record, "Fletched bolts: " .. bow.Bolts .. "/" .. cfg.MaxBolts .. ".")
		self.Effects:FireClient(record.Player, "Dragon", { Kind = "Crafted" })
		return true
	elseif kind == "HarpoonRack" then
		local cfg = Dragon.Weapons.Harpoon
		local quiver = self.Harpoons[record]
		if not quiver then
			if (bag.Timber or 0) < cfg.Craft.Timber or (bag.Crystal or 0) < cfg.Craft.Crystal then
				self:notice(record, "Three Dragonbane Harpoons need 3 timber and 1 crystal.")
				return false
			end
			bag.Timber -= cfg.Craft.Timber
			bag.Crystal -= cfg.Craft.Crystal
			self.Harpoons[record] = { Count = cfg.Count, ReadyAt = 0 }
			self:notice(
				record,
				"Dragonbane Harpoons ready ("
					.. cfg.Count
					.. "). T / L2 / THROW. Hits on a glowing weak point pin it open!"
			)
			self.Effects:FireClient(record.Player, "Dragon", { Kind = "Harpoons", Count = cfg.Count })
		else
			if quiver.Count >= cfg.Max then
				self:notice(record, "You carry the most harpoons you can (" .. cfg.Max .. ").")
				return false
			end
			if (bag.Timber or 0) < cfg.Refill.Timber then
				self:notice(record, "Two more harpoons need 1 timber.")
				return false
			end
			bag.Timber -= cfg.Refill.Timber
			quiver.Count = math.min(cfg.Max, quiver.Count + cfg.RefillCount)
			self:notice(record, "Harpoons: " .. quiver.Count .. "/" .. cfg.Max .. ".")
			self.Effects:FireClient(record.Player, "Dragon", { Kind = "Crafted" })
		end
		self:gear(record)
		return true
	elseif kind == "Ballista" then
		local cfg = Dragon.Weapons.Ballista
		if entry.State == "Broken" or entry.State == "Smashed" then
			local goal = if entry.State == "Broken" then cfg.Repair else cfg.Mend
			if (bag.Timber or 0) < 2 then
				self:notice(
					record,
					"Repairing the ballista needs timber: " .. (entry.Repair or 0) .. "/" .. goal .. "."
				)
				return false
			end
			bag.Timber -= 2
			entry.Repair = (entry.Repair or 0) + 2
			if entry.Repair >= goal then
				entry.State, entry.Repair = "Ready", 0
				self:notice(record, "Ballista repaired! Fire it (E / X) when a weak point glows.")
			else
				self:notice(record, "Ballista repair: " .. entry.Repair .. "/" .. goal .. " timber.")
			end
			self:labels(region)
			return true
		end
		return self:emplacement(record, region, entry, "Ballista")
	elseif kind == "Cannon" then
		return self:emplacement(record, region, entry, "Cannon")
	end
	return false
end
-- Labels, prompts and turret aim -------------------------------------------------------------
function Director:labels(region)
	local armory = region.Armory
	if not armory then
		return
	end
	local now = os.clock()
	local forge = armory.Forge
	if forge and forge.Label and forge.Label.Parent then
		forge.Label.Text = "DRAGONBANE FORGE\nCrossbow: 2 timber + 1 crystal · Bolts: 1 timber"
		forge.Spec.Prompt.ActionText = "Forge crossbow / fletch bolts"
	end
	local rack = armory.HarpoonRack
	if rack and rack.Label and rack.Label.Parent then
		rack.Label.Text = "HARPOON RACK\n3 harpoons: 3 timber + 1 crystal · restock 2: 1 timber"
		rack.Spec.Prompt.ActionText = "Take Dragonbane Harpoons"
	end
	local ballista = armory.Ballista
	if ballista and ballista.Label and ballista.Label.Parent then
		local cfg = Dragon.Weapons.Ballista
		local text, action
		if ballista.State == "Broken" then
			text = "BROKEN BALLISTA\nRepair: " .. (ballista.Repair or 0) .. "/" .. cfg.Repair .. " timber"
			action = "Repair ballista (2 timber)"
		elseif ballista.State == "Smashed" then
			text = "SMASHED BALLISTA\nMend: " .. (ballista.Repair or 0) .. "/" .. cfg.Mend .. " timber"
			action = "Mend ballista (2 timber)"
		elseif now < (ballista.ReadyAt or 0) then
			text = "BALLISTA\nReloading " .. math.ceil(ballista.ReadyAt - now) .. "s"
			action = "Fire ballista"
		else
			text = "BALLISTA\nREADY: fire at a glowing weak point"
			action = "Fire ballista"
		end
		ballista.Label.Text = text
		ballista.Spec.Prompt.ActionText = action
		local built = ballista.Built
		if built and built.Bolt and built.Bolt.Parent then
			local loaded = ballista.State == "Ready" and now >= (ballista.ReadyAt or 0)
			built.Bolt.Transparency = if loaded then 0 else 1
			built.Tip.Transparency = if loaded then 0 else 1
		end
	end
	local cannon = armory.Cannon
	if cannon and cannon.Label and cannon.Label.Parent then
		cannon.Label.Text = if now < (cannon.ReadyAt or 0)
			then "CRYSTAL CANNON\nRecharging " .. math.ceil(cannon.ReadyAt - now) .. "s"
			else "CRYSTAL CANNON\nREADY: 1 crystal per shot"
		cannon.Spec.Prompt.ActionText = "Load crystal & fire"
	end
end
function Director:aimTurrets(e)
	local armory = e.Region.Armory
	if not armory then
		return
	end
	for _, kind in { "Ballista", "Cannon" } do
		local entry = armory[kind]
		local built = entry and entry.Built
		if
			built
			and built.Local
			and entry.Ground
			and entry.Ground.Parent
			and entry.Ground:GetAttribute("Phase") == "Stable"
		then
			local pivot = Armory.pivot(built, e.Region.Center)
			local rotation
			if kind == "Ballista" and (entry.State == "Broken" or entry.State == "Smashed") then
				rotation = CFrame.Angles(0.45, 0, 0.35) * CFrame.new(0, -1.2, 0)
			else
				local dir = pivot:PointToObjectSpace(self.Pose.Position)
				local yaw = math.atan2(-dir.X, -dir.Z)
				local pitch = math.atan2(dir.Y, math.sqrt(dir.X * dir.X + dir.Z * dir.Z))
				rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.clamp(pitch, -0.2, 1.1), 0, 0)
			end
			Armory.aim(built, e.Region.Center, rotation)
		end
	end
end
-- Endings ------------------------------------------------------------------------------------
function Director:repel(e)
	local region = e.Region
	local tier = math.clamp(e.Tier, 1, 4)
	local R = Dragon.Rewards
	for record, dealt in e.Damage do
		if dealt >= 1 and record.State == "Alive" and not e.Escaped[record] then
			local profile = self:profile(record)
			local full = profile ~= nil and os.time() - (profile.DragonAt or 0) >= R.TrophyCooldown
			local factor = if full then 1 else R.ReducedFactor
			self.Svc:reward(record, {
				Coins = math.floor(R.Coins[tier] * factor),
				XP = math.floor(R.XP[tier] * factor),
				Relic = R.Relic,
			}, "Realm Destroyer repelled")
			self.Svc:achieve(record, "Dragonbane")
			self:discover(record, 4)
			if profile then
				profile.DragonKills = (profile.DragonKills or 0) + 1
				if full then
					profile.DragonAt = os.time()
					local scales = R.Scales[tier]
					local shard = if self.Rng:next() < R.EmberheartChance[tier] then 1 else 0
					profile.DragonScales = (profile.DragonScales or 0) + scales
					profile.Emberhearts = (profile.Emberhearts or 0) + shard
					local cosmetic = nil
					if not profile.Owned[R.Cosmetic] then
						profile.DragonRolls = (profile.DragonRolls or 0) + 1
						if self.Rng:next() < R.CosmeticChance or profile.DragonRolls >= R.CosmeticPity then
							profile.Owned[R.Cosmetic] = true
							profile.DragonRolls = 0
							cosmetic = "Dragonwing Mantle"
						end
					end
					self.Effects:FireClient(record.Player, "DragonTrophy", {
						Scales = scales,
						Emberhearts = shard,
						TotalScales = profile.DragonScales,
						TotalEmberhearts = profile.Emberhearts,
						Cosmetic = cosmetic,
					})
				else
					local wait = R.TrophyCooldown - (os.time() - (profile.DragonAt or 0))
					self:notice(
						record,
						"Dragon trophies recharge in " .. math.ceil(wait / 60) .. " min. Coins and XP halved."
					)
				end
			end
		end
	end
	for _, record in self:present(region) do
		self.Effects:FireClient(record.Player, "Dragon", { Kind = "Repelled" })
	end
	self:finish("Repelled")
end
function Director:raze(e, result)
	local region = e.Region
	local now = os.clock()
	for _, cell in region.Cells do
		if cell.State == "Stable" and cell.Part.Parent and not causeway[cell.Part.Name] then
			self.World:warnCell(region, cell, now, "Dragon")
		end
	end
	self.Effects:FireAllClients("Dragon", { Kind = "Raze", Position = region.Center, Result = result })
	for _, record in self:present(region) do
		self:notice(
			record,
			"The Realm Destroyer is razing this realm! Board the Sky Balloon or run the causeway NOW."
		)
	end
	self:finish(result)
end
function Director:finish(result)
	local e = self.Encounter
	if not e then
		return
	end
	self:clearMarkers(e)
	local st = self.Regions[e.Region]
	if st then
		st.Result = result
	end
	self.Encounter = nil
	self.Departing = { Until = os.clock() + 7, From = self.Pose.Position, Region = e.Region }
	self.Pause = os.clock() + Dragon.RaidPauseAfterEncounter
	self.Exposed, self.Phase = "", ""
	-- Damaged equipment rests again.
	local armory = e.Region.Armory
	if armory and e.Region.Model.Parent then
		self:labels(e.Region)
	end
end
-- Burning and fire patches (0.5 s steps) ------------------------------------------------------
function Director:burns(dt, now)
	self.BurnAccum += dt
	if self.BurnAccum < 0.5 then
		return
	end
	local step = self.BurnAccum
	self.BurnAccum = 0
	for i = #self.Patches, 1, -1 do
		local patch = self.Patches[i]
		local region = patch.Region
		local gone = now >= patch.Until
			or not patch.Part.Parent
			or not Common.support(region, patch.Local.X, patch.Local.Z)
		if gone then
			if patch.Part.Parent then
				patch.Part:Destroy()
			end
			table.remove(self.Patches, i)
		else
			local world = region.Center + patch.Local
			for _, record in Common.near(self.Svc, world, Dragon.FirePatch.Radius + 4) do
				local root = Common.root(record)
				if
					horizontal(root.Position - world).Magnitude <= Dragon.FirePatch.Radius
					and root.Position.Y - world.Y < 6
					and root.Position.Y - world.Y > -2
				then
					self.Svc:hurt(record, math.ceil(Dragon.FirePatch.Damage * step), "Dragonfire")
					self.Burning[record] = math.max(self.Burning[record] or 0, now + Dragon.Burning.Duration)
				end
			end
		end
	end
	for record, untilTime in self.Burning do
		if now >= untilTime or record.State ~= "Alive" then
			self.Burning[record] = nil
		else
			self.Svc:hurt(record, math.ceil(Dragon.Burning.Damage * step), "Burning")
		end
	end
end
-- Main tick (10 Hz from the round loop) -------------------------------------------------------
function Director:update(dt)
	local now = os.clock()
	self:burns(dt, now)
	for record in self.Crossbow do
		if record.State ~= "Alive" then
			self.Crossbow[record] = nil
		end
	end
	for record in self.Harpoons do
		if record.State ~= "Alive" then
			self.Harpoons[record] = nil
		end
	end
	if self.Encounter then
		self:fight(dt, now)
	elseif self.Departing then
		local d = self.Departing
		self.Mode, self.Action, self.Phase, self.Exposed = "Departing", "Fly", "", ""
		local away = d.Region.Center
			+ unitFlat(self.Pose.Position - d.Region.Center, Vector3.new(1, 0, 0)) * 900
			+ Vector3.new(0, 320, 0)
		self:steer(away, away, 110, dt, 1.5)
		if now >= d.Until then
			self.Departing = nil
			self.Mode = "Hidden"
		end
	else
		local focus = self:focus()
		if not focus or not self.Regions[focus] then
			self.Mode = "Hidden"
		else
			-- Encounter regions start their battle once explorers have had time to prepare.
			for region, st in self.Regions do
				if
					st.Stage == "Encounter"
					and not st.Done
					and region.Activated
					and now - region.Activated >= Dragon.EncounterDelay
					and #self:present(region) > 0
				then
					self:startEncounter(region, st, now)
					break
				end
			end
			if not self.Encounter then
				local st = self.Regions[focus]
				if self.Raid then
					self:raid(dt, now)
				elseif
					st.Stage ~= "Omen"
					and not (st.Stage == "Encounter" and not st.Done)
					and focus.Activated
					and now >= self.Pause
					and st.Raids < Dragon.Raid.MaxPerRegion
					and now >= (st.NextRaid or (focus.Activated + Dragon.Raid.First))
					and #self:present(focus) > 0
				then
					self:startRaid(focus, st, now)
					if self.Raid then
						self:raid(dt, now)
					else
						self:ambient(focus, dt, now)
					end
				else
					self:ambient(focus, dt, now)
				end
			end
		end
	end
	self.StatusAccum += dt
	if self.StatusAccum >= 0.5 then
		self.StatusAccum = 0
		for region in self.Regions do
			if region.Armory then
				self:labels(region)
			end
		end
	end
	self:publish()
end
-- Snapshot view for the HUD.
function Director:status(record)
	local e = self.Encounter
	local bow = self.Crossbow[record]
	local view = {
		Mode = self.Mode,
		Crossbow = if bow then bow.Bolts else nil,
		Harpoons = if self.Harpoons[record] then self.Harpoons[record].Count else nil,
	}
	if e then
		local near = e.Region.Index == record.Region
		view.Encounter = near
		view.HP = math.max(0, math.ceil(e.HP))
		view.MaxHP = e.MaxHP
		view.Tier = e.Tier
		view.Exposed = self.Exposed
		view.Attack = if e.Attack then Dragon.Attacks[e.Attack].Label else nil
		view.Phase = self.Phase
		view.RazeIn = math.max(0, math.ceil(e.RazeAt - os.clock()))
	end
	return view
end
return Director
