--!nonstrict
-- Artifact hunt: three artifacts lie in distant corners. Carry each to the pedestal.
-- A carrier who dies or leaves drops it; it returns to its resting place.
local Common = require(script.Parent.Common)
local Artifacts = {}
local C = Color3.fromRGB
local looks = {
	Idols = { C(40, 34, 40), "Basalt", "Obsidian idol" },
	Relics = { C(255, 214, 120), "Marble", "Crown relic" },
	Memories = { C(200, 140, 255), "Neon", "Memory fragment" },
}
function Artifacts.build(ctx, act)
	local S, rng, B = ctx.S, ctx.Rng, ctx.B
	local pedestal = S:find(rng, 5, { Mainland = true }, 40, function(x, z)
		return -math.sqrt(x * x + z * z) + rng:range(0, 20)
	end)
	if not pedestal then
		return false
	end
	act.Site = pedestal
	local look = looks[act.Def.Id] or looks.Relics
	local spots = table.clone(ctx.Land or { Mainland = true, Outskirts = true })
	spots.Grove = true
	act.Look = look
	B.Ground = ctx.Ground(pedestal.X, pedestal.Z)
	B.part(
		"ArtifactPedestal",
		Vector3.new(5, 2.4, 5),
		CFrame.new(ctx.World(pedestal.X, pedestal.Z, 1.2)),
		C(150, 140, 126),
		"Slate",
		{ Collide = true }
	)
	act.Sockets = {}
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2
		table.insert(
			act.Sockets,
			B.part(
				"ArtifactSocket",
				Vector3.new(1, 0.4, 1),
				CFrame.new(ctx.World(pedestal.X + math.cos(a) * 1.5, pedestal.Z + math.sin(a) * 1.5, 2.6)),
				C(60, 56, 54),
				"Slate"
			)
		)
	end
	Common.prompt(ctx, act, "Place", pedestal.X, pedestal.Z + 3.2, 2, "Place artifact", 0.3)
	Common.label(ctx, act, string.upper(act.Title) .. "\nReturn artifacts here", pedestal.X, pedestal.Z, 8)
	act.Items = {}
	for k = 1, 3 do
		local spot = S:find(rng, 3, spots, 50, function(x, z, entry)
			local d = math.sqrt((x - pedestal.X) ^ 2 + (z - pedestal.Z) ^ 2)
			return d * 0.05 + entry.Cell.Edge * 2 + rng:range(0, 2)
		end)
		if not spot then
			return false
		end
		B.Ground = ctx.Ground(spot.X, spot.Z)
		B.part(
			"ArtifactPlinth",
			Vector3.new(2.4, 0.8, 2.4),
			CFrame.new(ctx.World(spot.X, spot.Z, 0.4)),
			C(120, 112, 104),
			"Slate"
		)
		local spec = Common.prompt(ctx, act, "Take" .. k, spot.X, spot.Z, 2, "Take " .. look[3], 0.3)
		local item = spec.Part
		item.Transparency, item.Size = 0, Vector3.new(1.2, 2, 1.2)
		item.Color, item.Material = look[1], Enum.Material[look[2]]
		item.Shape = Enum.PartType.Block
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness, glow.Enabled = look[1], 10, 0.6, look[2] == "Neon"
		glow.Parent = item
		table.insert(act.Items, { Spec = spec, State = "Resting", Home = item.CFrame - ctx.Region.Center })
	end
	act.Goal = 3
	act.Hint = "Find three "
		.. look[3]:lower()
		.. "s around the realm (edges and outskirts) and carry them to the pedestal."
end
local function show(item, visible)
	item.Spec.Part.Transparency = if visible then 0 else 1
	item.Spec.Prompt.Enabled = visible
end
function Artifacts.interact(svc, act, record, spec)
	if act.Done then
		return false
	end
	if spec.Action == "Place" then
		for _, item in act.Items do
			if item.State == "Carried" and item.Carrier == record then
				item.State, item.Carrier = "Placed", nil
				act.Progress += 1
				local socket = act.Sockets[act.Progress]
				if socket and socket.Parent then
					socket.Color, socket.Material = act.Look[1], Enum.Material.Neon
				end
				svc:participate(act, record)
				if act.Progress >= act.Goal then
					svc:complete(
						act,
						"All three " .. act.Look[3]:lower() .. "s returned! The pedestal awakens.",
						"Puzzler"
					)
				else
					svc:notice(record, act.Look[3] .. " placed (" .. act.Progress .. "/3).")
					svc:update(act)
				end
				return true
			end
		end
		svc:notice(record, "Bring a " .. act.Look[3]:lower() .. " here.")
		return false
	end
	local index = tonumber(spec.Action:sub(5))
	local item = index and act.Items[index]
	if not item or item.State ~= "Resting" then
		return false
	end
	for _, other in act.Items do
		if other.Carrier == record then
			svc:notice(record, "You can only carry one artifact at a time.")
			return false
		end
	end
	item.State, item.Carrier = "Carried", record
	show(item, false)
	svc:participate(act, record)
	svc:notice(record, "Carrying a " .. act.Look[3]:lower() .. ". Bring it to the pedestal!")
	svc:update(act)
	return true
end
function Artifacts.update(_svc, act)
	for _, item in act.Items do
		if item.State == "Carried" then
			local record = item.Carrier
			local root, hum = Common.root(record)
			if
				record.State ~= "Alive"
				or not root
				or not hum
				or hum.Health <= 0
				or (root.Position - act.Region.Center).Magnitude > 260
			then
				item.State, item.Carrier = "Resting", nil
				if item.Spec.Part.Parent then
					show(item, true)
				end
			end
		end
	end
end
function Artifacts.carrying(act, record)
	for _, item in act.Items or {} do
		if item.Carrier == record then
			return true
		end
	end
	return false
end
function Artifacts.status(act)
	local carried = 0
	for _, item in act.Items do
		if item.State == "Carried" then
			carried += 1
		end
	end
	return if act.Done
		then "Restored"
		else string.format(
			"%d/3 placed%s",
			act.Progress,
			if carried > 0 then " · " .. carried .. " carried" else ""
		)
end
return Artifacts
