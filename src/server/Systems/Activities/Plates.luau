--!nonstrict
-- Pressure plates: every plate must be pressed at once. A pressed plate stays latched for a
-- few seconds, so one player can dash between them; a group can simply hold them.
local Common = require(script.Parent.Common)
local Plates = {}
local C = Color3.fromRGB
Plates.Latch = 6
function Plates.build(ctx, act)
	local site = ctx.S:find(
		ctx.Rng,
		16,
		(ctx.Land or { Mainland = true, Outskirts = true }),
		60,
		function(x, z)
			return math.sqrt(x * x + z * z) * 0.3 + ctx.Rng:range(0, 25)
		end
	)
	if not site then
		return false
	end
	act.Site = site
	act.Plates = {}
	local yaw = ctx.Rng:range(0, math.pi * 2)
	local B = ctx.B
	for k = 1, 3 do
		local a = yaw + k / 3 * math.pi * 2
		local px, pz = site.X + math.cos(a) * 11.5, site.Z + math.sin(a) * 11.5
		B.Ground = ctx.Ground(px, pz)
		local rim = B.part(
			"PlateRim",
			Vector3.new(0.3, 7.2, 7.2),
			CFrame.new(ctx.World(px, pz, 0.12)) * CFrame.Angles(0, 0, math.pi / 2),
			C(110, 104, 98),
			"Slate",
			{ Shape = "Cylinder", Shadow = false }
		)
		local pad = B.part(
			"PressurePlate",
			Vector3.new(0.35, 5.6, 5.6),
			CFrame.new(ctx.World(px, pz, 0.2)) * CFrame.Angles(0, 0, math.pi / 2),
			C(80, 80, 90),
			"Slate",
			{ Shape = "Cylinder", Shadow = false }
		)
		B.part(
			"PlateRune",
			Vector3.new(0.38, 2.2, 2.2),
			CFrame.new(ctx.World(px, pz, 0.22)) * CFrame.Angles(0, 0, math.pi / 2),
			ctx.Accent,
			"Neon",
			{ Shape = "Cylinder", Shadow = false, Transparency = 0.6 }
		)
		table.insert(
			act.Plates,
			{ Pad = pad, Rim = rim, X = px, Z = pz, Y = ctx.S:height(px, pz), Until = 0 }
		)
	end
	act.Goal = 3
	local vx, vz = site.X, site.Z
	act.Vault = Common.vault(ctx, act, vx, vz, yaw + math.pi, nil)
	act.Hint = "Press all three plates within "
		.. Plates.Latch
		.. "s: dash between them, or bring friends to hold them."
end
function Plates.update(svc, act, _dt, now)
	if act.Done then
		return
	end
	local region = act.Region
	local latched = 0
	for _, plate in act.Plates do
		if plate.Pad.Parent then
			local center = region.Center + Vector3.new(plate.X, plate.Y or 0, plate.Z)
			for _, record in Common.near(svc, center + Vector3.new(0, 3, 0), 4.2) do
				plate.Until = now + Plates.Latch
				svc:participate(act, record)
			end
			local remaining = math.max(0, plate.Until - now)
			if remaining > 0 then
				latched += 1
				plate.Pad.Color = C(255, 214, 120):Lerp(C(120, 90, 50), 1 - remaining / Plates.Latch)
				plate.Pad.Material = Enum.Material.Neon
			else
				plate.Pad.Color, plate.Pad.Material = C(80, 80, 90), Enum.Material.Slate
			end
		end
	end
	if latched ~= act.Progress then
		act.Progress = latched
		svc:update(act)
	end
	if latched == #act.Plates then
		Common.setDoor(act.Vault, true)
		act.Vault.Chest.Prompt.Enabled = true
		svc:complete(act, "All plates held! The vault door grinds open.", "Puzzler")
	end
end
function Plates.interact(svc, act, record, spec)
	if spec.Action == "Vault" then
		return svc:openChest(act, record)
	end
	return false
end
function Plates.status(act)
	return if act.Done then "Vault open" else string.format("%d/3 plates", act.Progress)
end
return Plates
