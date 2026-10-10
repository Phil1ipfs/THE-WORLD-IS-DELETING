--!nonstrict
-- Treasure caches in risky places. Each player opens a cache once for personal loot.
-- Ledge: a pillar only reachable with Sky Leap. Edge: at the crumbling rim (first to fall).
-- Storm: a storm-charged hoard that can only be claimed while a storm rages outdoors.
local Common = require(script.Parent.Common)
local Cache = {}
local C = Color3.fromRGB
function Cache.build(ctx, act)
	local access = act.Def.Access or "Ledge"
	local S, B, rng = ctx.S, ctx.B, ctx.Rng
	local y = 0
	local site
	if access == "Edge" and ctx.Region.IceLake then
		local lake = ctx.Region.IceLake.Position - ctx.Region.Center
		site = { X = lake.X, Z = lake.Z }
		y = 0.85
	elseif access == "Edge" then
		site = S:find(rng, 4, (ctx.Land or { Mainland = true, Outskirts = true }), 50, function(_, _, entry)
			return entry.Cell.Edge + rng:range(0, 0.05)
		end)
	else
		site = S:find(rng, 6, (ctx.Land or { Mainland = true, Outskirts = true }), 40, function(x, z)
			return math.sqrt(x * x + z * z) * 0.1 + rng:range(0, 10)
		end)
	end
	if not site then
		return false
	end
	act.Site = site
	act.Access = access
	if access == "Ledge" then
		-- Normal jumps reach ~8 studs; Sky Leap reaches ~19. The pillar top is 14 studs up.
		y = 14
		local top =
			ctx.Region.AddCell("CacheLedge", Vector3.new(8, 1.6, 8), ctx.World(site.X, site.Z, y), 0.9)
		top.Color, top.Material = C(150, 140, 126), Enum.Material.Slate
		B.Ground = top
		B.part(
			"CachePillar",
			Vector3.new(6, y - 1.4, 6),
			CFrame.new(ctx.World(site.X, site.Z, (y - 1.6) / 2)) * CFrame.Angles(0, rng:range(0, 1), 0),
			ctx.Design and C(110, 104, 98) or C(110, 104, 98),
			"Rock",
			{ Collide = true }
		)
		for k = 1, 3 do
			B.blob(
				"RealmFlora",
				Vector3.new(2.6, 0.6, 2),
				CFrame.new(ctx.World(site.X + (k - 2) * 2, site.Z + 2.6, y + 0.1)),
				C(80, 130, 70),
				"Grass"
			)
		end
		act.Hint =
			"The cache sits atop a tall pillar. Jump, then Sky Leap (jump again in midair) to reach it."
	elseif access == "Edge" then
		act.Hint = "The cache waits at the crumbling rim. Edges fall first: grab it before the deletion does."
	else
		act.Hint =
			"A storm-charged hoard: it can only be claimed during a storm. Brave the weather (Aegis helps)."
	end
	act.Chest = Common.chest(
		ctx,
		act,
		"Open",
		site.X,
		site.Z,
		y,
		"Open cache",
		if access == "Storm" then C(170, 190, 255) else nil
	)
	if access == "Storm" then
		local rod = B.part(
			"StormRod",
			Vector3.new(0.4, 10, 0.4),
			CFrame.new(ctx.World(site.X + 2.5, site.Z, 5)),
			C(170, 176, 190),
			"Metal"
		)
		act.Rod = rod
		act.Chest.Prompt.Enabled = false
	end
	if act.Hidden then
		act.RevealRadius = 40
	end
end
function Cache.update(svc, act)
	if act.Access == "Storm" then
		local storming = svc.Events and svc.Events.Name == "Storm" and svc.Events.Phase == "Active"
		act.Chest.Prompt.Enabled = storming == true
		if act.Rod and act.Rod.Parent then
			act.Rod.Material = if storming then Enum.Material.Neon else Enum.Material.Metal
		end
	end
end
function Cache.interact(svc, act, record, spec)
	if spec.Action ~= "Open" then
		return false
	end
	local opened = svc:openChest(act, record)
	act.Discovered = act.Discovered or opened
	if opened and not act.Done then
		svc:complete(act, nil)
	end
	return opened
end
function Cache.status(act, record)
	if record and act.Claims[record.Player.UserId] then
		return "Opened"
	end
	return if act.Access == "Storm" then "Storm only" elseif act.Access == "Ledge" then "Sky Leap" else "Edge"
end
return Cache
