--!nonstrict
-- Constructor and state tests using Lune Instances. No UI rendering or input emulation.
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r = h.Roblox
local player = h:player(99)
h.Game:GetService("Players").LocalPlayer = player
local playerGui = r.Instance.new("PlayerGui")
playerGui.Parent = player
local cameraInstance = r.Instance.new("Camera")
cameraInstance.CFrame, cameraInstance.ViewportSize = r.CFrame.new(165, 110, 60), r.Vector2.new(1280, 720)
cameraInstance.Parent = h.Workspace
h.Workspace.CurrentCamera = cameraInstance
h.Game:GetService("UserInputService").TouchEnabled = false
h.Game:GetService("UserInputService").GamepadEnabled = false
local client = h.Game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Interface = h.Load(client.UI.Interface)
local Camera = h.Load(client.Controllers.CameraController)
local Audio = h.Load(client.Controllers.AudioController)
local Environment = h.Load(client.Controllers.EnvironmentController)
local Input = h.Load(client.Controllers.InputController)
local Movement = h.Load(client.Controllers.MovementController)
local requests = {}
local request = {
	FireServer = function(_, ...)
		table.insert(requests, { ... })
	end,
}
local settings = { Camera = true, Detail = true, Music = true, SFX = true }
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		error("FAIL " .. name .. ": " .. tostring(err), 0)
	end
	passed += 1
	print("PASS " .. name)
