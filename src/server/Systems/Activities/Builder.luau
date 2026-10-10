--!nonstrict
-- Builds a seeded selection of the realm's activity pool into a freshly generated region.
-- Different rounds (seeds) and regions draw different subsets and sites.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Random = require(Shared.Random)
local Objectives = require(Shared.ObjectiveConfig)
local G = require(script.Parent.Parent.Parent.Services.Geometry)
local Builder = {}
Builder.Count = 4
function Builder.build(region)
	local pool = table.clone(region.Design.Activities or {})
	local rng = Random.new(region.Seed + region.Index * 3301 + 17)
	for i = #pool, 2, -1 do
		local j = rng:integer(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local ctx = {
		Region = region,
		B = region.Props,
		S = region.Sites,
		Rng = rng,
		Accent = G.color(region.Biome.Accent),
		Design = region.Design,
		-- Heights are relative to the local ground (satellite islands sit higher or lower).
		World = function(x, z, y)
			return region.Center + Vector3.new(x, (y or 0) + region.Sites:height(x, z), z)
		end,
		Land = require(script.Parent.Parent.Parent.Services.Sites).Land,
		Ground = function(x, z)
			local entry = region.Sites:at(x, z)
			return if entry then entry.Cell.Part else region.Landing
		end,
	}
	local built = 0
	for _, def in pool do
		if built >= Builder.Count then
			break
		end
		local module = script.Parent:FindFirstChild(def.Type)
		if module then
			local act = {
				Id = region.Index .. ":" .. def.Id,
				Type = def.Type,
				Def = def,
				Title = def.Title,
				Hint = Objectives.Hints[def.Type] or "",
				Hidden = def.Hidden == true,
				Done = false,
				Progress = 0,
				Goal = 1,
				Prompts = {},
				Participants = {},
				Claims = {},
				Region = region,
			}
			if require(module).build(ctx, act) ~= false then
				table.insert(region.Activities, act)
				built += 1
			end
		end
	end
	-- Survey: always present when the region has satellite sub-areas.
	if region.Satellites and #region.Satellites > 0 then
		local survey = {
			Id = region.Index .. ":Survey",
			Type = "Survey",
			Def = { Type = "Survey", Id = "Survey", Title = "Chart the frontier sub-areas" },
			Title = "Chart the frontier sub-areas",
			Hint = Objectives.Hints.Survey,
			Done = false,
			Progress = 0,
			Goal = #region.Satellites,
			Prompts = {},
			Participants = {},
			Claims = {},
			Region = region,
		}
		if require(script.Parent.Survey).build(ctx, survey) ~= false then
			table.insert(region.Activities, survey)
			built += 1
		end
	end
	region.Model:SetAttribute("Activities", built)
end
return Builder
