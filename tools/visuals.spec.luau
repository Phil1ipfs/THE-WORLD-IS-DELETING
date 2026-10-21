--!nonstrict
-- Presentation regressions: realm asset integrity/budgets, sky profiles, atmosphere state,
-- machinery animation, power effects and HUD state. Object/state checks only: these do NOT
-- prove rendered appearance, frame rate or readability; Studio review remains required.
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r = h.Roblox
-- Fixture lookup (the bootstrap suite registers its own in its process).
r.implementMethod("Players", "GetPlayerByUserId", function(service, userId)
	for _, candidate in service:GetChildren() do
		if candidate:IsA("Player") and candidate.UserId == userId then
			return candidate
		end
	end
	return nil
end)
local V = r.Vector3
local Config = h.Load(h.Shared.GameConfig)
local Biomes = h.Load(h.Shared.BiomeConfig)
local RealmConfig = h.Load(h.Shared.RealmConfig)
local Generator = h.Load(h.Server.Systems.ExplorationGenerator)
local client = h.Game:GetService("StarterPlayer").StarterPlayerScripts.Client
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	assert(ok, "FAIL " .. name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end
local player = h:player(1201)
h.Game:GetService("Players").LocalPlayer = player
player:LoadCharacterAsync()
local playerGui = r.Instance.new("PlayerGui")
playerGui.Parent = player
local camera = r.Instance.new("Camera")
camera.CFrame, camera.ViewportSize = r.CFrame.new(0, 100, 0), r.Vector2.new(1280, 720)
camera.Parent, h.Workspace.CurrentCamera = h.Workspace, camera
h.Game:GetService("UserInputService").TouchEnabled = false
h.Game:GetService("UserInputService").GamepadEnabled = false
local folder = r.Instance.new("Folder")
folder.Name = "FloatingRealms"
folder.Parent = h.Workspace
local regions = {}
for i, biome in Biomes.List do
	local index = math.ceil((i - 1) * 320 / Config.RegionRise)
	regions[biome.Id] = Generator.build(folder, index, 0, 3489)
end
test("Every realm builds finite, budgeted, collapse-attached scenery", function()
	for id, region in regions do
		local parts, lights = 0, 0
		local attached = {}
		for _, s in region.Structures do
			attached[s.Part] = true
		end
		for _, c in region.Cells do
			attached[c.Part] = true
		end
		for _, node in region.Model:GetDescendants() do
			if node:IsA("BasePart") then
				parts += 1
				local p = node.CFrame.Position
				assert(p.X == p.X and p.Y == p.Y and p.Z == p.Z, id .. " has a NaN part: " .. node.Name)
				if node:GetAttribute("Detail") then
					assert(
						not node.CanCollide and not node.CanQuery,
						id .. " decoration blocks movement: " .. node.Name
					)
					assert(attached[node], id .. " decoration would float after collapse: " .. node.Name)
				end
			elseif node:IsA("PointLight") then
				lights += 1
				assert(not node.Shadows, "Scenery light casts expensive shadows")
			end
		end
		-- 0.5.0: realms are about 2x larger (satellite sub-areas, suspension bridges); budget raised.
		assert(parts < 7000, id .. " exceeds the per-region part budget: " .. parts)
		assert(lights <= 20, id .. " has too many lights: " .. lights)
	end
end)
test("Trees are multi-part with tapered trunks, branches and clustered canopies", function()
	for id, region in regions do
		local trunks, crowns, branches = 0, 0, 0
		for _, node in region.Model:GetDescendants() do
			if node.Name == "TreeTrunk" then
				trunks += 1
			elseif node.Name == "TreeCrown" then
				crowns += 1
			elseif node.Name == "TreeBranch" then
				branches += 1
			end
		end
		assert(trunks >= 30, id .. " has too few tree trunk segments: " .. trunks)
		assert(crowns + branches >= trunks, id .. " trees lack branches or canopy clusters")
	end
end)
test("Collectibles read as herbs, crystals and timber bundles", function()
	local region = regions.Grasslands
	local checked = {}
	for _, spec in region.Interactions do
		local kind = spec.Kind
		if (kind == "Herb" or kind == "Crystal" or kind == "Timber") and not checked[kind] then
			checked[kind] = true
			local counts = {}
			for _, child in spec.Part:GetChildren() do
				counts[child.Name] = (counts[child.Name] or 0) + 1
			end
			if kind == "Herb" then
				assert((counts.HerbLeaf or 0) >= 5 and counts.HerbSoil, "Herb is not a leafy plant")
			elseif kind == "Crystal" then
				assert(
					(counts.CrystalFacet or 0) == 2 and counts.CrystalCore and counts.CrystalShard,
					"Crystal lacks facets"
				)
			else
				assert((counts.TimberLog or 0) >= 2 and counts.TimberRope, "Timber is not a log bundle")
			end
			assert(not spec.Part.CanCollide and spec.Part.CanQuery)
		end
	end
	assert(checked.Herb and checked.Crystal and checked.Timber)
end)
test("Realms have distinct architecture, landmarks and furnished, functional shelters", function()
	local wallStyles, landmarks = {}, {}
	for id, region in regions do
		local wall, furniture = nil, 0
		for _, node in region.Model:GetDescendants() do
			if node.Name == "VillageWall" and not wall then
				wall = tostring(node.Material) .. tostring(node.Color)
			elseif node.Name == "HouseDetail" and node.Material == r.Enum.Material.Fabric then
				furniture += 1
			end
		end
		wallStyles[wall] = true
		local landmark = region.Model:GetAttribute("Landmark")
		assert(landmark, id .. " is missing its landmark")
		assert(not landmarks[landmark], "Landmark reused across realms")
		landmarks[landmark] = true
		assert(furniture >= 9, id .. " houses lack interiors")
		local houses = 0
		for _, zone in region.Shelters do
			if zone.Name == "House" then
				houses += 1
				assert(#zone.Breaches == 4, "House lacks window breach anchors")
			end
		end
		assert(houses >= 3)
	end
	local styles = 0
	for _ in wallStyles do
		styles += 1
	end
	assert(styles >= 9, "Realm houses share materials: " .. styles)
end)
test("Viewpoints and ledges are walkable ground; hazards are registered where realms need them", function()
	for id, region in regions do
		local viewpoint = false
		for _, cell in region.Cells do
			if cell.Part.Name == "Viewpoint" then
				viewpoint = true
				assert(cell.Part:GetAttribute("Ground") and cell.Part.CanCollide)
				local top = cell.Part.Position.Y + cell.Part.Size.Y / 2 - region.Center.Y
				assert(top > 3 and top < 30, id .. " viewpoint height out of range")
			end
		end
		assert(viewpoint, id .. " has no elevated viewpoint")
	end
	assert(#regions.Volcanic.Hazards >= 1 and #regions.Void.Hazards >= 1, "Lava/void hazards missing")
	assert(regions.Frozen.IceLake and regions.Frozen.IceLake.Material == r.Enum.Material.Ice)
end)
test("Sky profiles stay within safe ranges and blend continuously", function()
	for id, realm in RealmConfig.Realms do
		local sky = realm.Sky
		assert(sky.Atmos.Density <= 0.4, id .. " fog would hide routes")
		assert(sky.Bloom.Intensity <= 0.6 and sky.Bloom.Threshold >= 1.2, id .. " bloom too strong")
		assert(sky.Rays.Intensity <= 0.15 and sky.Clouds.Cover <= 0.85)
		assert(sky.Grade.Saturation <= 0.2 and sky.Grade.Saturation >= -0.1, id .. " oversaturated")
	end
	local a, b = RealmConfig.Realms.Grasslands.Sky, RealmConfig.Realms.Void.Sky
	local half = RealmConfig.blendSky(a, b, 0.5)
	assert(
		RealmConfig.blendSky(a, b, 0).ClockTime == a.ClockTime
			and RealmConfig.blendSky(a, b, 1).ClockTime == b.ClockTime
	)
	assert(math.abs(half.Atmos.Density - (a.Atmos.Density + b.Atmos.Density) / 2) < 1e-6)
end)
local settings = { Detail = true, Camera = true, Music = true, SFX = true }
local Environment = h.Load(client.Controllers.EnvironmentController)
local env = Environment.new(settings)
local snapshot = {
	State = "Alive",
	RoundNumber = 1,
	Origin = 0,
	Event = "Calm",
	EventPhase = "Calm",
	EventRemaining = 0,
	Sheltered = false,
	Distance = 150,
	Wave = -40,
	Biome = "Grasslands",
	Roster = {},
}
test("Each realm drives distinct lighting, sky and post-processing toward its profile", function()
	local lighting = h.Game:GetService("Lighting")
	assert(lighting:FindFirstChildOfClass("Sky") and lighting:FindFirstChildOfClass("SunRaysEffect"))
	assert(lighting:FindFirstChildOfClass("BloomEffect"))
	local clocks = {}
	for _, id in { "Grasslands", "Volcanic", "Void", "Frozen" } do
		local band
		for i, biome in Biomes.List do
			if biome.Id == id then
				band = i - 1
			end
		end
		camera.CFrame = r.CFrame.new(0, Config.StartY + band * 320 + 20, 0)
		for _ = 1, 160 do
			h:advance(0.1)
			env:update(0.1, snapshot)
		end
		local sky = RealmConfig.get(id).Sky
		assert(math.abs(lighting.ClockTime - sky.ClockTime) < 0.4, id .. " clock time not applied")
		assert(math.abs(env.Clouds.Cover - sky.Clouds.Cover) < 0.02, id .. " cloud cover not applied")
		assert(env.Bloom.Intensity <= 0.6 and env.Atmosphere.Density <= 0.4)
		clocks[id] = lighting.ClockTime
	end
	assert(clocks.Grasslands ~= clocks.Void and clocks.Volcanic ~= clocks.Frozen)
end)
test("Cloud sea, storm front and forked lightning build with the storm and respect detail", function()
	camera.CFrame = r.CFrame.new(0, 100, 0)
	snapshot.Event, snapshot.EventPhase, snapshot.EventRemaining = "Calm", "Calm", 0
	env:update(0.1, snapshot)
	assert(env.SeaEmitter.Rate > 0 and env.CloudSea.Position.Y < camera.CFrame.Position.Y - 100)
	assert(env.FrontEmitter.Rate == 0, "Storm front visible in clear weather")
	snapshot.Event, snapshot.EventPhase, snapshot.EventRemaining = "Storm", "Warning", 7
	for _ = 1, 10 do
		h:advance(0.1)
		env:update(0.1, snapshot)
	end
	local far = (env.StormFront.Position - camera.CFrame.Position).Magnitude
	snapshot.EventRemaining = 0
	for _ = 1, 40 do
		h:advance(0.1)
		env:update(0.1, snapshot)
	end
	local near = (env.StormFront.Position - camera.CFrame.Position).Magnitude
	assert(env.FrontEmitter.Rate > 0 and near < far - 50, "Storm front did not advance during buildup")
	env:lightning(camera)
	env:update(0.01, snapshot)
	assert(env.Forks[1].Beam.Enabled and env.StormState.ShakeAt)
	h:advance(0.3)
	env:update(0.1, snapshot)
	assert(not env.Forks[1].Beam.Enabled)
	settings.Detail = false
	env:update(0.1, snapshot)
	assert(env.SeaEmitter.Rate < 1 and env.RainSheets.Rate == 0)
	settings.Detail = true
	snapshot.Event, snapshot.EventPhase = "Calm", "Calm"
	for _ = 1, 150 do
		h:advance(0.1)
		env:update(0.1, snapshot)
	end
	assert(env.StormState.Phase == "Clear" and env.FrontEmitter.Rate == 0)
end)
test("Repaired machinery and Sky Balloon propellers spin locally around their hubs", function()
	local region = regions.Grasslands
	local wheel, blade
	for _, node in region.Model:GetDescendants() do
		if node.Name == "PropellerHub" then
			wheel = node
		elseif node.Name == "PropellerBlade" then
			blade = node
		end
	end
	assert(wheel and wheel:GetAttribute("Spin") and blade, "Docked balloon propeller missing")
	camera.CFrame = r.CFrame.new(region.Center + V.new(0, 20, 0))
	env:update(0.3, snapshot)
	local before, bladeBefore = wheel.CFrame, blade.CFrame
	for _ = 1, 5 do
		h:advance(0.1)
		env:update(0.1, snapshot)
	end
	assert(
		wheel.CFrame.Position == before.Position and wheel.CFrame ~= before,
		"Propeller hub did not rotate"
	)
	assert(blade.CFrame ~= bladeBefore, "Propeller blades did not follow the hub")
end)
local Effects = h.Load(client.Controllers.PowerEffects)
local fx = Effects.new(settings)
test("Power effects attach, animate and clean up; Aegis breaks when the shield is spent", function()
	camera.CFrame = r.CFrame.new(0, 100, 30)
	local root = player.Character.HumanoidRootPart
	root.Position = V.new(0, 100, 0)
	local hum = player.Character.Humanoid
	for _, name in { "Dash", "DoubleJump", "Shield", "Glide" } do
		fx:ability({ UserId = player.UserId, Name = name, Duration = 1, Velocity = V.zero })
		assert(player.Character:FindFirstChild("Power_" .. name), name .. " has no visual")
	end
	assert(player.Character.Power_Shield:FindFirstChild("AegisShell").Material == r.Enum.Material.ForceField)
	assert(player.Character.Power_Glide:FindFirstChild("SailWing"))
	local broke = false
	fx.OnShieldBreak = function()
		broke = true
	end
	h:advance(0.6)
	fx:update(0.6, { PowerStatus = { Shield = 0, Glide = 0, Overcharge = 0 } })
	assert(broke and not player.Character:FindFirstChild("Power_Shield"), "Aegis did not shatter")
	hum:SetAttribute("Airborne", false)
	h:advance(2)
	fx:update(2, { PowerStatus = { Shield = 0, Glide = 0, Overcharge = 0 } })
	for _, name in { "Dash", "DoubleJump", "Glide" } do
		assert(not player.Character:FindFirstChild("Power_" .. name), name .. " visual leaked")
	end
	for _, child in root:GetChildren() do
		assert(not child:GetAttribute("PowerFX"), "Dash trail attachment leaked")
	end
	fx:item({ UserId = player.UserId, Kind = "Crystal", Duration = 12 })
	assert(player.Character:FindFirstChild("Power_Overcharge"))
	fx:update(0.1, {})
	fx:item({ UserId = player.UserId, Kind = "Herb" })
	fx:item({ UserId = player.UserId, Kind = "Timber" })
	local spec
	for _, s in regions.Grasslands.Interactions do
		if s.Kind == "Herb" then
			spec = s
		end
	end
	camera.CFrame = r.CFrame.new(spec.Part.Position + V.new(0, 5, 10))
	fx:pickup(spec.Part, spec.Part.Position, "Herb")
	assert(fx.Folder:FindFirstChild("PickupGhost"), "Pickup has no lift animation")
end)
local Interface = h.Load(client.UI.Interface)
local ui = Interface.new({ FireServer = function() end }, settings)
local status = {
	State = "Alive",
	Round = "Running",
	Ready = true,
	Countdown = 0,
	Altitude = 40,
	Distance = 120,
	Survival = 30,
	Biome = "Grasslands",
	BiomeName = "Sky Grasslands",
	RegionName = "Havenwood Reach",
	Origin = 0,
	Cooldowns = { Dash = 4 },
	ItemCooldowns = {},
	Roster = {},
	Health = 50,
	MaxHealth = 100,
	PowerStatus = { Shield = 45, Glide = 0, Overcharge = 0 },
	Bag = { Timber = 2, Crystal = 1, Herb = 0, Relic = 1 },
	Profile = { Best = 0, Coins = 0, Owned = {}, Equipped = "none" },
	Objectives = {
		Region = "Havenwood Reach",
		Main = "Climb onward",
		TimeLeft = 150,
		Activities = {
			{
				Type = "Repair",
				Title = "Repair the Ancient Windmill",
				Progress = "2/6 supplies",
				Done = false,
				Distance = 80,
			},
			{ Type = "Cache", Title = "Hidden secret", Progress = "?", Hidden = true, Done = false },
			{
				Type = "Hunt",
				Title = "Drive off the Bramble Stalkers",
				Progress = "Cleared",
				Done = true,
				Distance = 20,
			},
		},
		Event = { Title = "Supply drop", Text = "Crate falling", Remaining = 40 },
		Perks = { "Gale Anklet" },
		Relics = 1,
	},
}
test("HUD shows health/shield bars, deletion meter, realm banner and cooldown sweeps", function()
	ui:update(status)
	assert(math.abs(ui.HealthFill.Size.X.Scale - 0.5) < 1e-6 and ui.ShieldFill.Size.X.Scale > 0.4)
	assert(ui.Health.Text:find("50/100") and ui.Health.Text:find("45"))
	assert(ui.DeletionFill.Size.X.Scale > 0.4)
	assert(ui.Banner.Visible and ui.BannerTitle.Text == "HAVENWOOD REACH")
	assert(ui.CooldownShades.Dash.Size.Y.Scale == 1, "New cooldown should start full")
	status.Cooldowns.Dash = 2
	ui:update(status)
	assert(math.abs(ui.CooldownShades.Dash.Size.Y.Scale - 0.5) < 1e-6)
	status.Cooldowns.Dash = 0
	ui:update(status)
	assert(ui.CooldownShades.Dash.Size.Y.Scale == 0)
end)
test(
	"Objective tracker lists realm activities, hides secrets, collapses, and shows events and perks",
	function()
		ui:update(status)
		assert(ui.Tracker.Visible)
		local text = ""
		for _, row in ui.TrackerRows do
			if row.Visible then
				text ..= row.Text .. "\n"
			end
		end
		assert(text:find("COLLAPSES IN", 1, true) and text:find("Repair the Ancient Windmill", 1, true))
		assert(text:find("Hidden secret", 1, true) and text:find("80m", 1, true))
		assert(text:find("Supply drop", 1, true) and text:find("Gale Anklet", 1, true))
		ui.TrackerHeader.Activated:Fire()
		local visible = 0
		for _, row in ui.TrackerRows do
			visible += if row.Visible then 1 else 0
		end
		assert(visible <= 4, "Collapsed tracker still lists everything")
		ui.TrackerHeader.Activated:Fire()
		status.State = "Lobby"
		ui:update(status)
		assert(not ui.Tracker.Visible)
		status.State = "Alive"
	end
)
test("Feed and popups report rewards, objectives and achievements without piling up", function()
	for i = 1, 9 do
		ui:event("Reward", { Coins = i, XP = 2 })
	end
	local entries = 0
	for _, child in ui.Feed:GetChildren() do
		if child:IsA("TextLabel") then
			entries += 1
		end
	end
	assert(entries <= 5, "Feed grew without bound")
	ui:event("Achievement", { Name = "Sky Rescuer", Text = "Rescue a stranded survivor", Unlock = nil })
	assert(ui.Achievement.Visible and ui.AchievementTitle.Text:find("Sky Rescuer"))
	ui:event("Objective", { Kind = "Complete", Title = "Repair", Text = "Done" })
	assert(ui.Toast.Text == "Done")
	ui:event("Hurt", { Amount = 20 })
	assert(ui.Flash.BackgroundColor3 == r.Color3.fromRGB(255, 60, 70), "Damage flash color not applied")
end)
print(
	string.format("%d presentation regressions passed (object state only; rendering pending Studio)", passed)
)
