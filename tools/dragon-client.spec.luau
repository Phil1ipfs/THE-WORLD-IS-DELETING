--!nonstrict
-- Client checks for the Realm Destroyer renderer and the dragon/balloon HUD, using Lune
-- Instances. No rendering, physics or input emulation: these verify construction, animation
-- state changes and HUD text, not visual quality (that needs Roblox Studio).
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r = h.Roblox
local V = r.Vector3
local player = h:player(77)
h.Game:GetService("Players").LocalPlayer = player
local playerGui = r.Instance.new("PlayerGui")
playerGui.Parent = player
local camera = r.Instance.new("Camera")
camera.CFrame, camera.ViewportSize = r.CFrame.new(0, 120, 120), r.Vector2.new(1280, 720)
camera.Parent = h.Workspace
h.Workspace.CurrentCamera = camera
h.Game:GetService("UserInputService").TouchEnabled = false
h.Game:GetService("UserInputService").GamepadEnabled = false
local client = h.Game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Interface = h.Load(client.UI.Interface)
local DragonController = h.Load(client.Controllers.DragonController)
local PowerEffects = h.Load(client.Controllers.PowerEffects)
local Power = h.Load(client.Controllers.PowerController)
local Rig = h.Load(h.Shared.DragonRig)
local settings = { Camera = true, Detail = true, Music = true, SFX = true }
local requests = {}
local request = {
	FireServer = function(_, ...)
		table.insert(requests, { ... })
	end,
}
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		error("FAIL " .. name .. ": " .. tostring(err), 0)
	end
	passed += 1
	print("PASS " .. name)
end
local state = r.Instance.new("Folder")
state.Name = "RealmDestroyer"
state.Parent = h.Game:GetService("ReplicatedStorage")
local fx = PowerEffects.new(settings)
local dragon = DragonController.new(settings, fx)
local function set(attributes)
	for key, value in attributes do
		state:SetAttribute(key, value)
	end
end
local function count(name)
	local n = 0
	for _, part in dragon.Model:GetChildren() do
		if part.Name == name then
			n += 1
		end
	end
	return n
