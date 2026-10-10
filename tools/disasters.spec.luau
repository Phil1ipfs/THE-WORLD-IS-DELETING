--!nonstrict
-- Production modules and analytic geometry only; no engine rendering/physics claims.
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r, V = h.Roblox, h.Roblox.Vector3
local Config = h.Load(h.Shared.GameConfig)
local Limits = h.Load(h.Shared.DisasterConfig)
local World = h.Load(h.Server.Systems.WorldManager)
local Players = h.Load(h.Server.Systems.PlayerManager)
local Adventure = h.Load(h.Server.Systems.AdventureService)
local client = h.Game:GetService("StarterPlayer").StarterPlayerScripts.Client
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	assert(ok, "FAIL " .. name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end
local function visual(detail)
	for _, player in h.Game:GetService("Players"):GetChildren() do
		if player.Character then
			player.Character:Destroy()
		end
		player:Destroy()
	end
	local old = h.Workspace:FindFirstChild("LocalAtmosphere")
	if old then
		old:Destroy()
	end
	local clouds = h.Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds:Destroy()
	end
	for _, node in h.Game:GetService("Lighting"):GetChildren() do
		if node:IsA("Atmosphere") or node.Name == "RealmGrade" then
			node:Destroy()
		end
	end
	h.Workspace.GlobalWind = V.zero
	local player = h:player(3200 + passed)
	h.Game:GetService("Players").LocalPlayer = player
	player:LoadCharacterAsync()
	player.Character.HumanoidRootPart.Position = V.new(Config.RegionRadius, Config.StartY + 4, 0)
	local camera = r.Instance.new("Camera")
	camera.CFrame, camera.ViewportSize =
		r.CFrame.new(Config.RegionRadius, Config.StartY + 8, 18), r.Vector2.new(1280, 720)
	camera.Parent, h.Workspace.CurrentCamera = h.Workspace, camera
	local options = { Detail = detail ~= false, Camera = true }
	local env = h.Load(client.Controllers.EnvironmentController).new(options)
	local data = {
		State = "Alive",
		RegionIndex = 0,
		RoundNumber = 1,
		Origin = 0,
		Event = "Storm",
		EventPhase = "Warning",
		EventRemaining = 8,
		Sheltered = false,
		Distance = 100,
		Biome = "Grasslands",
		Roster = {},
	}
	local function step(count, dt)
		for _ = 1, count do
			h:advance(dt)
			env:update(dt, data)
		end
	end
	return env, data, camera, options, step, player
end
local function world()
	local w = World.new()
	local players = Players.new(w, h.Effects)
	local adventure = Adventure.new(w, players, h.Effects)
	w:reset(712)
	local rec = players:add(h:player(3700 + passed))
	rec.Ready = true
	players:transition(rec, "Queued")
	players:begin(rec)
	return w, players, adventure, rec
end
local function dispose(w, players, rec)
	players:remove(rec.Player)
	rec.Player:Destroy()
	for _, region in w.Islands do
		w:dispose(region)
	end
	w.Root:Destroy()
end
test("Hurricane builds a tapered, rotating, textured funnel beside the realm without solid clouds", function()
	local env, data, camera, _, step = visual()
	step(20, 0.1)
	assert(env.Hurricane.Intensity == 0 and not env.Hurricane.Strands[1].Beams[1].Enabled)
	data.EventPhase, data.EventRemaining = "Active", 0
	step(65, 0.1)
	local funnel = env.Hurricane
	assert(funnel.Intensity > 0.95 and env.StormState.Hurricane > 0.95)
	assert(not funnel.Anchor.CanCollide and not funnel.Anchor.CanQuery and funnel.Anchor.Transparency == 1)
	assert((funnel.Anchor.Position - camera.CFrame.Position).Magnitude > 180)
	local points = funnel.Strands[1].Points
	assert(points[#points].CFrame.Position.Y - points[1].CFrame.Position.Y == Limits.Hurricane.Height)
	assert(
		V.new(points[#points].CFrame.Position.X, 0, points[#points].CFrame.Position.Z).Magnitude
			> V.new(points[1].CFrame.Position.X, 0, points[1].CFrame.Position.Z).Magnitude * 4
	)
	local before = points[4].CFrame.Position
	step(1, 0.1)
	assert((before - points[4].CFrame.Position).Magnitude > 0.5, "Funnel is static")
	for _, strand in funnel.Strands do
		for _, beam in strand.Beams do
			assert(beam.Enabled and beam.Texture:find("smoke_main", 1, true))
		end
	end
	for _, node in env.Root:GetDescendants() do
		if node:IsA("BasePart") then
			assert(node.Shape ~= r.Enum.PartType.Ball)
		end
	end
end)
test("Hurricane remains world-anchored, survives rebasing, and fades during recovery/reset", function()
	local env, data, camera, _, step = visual()
	data.EventPhase, data.EventRemaining = "Active", 0
	step(60, 0.1)
	local before, intensity = env.Hurricane.Anchor.Position, env.Hurricane.Intensity
	camera.CFrame += V.new(25, 0, 0)
	step(1, 0.1)
	assert(math.abs(env.Hurricane.Anchor.Position.X - before.X) < 0.01, "Hurricane followed camera movement")
	camera.CFrame -= V.new(0, 1024, 0)
	data.Origin = 1024
	step(1, 0.1)
	assert(math.abs(env.Hurricane.Anchor.Position.Y - before.Y + 1024) < 0.001)
	assert(env.Hurricane.Intensity >= intensity - 0.01, "Rebase erased hurricane strength")
	data.Event, data.EventPhase = "Calm", "Calm"
	step(1, 0.1)
	assert(env.Hurricane.Intensity > 0.9, "Recovery snapped the funnel away")
	step(160, 0.1)
	assert(env.Hurricane.Intensity == 0 and not env.Hurricane.Strands[1].Beams[1].Enabled)
	data.Event, data.EventPhase, data.EventRemaining = "Storm", "Active", 0
	step(50, 0.1)
	data.RoundNumber, data.Event, data.EventPhase = 2, "Calm", "Calm"
	step(1, 0.1)
	assert(env.Hurricane.Intensity == 0)
	data.State, data.Event, data.EventPhase = "Lobby", "Storm", "Active"
	step(1, 0.1)
	assert(env.Hurricane.Intensity == 0)
end)
test("Low detail and shelter retain the distant hurricane with fixed reusable budgets", function()
	local env, data, _, _, step = visual(false)
	data.EventPhase, data.EventRemaining = "Active", 0
	step(60, 0.1)
	local count = #env.Root:GetDescendants()
	local beams, budget = 0, 0
	for _, strand in env.Hurricane.Strands do
		for _, beam in strand.Beams do
			if beam.Enabled then
				beams += 1
			end
		end
	end
	for _, layer in env.Hurricane.Emitters do
		budget += layer.Emitter.Rate * layer.Emitter.Lifetime.Max
	end
	assert(beams == 20 and budget < 6)
	data.Sheltered = true
	step(20, 0.1)
	assert(env.Weather.Rate == 0 and env.Hurricane.Intensity > 0.9)
	assert(#env.Root:GetDescendants() == count, "Hurricane allocated during its update loop")
end)
test("Earthquake dust starts near grounded players, stops in transit/air, and honors low detail", function()
	local env, data, _, options, step, player = visual()
	data.Event, data.EventPhase = "Earthquake", "Warning"
	step(1, 0.1)
	assert(env.QuakeDust.Rate == 0)
	data.EventPhase = "Active"
	step(1, 0.1)
	assert(
		env.QuakeDust.Rate == 14 and env.QuakeAnchor.Position.Y < player.Character.HumanoidRootPart.Position.Y
	)
	data.Sheltered = true
	step(1, 0.1)
	assert(env.QuakeDust.Rate == 5)
	player.Character.Humanoid:SetAttribute("Airborne", true)
	step(1, 0.1)
	assert(env.QuakeDust.Rate == 0)
	player.Character.Humanoid:SetAttribute("Airborne", false)
	data.Transit = true
	step(1, 0.1)
	assert(env.QuakeDust.Rate == 0)
	data.Transit, options.Detail = false, false
	step(1, 0.1)
	assert(env.QuakeDust.Rate == 0)
end)
test(
	"Earthquake cracks nearby ground and house surfaces before staged collapse, preserving refuge and exits",
	function()
		local w, p, _, rec = world()
		local region = w.Islands[0]
		local floor = region.Shelters[2].Anchor
		local focus = floor.Position + V.new(0, 4, 0)
		local cracked, surfaces = w:earthquake(0, { focus })
		assert(cracked == 12 and surfaces == 6 and #region.SeismicSurfaces == 24)
		local selected, markedFloor, markedWall = {}, false, false
		for _, seam in region.SeismicSurfaces do
			assert(
				not seam.Part.CanCollide
					and not seam.Part.CanQuery
					and seam.Part.Material ~= r.Enum.Material.Neon
			)
			if seam.Source == floor then
				markedFloor = true
			end
			if seam.Source.Name == "VillageWall" then
				markedWall = true
			end
		end
		assert(markedFloor and markedWall, "The occupied house floor/walls did not fracture")
		for _, cell in region.Cells do
			if cell.Part:GetAttribute("CrackCause") == "Earthquake" then
				table.insert(selected, cell)
				assert(cell.State == "Cracking" and #cell.Cracks == 4 and cell.Part.CanCollide)
				assert((cell.Part.Position - focus).Magnitude < 100)
			end
		end
		assert(#selected == 12)
		for _, route in { region.Routes.Approach, region.Routes.Ascent, region.Routes.Arrival } do
			for _, part in route do
				-- Walking colliders stay solid; bridge planks/hangers are visual-only by design.
				assert(
					(part.CanCollide or not part:GetAttribute("Ground"))
						and part:GetAttribute("Phase") ~= "Cracking"
				)
				if part:GetAttribute("Ground") then
					assert(part:GetAttribute("Phase") == "Stable")
				end
			end
		end
		assert(floor.CanCollide and w:sheltered(focus))
		h:advance(Config.CorruptionWarning - 0.1)
		w:consume(-100)
		assert(selected[1].Part.CanCollide)
		h:advance(0.2)
		w:consume(-100)
		assert(selected[1].State == "Breaking" and not selected[1].Part.CanCollide)
		local before = selected[1].Cracks[1].Position.Y
		h:advance(1)
		w:consume(-100)
		assert(selected[1].Cracks[1].Position.Y < before)
		h:advance(3)
		w:consume(-100)
		assert(selected[1].State == "Gone" and floor.CanCollide and w:sheltered(focus))
		dispose(w, p, rec)
	end
)
test(
	"Seismic surface seams follow their source across rebasing and clean up without repeat growth",
	function()
		local w, p, _, rec = world()
		local region = w.Islands[0]
		w:earthquake(0, { region.Shelters[1].Anchor.Position + V.new(0, 4, 0) }, 2, 2)
		local seam = region.SeismicSurfaces[1]
		local before = seam.Part.Position.Y
		w:rebase(1024)
		w:consume(-2000)
		assert(math.abs(seam.Part.Position.Y - before + 1024) < 0.001)
		assert((seam.Part.CFrame.Position - (seam.Source.CFrame * seam.Offset).Position).Magnitude < 0.001)
		h:advance(Limits.Earthquake.SurfaceLifetime + 0.1)
		w:consume(-2000)
		assert(#region.SeismicSurfaces == 0 and not seam.Part.Parent)
		dispose(w, p, rec)
	end
)
test("Earthquake respects timber braces and cracks cannot provide collectible ground support", function()
	local w, p, _, rec = world()
	local region = w.Islands[0]
	local cell
	for _, c in region.Cells do
		if not c.Late then
			cell = c
			break
		end
	end
	cell.BracedUntil = h.Time + 18
	w:warnCell(region, cell, h.Time, "Earthquake")
	assert(cell.BreakAt >= cell.BracedUntil)
	for _, crack in cell.Cracks do
		assert(not crack.CanCollide and not crack.CanQuery and not crack:GetAttribute("Ground"))
	end
	h:advance(14.1)
	w:consume(-100)
	assert(cell.State == "Cracking" and cell.Part.CanCollide)
	h:advance(4)
	w:consume(-100)
	assert(cell.State == "Breaking")
	dispose(w, p, rec)
end)
test("Event director groups occupied areas once and caps quake work across multiple realms", function()
	local calls, records = {}, {}
	for i = 1, 12 do
		local character = r.Instance.new("Model")
		local root = r.Instance.new("Part")
		root.Name, root.Position, root.Parent = "HumanoidRootPart", V.new(i * 5, 84, 0), character
		table.insert(records, { Player = { Character = character }, Region = (i - 1) % 9, State = "Alive" })
	end
	local director = h.Load(h.Server.Systems.WorldEventDirector).new({
		earthquake = function(_, index, positions, cells, surfaces)
			table.insert(calls, { Index = index, Positions = positions, Cells = cells, Surfaces = surfaces })
		end,
	}, {
		active = function()
			return records
		end,
	}, { Surge = 1 }, h.Effects)
	director.Name, director.Phase, director.Until = "Earthquake", "Warning", 99
	director:update(99)
	local cells, surfaces, players = 0, 0, 0
	for _, call in calls do
		cells += call.Cells
		surfaces += call.Surfaces
		players += #call.Positions
	end
	assert(
		#calls == 9
			and cells <= Limits.Earthquake.TotalCells
			and surfaces <= Limits.Earthquake.TotalSurfaces
			and players == 12
	)
	director:update(100)
	assert(#calls == 9, "Active earthquake applied repeatedly")
	for _, rec in records do
		rec.Player.Character:Destroy()
	end
end)
test(
	"Disaster HUD identifies the hurricane and cracked-floor danger while retaining void priority",
	function()
		local env, data, _, options, _, player = visual()
		local gui = r.Instance.new("PlayerGui")
		gui.Parent = player
		h.Game:GetService("UserInputService").TouchEnabled = false
		h.Game:GetService("UserInputService").GamepadEnabled = false
		data.Round, data.Ready, data.Countdown = "Running", true, 0
		data.Altitude, data.Survival, data.Cooldowns = 0, 10, {}
		local ui = h.Load(client.UI.Interface).new({ FireServer = function() end }, options)
		data.EventPhase = "Active"
		env.StormState.Phase, env.StormState.Hurricane = "Extreme", 0.9
		ui:update(data)
		ui:updateStorm(data, env.StormState)
		assert(ui.Danger.Text:find("HURRICANE"))
		data.Event, data.EventPhase, data.EventRemaining = "Earthquake", "Warning", 8
		ui:update(data)
		assert(ui.Danger.Text:find("EARTHQUAKE IN 8s") and ui.Danger.Text:find("INTACT GROUND"))
		data.EventPhase = "Active"
		ui:update(data)
		ui:updateStorm(data, env.StormState)
		assert(ui.Danger.Text:find("FRACTURED GROUND"))
		data.Distance = 5
		ui:update(data)
		ui:updateStorm(data, env.StormState)
		assert(ui.Danger.Text:find("VOID"))
		ui.Gui:Destroy()
	end
)
test("Cave floor, walls and the underside of its ceiling fracture toward sheltered players", function()
	local w, p, _, rec = world()
	local region = w.Islands[0]
	local caveFloor = region.Shelters[4].Anchor
	local focus = caveFloor.Position + V.new(0, 4, 0)
	w:earthquake(0, { focus })
	local floor, wall, ceiling = false, false, false
	for _, seam in region.SeismicSurfaces do
		if seam.Source == caveFloor then
			floor = true
			assert(seam.Offset.Position.Y > 0)
		end
		if seam.Source.Name == "CaveRock" then
			if seam.Source.Size.Y < 4 then
				ceiling = true
				assert(
					seam.Offset.Position.Y < -seam.Source.Size.Y / 2,
					"Ceiling seam was hidden on top of the cave"
				)
			else
				wall = true
			end
		end
	end
	assert(floor and wall and ceiling and w:sheltered(focus))
	dispose(w, p, rec)
end)
print(
	string.format(
		"%d disaster regressions passed (offline; Studio visuals/physics/performance pending)",
		passed
	)
)
