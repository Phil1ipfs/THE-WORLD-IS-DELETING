--!nonstrict
-- Realm creatures: patrol -> aggro -> telegraphed wind-up -> attack -> recover.
-- Players strike with Gust Dash contact, by dropping onto a creature, or by Aegis reflection.
-- Movement is server-owned (anchored models) and always checked against intact terrain.
local Common = require(script.Parent.Common)
local Creatures = {}
local C = Color3.fromRGB
local kinds = {
	BrambleStalker = {
		Attack = "Lunge",
		HP = 3,
		Speed = 11,
		Body = C(86, 70, 46),
		Glow = C(180, 255, 110),
		Damage = 14,
		Name = "Bramble Stalker",
	},
	CrystalSentinel = {
		Attack = "Slam",
		HP = 5,
		Speed = 7,
		Body = C(140, 190, 240),
		Glow = C(120, 240, 255),
		Damage = 18,
		Radius = 12,
		Name = "Crystal Sentinel",
	},
	VineLurker = {
		Attack = "Lunge",
		HP = 3,
		Speed = 12,
		Body = C(48, 110, 60),
		Glow = C(230, 255, 90),
		Damage = 12,
		Name = "Vine Lurker",
	},
	EmberWisp = {
		Attack = "Strike",
		HP = 2,
		Speed = 10,
		Body = C(255, 120, 40),
		Glow = C(255, 200, 80),
		Damage = 16,
		Radius = 7,
		Hover = 4,
		Name = "Ember Wisp",
	},
	FrostWraith = {
		Attack = "Slam",
		HP = 3,
		Speed = 9,
		Body = C(200, 230, 255),
		Glow = C(140, 220, 255),
		Damage = 14,
		Radius = 10,
		Hover = 2,
		Name = "Frost Wraith",
	},
	DustGolem = {
		Attack = "Slam",
		HP = 4,
		Speed = 7,
		Body = C(170, 150, 120),
		Glow = C(255, 210, 120),
		Damage = 16,
		Radius = 11,
		Name = "Dust Golem",
	},
	StormSpirit = {
		Attack = "Strike",
		HP = 3,
		Speed = 12,
		Body = C(150, 160, 220),
		Glow = C(220, 230, 255),
		Damage = 16,
		Radius = 8,
		Hover = 5,
		Name = "Storm Spirit",
	},
	GearDrone = {
		Attack = "Lunge",
		HP = 3,
		Speed = 13,
		Body = C(140, 130, 110),
		Glow = C(255, 190, 80),
		Damage = 12,
		Hover = 3,
		Name = "Gear Drone",
	},
	StarMoth = {
		Attack = "Strike",
		HP = 2,
		Speed = 12,
		Body = C(236, 210, 250),
		Glow = C(255, 240, 170),
		Damage = 12,
		Radius = 7,
		Hover = 4,
		Name = "Star Moth",
	},
	Anomaly = {
		Attack = "Blink",
		HP = 4,
		Speed = 10,
		Body = C(30, 20, 46),
		Glow = C(233, 99, 255),
		Damage = 18,
		Radius = 10,
		Hover = 1,
		Name = "Deletion Anomaly",
	},
}
Creatures.Kinds = kinds
local function shape(kind, def, elite)
	local s = if elite then 1.6 else 1
	local body, glow = def.Body, def.Glow
	local parts
	if def.Hover and kind ~= "Anomaly" then
		parts = {
			{ "Core", Vector3.new(2.6, 2.6, 2.6) * s, CFrame.new(), body, Enum.Material.Neon, "Ball" },
			{
				"Shell",
				Vector3.new(4, 1.6, 4) * s,
				CFrame.new(0, 0.4 * s, 0),
				body:Lerp(C(0, 0, 0), 0.3),
				Enum.Material.Metal,
				nil,
				"Sphere",
			},
			{ "Eye", Vector3.new(1, 1, 1) * s, CFrame.new(0, 0, -1.4 * s), glow, Enum.Material.Neon, "Ball" },
			{
				"Wing",
				Vector3.new(4.5, 0.2, 2) * s,
				CFrame.new(2.6 * s, 0.6, 0) * CFrame.Angles(0, 0, 0.3),
				glow,
				Enum.Material.Neon,
			},
			{
				"Wing",
				Vector3.new(4.5, 0.2, 2) * s,
				CFrame.new(-2.6 * s, 0.6, 0) * CFrame.Angles(0, 0, -0.3),
				glow,
				Enum.Material.Neon,
			},
		}
	elseif kind == "Anomaly" then
		parts = {
			{ "Core", Vector3.new(3, 5, 3) * s, CFrame.new(0, 1, 0), body, Enum.Material.Basalt },
			{
				"Eye",
				Vector3.new(1.4, 1.4, 1.4) * s,
				CFrame.new(0, 2.4 * s, -1.4 * s),
				glow,
				Enum.Material.Neon,
				"Ball",
			},
			{
				"Shard",
				Vector3.new(1, 4, 1) * s,
				CFrame.new(2.4 * s, 2, 0) * CFrame.Angles(0, 0, -0.5),
				glow,
				Enum.Material.Neon,
			},
			{
				"Shard",
				Vector3.new(1, 4, 1) * s,
				CFrame.new(-2.4 * s, 2, 0) * CFrame.Angles(0, 0, 0.5),
				glow,
				Enum.Material.Neon,
			},
			{
				"Shard",
				Vector3.new(1, 3, 1) * s,
				CFrame.new(0, 4.6 * s, 0.6) * CFrame.Angles(0.4, 0, 0),
				glow,
				Enum.Material.Neon,
			},
		}
	else
		parts = {
			{
				"Core",
				Vector3.new(3.6, 2.6, 5) * s,
				CFrame.new(0, 1.8 * s, 0),
				body,
				Enum.Material.Rock,
				nil,
				"Sphere",
			},
			{
				"Head",
				Vector3.new(2.4, 2, 2.4) * s,
				CFrame.new(0, 2.6 * s, -2.6 * s),
				body:Lerp(C(255, 255, 255), 0.1),
				Enum.Material.Rock,
				nil,
				"Sphere",
			},
			{
				"Eye",
				Vector3.new(0.6, 0.6, 0.6) * s,
				CFrame.new(0.6 * s, 2.9 * s, -3.6 * s),
				glow,
				Enum.Material.Neon,
				"Ball",
			},
			{
				"Eye",
				Vector3.new(0.6, 0.6, 0.6) * s,
				CFrame.new(-0.6 * s, 2.9 * s, -3.6 * s),
				glow,
				Enum.Material.Neon,
				"Ball",
			},
		}
		for _, lx in { -1.4, 1.4 } do
			for _, lz in { -1.4, 1.4 } do
				table.insert(parts, {
					"Leg",
					Vector3.new(0.7, 2, 0.7) * s,
					CFrame.new(lx * s, 0.8 * s, lz * s),
					body:Lerp(C(0, 0, 0), 0.3),
					Enum.Material.Wood,
				})
			end
		end
		if kind == "CrystalSentinel" then
			for k = 1, 3 do
				table.insert(parts, {
					"Shard",
					Vector3.new(1, 3.4, 1) * s,
					CFrame.new((k - 2) * 1.2 * s, 3.8 * s, 0.4) * CFrame.Angles(0.2, 0, (k - 2) * 0.3),
					glow,
					Enum.Material.Glass,
				})
			end
		elseif kind == "DustGolem" then
			table.insert(parts, {
				"Shard",
				Vector3.new(5, 1.4, 1.4) * s,
				CFrame.new(0, 3.4 * s, 0),
				body,
				Enum.Material.Sandstone,
			})
		end
	end
	return parts