end
local ui
test("Client UI constructors use valid Roblox instance properties", function()
	ui = Interface.new(request, settings)
	assert(ui.Menu.Visible and ui.Gui.Parent == playerGui)
	assert(ui.MenuScale.Scale > 0 and ui.MenuScale.Scale <= 1)
	Input.start(request, ui)
	Movement.start(request, ui)
end)
local snapshot = {
	State = "Lobby",
	Round = "Waiting",
	Ready = true,
	Persistent = false,
	Countdown = 0,
	Altitude = 16,
	Distance = 100,
	Survival = 32,
	Biome = "Grasslands",
	BiomeName = "Sky Grasslands",
	Origin = 0,
	Cooldowns = {},
	Roster = {},
	Profile = { Best = 40, Coins = 200, Owned = {}, Equipped = "none" },
}
test("Every menu, alive HUD and elimination/spectator transition builds", function()
	ui:update(snapshot)
	for _, page in { "Help", "Settings", "Shop", "Leaderboard" } do
		ui:open(page)
		assert(ui.Panel.Visible and #ui.Body:GetChildren() > 1)
	end
	snapshot.State = "Alive"
	ui:update(snapshot)
	assert(ui.Hud.Visible and not ui.Menu.Visible)
	ui:update(snapshot)
	assert(ui.Controls.Visible)
	snapshot.Distance = 12
	snapshot.Cooldowns.Dash = 3.5
	ui:update(snapshot)
	assert(ui.Danger.Text ~= "" and ui.AbilityButtons.Dash.Text:find("3.5"))
	snapshot.Result = { Altitude = 16, Previous = 40, Coins = 3, Duration = 32, Reason = "test" }
	snapshot.State = "Eliminated"
	ui:update(snapshot)
	assert(ui.Panel.Visible and ui.Page == "Elimination")
	snapshot.State = "Spectating"
	ui:update(snapshot)
	assert(ui.Spectator.Visible)
	snapshot.State = "Queued"
	ui:update(snapshot)
	assert(ui.Menu.Visible)
end)
test("Atmosphere, audio and camera controllers initialize and update across all biomes", function()
	local audio = Audio.new(settings)
	local environment = Environment.new(settings)
	local camera = Camera.new(settings, request)
	local obstacles = h.Load(h.Server.Systems.ObstacleGenerator).new(h.Effects)
	local world = h.Load(h.Server.Systems.WorldManager).new(obstacles)
	world:reset(321)
	world.Islands[0].Landing.LocalTransparencyModifier = 0 -- Explicit engine default absent in Lune.
	world:destabilize(0, 1)
	cameraInstance.CFrame = r.CFrame.new(0, 100, 30)
	snapshot.Origin, snapshot.State = 0, "Alive"
	environment:update(0.3, snapshot)
	assert(#world.Islands[0].Cells[1].Cracks == 2)
	assert(world.Islands[0].Landing.LocalTransparencyModifier == 0, "Intact ground was hidden")
	world:rebase(1024)
	snapshot.Origin = 1024
	cameraInstance.CFrame -= r.Vector3.new(0, 1024, 0)
	environment:update(0.3, snapshot)
	assert(world.Islands[0].Cells[1].Cracks[1].Position.Y < 0)
	snapshot.Event, snapshot.EventPhase, snapshot.Sheltered = "Storm", "Active", false
	environment:update(0.3, snapshot)
	assert(environment.Weather.Rate > 0)
	snapshot.Sheltered = true
	environment:update(0.3, snapshot)
	assert(environment.Weather.Rate == 0)
	snapshot.Event, snapshot.EventPhase, snapshot.Sheltered = "Calm", "Calm", false
	snapshot.Origin = 0
	for index = 0, 9 do
		cameraInstance.CFrame = r.CFrame.new(0, 80 + index * 320, 0)
		snapshot.State, snapshot.Biome = "Alive", h.Load(h.Shared.BiomeConfig).List[index + 1].Id
		environment:update(0.3, snapshot)
		audio:update(0.1, snapshot)
	end
	snapshot.State = "Lobby"
	camera:update(0.1, snapshot)
	assert(cameraInstance.CameraType == r.Enum.CameraType.Scriptable)
	settings.Detail, settings.Music, settings.SFX = false, false, false
	environment:update(0.3, snapshot)
	audio:update(0.1, snapshot)
	assert(environment.Weather.Rate == 0 and audio.MusicGroup.Volume == 0 and audio.SFXGroup.Volume == 0)
end)
test("Adventure status stays above mobile ability controls in short landscape viewports", function()
	cameraInstance.ViewportSize = r.Vector2.new(844, 390)
	h.Game:GetService("UserInputService").TouchEnabled = true
	local compact = Interface.new(request, settings)
	snapshot.State = "Alive"
	compact:update(snapshot)
	local statusBottom = compact.Adventure.Position.Y.Offset + compact.Adventure.Size.Y.Offset
	local controlsTop = 390 + compact.Controls.Position.Y.Offset - compact.Controls.Size.Y.Offset
	assert(statusBottom < controlsTop, "Adventure status overlaps ability controls")
	compact:open("Settings")
	assert(compact.Panel.ZIndex > 1, "Modal does not layer above HUD")
	compact.Gui:Destroy()
end)
test("Storm approach is visible before damage and remains visible with detail off", function()
	local environment = Environment.new({ Detail = false, Camera = false })
	snapshot.State, snapshot.Event, snapshot.EventPhase = "Alive", "Storm", "Warning"
	snapshot.EventRemaining, snapshot.Sheltered = 8, false
	environment:update(0.3, snapshot)
	local cover = environment.Clouds.Cover
	assert(environment.Clouds.Parent:IsA("Terrain") and environment.Weather.Rate > 0)
	assert(not environment.Root:FindFirstChild("ApproachingStorm"), "Old solid storm clouds remain")
	assert(environment.CloudLayers[1].Anchor.Position.Y - cameraInstance.CFrame.Position.Y >= 240)
	environment:lightning(cameraInstance)
	environment:update(0.05, snapshot)
	assert(environment.Bolts[1].Enabled and environment.FlashLight.Brightness == 0)
	snapshot.EventRemaining = 2
	environment:update(0.3, snapshot)
	assert(environment.Clouds.Cover > cover, "Cloud cover did not build during approach")
	ui:update(snapshot)
	assert(ui.Danger.Text:find("STORM IN 2s") and ui.EventMeter.Visible)
	assert(math.abs(ui.EventMeter.Size.X.Scale - 0.225) < 0.001)
	snapshot.EventPhase, snapshot.Sheltered = "Active", true
	environment:update(0.3, snapshot)
	ui:update(snapshot)
	assert(environment.Weather.Rate == 0 and ui.Danger.Text:find("SHELTERED"))
	snapshot.Event, snapshot.EventPhase = "Calm", "Calm"
	for _ = 1, 60 do
		environment:update(0.2, snapshot)
	end
	assert(environment.StormState.Phase == "Clear" and environment.Weather.Rate == 0)
	environment.Root:Destroy()
end)
test("All ten realm HUD themes change and portable items send use intents", function()
	for _, biome in h.Load(h.Shared.BiomeConfig).List do
		snapshot.Biome, snapshot.BiomeName = biome.Id, biome.Name
		snapshot.Bag = { Timber = 4, Crystal = 2, Herb = 1 }
		snapshot.Health, snapshot.MaxHealth = 60, 100
		snapshot.PowerStatus = { Shield = 45, Glide = 3, Overcharge = 8 }
		ui:update(snapshot)
		assert(ui.ThemeColor == r.Color3.fromRGB(table.unpack(biome.Accent)))
		assert(ui.Biome.Text:find(biome.Name, 1, true))
		assert(ui.Health.Text:find("60/100") and ui.Health.Text:find("45"))
		assert(ui.AbilityButtons.Glide.Text:find("ACTIVE 3"))
	end
	for _, kind in { "Herb", "Crystal", "Timber" } do
		ui.ItemButtons[kind].Activated:Fire()
		assert(requests[#requests][1] == "UseItem" and requests[#requests][2] == kind)
	end
end)
test("Local movement applies only authorized avatar impulses and stops during transit", function()
	player:LoadCharacterAsync()
	local power = h.Load(client.Controllers.PowerController).new()
	local root = player.Character.HumanoidRootPart
	root.AssemblyLinearVelocity = r.Vector3.zero
	power:activate({ UserId = 999, Name = "Dash", Velocity = r.Vector3.new(60, 3, 0), Duration = 0.3 })
	assert(root.AssemblyLinearVelocity == r.Vector3.zero)
	power:activate({
		UserId = player.UserId,
		Name = "Dash",
		Velocity = r.Vector3.new(62, 3, 0),
		Duration = h.Load(h.Shared.GameConfig).Ability.Dash.Duration,
	})
	h:advance(0.75)
	root.AssemblyLinearVelocity = r.Vector3.new(0, -10, 0)
	power:update({ State = "Alive" })
	assert(root.AssemblyLinearVelocity.X == 62 and root.AssemblyLinearVelocity.Y == -10)
	player.Character.Humanoid:SetAttribute("Airborne", true)
	power:update({ State = "Alive", PowerStatus = { Glide = 3, Overcharge = 0 } })
	assert(root.AssemblyLinearVelocity.X == 62 and root.AssemblyLinearVelocity.Y == -9)
	h:advance(0.3)
	root.AssemblyLinearVelocity = r.Vector3.zero
	power:update({ State = "Alive" })
	assert(root.AssemblyLinearVelocity == r.Vector3.zero, "Client dash did not expire")
	power:update({ State = "Alive", Transit = true })
	assert(power.DashUntil == 0)
	power:activate({ UserId = player.UserId, Name = "Dash", Velocity = r.Vector3.new(62, 3, 0), Duration = 1 })
	player.Character.Humanoid.Health = 0
	root.AssemblyLinearVelocity = r.Vector3.zero
	power:update({ State = "Alive" })
	assert(
		power.DashUntil == 0 and root.AssemblyLinearVelocity == r.Vector3.zero,
		"Dash continued before the death snapshot arrived"
	)
end)
test("Seal keys show ownership and offer placement on mobile without adding HUD height", function()
	snapshot.State = "Alive"
	snapshot.Seal = { Sun = true, Leaf = false, Moon = true, Progress = 0, Nearby = true, Open = false }
	ui.Panel.Visible = false
	ui:update(snapshot)
	assert(ui.Adventure.Text:find("Sun [+]", 1, true))
	assert(ui.GlyphButtons.Sun.Visible and not ui.ItemButtons.Herb.Visible)
	assert(ui.GlyphButtons.Sun.Text:find("PLACE NEXT"))
	assert(ui.GlyphButtons.Leaf.Text:find("COLLECT FIRST"))
	assert(ui.Controls.Size.Y.Offset == 104)
	for _, glyph in { "Sun", "Leaf", "Moon" } do
		ui.GlyphButtons[glyph].Activated:Fire()
		assert(requests[#requests][1] == "UseGlyph" and requests[#requests][2] == glyph)
	end
	local count = #requests
	ui:open("Settings")
	ui.GlyphButtons.Sun.Activated:Fire()
	assert(#requests == count, "Modal allowed a hidden key action")
	ui:open("Menu")
	snapshot.Seal.Nearby = false
	ui:update(snapshot)
	assert(not ui.GlyphButtons.Sun.Visible and ui.ItemButtons.Herb.Visible)
	snapshot.Seal.Nearby, snapshot.Seal.Open = true, true
	ui:update(snapshot)
	assert(not ui.GlyphButtons.Sun.Visible and ui.ItemButtons.Herb.Visible)
end)
print(string.format("%d offline client tests passed (no rendering or Studio)", passed))