end
test("Hidden dragon builds nothing; a visible one builds a full dragon silhouette", function()
	set({ Visible = false })
	dragon:update(0.016)
	assert(not dragon.Built)
	set({
		Visible = true,
		Pose = r.CFrame.new(0, 140, 0),
		Action = "Fly",
		Phase = "",
		Exposed = "",
		Aim = V.new(0, 100, -60),
	})
	dragon:update(0.016)
	assert(dragon.Built and dragon.Model.Parent == h.Workspace)
	-- Recognisable anatomy, not a small creature: neck, horned head and jaw, four limbs,
	-- articulated wings, a long spiked tail, layered scales and glowing eyes.
	assert(count("Neck") >= 6 and count("Skull") == 1 and count("Jaw") == 1)
	assert(count("Horn") >= 6 and count("Eye") == 2 and count("Tooth") >= 6)
	assert(count("Thigh") == 4 and count("Shin") == 4 and count("Claw") == 12)
	assert(count("WingBone") == 4 and count("WingFinger") == 8 and count("WingMembrane") == 24)
	assert(count("Tail") >= 10 and count("TailSpike") >= 10 and count("TailBlade") == 2)
	assert(count("FlankScale") >= 20 and count("SpineSpike") >= 8 and count("BellyPlate") >= 5)
	for _, part in dragon.Model:GetChildren() do
		if part.Name == "Eye" then
			assert(part.Material == r.Enum.Material.Neon, "Eyes must glow")
		end
		assert(not part.CanCollide and not part.CanQuery, part.Name .. " must not collide or block rays")
	end
	-- Enormous: wingspan and length far exceed a 5-stud player.
	local min, max = V.new(1e9, 1e9, 1e9), V.new(-1e9, -1e9, -1e9)
	for _, part in dragon.Model:GetChildren() do
		if part.Transparency < 1 then
			local p = part.Position
			min = V.new(math.min(min.X, p.X), math.min(min.Y, p.Y), math.min(min.Z, p.Z))
			max = V.new(math.max(max.X, p.X), math.max(max.Y, p.Y), math.max(max.Z, p.Z))
		end
	end
	local size = max - min
	assert(size.X > 70 and size.Z > 70, "Dragon is not enormous: " .. tostring(size))
end)
test("Wings flap, the neck ends at the server head point, and the pose is smoothed", function()
	local membrane
	for _, part in dragon.Model:GetChildren() do
		if part.Name == "WingMembrane" then
			membrane = part
			break
		end
	end
	local before = membrane.CFrame
	for _ = 1, 20 do
		dragon:update(0.033)
	end
	assert(membrane.CFrame ~= before, "Wing membranes did not animate")
	local head = dragon.HeadCF.Position
	local expected = r.CFrame.new(0, 140, 0) * V.new(Rig.head("Fly").X, Rig.head("Fly").Y, Rig.head("Fly").Z)
	assert((head - expected).Magnitude < 2, "Head drifted from the server head point")
	set({ Pose = r.CFrame.new(40, 140, 0) })
	dragon:update(0.033)
	assert(dragon.Smooth.Position.X > 0 and dragon.Smooth.Position.X < 40, "Pose was not smoothed")
	set({ Pose = r.CFrame.new(0, -900, 0) })
	dragon:update(0.033)
	assert(dragon.Smooth.Position.Y == -900, "Rebase-sized jumps must snap")
	set({ Pose = r.CFrame.new(0, 140, 0) })
	dragon:update(0.033)
end)
test("Breath wind-up smokes, active breath fires, and exposed weak points glow and label", function()
	set({ Action = "Breath", Phase = "Windup", Exposed = "Heart" })
	dragon:update(0.033)
	assert(dragon.Smoke.Rate > 0 and dragon.Fire.Rate == 0)
	assert(dragon.HeartGlow.Transparency < 1 and dragon.Markers.Heart.Gui.Enabled)
	assert(not dragon.Markers.Head.Gui.Enabled)
	set({ Phase = "Active" })
	dragon:update(0.033)
	assert(dragon.Fire.Rate > 0, "No fire during active breath")
	set({ Action = "Landed", Phase = "Recover", Exposed = "Wings" })
	dragon:update(0.033)
	assert(dragon.Fire.Rate == 0 and dragon.Markers.WingL.Gui.Enabled and dragon.Markers.WingR.Gui.Enabled)
	assert(not dragon.Markers.Heart.Gui.Enabled)
	set({ Action = "Stunned", Exposed = "Head" })
	dragon:update(0.033)
	assert(dragon.Markers.Head.Gui.Enabled and dragon.Head.Glow.Transparency < 1)
	set({ Visible = false })
	dragon:update(0.033)
	assert(dragon.Model.Parent == nil, "Hidden dragon must leave the workspace")
end)
test("Dragon events render impacts, meteors and shot tracers without errors", function()
	local weather = {}
	dragon:event({ Kind = "Roar", Position = V.new(0, 140, 0) }, weather)
	assert(weather.ShakeAt, "Roar should shake the camera")
	dragon:event({ Kind = "Impact", Position = V.new(0, 100, 0), Radius = 26 }, weather)
	dragon:event(
		{ Kind = "Gust", Position = V.new(0, 100, 0), Direction = V.new(0, 0, -1), Length = 70, Width = 26 },
		weather
	)
	dragon:event({ Kind = "Meteors", Points = { V.new(0, 100, 0), V.new(10, 100, 0) }, Delay = 1 }, weather)
	dragon:shot({ Weapon = "Crossbow", From = V.new(0, 103, 0), To = V.new(0, 140, -10), Damage = 4 })
	dragon:shot({ Weapon = "Cannon", From = V.new(0, 103, 0), To = V.new(0, 140, -10), Damage = 0 })
	h:advance(1.2)
	local power = Power.new()
	player:LoadCharacterAsync()
	local root = player.Character.HumanoidRootPart
	root.AssemblyLinearVelocity = V.zero
	power:knockback({ Velocity = V.new(0, 20, -80) })
	assert(
		root.AssemblyLinearVelocity.Z == -80,
		"Wing gust knockback not applied locally: " .. tostring(root.AssemblyLinearVelocity)
	)
	power:knockback({ Velocity = V.new(0, 0, -900) })
	assert(root.AssemblyLinearVelocity.Z == -80, "Implausible knockback must be ignored")
end)
local ui
test("HUD: boss bar, weak-point prompt, FIRE button, balloon card and dragon events", function()
	ui = Interface.new(request, settings)
	local snapshot = {
		State = "Alive",
		Round = "Running",
		Ready = true,
		Countdown = 0,
		Altitude = 700,
		Distance = 300,
		Survival = 120,
		Biome = "Jungle",
		BiomeName = "Floating Jungle",
		RegionName = "Verdant Hang",
		Origin = 0,
		Cooldowns = {},
		Roster = {},
		Health = 80,
		MaxHealth = 100,
		Bag = { Timber = 2, Crystal = 1, Herb = 0 },
		Profile = { Best = 0, Coins = 0, Owned = {}, Equipped = "none" },
		Dragon = {
			Mode = "Encounter",
			Encounter = true,
			HP = 90,
			MaxHP = 150,
			Tier = 1,
			Exposed = "Heart",
			Phase = "Recover",
			RazeIn = 101,
			Crossbow = 17,
		},
	}
	ui:update(snapshot)
	assert(ui.Boss.Visible and ui.BossHP.Text == "90 / 150")
	assert(string.find(ui.BossInfo.Text, "HEART", 1, true) and string.find(ui.BossInfo.Text, "1:41", 1, true))
	assert(string.find(ui.BossInfo.Text, "SKY BALLOON", 1, true), "The escape choice must be shown")
	assert(ui.FireButton.Visible and string.find(ui.FireButton.Text, "17", 1, true))
	assert(string.find(ui.Objective.Text, "Realm Destroyer", 1, true))
	snapshot.Dragon.Exposed, snapshot.Dragon.Attack, snapshot.Dragon.Phase = "", "Fire Breath", "Windup"
	ui:update(snapshot)
	assert(string.find(ui.BossInfo.Text, "FIRE BREATH INCOMING", 1, true))
	local fired
	ui.OnFire = function()
		fired = true
	end
	ui.FireButton.Activated:Fire()
	assert(fired, "FIRE button did not trigger the crossbow")
	snapshot.Dragon = { Mode = "Ambient" }
	snapshot.Balloon = { Phase = "Boarding", Departs = 4, Riders = 2, Progress = 0 }
	ui:update(snapshot)
	assert(not ui.Boss.Visible and not ui.FireButton.Visible)
	assert(ui.BalloonCard.Visible and string.find(ui.BalloonCard.Text, "DEPARTING IN 4", 1, true))
	assert(ui.Objective.Text == "Ride the Sky Balloon to the next realm")
	snapshot.Balloon = { Phase = "Flight", Departs = 0, Riders = 2, Progress = 0.5 }
	ui:update(snapshot)
	assert(string.find(ui.BalloonCard.Text, "50%", 1, true))
	ui:event("Dragon", { Kind = "Encounter", Tier = 1, RazeIn = 150 })
	assert(ui.Banner.Visible and ui.BannerTitle.Text == "THE REALM DESTROYER")
	ui:event(
		"DragonTrophy",
		{ Scales = 9, Emberhearts = 1, TotalScales = 9, TotalEmberhearts = 1, Cosmetic = "Dragonwing Mantle" }
	)
	assert(ui.Achievement.Visible and string.find(ui.AchievementTitle.Text, "Dragonwing", 1, true))
	ui:event("Bestiary", { Name = "Realm Destroyer", Stage = 2, Of = 4, Text = "Survived a raid" })
end)
test("Bestiary page shows progressive discovery; shop shows the dragon drop and craft cost", function()
	local snapshot = {
		State = "Lobby",
		Round = "Waiting",
		Ready = true,
		Countdown = 0,
		Altitude = 0,
		Distance = 100,
		Survival = 0,
		Biome = "Grasslands",
		BiomeName = "Sky Grasslands",
		Origin = 0,
		Cooldowns = {},
		Roster = {},
		Profile = {
			Best = 0,
			Coins = 0,
			Owned = {},
			Equipped = "none",
			DragonScales = 12,
			Emberhearts = 1,
			DragonKills = 1,
			Bestiary = { RealmDestroyer = 1, BrambleStalker = 1 },
		},
	}
	ui:update(snapshot)
	assert(ui.MenuCards.Bestiary, "Bestiary menu card missing")
	ui.MenuCards.Bestiary.Activated:Fire()
	assert(ui.Page == "Bestiary" and ui.Panel.Visible)
	local all = ""
	for _, child in ui.Body:GetChildren() do
		if child:IsA("TextLabel") then
			all ..= child.Text .. "\n"
		end
	end
	assert(string.find(all, "REALM DESTROYER", 1, true) and string.find(all, "Mythic", 1, true))
	assert(string.find(all, "DISCOVERY 1/4", 1, true) and string.find(all, "Sighted", 1, true))
	assert(string.find(all, "Survive one of its raids", 1, true), "Abilities should stay hidden at stage 1")
	assert(string.find(all, "12 Dragon Scales", 1, true) and string.find(all, "catalogued: 1", 1, true))
	snapshot.Profile.Bestiary.RealmDestroyer = 4
	ui.Data = snapshot
	ui:open("Bestiary")
	all = ""
	for _, child in ui.Body:GetChildren() do
		if child:IsA("TextLabel") then
			all ..= child.Text .. "\n"
		end
	end
	assert(string.find(all, "Fire Breath", 1, true) and string.find(all, "Heart", 1, true))
	ui:open("Shop")
	local found = ui.ShopCards.dragonwing and ui.ShopCards.dragonwing.Action.Text
	assert(
		found and string.find(found, "12/40", 1, true),
		"Shop card lacks the craft progress: " .. tostring(found)
	)
	ui:open("Menu")
end)
local SoundBank = h.Load(h.Shared.SoundBank)
local AudioConfig = h.Load(h.Shared.AudioConfig)
local AudioController = h.Load(client.Controllers.AudioController)
-- The only files in content/sounds of the installed Roblox client (checked 2026-10-11).
local bundled = {
	"action_falling.ogg",
	"action_footsteps_plastic.mp3",
	"action_get_up.mp3",
	"action_jump.mp3",
	"action_jump_land.mp3",
	"action_swim.mp3",
	"impact_explosion_03.mp3",
	"impact_water.mp3",
	"oof.ogg",
	"ouch.ogg",
	"volume_slider.ogg",
}
test("Designed sounds use only client-bundled files and cover every audio slot", function()
	local allowed = {}
	for _, file in bundled do
		allowed["rbxasset://sounds/" .. file] = true
	end
	for path in SoundBank.paths() do
		assert(allowed[path], "Recipe uses a file the Roblox client does not ship: " .. path)
	end
	for _, path in SoundBank.Files do
		assert(allowed[path], "Unverified bundled file: " .. path)
	end
	-- Every configurable slot has a designed cue/bed, except music (no designed substitute).
	local music = { Music = true, Wildlife = true }
	for key, value in AudioConfig do
		if type(value) == "string" and not music[key] then
			assert(
				SoundBank.Cues[key] or SoundBank.Beds[key] or SoundBank.Loops[key],
				"Audio slot has no designed sound: " .. key
			)
		end
	end
	for _, key in
		{
			"DragonRoar",
			"DragonFire",
			"DragonWings",
			"HarpoonThrow",
			"CannonFire",
			"BalloonDepart",
			"ForgeCraft",
		}
	do
		assert(AudioController.resolve(key), key .. " does not resolve")
	end
end)
test("Audio controller plays layered cues with effects and starts the designed beds", function()
	local audio = AudioController.new(settings)
	assert(audio.StormWind.SoundId ~= "" and audio.Danger.SoundId ~= "", "Designed beds did not load")
	local before = audio.Played or 0
	assert(audio:play("DragonRoar"), "Roar did not play")
	h:advance(0.5)
	assert((audio.Played or 0) - before == 3, "Roar should play its three layers")
	local shaped = false
	for _, item in audio.Pool do
		if item.Sound:FindFirstChildOfClass("DistortionSoundEffect") then
			shaped = true
		end
	end
	assert(shaped, "Roar layers lack their distortion effect")
	assert(audio:play("HarpoonThrow") and audio:play("CannonFire") and audio:play("BalloonArrive"))
	settings.SFX = false
	assert(not audio:play("Pickup"), "SFX setting must silence cues")
	settings.SFX = true
	-- Positioned cues beyond their range are skipped; long-range cues still play.
	assert(not audio:play("Hit", camera.CFrame.Position + V.new(0, 0, 500)))
	assert(audio:play("Thunder", camera.CFrame.Position + V.new(0, 0, 900)))
end)
test("THROW button, harpoon flight visual and the dragon's breath loop", function()
	ui:update({
		State = "Alive",
		Round = "Running",
		Ready = true,
		Countdown = 0,
		Altitude = 700,
		Distance = 300,
		Survival = 1,
		Biome = "Jungle",
		BiomeName = "Floating Jungle",
		RegionName = "Verdant Hang",
		Origin = 0,
		Cooldowns = {},
		Roster = {},
		Health = 100,
		MaxHealth = 100,
		Bag = { Timber = 0, Crystal = 0, Herb = 0 },
		Profile = { Best = 0, Coins = 0, Owned = {}, Equipped = "none" },
		Dragon = {
			Mode = "Encounter",
			Encounter = true,
			HP = 100,
			MaxHP = 150,
			Tier = 1,
			Exposed = "",
			RazeIn = 90,
			Harpoons = 4,
		},
	})
	assert(ui.ThrowButton.Visible and string.find(ui.ThrowButton.Text, "4 harpoons", 1, true))
	assert(not ui.FireButton.Visible, "FIRE needs a crossbow")
	local thrown
	ui.OnThrow = function()
		thrown = true
	end
	ui.ThrowButton.Activated:Fire()
	assert(thrown)
	dragon:shot({ Weapon = "Harpoon", From = V.new(0, 103, 0), To = V.new(0, 140, -30), Damage = 11 })
	local flying = false
	for _, part in fx.Folder:GetChildren() do
		if part.Name == "DragonbaneHarpoonFlight" then
			flying = true
		end
	end
	assert(flying, "No harpoon in flight")
	set({
		Visible = true,
		Pose = r.CFrame.new(0, 140, 0),
		Action = "Breath",
		Phase = "Active",
		Aim = V.new(0, 100, -60),
	})
	dragon:update(0.033)
	assert(dragon.FireSound and dragon.FireSound.Looped and dragon.FireOn, "Breath loop silent")
	set({ Phase = "Recover" })
	dragon:update(0.033)
	assert(not dragon.FireOn, "Breath loop kept playing")
end)
test("Shop: balance header, category tabs, card states, purchase requests and live refresh", function()
	local ShopView = h.Load(client.UI.ShopView)
	local Catalog = h.Load(h.Shared.ShopConfig)
	local RulesModule = h.Load(h.Shared.Rules)
	-- Every catalog item persists and has the presentation fields the cards need.
	local ids = {}
	for _, item in Catalog do
		assert(not ids[item.Id], "Duplicate shop id " .. item.Id)
		ids[item.Id] = true
		assert(item.Desc and item.Rarity and ShopView.Rarity[item.Rarity], item.Id .. " lacks desc/rarity")
		local owned = {}
		owned[item.Id] = true
		assert(RulesModule.profile({ Owned = owned }).Owned[item.Id], item.Id .. " would not persist")
	end
	local profile = {
		Best = 0,
		Coins = 150,
		Owned = { none = true, azure = true, wave = true },
		Equipped = "azure",
		Achievements = { Treasure = true },
		DragonScales = 40,
		Emberhearts = 2,
	}
	local snapshot = {
		State = "Lobby",
		Round = "Waiting",
		Ready = true,
		Countdown = 0,
		Altitude = 0,
		Distance = 100,
		Survival = 0,
		Biome = "Grasslands",
		BiomeName = "Sky Grasslands",
		Origin = 0,
		Cooldowns = {},
		Roster = {},
		Profile = profile,
	}
	ui:update(snapshot)
	ui.ShopTab = nil
	ui:open("Shop")
	assert(ui.Body:FindFirstChild("ShopHeader") and ui.Body.ShopHeader.Coins.Text == "◉ 150")
	assert(ui.Body:FindFirstChild("Unequip"), "Unequip button missing while something is equipped")
	local cards = ui.ShopCards
	assert(string.find(cards.azure.Label, "EQUIPPED", 1, true) and not cards.azure.Enabled)
	assert(cards.ember.Label == "BUY · 100 COINS" and cards.ember.Enabled)
	assert(cards.galewings.Label == "NEED 350 COINS" and not cards.galewings.Enabled)
	assert(cards.halo.Label == "CLAIM" and cards.halo.Enabled)
	assert(string.find(cards.stormtrail.Label, "LOCKED", 1, true))
	assert(string.find(cards.dragonwing.Label, "CRAFT", 1, true) and cards.dragonwing.Enabled)
	assert(cards.wave.Label == "OWNED ✓" and not cards.wave.Enabled, "Emotes are owned, not equipped")
	table.clear(requests)
	cards.ember.Action.Activated:Fire()
	assert(requests[1] and requests[1][1] == "Purchase" and requests[1][2] == "ember")
	cards.galewings.Action.Activated:Fire()
	assert(#requests == 1, "An unaffordable item must not send a purchase")
	-- Tabs filter the grid.
	ui.ShopTabButtons.Wings.Activated:Fire()
	assert(ui.ShopCards.galewings and ui.ShopCards.dragonwing and not ui.ShopCards.azure)
	-- Server confirmation (new profile) re-renders the open shop in place.
	profile.Coins, profile.Owned.ember, profile.Equipped = 50, true, "ember"
	ui:update(snapshot)
	ui.ShopTabButtons.All.Activated:Fire()
	assert(
		string.find(ui.ShopCards.ember.Label, "EQUIPPED", 1, true)
			and ui.Body.ShopHeader.Coins.Text == "◉ 50"
	)
	ui:open("Menu")
end)
test("Environment update tolerates the BalloonFlights folder and hubless propeller blades", function()
	-- Regression: Studio logged "GetPivot is not a valid member of Folder BalloonFlights" every
	-- frame, and a nil spinner hub when streaming delivered blades before their hub.
	local world = h.Workspace:FindFirstChild("FloatingRealms") or r.Instance.new("Model")
	world.Name, world.Parent = "FloatingRealms", h.Workspace
	local flights = r.Instance.new("Folder")
	flights.Name, flights.Parent = "BalloonFlights", world
	local island = r.Instance.new("Model")
	island.Name, island.Parent = "Region_0", world
	local blade = r.Instance.new("Part")
	blade.Name, blade.Parent = "PropellerBlade", island
	blade:SetAttribute("SpinKey", "Orphan")
	local Environment = h.Load(client.Controllers.EnvironmentController)
	local env = Environment.new(settings)
	local snapshot = {
		State = "Alive",
		Origin = 0,
		Biome = "Grasslands",
		Altitude = 10,
		Distance = 200,
		Event = "Calm",
		EventPhase = "Calm",
		RegionIndex = 0,
		Countdown = 0,
	}
	for _ = 1, 3 do
		h:advance(0.1)
		env:update(0.1, snapshot)
	end
	flights:Destroy()
	island:Destroy()
end)
print(passed .. " dragon client tests passed (Lune fixtures; NOT Roblox Studio)")