end
-- Spawns a creature model at a local position; ctx provides region/world helpers.
function Creatures.spawn(ctx, kind, x, z, elite, owner)
	local def = kinds[kind] or kinds.BrambleStalker
	local position = ctx.World(x, z, def.Hover or 0)
	local model = Common.figure(ctx, "Creature_" .. kind, position, shape(kind, def, elite))
	model:SetAttribute("Creature", kind)
	model:SetAttribute("Elite", elite == true)
	local ring = Instance.new("Part")
	ring.Name, ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch =
		"AttackMarker", true, false, false, false
	ring.Shape, ring.Material, ring.Color = Enum.PartType.Cylinder, Enum.Material.Neon, def.Glow
	ring.Size, ring.Transparency, ring.CastShadow = Vector3.new(0.2, 1, 1), 1, false
	ring.Parent = ctx.Region.Model
	local hp = def.HP + (if elite then 4 else 0)
	local bill = Instance.new("BillboardGui")
	bill.Name, bill.Size, bill.StudsOffset, bill.MaxDistance =
		"CreatureBar", UDim2.fromOffset(110, 26), Vector3.new(0, 6 * (if elite then 1.6 else 1), 0), 90
	bill.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Font, label.TextSize =
		UDim2.fromScale(1, 1), 1, Enum.Font.GothamBold, 13
	label.TextColor3, label.TextStrokeTransparency = def.Glow, 0.3
	label.Parent = bill
	bill.Adornee, bill.Parent = model.PrimaryPart, model.PrimaryPart
	local creature = {
		Kind = kind,
		Def = def,
		Model = model,
		Marker = ring,
		Label = label,
		Elite = elite == true,
		HP = hp,
		MaxHP = hp,
		Home = Vector3.new(x, 0, z),
		Local = Vector3.new(x, 0, z),
		State = "Idle",
		StateAt = 0,
		Yaw = 0,
		Hitters = {},
		LastDash = {},
		Owner = owner,
		Region = ctx.Region,
	}
	Creatures.label(creature)
	return creature
