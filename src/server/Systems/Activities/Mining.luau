--!nonstrict
-- Crystal veins: strike each vein several times. Every striker shares the yield, so a
-- group mines faster and everyone benefits.
local Common = require(script.Parent.Common)
local Props = require(script.Parent.Parent.Parent.Services.Props)
local Mining = {}
local C = Color3.fromRGB
Mining.Hits = 4
function Mining.build(ctx, act)
	local site = ctx.S:find(
		ctx.Rng,
		12,
		(ctx.Land or { Mainland = true, Outskirts = true }),
		60,
		function(_, _, entry)
			return entry.Cell.Edge + ctx.Rng:range(0, 0.3)
		end
	)
	if not site then
		return false
	end
	act.Site = site
	act.Veins = {}
	local B = ctx.B
	for k = 1, act.Def.Count or 3 do
		local a = k / 3 * math.pi * 2 + ctx.Rng:range(-0.3, 0.3)
		local x, z = site.X + math.cos(a) * 7.5, site.Z + math.sin(a) * 7.5
		B.Ground = ctx.Ground(x, z)
		Props.rock(B, ctx.World(x, z), 2.2, C(90, 96, 120), Enum.Material.Slate)
		local shards = {}
		for j = 1, 4 do
			local body = Props.shard(
				B,
				CFrame.new(ctx.World(x + (j - 2.5) * 0.9, z, 1.5))
					* CFrame.Angles(ctx.Rng:range(-0.4, 0.4), j, ctx.Rng:range(-0.4, 0.4)),
				Vector3.new(1.3, 3 + j * 0.6, 1.3),
				ctx.Accent,
				j == 2,
				"CrystalVein"
			)
			table.insert(shards, body)
		end
		local spec = Common.prompt(ctx, act, "Mine" .. k, x, z, 2.5, "Strike vein", 0.3)
		table.insert(act.Veins, { HP = Mining.Hits, Shards = shards, Spec = spec, Strikers = {} })
	end
	act.Goal = #act.Veins
	act.Hint = "Strike each vein "
		.. Mining.Hits
		.. " times. Everyone who strikes a vein shares its crystals."
end
function Mining.interact(svc, act, record, spec)
	local index = tonumber(spec.Action:sub(5))
	local vein = index and act.Veins[index]
	if not vein or vein.HP <= 0 then
		return false
	end
	vein.HP -= 1
	vein.Strikers[record] = true
	svc:participate(act, record)
	svc.Effects:FireAllClients("Mined", { Position = spec.Part.Position, Left = vein.HP })
	local shard = vein.Shards[vein.HP + 1]
	if shard and shard.Parent then
		shard.Transparency = 1
	end
	if vein.HP > 0 then
		svc:notice(record, "Crack! " .. vein.HP .. " strikes left on this vein.")
		return true
	end
	spec.Prompt.Enabled = false
	for striker in vein.Strikers do
		svc:grant(striker, "Crystal", 2)
		svc:notice(striker, "Vein shattered: +2 crystals.")
	end
	act.Progress += 1
	if act.Progress >= act.Goal then
		svc:complete(act, "Every vein is mined out!")
	else
		svc:update(act)
	end
	return true
end
function Mining.status(act)
	return if act.Done then "Mined out" else string.format("%d/%d veins", act.Progress, act.Goal)
end
return Mining
