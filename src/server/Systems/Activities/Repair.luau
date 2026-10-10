--!nonstrict
-- Cooperative machine repair. Shared contributions; finishing changes the realm:
-- Windmill opens mill stores, Resonator overcharges everyone, Pump cools lava,
-- Beacon reveals hidden caches, generators fortify shelters (and speed the elevator).
local Common = require(script.Parent.Common)
local Props = require(script.Parent.Parent.Parent.Services.Props)
local Repair = {}
local C = Color3.fromRGB
local function machine(ctx, act, x, z)
	local B, id = ctx.B, act.Def.Id
	local w = ctx.World
	B.Ground = ctx.Ground(x, z)
	local moving, lights = {}, {}
	if id == "Windmill" then
		B.part(
			"Machine",
			Vector3.new(7, 2, 7),
			CFrame.new(w(x, z, 1)),
			C(120, 112, 104),
			"Cobblestone",
			{ Collide = true }
		)
		B.part(
			"Machine",
			Vector3.new(5, 16, 5),
			CFrame.new(w(x, z, 10)),
			C(226, 214, 190),
			"Plaster",
			{ Collide = true }
		)
		B.cone("Machine", w(x, z, 18), 4.2, 5, C(150, 72, 52), "RoofShingles", 0.4)
		local hub = B.part(
			"MachineHub",
			Vector3.new(1.2, 1.6, 1.6),
			CFrame.new(w(x, z - 3, 15)) * CFrame.Angles(0, math.pi / 2, 0),
			C(90, 64, 44),
			"Wood",
			{ Shape = "Cylinder" }
		)
		hub:SetAttribute("SpinKey", act.Id)
		table.insert(moving, hub)
		for k = 0, 3 do
			local blade = B.part(
				"MachineBlade",
				Vector3.new(1.4, 9, 0.2),
				CFrame.new(w(x, z - 3.5, 15))
					* CFrame.Angles(0, 0, k * math.pi / 2 + 0.3)
					* CFrame.new(0, 4.8, 0),
				C(196, 180, 150),
				"Fabric"
			)
			blade:SetAttribute("SpinKey", act.Id)
			if k == 1 then
				blade.CFrame = CFrame.new(w(x + 3, z - 2, 1)) * CFrame.Angles(0.2, 0.4, math.pi / 2)
				blade:SetAttribute("SpinKey", nil)
				act.Broken = blade
			end
			table.insert(moving, blade)
		end
	elseif
		id == "Resonator"
		or id == "Beacon"
		or id == "Generator"
		or id == "StormGenerator"
		or id == "Pump"
	then
		local metal = if id == "Beacon" then C(110, 90, 70) else C(120, 126, 134)
		B.part(
			"Machine",
			Vector3.new(8, 1.2, 8),
			CFrame.new(w(x, z, 0.6)),
			C(90, 92, 96),
			if id == "Beacon" then "Slate" else "DiamondPlate",
			{ Collide = true }
		)
		B.part(
			"Machine",
			Vector3.new(4.5, 6, 4.5),
			CFrame.new(w(x, z, 4)),
			metal,
			if id == "Beacon" then "WoodPlanks" else "CorrodedMetal",
			{ Collide = true }
		)
		local core = B.part(
			"MachineCore",
			Vector3.new(2.4, 2.4, 2.4),
			CFrame.new(w(x, z, 8.6)),
			C(60, 60, 66),
			"Glass",
			{ Shape = "Ball" }
		)
		table.insert(lights, core)
		for k = 1, 4 do
			local a = k / 4 * math.pi * 2
			local coil = B.part(
				"MachineCoil",
				Vector3.new(0.6, 5, 0.6),
				CFrame.new(w(x + math.cos(a) * 3.2, z + math.sin(a) * 3.2, 4)),
				C(160, 120, 70),
				"Metal"
			)
			table.insert(lights, coil)
		end
		if id == "Pump" or id == "Generator" or id == "StormGenerator" then
			table.insert(
				moving,
				Props.gear(
					B,
					CFrame.new(w(x - 3, z, 5)) * CFrame.Angles(0, math.pi / 2, 0),
					2,
					C(176, 140, 76),
					"MachineHub"
				)
			)
			B.limb("Machine", w(x + 2.2, z, 2), w(x + 8, z, 2), 1.2, C(110, 104, 96), "CorrodedMetal")
		end
		if id == "Beacon" then
			B.cone("Machine", w(x, z, 7), 3, 2.4, C(120, 90, 60), "WoodPlanks", 0)
		end
	end
	act.Moving, act.Lights = moving, lights