end
function Creatures.label(c)
	c.Label.Text = (if c.Elite then "ELITE " else "")
		.. c.Def.Name
		.. "  HP "
		.. math.max(0, c.HP)
		.. "/"
		.. c.MaxHP
end
function Creatures.scale(c, players)
	if c.Elite and not c.Scaled then
		c.Scaled = true
		c.MaxHP += math.clamp(players - 1, 0, 5) * 2
		c.HP = c.MaxHP
		Creatures.label(c)
	end
end
local function place(c, now)
	local region = c.Region
	local bob = math.sin(now * 3 + c.Home.X) * (if c.Def.Hover then 0.6 else 0.15)
	local cf = CFrame.new(
		region.Center
			+ Vector3.new(
				c.Local.X,
				(c.Def.Hover or 0) + bob + Common.height(region, c.Local.X, c.Local.Z),
				c.Local.Z
			)
	) * CFrame.Angles(0, c.Yaw, 0)
	c.Model:PivotTo(cf)
end
local function telegraph(c, on)
	for _, p in c.Model:GetChildren() do
		if
			p:IsA("BasePart")
			and (p.Name == "Eye" or p.Name == "Core" or p.Name == "Shard" or p.Name == "Wing")
		then
			p:SetAttribute("BaseColor", p:GetAttribute("BaseColor") or p.Color)
			p.Color = if on then C(255, 70, 70) else p:GetAttribute("BaseColor")
		end
	end
end
function Creatures.remove(c)
	if c.Model.Parent then
		c.Model.Parent = nil
	end
	if c.Marker.Parent then
		c.Marker.Parent = nil
	end
	c.State = "Gone"
