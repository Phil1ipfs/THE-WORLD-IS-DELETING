--!nonstrict
-- Air-current course: an updraft vent launches players onto a launch platform; open Wind Sail
-- and fly through four rings in order before the timer expires.
local Common = require(script.Parent.Common)
local Rings = {}
local C = Color3.fromRGB
Rings.Window = 14
Rings.Lift = 100
function Rings.build(ctx, act)
	local S, rng, B = ctx.S, ctx.Rng, ctx.B
	local start
	for _ = 1, 40 do
		local candidate = S:find(rng, 6, { Mainland = true, Outskirts = true }, 6)
		if candidate then
			-- Course runs toward the region center so every ring hangs over land.
			local dir = Vector3.new(-candidate.X, 0, -candidate.Z)
			if dir.Magnitude > 30 then
				dir = dir.Unit
				local ok = true
				for k = 1, 4 do
					local p = Vector3.new(candidate.X, 0, candidate.Z) + dir * (14 + k * 10)
					if not S:at(p.X, p.Z) then
						ok = false
					end
				end
				if ok then
					start = { X = candidate.X, Z = candidate.Z, Dir = dir }
					break
				end
			end
		end
	end
	if not start then
		return false
	end
	act.Site = start
	-- Launch platform reached by the updraft vent beside it.
	local top = ctx.Region.AddCell("LaunchPad", Vector3.new(8, 1.4, 8), ctx.World(start.X, start.Z, 22), 0.9)
	top.Color, top.Material = C(176, 160, 130), Enum.Material.WoodPlanks
	B.Ground = top
	local tower = Instance.new("TrussPart")
	tower.Name, tower.Size, tower.Anchored = "LaunchTower", Vector3.new(2, 21, 2), true
	tower.CFrame, tower.Material, tower.Color =
		CFrame.new(ctx.World(start.X, start.Z, 10.6)), Enum.Material.Wood, C(110, 80, 56)
	tower:SetAttribute("Region", ctx.Region.Index)
	tower.Parent = ctx.Region.Model
	table.insert(ctx.Region.Structures, { Part = tower, Ground = top })
	local vent = Vector3.new(start.X, 0, start.Z) - start.Dir * 7
	act.Vent = vent
	B.Ground = ctx.Ground(vent.X, vent.Z)
	local grate = B.part(
		"UpdraftVent",
		Vector3.new(0.4, 5, 5),
		CFrame.new(ctx.World(vent.X, vent.Z, 0.15)) * CFrame.Angles(0, 0, math.pi / 2),
		C(140, 150, 160),
		"DiamondPlate",
		{ Shape = "Cylinder", Shadow = false }
	)
	B.emitter(
		grate,
		"rbxasset://textures/particles/smoke_main.dds",
		C(230, 245, 255),
		6,
		{ 1.2, 1.8 },
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) }),
		{ 18, 26 },
		{
			EmissionDirection = Enum.NormalId.Right,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
			SpreadAngle = Vector2.new(6, 6),
		}
	)
	act.Rings = {}
	for k = 1, 4 do
		local p = Vector3.new(start.X, 0, start.Z) + start.Dir * (14 + k * 10)
		local height = 24 - (14 + k * 10) * 0.36 -- Matches the Wind Sail glide slope.
		local center = ctx.World(p.X, p.Z, height)
		local frame = CFrame.lookAt(center, center + start.Dir)
		local segments = {}
		B.Ground = ctx.Ground(p.X, p.Z)
		for j = 1, 10 do
			local a = j / 10 * math.pi * 2
			table.insert(
				segments,
				B.part(
					"WindRing",
					Vector3.new(1.8, 0.5, 0.5),
					frame * CFrame.Angles(0, 0, a) * CFrame.new(0, 5, 0),
					C(200, 230, 255),
					"Neon",
					{ Shadow = false, Transparency = 0.35 }
				)
			)
		end
		table.insert(act.Rings, { Local = Vector3.new(p.X, height, p.Z), Segments = segments })
	end
	act.Next, act.Goal = 1, 4
	act.Runner = nil
	Common.label(
		ctx,
		act,
		"AIR CURRENT COURSE\nRide the vent, then glide through the rings",
		start.X,
		start.Z,
		27
	)
	act.Hint = "Step on the updraft vent, land on the platform, jump and open Wind Sail (F). Pass all rings within "
		.. Rings.Window
		.. "s."
	Rings.paint(act)
end
function Rings.paint(act)
	for k, ring in act.Rings do
		local color = if act.Done or k < act.Next
			then C(130, 255, 160)
			elseif k == act.Next then C(255, 220, 120)
			else C(200, 230, 255)
		Common.tint(ring.Segments, color)
	end
end
function Rings.update(svc, act, _dt, now)
	local region = act.Region
	-- Updraft: authorized lift applied by the owning client and allowed by movement auditing.
	local ventWorld = region.Center + Vector3.new(act.Vent.X, 2, act.Vent.Z)
	for _, record in Common.near(svc, ventWorld, 4) do
		if now >= (record.UpdraftAt or 0) then
			record.UpdraftAt = now + 1.5
			record.MovementUntil = math.max(record.MovementUntil or 0, now + 2.5)
			svc.Effects:FireClient(record.Player, "Updraft", { Lift = Rings.Lift, Position = ventWorld })
		end
	end
	if act.Done then
		return
	end
	if act.Runner and now > act.Deadline then
		svc:notice(act.Runner, "Too slow: the air current faded. Try the course again.")
		act.Runner, act.Next = nil, 1
		Rings.paint(act)
		svc:update(act)
	end
	local ring = act.Rings[act.Next]
	if not ring then
		return
	end
	for _, record in Common.near(svc, region.Center + ring.Local, 6) do
		if act.Next == 1 then
			act.Runner, act.Deadline = record, now + Rings.Window
		end
		if record == act.Runner then
			act.Next += 1
			act.Progress = act.Next - 1
			svc:participate(act, record)
			if act.Next > #act.Rings then
				svc:complete(act, record.Player.DisplayName .. " mastered the air currents!")
			else
				svc:update(act)
			end
			Rings.paint(act)
			break
		end
	end
end
function Rings.interact()
	return false
end
function Rings.status(act)
	return if act.Done then "Mastered" else string.format("%d/4 rings", act.Progress)
end
return Rings