end
function Repair.build(ctx, act)
	local site = ctx.S:find(
		ctx.Rng,
		9,
		(ctx.Land or { Mainland = true, Outskirts = true }),
		40,
		function(x, z)
			return math.sqrt(x * x + z * z) * 0.2 + ctx.Rng:range(0, 20)
		end
	)
	if not site then
		return false
	end
	act.Need = table.clone(act.Def.Cost or { Timber = 4 })
	act.Goal = 0
	for _, amount in act.Need do
		act.Goal += amount
	end
	act.Site = site
	machine(ctx, act, site.X, site.Z)
	local cost = {}
	for kind, amount in act.Need do
		table.insert(cost, amount .. " " .. kind:lower())
	end
	table.sort(cost)
	Common.prompt(ctx, act, "Contribute", site.X, site.Z + 5.5, 2, "Contribute supplies", 0.35)
	Common.label(
		ctx,
		act,
		string.upper(act.Title) .. "\nNeeds " .. table.concat(cost, " + ") .. " (shared)",
		site.X,
		site.Z,
		13
	)
	act.Hint = "Bring " .. table.concat(cost, " + ") .. ". Anyone can contribute; the reward is shared."
end
function Repair.interact(svc, act, record, spec)
	if act.Done then
		if act.Stores and not act.Stores[record.Player.UserId] then
			act.Stores[record.Player.UserId] = true
			svc:grant(record, "Herb", 2)
			svc:grant(record, "Timber", 2)
			svc:notice(record, "Mill stores: +2 herbs, +2 timber.")
			return true
		end
		svc:notice(record, "Already repaired.")
		return false
	end
	local bag = record.Bag
	local gave = 0
	for kind, remaining in act.Need do
		local amount = math.min(remaining, bag[kind] or 0, 2)
		if amount > 0 then
			bag[kind] -= amount
			act.Need[kind] -= amount
			gave += amount
		end
	end
	if gave == 0 then
		local missing = {}
		for kind, remaining in act.Need do
			if remaining > 0 then
				table.insert(missing, remaining .. " " .. kind:lower())
			end
		end
		table.sort(missing)
		svc:notice(record, "This machine still needs " .. table.concat(missing, " + ") .. ".")
		return false
	end
	svc:participate(act, record)
	act.Progress += gave
	if act.Progress >= act.Goal then
		Repair.finish(svc, act)
	else
		svc:notice(record, string.format("Repair progress %d/%d. Others can help.", act.Progress, act.Goal))
		svc:update(act)
	end
	local _ = spec
	return true
end
function Repair.finish(svc, act)
	local region, id = act.Region, act.Def.Id
	for _, p in act.Moving do
		if p.Parent then
			p:SetAttribute("Spin", if id == "Windmill" then 0.9 else 2)
		end
	end
	if act.Broken and act.Broken.Parent then
		act.Broken.Parent = nil
	end
	Common.tint(act.Lights, region.Props and C(130, 240, 255) or C(130, 240, 255), Enum.Material.Neon)
	local text
	if id == "Windmill" then
		act.Stores = {}
		local spec = act.Prompts.Contribute
		spec.Prompt.ActionText = "Collect mill stores"
		text = "The windmill turns! Mill stores open: everyone can collect herbs and timber here."
	elseif id == "Resonator" then
		for _, record in svc:inRegion(region) do
			record.OverchargeUntil = math.max(record.OverchargeUntil or 0, os.clock() + 15)
			svc:grant(record, "Crystal", 1)
		end
		text = "The resonator sings: everyone in the realm is overcharged for 15s (+1 crystal)."
	elseif id == "Pump" then
		for _, hazard in region.Hazards do
			if hazard.Kind == "Lava" then
				hazard.Disabled = true
				if hazard.Part.Parent then
					hazard.Part.Color, hazard.Part.Material = C(60, 48, 46), Enum.Material.CrackedLava
				end
			end
		end
		text = "Coolant flows: the magma pools have cooled and are safe to cross."
	elseif id == "Beacon" then
		for _, other in region.Activities do
			other.Discovered = true
		end
		text = "The beacon blazes: hidden caches in this realm are revealed."
	else
		region.ShelterPowered = true
		if id == "Generator" then
			region.ExpressLift = true
		end
		text = "Power restored: shelters are fortified against storm breaches and heal occupants"
			.. (if id == "Generator" then "; the sky elevator runs express." else ".")
	end
	svc:complete(act, text)
	if id ~= "Windmill" then
		act.Prompts.Contribute.Prompt.Enabled = false
	end
end
function Repair.status(act)
	return if act.Done then "Repaired" else string.format("%d/%d supplies", act.Progress, act.Goal)
end
return Repair
