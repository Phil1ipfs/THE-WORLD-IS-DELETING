--!nonstrict
-- Reusable enemy AI. States: Patrol -> (detect) Chase/Stalk -> Windup (telegraph) -> Attack ->
-- Recover (opening) with Stagger, Retreat, Hidden (ambush/burrow), Dying and Gone.
-- Movement is server-owned and steered over intact terrain cells (it never walks off islands);
-- damage is server-validated against real player positions.
-- Players hurt creatures with Gust Dash contact, by dropping onto them, or by Aegis reflection,
-- subject to each creature's weakness (armor, exposed openings, aerial, hidden).
local Common = require(script.Parent.Common)
local Animated = require(script.Parent.Animated)
local Bestiary = require(script.Parent.Bestiary)
local Creatures = {}
local C = Color3.fromRGB
Creatures.Kinds = Bestiary.Defs
local ranges =
	{ Lunge = 14, Charge = 26, Slam = 9, Strike = 32, Volley = 30, Blink = 30, Dive = 40, Burrow = 28 }
local windups = {
	Lunge = 0.9,
	Charge = 1.0,
	Slam = 1.2,
	Strike = 1.1,
	Volley = 1.0,
	Blink = 0.8,
	Dive = 1.3,
	Burrow = 1.4,
}
local glowParts = {
	Eye = true,
	Core = true,
	Spike = true,
	Wing = true,
	Shard = true,
	Petal = true,
	Frill = true,
	Horn = true,
	Armor = true,
}
local function marker(parent, color)
	local ring = Instance.new("Part")
	ring.Name, ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch =
		"AttackMarker", true, false, false, false
	ring.Shape, ring.Material, ring.Color = Enum.PartType.Cylinder, Enum.Material.Neon, color
	ring.Size, ring.Transparency, ring.CastShadow = Vector3.new(0.2, 1, 1), 1, false
	ring.Parent = parent
	return ring
end
function Creatures.spawn(ctx, kind, x, z, elite, owner)
	local def = Bestiary.get(kind)
	local scale = def.Scale * (if elite then 1.35 else 1)
	local region = ctx.Region
	local position = ctx.World(x, z, def.Hover or 0)
	local fig = Animated.build(region.Model, position, Bestiary.parts(def), scale)
	fig.Model.Name = "Creature_" .. def.Id
	fig.Model:SetAttribute("Creature", def.Id)
	fig.Model:SetAttribute("Tier", def.Tier)
	local markers = {}
	for i = 1, 3 do
		markers[i] = marker(region.Model, def.Glow)
	end
	local hp = def.HP + (if elite then 3 else 0)
	local bill = Instance.new("BillboardGui")
	bill.Name, bill.Size, bill.MaxDistance, bill.AlwaysOnTop =
		"CreatureBar", UDim2.fromOffset(150, 26), 90, true
	bill.StudsOffset = Vector3.new(0, 4 * scale + (if def.Plan == "Colossus" then 9 * scale else 2), 0)
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Font, label.TextSize =
		UDim2.fromScale(1, 1), 1, Enum.Font.GothamBold, 13
	label.TextColor3 = if def.Tier == "Rare"
		then C(255, 140, 120)
		elseif def.Tier == "Elite" then C(255, 214, 120)
		else def.Glow
	label.TextStrokeTransparency = 0.3
	label.Parent = bill
	bill.Adornee, bill.Parent = fig.Parts[1], fig.Model
	local c = {
		Kind = def.Id,
		Def = def,
		Figure = fig,
		Model = fig.Model,
		Marker = markers[1],
		Markers = markers,
		Label = label,
		Elite = elite == true or def.Tier ~= "Common",
		HP = hp,
		MaxHP = hp,
		Armor = def.Armor or 0,
		Home = Vector3.new(x, 0, z),
		Local = Vector3.new(x, 0, z),
		Waypoint = Vector3.new(x, 0, z),
		State = if def.Ambush or def.Plan == "Burrower" then "Hidden" else "Patrol",
		StateAt = 0,
		Yaw = (ctx.Rng and ctx.Rng:range(0, 6.28)) or 0,
		Hitters = {},
		LastDash = {},
		AttackIndex = 0,
		Owner = owner,
		Region = region,
		Lift = 0,
	}
	Creatures.label(c)
	Creatures.place(c, 0, 0)
	return c
