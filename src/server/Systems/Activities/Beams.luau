--!nonstrict
-- Light puzzle: a crystal emitter shines through three rotatable mirrors toward a receiver.
-- The visible beam shows exactly where light currently goes, so the solution is readable.
local Common = require(script.Parent.Common)
local Beams = {}
local C = Color3.fromRGB
local layout = { { -15, 0 }, { -6, 7 }, { 3, -7 }, { 12, 7 }, { 19, -1 } }
function Beams.build(ctx, act)
	local rng, B, S = ctx.Rng, ctx.B, ctx.S
	local land = (ctx.Land or { Mainland = true, Outskirts = true })
	local site, yaw
	local function point(k)
		local p = layout[k]
		local c, s = math.cos(yaw), math.sin(yaw)
		return Vector3.new(site.X + p[1] * c - p[2] * s, 0, site.Z + p[1] * s + p[2] * c)
	end
	-- Find a center, then a rotation whose five stations all stand on clear land.
	for _ = 1, 30 do
		local candidate = S:find(rng, 8, land, 8)
		if candidate then
			table.remove(S.Circles) -- Stations reserve their own footprints below.
			site = candidate
			local placed = false
			for turn = 0, 7 do
				yaw = turn * math.pi / 4 + rng:range(0, 0.3)
				local ok = true
				for k = 1, 5 do
					local p = point(k)
					if not S:fits(p.X, p.Z, 2.5, land) then
						ok = false
						break
					end
				end
				if ok then
					placed = true
					break
				end
			end
			if placed then
				break
			end
			site = nil
		end
	end
	if not site then
		return false
	end
	act.Site = site
	for k = 1, 5 do
		local p = point(k)
		S:reserve(p.X, p.Z, 3)
	end
	act.Nodes = {}
	for k = 1, 5 do
		local p = point(k)
		act.Nodes[k] = Vector3.new(p.X, S:height(p.X, p.Z), p.Z)
	end
	local light = C(255, 246, 200):Lerp(ctx.Accent, 0.4)
	act.Light = light
	-- Emitter and receiver crystals.
	for _, k in { 1, 5 } do
		local p = act.Nodes[k]
		B.Ground = ctx.Ground(p.X, p.Z)
		B.part(
			"BeamPedestal",
			Vector3.new(3, 2, 3),
			CFrame.new(ctx.World(p.X, p.Z, 1)),
			C(120, 120, 130),
			"Slate",
			{ Collide = true }
		)
		local crystal = B.part(
			"BeamCrystal",
			Vector3.new(1.6, 2.6, 1.6),
			CFrame.new(ctx.World(p.X, p.Z, 3.3)) * CFrame.Angles(0, math.pi / 4, 0),
			if k == 1 then light else C(70, 70, 80),
			if k == 1 then "Neon" else "Glass"
		)
		if k == 5 then
			act.Receiver = crystal
		end
	end
	act.Mirrors, act.Segments = {}, {}
	for k = 2, 4 do
		local p = act.Nodes[k]
		B.Ground = ctx.Ground(p.X, p.Z)
		B.part(
			"BeamPedestal",
			Vector3.new(2.6, 1.4, 2.6),
			CFrame.new(ctx.World(p.X, p.Z, 0.7)),
			C(120, 120, 130),
			"Slate",
			{ Collide = true }
		)
		local panel = B.part(
			"BeamMirror",
			Vector3.new(3.4, 3.2, 0.3),
			CFrame.new(ctx.World(p.X, p.Z, 3)),
			C(210, 230, 255),
			"Glass",
			{ Transparency = 0.1 }
		)
		panel.Reflectance = 0.5
		local frame = B.part(
			"BeamMirror",
			Vector3.new(3.8, 0.3, 0.5),
			CFrame.new(ctx.World(p.X, p.Z, 4.7)),
			C(176, 140, 76),
			"Metal"
		)
		local nextPoint = act.Nodes[k + 1]
		local correct = math.atan2(nextPoint.Z - p.Z, nextPoint.X - p.X)
		local mirror = { Panel = panel, Frame = frame, Node = k, Correct = correct, Turn = rng:integer(1, 3) }
		table.insert(act.Mirrors, mirror)
		Common.prompt(ctx, act, "Rotate" .. (k - 1), p.X, p.Z, 2, "Rotate mirror", 0.2)
	end
	for k = 1, 4 do
		local seg = B.part(
			"LightBeam",
			Vector3.new(0.35, 0.35, 1),
			CFrame.new(ctx.World(site.X, site.Z, 3)),
			light,
			"Neon",
			{ Shadow = false, Transparency = 0.15 }
		)
		act.Segments[k] = seg
	end
	-- Chest at the receiver unlocks when light arrives.
	local r = act.Nodes[5]
	act.Chest = Common.chest(ctx, act, "Vault", r.X + 3, r.Z + 3, 0, "Open light vault")
	act.Chest.Prompt.Enabled = false
	act.Goal = 3
	Beams.render(act)
	act.Hint = "Rotate each mirror until the beam travels from the emitter crystal to the dark receiver."
end
local function place(seg, a, b)
	local length = (b - a).Magnitude
	seg.Size = Vector3.new(0.35, 0.35, math.max(0.1, length))
	seg.CFrame = CFrame.lookAt((a + b) / 2, b)
end
function Beams.render(act)
	local region = act.Region
	local function world(p)
		return region.Center + Vector3.new(p.X, 3.2 + p.Y, p.Z)
	end
	place(act.Segments[1], world(act.Nodes[1]), world(act.Nodes[2]))
	act.Segments[1].Transparency = 0.15
	local reached = 0
	local carrying = true
	for i, mirror in act.Mirrors do
		local seg = act.Segments[i + 1]
		local angle = mirror.Correct + mirror.Turn * math.pi / 2
		local p = act.Nodes[mirror.Node]
		local aim = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if mirror.Panel.Parent then
			local center = world(p)
			mirror.Panel.CFrame = CFrame.lookAt(center, center + aim) * CFrame.Angles(0, math.pi / 4, 0)
		end
		if carrying then
			if mirror.Turn == 0 then
				place(seg, world(p), world(act.Nodes[mirror.Node + 1]))
				reached += 1
			else
				place(seg, world(p), world(p) + aim * 7)
				carrying = false
			end
			seg.Transparency = 0.15
		else
			seg.Transparency = 1
		end
	end
	act.Progress = reached
	if act.Receiver.Parent then
		act.Receiver.Color = if reached == 3 then act.Light else C(70, 70, 80)
		act.Receiver.Material = if reached == 3 then Enum.Material.Neon else Enum.Material.Glass
	end
end
function Beams.interact(svc, act, record, spec)
	if spec.Action == "Vault" then
		return svc:openChest(act, record)
	end
	if act.Done then
		return false
	end
	local index = tonumber(spec.Action:sub(7))
	local mirror = index and act.Mirrors[index]
	if not mirror then
		return false
	end
	mirror.Turn = (mirror.Turn + 1) % 4
	svc:participate(act, record)
	Beams.render(act)
	if act.Progress == 3 then
		act.Chest.Prompt.Enabled = true
		svc:complete(act, "Light reaches the receiver! The light vault unlocks.", "Puzzler")
	else
		svc:update(act)
	end
	return true
end
function Beams.status(act)
	return if act.Done then "Lit" else string.format("%d/3 mirrors", act.Progress)
end
return Beams
