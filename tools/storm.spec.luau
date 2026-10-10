--!nonstrict
-- Object/state regression coverage. No rendering, GPU benchmark or actual audio playback.
local Harness = require("./OfflineHarness")
local fixture = Harness.new() -- Lune service implementations register once per process.
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	assert(ok, "FAIL " .. name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end
local function setup(detail, motion)
	local h = fixture
	local r = h.Roblox
	for _, old in h.Game:GetService("Players"):GetChildren() do
		if old.Character then
			old.Character:Destroy()
		end
		old:Destroy()
	end
	local oldRoot = h.Workspace:FindFirstChild("LocalAtmosphere")
	if oldRoot then
		oldRoot:Destroy()
	end
	local clouds = h.Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds:Destroy()
	end
	local lighting = h.Game:GetService("Lighting")
	for _, node in lighting:GetChildren() do
		if node:IsA("Atmosphere") or node.Name == "RealmGrade" then
			node:Destroy()
		end
	end
	lighting.Brightness, lighting.ExposureCompensation = 2, 0
	h.Workspace.GlobalWind = r.Vector3.zero
	local player = h:player(451)
	h.Game:GetService("Players").LocalPlayer = player
	player:LoadCharacterAsync()
	local camera = r.Instance.new("Camera")
	camera.CFrame, camera.ViewportSize = r.CFrame.new(0, 100, 0), r.Vector2.new(1280, 720)
	camera.Parent, h.Workspace.CurrentCamera = h.Workspace, camera
	local settings = { Detail = detail ~= false, Camera = motion ~= false, Music = true, SFX = true }
	local client = h.Game:GetService("StarterPlayer").StarterPlayerScripts.Client
	local environment = h.Load(client.Controllers.EnvironmentController).new(settings)
	local data = {
		State = "Alive",
		RoundNumber = 1,
		Origin = 0,
		Event = "Calm",
		EventPhase = "Calm",
		EventRemaining = 0,
		Sheltered = false,
		Distance = 100,
		Biome = "Grasslands",
		Roster = {},
	}
	local function step(count, dt)
		for _ = 1, count do
			h:advance(dt)
			environment:update(dt, data)
		end
	end
	return h, r, environment, data, camera, settings, step, client
end

test("Four phases subdivide the original timers with continuous intensity targets", function()
	local h = fixture
	local storm = h.Load(h.Shared.StormConfig)
	local phase, intensity = storm.sample("Storm", "Warning", 8)
	assert(phase == "Approaching" and intensity == 0.08)
	local _, approachEnd = storm.sample("Storm", "Warning", 0)
	local _, heavyStart = storm.sample("Storm", "Active", 16)
	assert(math.abs(approachEnd - heavyStart) < 0.0001)
	local previous = 0
	for remaining = 16, 0, -1 do
		phase, intensity = storm.sample("Storm", "Active", remaining)
		assert(intensity >= previous and intensity <= 1)
		assert(phase == (if remaining > 8 then "Heavy" else "Extreme"))
		previous = intensity
	end
	assert(storm.sample("Earthquake", "Active", 0) == "Clear")
end)

test("Clouds use Terrain and high textured layers with no solid spheres", function()
	local _, r, env, data, camera, _, step = setup()
	data.Event, data.EventPhase, data.EventRemaining = "Storm", "Warning", 2
	step(10, 0.1)
	assert(env.Clouds.Parent:IsA("Terrain") and #env.CloudLayers == 3)
	assert(not env.Root:FindFirstChild("ApproachingStorm"))
	for _, layer in env.CloudLayers do
		assert(layer.Anchor.Transparency == 1 and not layer.Anchor.CanCollide)
		assert(layer.Anchor.Position.Y - camera.CFrame.Position.Y >= 240)
		assert(layer.Emitter.Texture:find("smoke_main", 1, true))
	end
	for _, part in env.Root:GetDescendants() do
		if part:IsA("BasePart") then
			assert(part.Shape ~= r.Enum.PartType.Ball, "Physical cloud sphere remains")
		end
	end
end)

test("Buildup, heavy, extreme and recovery change smoothly without fogging out nearby routes", function()
	local _, _, env, data, _, _, step = setup()
	data.Event, data.EventPhase, data.EventRemaining = "Storm", "Warning", 0
	step(40, 0.1)
	assert(env.StormState.Phase == "Approaching" and math.abs(env.StormState.Intensity - 0.45) < 0.001)
	local before = env.StormState.Intensity
	data.EventPhase, data.EventRemaining = "Active", 16
	step(1, 0.1)
	assert(env.StormState.Phase == "Heavy" and math.abs(env.StormState.Intensity - before) < 0.01)
	data.EventRemaining = 0
	step(50, 0.1)
	assert(env.StormState.Phase == "Extreme" and env.Weather.Rate > 50)
	assert(env.Atmosphere.Density <= 0.4 and env.Atmosphere.Haze <= 1.41)
	before = env.Clouds.Cover
	data.Event, data.EventPhase = "Calm", "Calm"
	step(1, 0.1)
	assert(env.StormState.Phase == "Recovery" and env.Weather.Rate > 40)
	assert(math.abs(env.Clouds.Cover - before) < 0.02, "Recovery snapped the sky clear")
	step(120, 0.1)
	assert(env.StormState.Phase == "Clear" and env.StormState.Intensity == 0)
	assert(
		env.WeatherMode ~= "Rain"
			and env.Weather.Rate <= 10.05
			and math.abs(env.Clouds.Cover - env.BaseCloud.Cover) < 0.001
	)
end)

test(
	"Low detail retains sky and limited rain while removing optional wind spray and bright flashes",
	function()
		local _, _, env, data, _, _, step = setup(false, false)
		data.Event, data.EventPhase, data.EventRemaining = "Storm", "Active", 0
		step(80, 0.1)
		assert(env.Clouds.Cover > 0.9 and env.Weather.Rate > 0 and env.Weather.Rate <= 24)
		assert(env.CloudLayers[1].Emitter.Rate > 0 and env.CloudLayers[3].Emitter.Rate == 0)
		assert(env.WindParticles.Rate == 0 and env.FlashLight.Brightness == 0)
	end
)

test("Shelter suppresses rain, wind spray and gusts without erasing the storm sky", function()
	local _, _, env, data, _, _, step = setup()
	data.Event, data.EventPhase, data.EventRemaining = "Storm", "Active", 0
	step(40, 0.1)
	assert(env.Weather.Rate > 50)
	data.Sheltered = true
	step(1, 0.1)
	assert(env.Weather.Rate == 0 and env.WindParticles.Rate == 0 and env.StormState.Gust == 0)
	assert(env.Clouds.Cover > 0.9)
	data.Sheltered = false
	step(10, 0.1)
	assert(env.Weather.Rate > 0)
end)

test("Lightning is distant, transient and records a delayed thunder cue", function()
	local h, _, env, data, camera, _, step = setup()
	data.Event, data.EventPhase, data.EventRemaining = "Storm", "Warning", 4
	step(1, 0.1)
	assert(env.StormState.LightningSerial == 0)
	h:advance(3.1)
	step(1, 0.01)
	assert(env.StormState.LightningSerial == 1 and #env.Bolts == 6 and env.Bolts[1].Enabled)
	assert((env.LightningAnchor.Position - camera.CFrame.Position).Magnitude > 280)
	assert(env.StormState.ThunderDelay >= 0.8 and env.StormState.ThunderDelay <= 3)
	assert(env.FlashLight.Brightness > 0)
	step(1, 0.2)
	assert(not env.Bolts[1].Enabled and env.FlashLight.Brightness == 0)
end)

test("Weather reuses bounded geometry and particle budgets through gusts and rebasing", function()
	local h, r, env, data, camera, _, step = setup()
	data.Event, data.EventPhase, data.EventRemaining = "Storm", "Active", 0
	step(1, 0.1)
	local count, parts = #env.Root:GetDescendants(), 0
	for _, node in env.Root:GetDescendants() do
		if node:IsA("BasePart") then
			parts += 1
		end
	end
	-- 19 original anchors + CloudSea + StormFront (fixed; no per-strike or per-frame parts).
	assert(parts <= 21, "Weather geometry exceeded its fixed anchor budget")
	for _ = 1, 35 do
		env:lightning(camera)
		step(1, 0.2)
	end
	assert(#env.Root:GetDescendants() == count, "Lightning allocates unbounded effects")
	local cloudBudget = 0
	for _, layer in env.CloudLayers do
		cloudBudget += layer.Emitter.Rate * layer.Emitter.Lifetime.Max
	end
	assert(cloudBudget < 24 and env.Weather.Rate * env.Weather.Lifetime.Max <= 44.01)
	assert(h.Workspace.GlobalWind.Magnitude > 0 and env.Weather.Acceleration.X > 0)
	camera.CFrame -= r.Vector3.new(0, 1024, 0)
	data.Origin = 1024
	step(1, 0.1)
	assert(env.CloudLayers[1].Anchor.Position.Y - camera.CFrame.Position.Y >= 240)
end)

test("New round or sanctuary exit cancels storm intensity and active lightning", function()
	local _, _, env, data, camera, _, step = setup()
	data.Event, data.EventPhase, data.EventRemaining = "Storm", "Active", 0
	step(30, 0.1)
	env:lightning(camera)
	data.RoundNumber, data.Event, data.EventPhase = 2, "Calm", "Calm"
	step(1, 0.1)
	assert(env.StormState.Phase == "Clear" and not env.Bolts[1].Enabled)
	assert(env.StormState.Intensity == 0)
	data.State, data.Event, data.EventPhase = "Lobby", "Storm", "Active"
	step(1, 0.1)
	assert(env.StormState.Phase == "Clear" and env.Weather.Rate == 0)
end)

test("Thunder waits for its travel delay, remains bounded and respects unconfigured audio/mute", function()
	local h, _, env, data, camera, settings, step, client = setup()
	local audio = h.Load(client.Controllers.AudioController).new(settings)
	data.Event, data.EventPhase, data.EventRemaining = "Storm", "Warning", 6
	step(1, 0.1)
	audio:update(0.1, data, env.StormState)
	env:lightning(camera)
	audio:update(0.1, data, env.StormState)
	assert(#audio.ThunderQueue == 2)
	local due = audio.ThunderQueue[2].At
	assert(math.abs(due - h.Time - env.StormState.ThunderDelay) < 0.0001)
	h:advance(env.StormState.ThunderDelay - 0.01)
	audio:update(0.1, data, env.StormState)
	assert(#audio.ThunderQueue == 2, "Thunder sounded before its delay")
	h:advance(0.02)
	audio:update(0.1, data, env.StormState)
	assert(#audio.ThunderQueue == 1 and audio.Thunder.Volume == 0, "Unconfigured audio attempted playback")
	for _ = 1, 12 do
		env:lightning(camera)
		audio:update(0.1, data, env.StormState)
	end
	assert(#audio.ThunderQueue <= 3)
	settings.SFX = false
	audio:update(0.1, data, env.StormState)
	assert(audio.SFXGroup.Volume == 0)
	data.State = "Lobby"
	audio:update(0.1, data, env.StormState)
	assert(#audio.ThunderQueue == 0)
end)

test("Extreme gust camera motion stays subtle and respects camera settings and shelter", function()
	local fixture, _, weather, snapshot, _, options, _, modules = setup()
	local cameraController =
		fixture.Load(modules.Controllers.CameraController).new(options, { FireServer = function() end })
	weather.StormState.Phase, weather.StormState.Gust = "Extreme", 1
	cameraController:update(0.1, snapshot, weather.StormState)
	local hum = fixture.Game:GetService("Players").LocalPlayer.Character.Humanoid
	assert(hum.CameraOffset.Magnitude > 0 and hum.CameraOffset.Magnitude < 0.09)
	options.Camera = false
	cameraController:update(0.1, snapshot, weather.StormState)
	assert(hum.CameraOffset.Magnitude == 0)
	options.Camera, snapshot.Sheltered = true, true
	cameraController:update(0.1, snapshot, weather.StormState)
	assert(hum.CameraOffset.Magnitude == 0)
end)

test("Storm HUD shows severity, shelter and recovery while retaining health and void warnings", function()
	local h, r, env, data, _, _, _, client = setup()
	local gui = r.Instance.new("PlayerGui")
	gui.Parent = h.Game:GetService("Players").LocalPlayer
	h.Game:GetService("UserInputService").TouchEnabled = false -- Engine defaults absent in Lune.
	h.Game:GetService("UserInputService").GamepadEnabled = false
	local ui = h.Load(client.UI.Interface)
		.new({ FireServer = function() end }, { Detail = true, Camera = true })
	data.Round, data.Ready, data.Countdown = "Running", true, 0
	data.Altitude, data.Survival, data.Cooldowns, data.BiomeName = 30, 16, {}, "Sky Grasslands"
	data.Health, data.MaxHealth = 63, 100
	data.Event, data.EventPhase, env.StormState.Phase = "Storm", "Active", "Extreme"
	ui:update(data)
	ui:updateStorm(data, env.StormState)
	assert(ui.Danger.Text:find("EXTREME STORM") and ui.Health.Text:find("63/100"))
	data.Sheltered = true
	ui:updateStorm(data, env.StormState)
	assert(ui.Danger.Text:find("SHELTERED"))
	data.Event, data.EventPhase, env.StormState.Phase = "Calm", "Calm", "Recovery"
	ui:updateStorm(data, env.StormState)
	assert(ui.Danger.Text:find("CLEARING"))
	data.Distance = 5
	ui:update(data)
	ui:updateStorm(data, env.StormState)
	assert(ui.Danger.Text:find("VOID"), "Recovery text hid a lethal deletion warning")
	ui.Gui:Destroy()
end)

test("Existing server warning, exposure damage, shelter and recovery schedule remain intact", function()
	local h = setup()
	local hum = h.Game:GetService("Players").LocalPlayer.Character.Humanoid
	local sheltered = false
	local record = { Player = h.Game:GetService("Players").LocalPlayer, State = "Alive", Region = 0 }
	local players = {
		active = function()
			return { record }
		end,
		damage = function(_, _, amount)
			hum.Health -= amount
		end,
	}
	local world = {
		sheltered = function()
			return sheltered
		end,
	}
	local events = h.Load(h.Server.Systems.WorldEventDirector).new(world, players, { Surge = 1 }, h.Effects)
	events:reset()
	events:update(35)
	assert(events.Phase == "Warning" and events.Until == 43 and hum.Health == 100)
	events:update(43)
	assert(events.Phase == "Active" and events.Until == 59 and hum.Health == 92)
	sheltered = true
	events:update(45)
	assert(hum.Health == 92)
	sheltered = false
	events:update(51)
	assert(hum.Health == 84 and events.Phase == "Active")
	events:update(59)
	assert(events.Phase == "Calm" and events.Next == 91 and hum.Health == 84)
end)
print(
	string.format(
		"%d storm regressions passed (offline state only; Studio visuals/performance/audio pending)",
		passed
	)
)