end
function Creatures.label(c)
	c.Label.Text = (if c.Def.Tier == "Rare" then "★ " elseif c.Def.Tier == "Elite" then "ELITE " else "")
		.. c.Def.Name
		.. "  HP "
		.. math.max(0, c.HP)
		.. "/"
		.. c.MaxHP
		.. (if c.Armor > 0 then "  ARMOR " .. c.Armor else "")
end
function Creatures.scale(c, players)
	if c.Elite and not c.Scaled then
		c.Scaled = true
		c.MaxHP += math.clamp(players - 1, 0, 5) * 2
		c.HP = c.MaxHP
		Creatures.label(c)
	end
end
local function ground(c, x, z)
	return Common.height(c.Region, x or c.Local.X, z or c.Local.Z)
end
function Creatures.world(c)
	return c.Region.Center + Vector3.new(c.Local.X, ground(c), c.Local.Z)
end
function Creatures.place(c, dt, gait)
	local bar = c.Label.Parent
	if bar then
		bar.Enabled = c.State ~= "Hidden"
	end
	local def = c.Def
	local pose
	if c.State == "Hidden" then
		pose = CFrame.new(0, -4 * c.Figure.Scale, 0)
	elseif c.State == "Stagger" then
		pose = CFrame.Angles(0.25, 0, math.sin(os.clock() * 30) * 0.08)
	elseif c.State == "Dying" then
		pose = CFrame.new(0, -math.min(1, os.clock() - c.StateAt) * 2.5, 0) * CFrame.Angles(0, 0, 0.5)
	elseif c.Crouch then
		pose = CFrame.new(0, -0.5, 0) * CFrame.Angles(0.12, 0, 0)
	end
	local y = ground(c) + (def.Hover or 0) * c.Figure.Scale / def.Scale + c.Lift
	local root = CFrame.new(c.Region.Center + Vector3.new(c.Local.X, y, c.Local.Z))
		* CFrame.Angles(0, c.Yaw, 0)
	Animated.place(c.Figure, root, dt, gait or 0, pose)
end
local function telegraph(c, on)
	Animated.tint(c.Figure, glowParts, if on then C(255, 70, 70) else nil)
end
local function hideMarkers(c)
	for _, m in c.Markers do
		if m.Parent then
			m.Transparency = 1
		end
	end
end
local function showMarker(c, i, center, radius)
	local m = c.Markers[i]
	if m and m.Parent then
		m.Size = Vector3.new(0.2, radius * 2, radius * 2)
		m.CFrame = CFrame.new(center.X, center.Y + 0.2, center.Z) * CFrame.Angles(0, 0, math.pi / 2)
		m.Transparency = 0.5
	end
end
function Creatures.remove(c)
	if c.Model.Parent then
		c.Model.Parent = nil
	end
	for _, m in c.Markers do
		m.Parent = nil
	end
	c.State = "Gone"
end
-- Applies one hit; returns true when defeated. kind: "Dash" | "Stomp" | "Reflect".
function Creatures.hit(svc, c, record, amount, now, kind)
	local def = c.Def
	if c.State == "Gone" or c.State == "Dying" or c.State == "Hidden" or now < (c.HurtUntil or 0) then
		return false
	end
	c.HurtUntil = now + 0.35
	c.Hitters[record] = true
	local boosted = now < (record.OverchargeUntil or 0)
	if def.Weakness == "Exposed" and c.State ~= "Recover" and c.State ~= "Stagger" and kind ~= "Reflect" then
		if now > (c.WarnAt or 0) then
			c.WarnAt = now + 2
			svc:notice(record, def.Name .. " is shielded. Strike right after it attacks!")
		end
		return false
	end
	if c.Armor > 0 and kind ~= "Stomp" then
		c.Armor = math.max(0, c.Armor - (if boosted then 2 else 1))
		Creatures.label(c)
		svc.Effects:FireAllClients(
			"CreatureHit",
			{ Position = Creatures.world(c), Kind = c.Kind, Armor = true }
		)
		if c.Armor > 0 and now > (c.WarnAt or 0) then
			c.WarnAt = now + 2
			svc:notice(
				record,
				"Armor cracking! Overcharged dashes (C) shatter it faster; stomps go straight through."
			)
		end
		return false
	end
	c.HP -= amount
	Creatures.label(c)
	svc.Effects:FireAllClients(
		"CreatureHit",
		{ Position = Creatures.world(c), Kind = c.Kind, Defeated = c.HP <= 0 }
	)
	if c.HP <= 0 then
		c.State, c.StateAt = "Dying", now
		telegraph(c, false)
		hideMarkers(c)
		return true
	end
	-- Knock back away from the attacker.
	local root = Common.root(record)
	if root then
		local away = Creatures.world(c) - root.Position
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude > 0.1 then
			local nextLocal = c.Local + away.Unit * (if def.StaggerResist then 2 else 5)
			if Common.support(c.Region, nextLocal.X, nextLocal.Z) then
				c.Local = nextLocal
			end
		end
	end
	telegraph(c, false)
	hideMarkers(c)
	c.Lift = 0
	if not def.StaggerResist then
		c.State, c.StateAt = "Stagger", now
	elseif c.State == "Windup" or c.State == "Attack" then
		c.State, c.StateAt = "Recover", now
	end
	if c.HP <= c.MaxHP * 0.3 and not c.Retreated and not def.StaggerResist and def.Speed > 0 then
		c.Retreated = true
		c.State, c.StateAt = "Retreat", now
	end
	return false
