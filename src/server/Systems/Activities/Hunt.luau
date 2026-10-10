--!nonstrict
-- Creature lair: defeat every creature guarding it. Elite guardians scale with players nearby.
-- A spoils chest appears for everyone once the lair is cleared.
local Common = require(script.Parent.Common)
local Creatures = require(script.Parent.Creatures)
local Hunt = {}
function Hunt.build(ctx, act)
	local site = ctx.S:find(
		ctx.Rng,
		12,
		(ctx.Land or { Mainland = true, Outskirts = true }),
		40,
		function(x, z)
			return math.sqrt(x * x + z * z) + ctx.Rng:range(0, 40)
		end
	)
	if not site then
		return false
	end
	act.Site = site
	act.Creatures = {}
	local kind = ctx.Design.Creature
	local count = act.Def.Count or 2
	for k = 1, count do
		local a = k / count * math.pi * 2
		local radius = if count > 1 then 5 else 0
		table.insert(
			act.Creatures,
			Creatures.spawn(
				ctx,
				kind,
				site.X + math.cos(a) * radius,
				site.Z + math.sin(a) * radius,
				act.Def.Elite
			)
		)
	end
	act.Goal = count
	-- Lair dressing: scattered bones/debris and a dormant spoils chest.
	local B = ctx.B
	B.Ground = ctx.Ground(site.X, site.Z)
	for k = 1, 5 do
		local a = k * 1.3
		B.part(
			"LairDebris",
			Vector3.new(ctx.Rng:range(0.6, 1.4), 0.4, ctx.Rng:range(1.4, 3)),
			CFrame.new(ctx.World(site.X + math.cos(a) * 9, site.Z + math.sin(a) * 9, 0.2))
				* CFrame.Angles(0, a, 0),
			Color3.fromRGB(220, 210, 190),
			"SmoothPlastic",
			{ Shadow = false }
		)
	end
	act.Chest = Common.chest(ctx, act, "Spoils", site.X, site.Z - 2)
	act.Chest.Prompt.Enabled = false
	act.Chest.Part.Transparency = 1
	for _, child in act.Chest.Part:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = 1
		elseif child:IsA("ParticleEmitter") then
			child.Enabled = false
		end
	end
	local name = Creatures.Kinds[kind].Name
	act.Hint = "Gust Dash through each "
		.. name
		.. " or drop onto it. Red glow = attack coming: move away or raise Aegis."
end
function Hunt.update(svc, act, dt, now)
	if act.Done then
		return
	end
	local alive = 0
	for _, c in act.Creatures do
		if c.State ~= "Gone" then
			if c.Elite then
				Creatures.scale(c, #svc:inRegion(act.Region))
			end
			local result = Creatures.update(svc, c, dt, now)
			if result == "Defeated" then
				act.Progress += 1
				for record in c.Hitters do
					svc:participate(act, record)
				end
				svc:announce(act, c.Def.Name .. " defeated!")
				svc:achieve(c.Hitters, "Hunter")
			elseif result ~= "Fell" then
				alive += 1
			end
		end
	end
	if alive == 0 then
		if act.Progress == 0 then
			svc:fail(act, "The creatures fell with the ground. The lair is gone.")
			return
		end
		act.Chest.Prompt.Enabled = true
		act.Chest.Part.Transparency = 0
		for _, child in act.Chest.Part:GetChildren() do
			if child:IsA("BasePart") then
				child.Transparency = 0
			elseif child:IsA("ParticleEmitter") then
				child.Enabled = true
			end
		end
		svc:complete(act, act.Title .. ": lair cleared! A spoils chest appeared.")
	end
end
function Hunt.interact(svc, act, record, spec)
	if spec.Action == "Spoils" then
		return svc:openChest(act, record)
	end
	return false
end
function Hunt.status(act)
	return if act.Done then "Cleared" else string.format("%d/%d defeated", act.Progress, act.Goal)
end
function Hunt.cleanup(act)
	for _, c in act.Creatures or {} do
		Creatures.remove(c)
	end
end
return Hunt
