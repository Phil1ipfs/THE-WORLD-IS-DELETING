--!nonstrict
-- Suspension bridges and realm expansion: plank decks, curvature, invisible walkable colliders,
-- ropes/posts, sway tagging and client sway, satellite sub-areas, bridges to them, survey
-- charting, height-correct content and deletion pacing. Offline fixtures only.
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r = h.Roblox
local V = r.Vector3
local Config = h.Load(h.Shared.GameConfig)
local Rules = h.Load(h.Shared.Rules)
local Bridge = h.Load(h.Server.Services.SuspensionBridge)
local World = h.Load(h.Server.Systems.WorldManager)
local Players = h.Load(h.Server.Systems.PlayerManager)
local Adventure = h.Load(h.Server.Systems.AdventureService)
local Objectives = h.Load(h.Server.Systems.ObjectiveService)
local Rewards = h.Load(h.Server.Systems.RewardManager)
local RNG = h.Load(h.Shared.Random)
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	assert(ok, "FAIL " .. name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end
local profiles = {}
local data = {
	get = function(_, player)
		profiles[player] = profiles[player] or Rules.profile(nil)
		return profiles[player]
	end,
}
local world = World.new()
local players = Players.new(world, h.Effects)
local rewards = Rewards.new(data, h.Effects)
local adventure = Adventure.new(world, players, h.Effects, rewards)
local objectives = Objectives.new(world, players, h.Effects, rewards, data)
adventure.Objectives, objectives.Adventure = objectives, adventure
world:reset(Config.Seed)
local region = world.Islands[0]
local params = { FilterDescendantsInstances = { world.Root } }
local function down(position, depth)
	return h.Workspace:Raycast(position, V.new(0, -(depth or 7), 0), params)
end
test(
	"Bridge builder makes separate gapped planks on a gentle curve with an invisible walkable deck",
	function()
		local folder = r.Instance.new("Model")
		folder.Parent = h.Workspace
		local a, b = V.new(0, 100, 0), V.new(0, 160, 300)
		local colliders = {}
		local built = Bridge.build({
			Parent = folder,
			A = a,
			B = b,
			Width = 10,
			Name = "TestDeck",
			Rng = RNG.new(5),
			Ground = function(c)
				table.insert(colliders, c)
			end,
		})
		local planks, ropes, posts, hangers = {}, 0, 0, 0
		for _, p in built.Parts do
			if p.Name == "BridgePlank" then
				table.insert(planks, p)
				assert(not p.CanCollide and p:GetAttribute("Sway") and p:GetAttribute("SwayDir"))
			elseif p.Name == "BridgeRope" then
				ropes += 1
			elseif p.Name == "BridgePost" then
				posts += 1
			elseif p.Name == "BridgeHanger" then
				hangers += 1
			end
		end
		assert(#planks >= 120, "Too few planks: " .. #planks)
		assert(ropes >= 20 and hangers >= 20 and posts == 4, "Missing ropes, hangers or anchor posts")
		-- Consecutive planks leave visible gaps.
		for i = 2, #planks do
			local gap = (planks[i].Position - planks[i - 1].Position).Magnitude
			assert(
				gap > planks[i].Size.Z * 0.98 and gap < Bridge.Pitch * 1.4,
				"Plank spacing broken at " .. i
			)
		end
		-- Gentle sag: the deck midpoint sits a little below the straight chord, never a deep dip.
		local mid = planks[math.floor(#planks / 2)].Position
		local chordY = a.Y + (b.Y - a.Y) * ((mid.Z - a.Z) / (b.Z - a.Z))
		assert(chordY - mid.Y > 2 and chordY - mid.Y < 10, "Sag out of range: " .. (chordY - mid.Y))
		-- Invisible colliders form the walking surface and stay under every plank.
		local localParams = { FilterDescendantsInstances = { folder } }
		for _, c in colliders do
			assert(
				c.Transparency == 1
					and c.CanCollide
					and c:GetAttribute("Ground")
					and not c:GetAttribute("Sway")
			)
		end
		-- Sampled at collider centers: the Lune fixture's CFrame.lookAt mirrors local Z, so tilted
		-- boxes are only reliable at their centers offline (Roblox lookAt is correct).
		for _, c in colliders do
			local top = c.Position + V.new(0, 3, 0)
			local hit = h.Workspace:Raycast(top, V.new(0, -5, 0), localParams)
			assert(hit and hit.Instance.Name == "TestDeck", "No walkable deck at collider")
			local nearest, best = nil, math.huge
			for _, plank in planks do
				local d = (
					V.new(plank.Position.X, 0, plank.Position.Z) - V.new(c.Position.X, 0, c.Position.Z)
				).Magnitude
				if d < best then
					nearest, best = plank, d
				end
			end
			assert(math.abs(hit.Position.Y - nearest.Position.Y) < 0.8, "Deck surface far from planks")
		end
		-- Endpoints join the islands exactly.
		assert((planks[1].Position - a).Magnitude < 3 and (planks[#planks].Position - b).Magnitude < 3)
		folder:Destroy()
	end
)
test("The sky causeway and island crossings are suspension bridges that stay walkable end to end", function()
	local planks = 0
	for _, p in region.Routes.Ascent do
		planks += if p.Name == "BridgePlank" then 1 else 0
	end
	assert(planks > 100, "Causeway is not a plank suspension bridge")
	for _, route in { region.Routes.Ascent, region.Routes.Grove, region.Routes.Cave } do
		for _, p in route do
			if p:GetAttribute("Ground") then
				assert(p.Transparency == 1, "Collider visible")
				local foot = p.CFrame:PointToWorldSpace(V.new(0, p.Size.Y / 2, 0))
				local hit = down(foot + V.new(0, 3, 0))
				assert(
					hit and hit.Instance:GetAttribute("Ground"),
					"Gap in bridge walking surface at "
						.. p.Name
						.. " hit "
						.. tostring(hit and hit.Instance:GetFullName())
				)
			end
		end
	end
end)
test("Every region gains named sub-areas joined by rope bridges, with signposts and supplies", function()
	for index = 0, 2 do
		local reg = world.Islands[index]
		assert(#reg.Satellites >= 3, "Region " .. index .. " lacks sub-areas")
		for _, sat in reg.Satellites do
			assert(sat.Name and sat.Name ~= sat.Kind, "Sub-area unnamed")
			local cells = 0
			for _, c in reg.Cells do
				if c.Part.Name == "Earth_" .. sat.Kind then
					cells += 1
					local top = c.Part.Position.Y + c.Part.Size.Y / 2 - reg.Center.Y
					assert(math.abs(top - sat.Height) < 0.01, "Sub-area at wrong elevation")
				end
			end
			assert(cells >= 9)
			local bridge = reg.Routes.Satellites[sat.Kind]
			local colliders = {}
			for _, p in bridge do
				if p:GetAttribute("Ground") then
					table.insert(colliders, p)
				end
			end
			assert(#colliders >= 3, "Sub-area bridge missing")
			-- Both bridge ends meet walkable ground of their landmass.
			local first = colliders[1].CFrame:PointToWorldSpace(V.new(0, 0.5, colliders[1].Size.Z / 2 - 1))
			local last = colliders[#colliders].CFrame:PointToWorldSpace(
				V.new(0, 0.5, -colliders[#colliders].Size.Z / 2 + 1)
			)
			assert(math.abs(first.Y - reg.Center.Y - 0.2) < 1.5, "Bridge does not start at mainland level")
			assert(
				math.abs(last.Y - reg.Center.Y - sat.Height - 0.2) < 1.5,
				"Bridge does not reach the sub-area"
			)
		end
		local signs = 0
		for _, node in reg.Model:GetChildren() do
			signs += if node.Name == "Signpost" then 1 else 0
		end
		assert(signs >= #reg.Satellites * 2, "Bridge heads lack signposts")
	end
end)
test("Content on elevated sub-areas sits on their surface, never inside or above the island", function()
	local checked = 0
	for _, reg in world.Islands do
		for _, spec in reg.Interactions do
			local entry =
				reg.Sites:at(spec.Part.Position.X - reg.Center.X, spec.Part.Position.Z - reg.Center.Z)
			if entry and entry.Height ~= 0 then
				local above = spec.Part.Position.Y - (reg.Center.Y + entry.Height)
				assert(above > 0 and above < 18, "Interaction misplaced on " .. entry.Zone .. ": " .. above)
				checked += 1
			end
		end
	end
	assert(checked >= 6, "No content reached the sub-areas")
end)
test("Survey cairns can be charted by one player; charting every sub-area pays a perk", function()
	local survey
	for _, act in region.Activities do
		if act.Type == "Survey" then
			survey = act
		end
	end
	assert(survey and survey.Goal == #region.Satellites)
	world:activate(0)
	local p = h:player(5001)
	local rec = players:add(p)
	rec.Ready = true
	players:transition(rec, "Queued")
	players:begin(rec)
	rec.Region = 0
	for i = 1, survey.Goal do
		local spec = survey.Prompts["Chart" .. i]
		local root = p.Character.HumanoidRootPart
		root.Position = spec.Part.Position + V.new(0, 1.5, 0)
		rec.LastPosition, rec.LastCheck = root.Position, h.Time
		h:advance(0.6)
		assert(adventure:interact(rec, region, spec), "Chart " .. i .. " rejected")
	end
	assert(survey.Claims[p.UserId] and rec.Perks and next(rec.Perks), "Survey reward missing")
	local row
	for _, entry in objectives:status(rec).Activities do
		if entry.Type == "Survey" then
			row = entry
		end
	end
	assert(row.Done and row.Progress:find(survey.Goal .. "/" .. survey.Goal, 1, true))
	players:remove(p)
end)
test("Falling bridge colliders stay invisible; sub-areas warn before the core; lifetime is 240s", function()
	assert(Config.RegionLifetime == 240)
	local collider
	for _, c in region.Cells do
		if c.Part.Name == "ForestBridge" then
			collider = c
			break
		end
	end
	world:warnCell(region, collider, h.Time)
	h:advance(Config.CorruptionWarning + 0.1)
	world:consume(-1000)
	h:advance(1)
	world:consume(-1000)
	assert(
		collider.State == "Breaking" and collider.Part.Transparency == 1,
		"Collider became visible while falling"
	)
	local coreEdge, satEdge = 1, 0
	for _, c in region.Cells do
		local name = c.Part.Name
		if name == "Earth_Mainland" then
			coreEdge = math.min(coreEdge, c.Edge)
		elseif
			name:sub(1, 6) == "Earth_"
			and name ~= "Earth_Grove"
			and name ~= "Earth_Cave"
			and name ~= "Earth_Outskirts"
		then
			satEdge = math.max(satEdge, c.Edge)
		end
	end
	assert(satEdge > 0.9 and coreEdge < 0.3, "Sub-areas should fall before the core")
end)
local client = h.Game:GetService("StarterPlayer").StarterPlayerScripts.Client
local player = h:player(5101)
h.Game:GetService("Players").LocalPlayer = player
local camera = r.Instance.new("Camera")
camera.Parent, h.Workspace.CurrentCamera = h.Workspace, camera
test("Clients sway visible planks and ropes sideways while colliders stay fixed", function()
	local reg = world.Islands[0]
	camera.CFrame = r.CFrame.new(reg.Center + V.new(80, 30, 20))
	local env = h.Load(client.Controllers.EnvironmentController).new({ Detail = true, Camera = true })
	local snapshot = {
		State = "Alive",
		Origin = 0,
		Event = "Calm",
		EventPhase = "Calm",
		Distance = 200,
		Biome = "Grasslands",
		Roster = {},
	}
	local plank, collider
	for _, p in reg.Routes.Grove do
		if p.Name == "BridgePlank" and math.abs(p:GetAttribute("Sway") - 0.5) < 0.2 then
			plank = p
		elseif p:GetAttribute("Ground") then
			collider = p
		end
	end
	env:update(0.3, snapshot)
	local plankBefore, colliderBefore = plank.Position, collider.CFrame
	for _ = 1, 10 do
		h:advance(0.13)
		env:update(0.13, snapshot)
	end
	local moved = (plank.Position - plankBefore).Magnitude
	assert(moved > 0.01 and moved < 1, "Sway missing or excessive: " .. moved)
	assert(collider.CFrame == colliderBefore, "Collision surface moved")
end)
print(string.format("%d bridge/expansion regressions passed (offline; Studio visuals/feel pending)", passed))