end
-- Followers (escorted NPCs, sheep) registered on the region can be targeted too.
local function targets(svc, c, world, radius)
	local list = {}
	for _, record in Common.near(svc, world, radius) do
		local root = Common.root(record)
		table.insert(
			list,
			{ Record = record, Position = root.Position, Distance = (root.Position - world).Magnitude }
		)
	end
	for _, follower in c.Region.Followers or {} do
		if follower.Active and follower.Active() then
			local p = follower.Position()
			local d = (p - world).Magnitude
			if d <= radius then
				table.insert(list, { Follower = follower, Position = p, Distance = d })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Distance < b.Distance
	end)
	return list
end
local function hurtAt(svc, c, center, radius, damage)
	for _, record in Common.near(svc, center, radius) do
		local root = Common.root(record)
		if math.abs(root.Position.Y - center.Y) < 9 then
			svc:hurt(record, damage, c.Def.Name)
		end
	end
	for _, follower in c.Region.Followers or {} do
		if follower.Active and follower.Active() and (follower.Position() - center).Magnitude < radius then
			follower.Hit(c)
		end
	end
	svc.Effects:FireAllClients("CreatureAttack", { Position = center, Kind = c.Kind, Radius = radius })
end
local function steer(c, goal, speed, dt)
	local delta = Vector3.new(goal.X - c.Local.X, 0, goal.Z - c.Local.Z)
	if delta.Magnitude < 0.5 or speed <= 0 then
		return 0
	end
	local dir = delta.Unit
	-- Try straight, then sidestep 45 degrees either way around gaps and edges.
	for _, angle in { 0, 0.8, -0.8, 1.6, -1.6 } do
		local d = CFrame.Angles(0, angle, 0):VectorToWorldSpace(dir)
		local nextLocal = c.Local + d * math.min(delta.Magnitude, speed * dt)
		if
			Common.support(c.Region, nextLocal.X, nextLocal.Z)
			and math.abs(ground(c, nextLocal.X, nextLocal.Z) - ground(c)) < 6
		then
			c.Local = nextLocal
			c.Yaw = math.atan2(-d.X, -d.Z)
			return 1
		end
	end
	return 0
end
local function nextAttack(c)
	c.AttackIndex = c.AttackIndex % #c.Def.Attacks + 1
	return c.Def.Attacks[c.AttackIndex]
