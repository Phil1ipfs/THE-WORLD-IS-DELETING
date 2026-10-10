--!nonstrict
-- Menu, ocean and queue regressions: exact 5-second countdown, cancel/duplicate protection,
-- server ocean death, baseplate removal, ocean coverage, menu camera clearance and menu UI.
-- Offline fixtures: no rendering, Terrain water appearance, physics or real input.
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r = h.Roblox
local V = r.Vector3
local Config = h.Load(h.Shared.GameConfig)
local Scene = h.Load(h.Shared.MenuScene)
local World = h.Load(h.Server.Systems.WorldManager)
local Players = h.Load(h.Server.Systems.PlayerManager)
local Round = h.Load(h.Server.Systems.RoundManager)
local Deletion = h.Load(h.Server.Systems.DeletionController)
local Ocean = h.Load(h.Server.Services.Ocean)
local Vista = h.Load(h.Server.Services.MenuVista)
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	assert(ok, "FAIL " .. name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end
local fills = {}
r.implementMethod("Terrain", "FillBlock", function(_, cf, size, material)
	table.insert(fills, { CFrame = cf, Size = size, Material = material })
end)
local function system()
	local world = World.new()
	world:reset(Config.Seed)
	local players = Players.new(world, h.Effects)
	local wave = Deletion.new()
	local round = Round.new(world, wave, players, h.Effects)
	return world, players, round, wave
end
local function cleanup(world, players, wave, list)
	for _, p in list do
		players:remove(p)
		p:Destroy()
	end
	world.Root:Destroy()
	wave.Part:Destroy()
end
test(
	"Queue countdown is exactly 5 seconds, starts on click and cannot be extended by repeat clicks",
	function()
		assert(Config.Intermission == 5)
		local world, players, round, wave = system()
		local p = h:player(3001)
		local record = players:add(p)
		record.Ready = true
		local start = h.Time
		round:queue(record)
		assert(record.State == "Queued" and round.State == "Intermission", "Countdown did not start on click")
		assert(math.abs(round.Ends - start - 5) < 1e-6)
		local shown = {}
		for step = 0, 4 do
			h.Time = start + step + 0.01
			table.insert(shown, math.max(0, math.ceil(round.Ends - h.Time)))
			round:queue(record) -- Repeated clicks are idempotent.
			round:update(0.1)
			assert(round.State == "Intermission", "Match started before the countdown ended")
		end
		assert(table.concat(shown, ",") == "5,4,3,2,1", "Countdown sequence was " .. table.concat(shown, ","))
		assert(math.abs(round.Ends - start - 5) < 1e-6, "Repeat clicks extended the countdown")
		h.Time = start + 4.95
		round:update(0.1)
		assert(round.State == "Intermission")
		h.Time = start + 5.01
		round:update(0.1)
		assert(round.State == "Running" and record.State == "Alive", "Match did not start at 5 seconds")
		cleanup(world, players, wave, { p })
	end
)
test("A second player joins the same countdown; cancelling leaves the queue cleanly", function()
	local world, players, round, wave = system()
	local a, b = h:player(3011), h:player(3012)
	local ra, rb = players:add(a), players:add(b)
	ra.Ready, rb.Ready = true, true
	round:queue(ra)
	local ends = round.Ends
	h:advance(2)
	round:queue(rb)
	assert(round.Ends == ends and round:queued() == 2, "Second player restarted the countdown")
	assert(round:cancel(rb) and rb.State == "Lobby" and round:queued() == 1)
	assert(round:cancel(ra) and ra.State == "Lobby")
	round:update(0.1)
	assert(round.State == "Waiting", "Empty queue kept counting down")
	assert(not round:cancel(ra), "Cancelled twice")
	cleanup(world, players, wave, { a, b })
end)
test("Falling into the ocean kills alive players once; players above the water are safe", function()
	local world, players, round, wave = system()
	local p = h:player(3021)
	local record = players:add(p)
	record.Ready = true
	round:queue(record)
	h:advance(5.1)
	round:update(0.1)
	assert(record.State == "Alive")
	local root = p.Character.HumanoidRootPart
	root.Position = V.new(0, Config.OceanY + 4, 0)
	record.LastPosition, record.LastCheck, record.SpawnGrace = root.Position, h.Time, 0
	h:advance(0.1)
	players:update(-1000)
	assert(record.State == "Alive", "Player above the water died")
	local before = #h.Events
	root.Position = V.new(0, Config.OceanY - 1, 0)
	record.LastPosition = root.Position
	h:advance(0.1)
	players:update(-1000)
	players:update(-1000)
	assert(record.State == "Eliminated" and record.Reason == "Fell into the ocean")
	local deaths = 0
	for i = before + 1, #h.Events do
		if h.Events[i][1] == "OceanDeath" then
			deaths += 1
		end
	end
	assert(deaths == 1, "Ocean death fired " .. deaths .. " times")
	assert(p.Character.Humanoid.Health == 0)
	cleanup(world, players, wave, { p })
end)
test("Lobby players who fall into the ocean die and respawn at the sanctuary; transit is exempt", function()
	local world, players, _, wave = system()
	local p = h:player(3031)
	local record = players:add(p)
	local root = p.Character.HumanoidRootPart
	root.Position = V.new(Config.LobbyX, Config.OceanY - 2, 0)
	players:oceanSweep()
	assert(p.Character.Humanoid.Health == 0 and record.OceanRespawn)
	players:oceanSweep()
	h:advance(1.6)
	assert(not record.OceanRespawn)
	local newRoot = p.Character.HumanoidRootPart
	assert(
		newRoot.Position.Y > 70 and math.abs(newRoot.Position.X - Config.LobbyX) < 20,
		"Not respawned at the sanctuary"
	)
	-- An elevator rider is server-controlled and never ocean-checked.
	record.State, record.Transit = "Alive", true
	newRoot.Position = V.new(0, Config.OceanY - 5, 0)
	players:update(-1000)
	assert(record.State == "Alive")
	record.Transit = nil
	cleanup(world, players, wave, { p })
end)
test(
	"Ocean setup removes template baseplates and fills Terrain water under every realm and the lobby",
	function()
		local baseplate = r.Instance.new("Part")
		baseplate.Name, baseplate.Parent = "Baseplate", h.Workspace
		table.clear(fills)
		local removed, filled = Ocean.setup(h.Workspace.Terrain)
		assert(removed >= 1 and not h.Workspace:FindFirstChild("Baseplate"), "Baseplate still present")
		assert(filled == #fills and #fills >= 16)
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, fill in fills do
			assert(fill.Material == r.Enum.Material.Water)
			local top = fill.CFrame.Position.Y + fill.Size.Y / 2
			assert(math.abs(top - Config.OceanY) < 1e-6, "Water surface misaligned with the death boundary")
			minX = math.min(minX, fill.CFrame.Position.X - fill.Size.X / 2)
			maxX = math.max(maxX, fill.CFrame.Position.X + fill.Size.X / 2)
			minZ = math.min(minZ, fill.CFrame.Position.Z - fill.Size.Z / 2)
			maxZ = math.max(maxZ, fill.CFrame.Position.Z + fill.Size.Z / 2)
		end
		assert(
			minX < -1200 and maxX > Config.LobbyX + 900 and minZ < -1500 and maxZ > 1500,
			"Ocean too small"
		)
		assert(Config.OceanY % 4 == 0, "Ocean surface off the voxel grid")
		assert(h.Workspace:GetAttribute("OceanY") == Config.OceanY)
	end
)
test(
	"Menu vista builds a floating village, distant islands and mountains with a clear camera orbit",
	function()
		local model = r.Instance.new("Model")
		model.Parent = h.Workspace
		local count = Vista.build(model)
		assert(count > 300 and count < 4000, "Vista part budget: " .. count)
		local names = {}
		for _, node in model:GetDescendants() do
			names[node.Name] = (names[node.Name] or 0) + 1
		end
		for _, needed in
			{
				"VistaIsland",
				"VistaWaterfall",
				"VillageWall",
				"TreeTrunk",
				"VistaMountain",
				"VistaStack",
				"VistaBridge",
				"VistaTower",
			}
		do
			assert(names[needed], "Vista lacks " .. needed)
		end
		assert(not names.Baseplate)
		local parts = {}
		for _, node in model:GetDescendants() do
			if node:IsA("BasePart") and node.Name ~= "VistaMountain" then
				table.insert(parts, node)
			end
		end
		local c = Scene.center(Config.LobbyX)
		for t = 0, 900, 0.75 do
			local p, f = Scene.camera(t, Config.LobbyX)
			local horizontal = math.sqrt((p.X - c.X) ^ 2 + (p.Z - c.Z) ^ 2)
			assert(horizontal >= Scene.MinRadius - 0.01 and horizontal <= Scene.MaxRadius + 0.01)
			assert(p.Y - c.Y >= Scene.MinHeight - 0.01 and f.Y < p.Y, "Camera not looking down at the island")
			local camera = V.new(p.X, p.Y, p.Z)
			for _, part in parts do
				local clearance = (part.Position - camera).Magnitude - part.Size.Magnitude / 2
				assert(clearance > 1, "Menu camera clips " .. part.Name .. " at t=" .. t)
			end
		end
		model:Destroy()
	end
)
local player = h:player(3041)
h.Game:GetService("Players").LocalPlayer = player
local playerGui = r.Instance.new("PlayerGui")
playerGui.Parent = player
local camera = r.Instance.new("Camera")
camera.CFrame, camera.ViewportSize = r.CFrame.new(0, 100, 0), r.Vector2.new(1280, 720)
camera.Parent, h.Workspace.CurrentCamera = h.Workspace, camera
h.Game:GetService("UserInputService").TouchEnabled = false
h.Game:GetService("UserInputService").GamepadEnabled = false
local client = h.Game:GetService("StarterPlayer").StarterPlayerScripts.Client
local requests = {}
local settings = { Detail = true, Camera = true, Music = true, SFX = true }
local ui = h.Load(client.UI.Interface).new({
	FireServer = function(_, ...)
		table.insert(requests, { ... })
	end,
}, settings)
local snapshot = {
	State = "Lobby",
	Round = "Waiting",
	Ready = true,
	Countdown = 0,
	Queued = 0,
	Altitude = 0,
	Distance = 120,
	Survival = 0,
	Biome = "Grasslands",
	BiomeName = "Sky Grasslands",
	Origin = 0,
	Cooldowns = {},
	Roster = {},
	Profile = { Best = 0, Coins = 0, Owned = {}, Equipped = "none" },
}
test("Menu shows the title, primary action and four working secondary cards", function()
	ui:update(snapshot)
	assert(ui.Menu.Visible and ui.MenuContent.Visible)
	assert(ui.TitleLines[1].Text == "THE WORLD" and ui.TitleLines[2].Text == "IS DELETING")
	for page, card in ui.MenuCards do
		card.Activated:Fire()
		assert(ui.Panel.Visible and ui.Page == page, page .. " card did not open its page")
		ui:open("Menu")
	end
	assert(ui.MenuScale.Scale > 0 and ui.MenuScale.Scale <= 1)
	camera.ViewportSize = r.Vector2.new(390, 844)
	local narrow = h.Load(client.UI.Interface).new({ FireServer = function() end }, settings)
	assert(narrow.MenuNarrow and narrow.MenuScale.Scale < 1 and narrow.MenuContent.AnchorPoint.X == 0.5)
	narrow.Gui:Destroy()
	camera.ViewportSize = r.Vector2.new(1280, 720)
end)
test("BEGIN ASCENT queues once and the card counts 5 → 1 then START with a fade", function()
	table.clear(requests)
	snapshot.State = "Lobby"
	ui:update(snapshot)
	ui.Play.Activated:Fire()
	assert(#requests == 1 and requests[1][1] == "Play")
	local ticks = {}
	ui.OnCountdown = function(n)
		table.insert(ticks, n)
	end
	snapshot.State, snapshot.Round, snapshot.Queued = "Queued", "Intermission", 1
	for n = 5, 1, -1 do
		snapshot.Countdown = n
		ui:update(snapshot)
		ui:update(snapshot)
		assert(ui.Queue.Visible and ui.QueueNumber.Text == tostring(n))
		assert(
			not ui.Queue:FindFirstChildOfClass("UIGradient"),
			"Queue card gradient would tint its contents"
		)
	end
	ui.Play.Activated:Fire()
	assert(#requests == 1, "Queued player could queue twice")
	ui.QueueCancel.Activated:Fire()
	assert(requests[#requests][1] == "Cancel")
	snapshot.State, snapshot.Round, snapshot.RegionName = "Alive", "Running", "Havenwood Reach"
	ui:update(snapshot)
	assert(ui.QueueNumber.Text == "START" and ui.Fade.Visible, "No START transition")
	assert(table.concat(ticks, ",") == "5,4,3,2,1,0", "Countdown cues were " .. table.concat(ticks, ","))
	assert(not ui.Menu.Visible)
end)
test("Menu camera follows the cinematic orbit in the lobby and hands control back in play", function()
	local cameraController = h.Load(client.Controllers.CameraController)
		.new(settings, { FireServer = function() end })
	snapshot.State = "Lobby"
	player:LoadCharacterAsync()
	cameraController:update(0.1, snapshot, nil)
	assert(camera.CameraType == r.Enum.CameraType.Scriptable)
	local p = Scene.camera(h.Time, Config.LobbyX)
	assert((camera.CFrame.Position - V.new(p.X, p.Y, p.Z)).Magnitude < 1, "Menu camera off its path")
	snapshot.State = "Alive"
	cameraController:update(0.1, snapshot, nil)
	assert(camera.CameraType == r.Enum.CameraType.Custom, "Camera not restored for gameplay")
end)
print(string.format("%d menu/ocean/queue regressions passed (offline; Studio visuals pending)", passed))