end
-- Applies one hit; returns true when defeated.
function Creatures.hit(svc, c, record, amount, now)
	if c.State == "Gone" or now < (c.HurtUntil or 0) then
		return false
	end
	c.HurtUntil = now + 0.35
	c.HP -= amount
	c.Hitters[record] = true
	Creatures.label(c)
	svc.Effects:FireAllClients(
		"CreatureHit",
		{ Position = c.Model:GetPivot().Position, Kind = c.Kind, Defeated = c.HP <= 0 }
	)
	if c.HP <= 0 then
		Creatures.remove(c)
		return true
	end
	-- Knock back from the attacker so hits read clearly.
	local root = Common.root(record)
	if root then
		local away = (c.Region.Center + c.Local) - root.Position
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude > 0.1 then
			c.Local += away.Unit * 5
		end
	end
	c.State, c.StateAt = "Recover", now
	telegraph(c, false)
	c.Marker.Transparency = 1
	return false
end
-- Advances one creature; returns "Defeated" with the hitters list when it dies.
function Creatures.update(svc, c, dt, now)
	if c.State == "Gone" then
		return nil
	end
	local region = c.Region
	if not Common.support(region, c.Local.X, c.Local.Z) then
		-- Its ground was deleted: the creature falls with it, no reward.
		Creatures.remove(c)
		return "Fell"
	end
	local def = c.Def
	local world = region.Center + c.Local + Vector3.new(0, Common.height(region, c.Local.X, c.Local.Z), 0)
	-- Player strikes: dash contact, falling stomp, and Aegis reflection during lunges.
	for _, record in Common.near(svc, world, 9 * (if c.Elite then 1.4 else 1)) do
		local root = Common.root(record)
		local offset = root.Position - world
		local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
		local dashing = now < (record.DashUntil or 0) and record.DashSerial ~= c.LastDash[record]
		local stomp = offset.Y > 2 and horizontal < 4.5 and root.AssemblyLinearVelocity.Y < -12
		if dashing and horizontal < 7 * (if c.Elite then 1.3 else 1) then
			c.LastDash[record] = record.DashSerial
			local boosted = now < (record.OverchargeUntil or 0)
			if Creatures.hit(svc, c, record, if boosted then 2 else 1, now) then
				return "Defeated"
			end
		elseif stomp and now >= (c.HurtUntil or 0) then
			if Creatures.hit(svc, c, record, 1, now) then
				return "Defeated"
			end
		end
	end
	-- Target the nearest player within aggro range of the lair.
	local target, best = nil, 42
	for _, record in Common.near(svc, world, 42) do
		local root = Common.root(record)
		local fromHome = (root.Position - (region.Center + c.Home))
		if Vector3.new(fromHome.X, 0, fromHome.Z).Magnitude < 60 then
			local d = (root.Position - world).Magnitude
			if d < best then
				target, best = record, d
			end
		end
	end
	local function moveToward(goal, speed)
		local delta = Vector3.new(goal.X - c.Local.X, 0, goal.Z - c.Local.Z)
		if delta.Magnitude > 0.5 then
			local step = delta.Unit * math.min(delta.Magnitude, speed * dt)
			local nextLocal = c.Local + step
			if Common.support(region, nextLocal.X, nextLocal.Z) then
				c.Local = nextLocal
			end
			c.Yaw = math.atan2(-delta.X, -delta.Z)
		end
	end
	if c.State == "Idle" or c.State == "Chase" then
		if target then
			local root = Common.root(target)
			local goal = root.Position - region.Center
			c.State = "Chase"
			moveToward(goal, def.Speed)
			local range = if def.Attack == "Lunge"
				then 14
				elseif def.Attack == "Slam" then (def.Radius or 10) * 0.8
				else 32
			if best <= range and now >= (c.ReadyAt or 0) then
				c.State, c.StateAt, c.Target = "Windup", now, target
				c.AimAt = goal
				telegraph(c, true)
				if def.Attack == "Slam" or def.Attack == "Blink" then
					c.Marker.Size = Vector3.new(0.2, (def.Radius or 10) * 2, (def.Radius or 10) * 2)
					c.Marker.CFrame = CFrame.new(world.X, world.Y + 0.2, world.Z)
						* CFrame.Angles(0, 0, math.pi / 2)
					c.Marker.Transparency = 0.55
				elseif def.Attack == "Strike" then
					c.Marker.Size = Vector3.new(0.2, (def.Radius or 7) * 2, (def.Radius or 7) * 2)
					c.Marker.CFrame = CFrame.new(
						region.Center.X + goal.X,
						region.Center.Y + Common.height(region, goal.X, goal.Z) + 0.2,
						region.Center.Z + goal.Z
					) * CFrame.Angles(0, 0, math.pi / 2)
					c.Marker.Transparency = 0.5
				end
			end
		else
			c.State = "Idle"
			local wander = c.Home
				+ Vector3.new(math.sin(now * 0.4 + c.Home.Z) * 6, 0, math.cos(now * 0.33 + c.Home.X) * 6)
			moveToward(wander, def.Speed * 0.35)
		end
	elseif c.State == "Windup" then
		local windup = if c.Elite then 0.9 else 1.15
		if now - c.StateAt >= windup then
			c.State, c.StateAt = "Attack", now
			telegraph(c, false)
			local damage = def.Damage + (if c.Elite then 6 else 0)
			if def.Attack == "Lunge" then
				local root = c.Target and Common.root(c.Target)
				c.LungeTo = if root then root.Position - region.Center else c.AimAt
			elseif def.Attack == "Blink" then
				-- Anomaly blinks onto its target's last position, then detonates.
				if c.AimAt and Common.support(region, c.AimAt.X, c.AimAt.Z) then
					c.Local = Vector3.new(c.AimAt.X, 0, c.AimAt.Z)
				end
				local center = region.Center
					+ c.Local
					+ Vector3.new(0, Common.height(region, c.Local.X, c.Local.Z), 0)
				for _, record in Common.near(svc, center, def.Radius or 10) do
					svc:hurt(record, damage, def.Name)
				end
				c.Marker.CFrame = CFrame.new(center.X, center.Y + 0.2, center.Z)
					* CFrame.Angles(0, 0, math.pi / 2)
			else
				local center = if def.Attack == "Strike" then region.Center + c.AimAt else world
				for _, record in Common.near(svc, center, def.Radius or 10) do
					local root = Common.root(record)
					if math.abs(root.Position.Y - center.Y) < 8 then
						svc:hurt(record, damage, def.Name)
					end
				end
				svc.Effects:FireAllClients(
					"CreatureAttack",
					{ Position = center, Kind = c.Kind, Radius = def.Radius or 10 }
				)
			end
		end
	elseif c.State == "Attack" then
		if def.Attack == "Lunge" and c.LungeTo then
			moveToward(c.LungeTo, def.Speed * 3.6)
			for _, record in
				Common.near(
					svc,
					region.Center + c.Local + Vector3.new(0, Common.height(region, c.Local.X, c.Local.Z), 0),
					4.5
				)
			do
				if not c.Struck or not c.Struck[record] then
					c.Struck = c.Struck or {}
					c.Struck[record] = true
					if now < (record.ShieldUntil or 0) and (record.ShieldHealth or 0) > 0 then
						svc:hurt(record, def.Damage, def.Name)
						if Creatures.hit(svc, c, record, 1, now) then
							return "Defeated"
						end
					else
						svc:hurt(record, def.Damage, def.Name)
					end
				end
			end
		end
		if now - c.StateAt >= 0.6 then
			c.State, c.StateAt, c.Struck, c.LungeTo = "Recover", now, nil, nil
			c.Marker.Transparency = 1
		end
	elseif c.State == "Recover" then
		if now - c.StateAt >= 1.3 then
			c.State = "Idle"
			c.ReadyAt = now + 0.4
		end
		local fromHome = c.Local - c.Home
		if fromHome.Magnitude > 50 then
			moveToward(c.Home, def.Speed)
		end
	end
	place(c, now)
	return nil
end
function Creatures.prepare(c)
	c.LastDash = c.LastDash or {}
	return c
end
return Creatures