end
-- Advances one creature; returns "Defeated" once (when it dies) or "Fell" if its ground vanished.
function Creatures.update(svc, c, dt, now)
	local def = c.Def
	if c.State == "Gone" then
		return nil
	end
	if c.State == "Dying" then
		local alpha = math.clamp(now - c.StateAt, 0, 1)
		Animated.fade(c.Figure, alpha)
		Creatures.place(c, dt, 0)
		if alpha >= 1 then
			Creatures.remove(c)
		end
		return nil
	end
	if not Common.support(c.Region, c.Local.X, c.Local.Z) then
		Creatures.remove(c)
		return "Fell"
	end
	local world = Creatures.world(c)
	local scale = c.Figure.Scale
	local reach = 7 * math.max(1, scale * 0.8)
	-- Player strikes: dash contact, falling stomp.
	for _, record in Common.near(svc, world + Vector3.new(0, (def.Hover or 0), 0), 9 + reach) do
		local root = Common.root(record)
		local offset = root.Position - (world + Vector3.new(0, (def.Hover or 0) + c.Lift, 0))
		local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
		local dashing = now < (record.DashUntil or 0) and record.DashSerial ~= c.LastDash[record]
		local stomp = offset.Y > 1 and horizontal < 4.5 * scale and root.AssemblyLinearVelocity.Y < -12
		local aerialOk = def.Weakness ~= "Aerial" or math.abs(offset.Y) < 5 * scale or stomp
		if dashing and horizontal < reach and math.abs(offset.Y) < 6 * scale and aerialOk then
			c.LastDash[record] = record.DashSerial
			local boosted = now < (record.OverchargeUntil or 0)
			if Creatures.hit(svc, c, record, if boosted then 2 else 1, now, "Dash") then
				return "Defeated"
			end
		elseif stomp and now >= (c.HurtUntil or 0) then
			if Creatures.hit(svc, c, record, 1, now, "Stomp") then
				return "Defeated"
			end
		end
	end
	local candidates = targets(svc, c, world, def.Detect)
	local target = candidates[1]
	if target then
		local fromHome = Vector3.new(
			target.Position.X - c.Region.Center.X - c.Home.X,
			0,
			target.Position.Z - c.Region.Center.Z - c.Home.Z
		)
		if fromHome.Magnitude > 75 then
			target = nil -- Leashed: never chases far from its territory.
		end
	end
	local gait = 0
	c.Crouch = false
	local state = c.State
	if state == "Hidden" then
		if target and target.Distance < (if def.Ambush then def.Detect else def.Detect * 0.8) then
			if def.Plan == "Burrower" then
				c.State, c.StateAt, c.Pending =
					"Windup", now, { Kind = "Burrow", Target = target.Position - c.Region.Center }
				showMarker(c, 1, target.Position - Vector3.new(0, 3, 0), def.Radius)
			else
				c.State, c.StateAt = "Windup", now
				c.Pending = { Kind = "Lunge", Target = target.Position - c.Region.Center }
				telegraph(c, true)
			end
		end
	elseif state == "Patrol" or state == "Chase" then
		if target then
			c.State = "Chase"
			local kind = def.Attacks[c.AttackIndex % #def.Attacks + 1]
			local range = if kind == "Slam" then def.Radius * 0.8 else ranges[kind] or 14
			if target.Distance <= range and now >= (c.ReadyAt or 0) then
				kind = nextAttack(c)
				c.State, c.StateAt = "Windup", now
				c.Pending =
					{ Kind = kind, Target = target.Position - c.Region.Center, Record = target.Record }
				telegraph(c, true)
				if kind == "Slam" then
					showMarker(c, 1, world, def.Radius)
				elseif kind == "Strike" or kind == "Dive" then
					showMarker(c, 1, target.Position - Vector3.new(0, 3, 0), def.Radius)
				elseif kind == "Volley" then
					c.Pending.Points = {}
					for i = 1, 3 do
						local p = target.Position
							- Vector3.new(0, 3, 0)
							+ Vector3.new(math.cos(i * 2.1 + now) * 5, 0, math.sin(i * 2.1 + now) * 5)
								* (if i == 1 then 0 else 1)
						table.insert(c.Pending.Points, p)
						showMarker(c, i, p, def.Radius * 0.7)
					end
				end
			elseif not def.Rooted then
				local speed = def.Speed * (if def.Erratic then 0.8 else 1)
				if def.Stalks and target.Distance > 16 then
					speed *= 0.55
					c.Crouch = true
				end
				local goal = target.Position - c.Region.Center
				if def.Erratic then
					goal += Vector3.new(math.sin(now * 2.3) * 8, 0, math.cos(now * 1.7) * 8)
				end
				gait = steer(c, goal, speed, dt)
			else
				local d = target.Position - world
				c.Yaw = math.atan2(-d.X, -d.Z)
			end
		else
			c.State = "Patrol"
			if not def.Rooted then
				if (c.Waypoint - c.Local).Magnitude < 2 or now >= (c.NextWaypoint or 0) then
					c.NextWaypoint = now + 4 + (c.HP % 3)
					local a = now * 1.7 + c.Home.X
					local candidate = c.Home + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
					if Common.support(c.Region, candidate.X, candidate.Z) then
						c.Waypoint = candidate
					end
				end
				gait = steer(c, c.Waypoint, def.Speed * 0.35, dt) * 0.4
			end
		end
	elseif state == "Windup" then
		local p = c.Pending
		local windup = (windups[p.Kind] or 1) * (if c.Def.Tier == "Rare" then 0.85 else 1)
		if p.Kind == "Dive" then
			c.Lift = math.min(10, c.Lift + dt * 12)
		elseif p.Kind == "Burrow" then
			c.Hidden = true
		end
		if now - c.StateAt >= windup then
			c.State, c.StateAt = "Attack", now
			telegraph(c, false)
			if p.Kind == "Lunge" or p.Kind == "Charge" then
				local dir = Vector3.new(p.Target.X - c.Local.X, 0, p.Target.Z - c.Local.Z)
				c.ChargeDir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
				c.Struck = {}
			elseif p.Kind == "Slam" then
				hurtAt(svc, c, world, def.Radius, def.Damage)
			elseif p.Kind == "Strike" then
				hurtAt(
					svc,
					c,
					c.Region.Center + Vector3.new(p.Target.X, ground(c, p.Target.X, p.Target.Z), p.Target.Z),
					def.Radius,
					def.Damage
				)
			elseif p.Kind == "Volley" then
				for _, point in p.Points do
					hurtAt(
						svc,
						c,
						point + Vector3.new(0, 3, 0),
						def.Radius * 0.7,
						math.floor(def.Damage * 0.6)
					)
				end
			elseif p.Kind == "Blink" or p.Kind == "Burrow" or p.Kind == "Dive" then
				local goal = Vector3.new(p.Target.X, 0, p.Target.Z)
				if Common.support(c.Region, goal.X, goal.Z) then
					c.Local = goal + (if p.Kind == "Blink" then Vector3.new(2, 0, 2) else Vector3.zero)
				end
				c.Lift = 0
				hurtAt(svc, c, Creatures.world(c) + Vector3.new(0, 2, 0), def.Radius, def.Damage)
			end
			if p.Kind == "Burrow" then
				c.State, c.StateAt = "Recover", now -- Emerged and vulnerable.
			end
		end
	elseif state == "Attack" then
		local p = c.Pending
		if (p.Kind == "Lunge" or p.Kind == "Charge") and c.ChargeDir then
			local burst = def.Speed * (if p.Kind == "Charge" then 3.2 else 3.6)
			local moved = steer(c, c.Local + c.ChargeDir * 12, burst, dt)
			gait = 1
			for _, entry in targets(svc, c, Creatures.world(c), 4.5 * math.max(1, scale * 0.8)) do
				local key = entry.Record or entry.Follower
				if not c.Struck[key] then
					c.Struck[key] = true
					if entry.Follower then
						entry.Follower.Hit(c)
					elseif now < (entry.Record.ShieldUntil or 0) and (entry.Record.ShieldHealth or 0) > 0 then
						svc:hurt(entry.Record, def.Damage, def.Name)
						if Creatures.hit(svc, c, entry.Record, 1, now, "Reflect") then
							return "Defeated"
						end
					else
						svc:hurt(entry.Record, def.Damage, def.Name)
					end
				end
			end
			if moved == 0 then
				c.ChargeDir = nil -- Stopped at an edge or obstacle.
			end
		end
		if now - c.StateAt >= (if p.Kind == "Charge" then 1 else 0.6) then
			c.State, c.StateAt, c.ChargeDir = "Recover", now, nil
			hideMarkers(c)
		end
	elseif state == "Recover" then
		c.Hidden = false
		if now - c.StateAt >= (if def.Weakness == "Exposed" then 2 else 1.3) then
			c.State = "Chase"
			c.ReadyAt = now + 0.4
			hideMarkers(c)
		end
	elseif state == "Stagger" then
		if now - c.StateAt >= 0.7 then
			c.State = "Chase"
		end
	elseif state == "Retreat" then
		local away = c.Home
		if target then
			local d = world - target.Position
			away = c.Local + Vector3.new(d.X, 0, d.Z).Unit * 10
		end
		gait = steer(c, away, def.Speed * 1.2, dt)
		if now - c.StateAt >= 3 then
			c.State = "Chase"
		end
	end
	-- Leash home when far from its territory.
	if (c.Local - c.Home).Magnitude > 60 and c.State ~= "Attack" and c.State ~= "Windup" then
		gait = steer(c, c.Home, def.Speed, dt)
	end
	Creatures.place(c, dt, gait)
	return nil
end
function Creatures.prepare(c)
	c.LastDash = c.LastDash or {}
	return c
end
return Creatures
