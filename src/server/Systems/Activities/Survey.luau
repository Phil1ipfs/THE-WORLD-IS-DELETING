--!nonstrict
-- Survey: a cairn stands on every satellite sub-area. Charting one pays a small reward;
-- charting all of them (per player) pays the survey reward including a perk.
local Common = require(script.Parent.Common)
local Objectives = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").ObjectiveConfig)
local Survey = {}
local C = Color3.fromRGB
function Survey.build(ctx, act)
	local region, B = ctx.Region, ctx.B
	act.Cairns, act.Charts = {}, {}
	for i, sat in region.Satellites do
		local site = ctx.S:find(ctx.Rng, 3, { [sat.Kind] = true }, 40, function(x, z)
			return -math.sqrt((x - sat.X) ^ 2 + (z - sat.Z) ^ 2)
		end)
		if site then
			B.Ground = ctx.Ground(site.X, site.Z)
			for k = 0, 2 do
				B.part(
					"SurveyCairn",
					Vector3.new(2.4 - k * 0.6, 0.9, 2.2 - k * 0.5),
					CFrame.new(ctx.World(site.X, site.Z, 0.45 + k * 0.85)) * CFrame.Angles(0, k * 0.7, 0),
					C(140, 134, 124),
					"Slate"
				)
			end
			B.part(
				"SurveyCairn",
				Vector3.new(0.25, 6, 0.25),
				CFrame.new(ctx.World(site.X + 0.6, site.Z, 3)),
				C(110, 80, 56),
				"Wood"
			)
			B.part(
				"SurveyFlag",
				Vector3.new(0.1, 1.3, 2.2),
				CFrame.new(ctx.World(site.X + 0.6, site.Z + 1.1, 5.3)),
				ctx.Accent,
				"Fabric"
			)
			local spec =
				Common.prompt(ctx, act, "Chart" .. i, site.X + 2.5, site.Z, 2, "Chart " .. sat.Name, 0.4)
			act.Cairns[i] = { Spec = spec, Name = sat.Name }
		end
	end
	if #act.Cairns == 0 then
		return false
	end
	act.Goal = #act.Cairns
	act.Hint = "Cross the rope bridges and chart every frontier sub-area: "
		.. table.concat(
			(function()
				local names = {}
				for _, cairn in act.Cairns do
					table.insert(names, cairn.Name)
				end
				return names
			end)(),
			", "
		)
		.. "."
end
local function charted(act, record)
	local set = act.Charts[record.Player.UserId]
	local count = 0
	for _ in set or {} do
		count += 1
	end
	return count, set
end
function Survey.interact(svc, act, record, spec)
	local index = tonumber(spec.Action:sub(6))
	local cairn = index and act.Cairns[index]
	if not cairn then
		return false
	end
	local id = record.Player.UserId
	act.Charts[id] = act.Charts[id] or {}
	if act.Charts[id][index] then
		svc:notice(record, cairn.Name .. " is already on your map.")
		return false
	end
	act.Charts[id][index] = true
	local count = charted(act, record)
	svc:reward(record, { Coins = 5, XP = 12 }, "Charted " .. cairn.Name)
	if count < act.Goal then
		svc:notice(record, string.format("Charted %s (%d/%d).", cairn.Name, count, act.Goal))
		return true
	end
	act.Claims[id] = true
	svc:participate(act, record)
	if not act.Done then
		svc:complete(act, record.Player.DisplayName .. " charted the whole frontier!")
	else
		svc:reward(record, Objectives.Rewards.Survey, act.Title)
	end
	return true
end
function Survey.status(act, record)
	if not record then
		return string.format("%d sub-areas", act.Goal)
	end
	return string.format("%d/%d charted", charted(act, record), act.Goal)
end
return Survey
