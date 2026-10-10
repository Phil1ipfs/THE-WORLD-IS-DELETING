--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Biomes = require(Shared.BiomeConfig)
local G = require(script.Parent.Services.Geometry)

local net = Instance.new("Folder")
net.Name = "Network"
net.Parent = ReplicatedStorage
local function remote(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = net
	return event
end
local request, snapshot, effects = remote("Request"), remote("Snapshot"), remote("Effects")
local obstacles = require(script.Parent.Systems.ObstacleGenerator).new(effects)
local world = require(script.Parent.Systems.WorldManager).new(obstacles)
world.Effects = effects
local wave = require(script.Parent.Systems.DeletionController).new()
local players = require(script.Parent.Systems.PlayerManager).new(world, effects)
local round = require(script.Parent.Systems.RoundManager).new(world, wave, players, effects)
local data = require(script.Parent.Systems.DataManager).new()
local rewards = require(script.Parent.Systems.RewardManager).new(data, effects)
local abilities = require(script.Parent.Systems.AbilityService).new(effects)
local cosmetics = require(script.Parent.Services.CosmeticService).new(data, rewards, effects)
local adventure = require(script.Parent.Systems.AdventureService).new(world, players, effects, rewards)
local objectives = require(script.Parent.Systems.ObjectiveService).new(world, players, effects, rewards, data)
adventure.Objectives, objectives.Adventure = objectives, adventure
local events = require(script.Parent.Systems.WorldEventDirector).new(world, players, wave, effects)
round.Adventure, round.Events = adventure, events
round.Objectives, objectives.Events, events.Objectives = objectives, events, objectives
obstacles.Players = players
obstacles.OnBonus = function(record, amount)
	rewards:bonus(record, amount)
end
players.OnEliminated = function(record)
	adventure:cancel(record)
	objectives:finish(record)
	rewards:finish(record)
end
players.OnSpawn = function(record)
	cosmetics:apply(record.Player)
end

local lobby = Instance.new("Model")
lobby.Name = "SkySanctuary"
lobby.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
lobby.Parent = workspace
G.part(
	lobby,
	"Sanctuary",
	Vector3.new(110, 5, 110),
	CFrame.new(Config.LobbyX, 77.5, 0),
	Color3.fromRGB(96, 158, 78),
	Enum.Material.Grass
)
G.part(
	lobby,
	"SanctuaryPlaza",
	Vector3.new(30, 0.3, 30),
	CFrame.new(Config.LobbyX, 80.1, 0),
	Color3.fromRGB(176, 168, 150),
	Enum.Material.Cobblestone,
	false
)
-- Cinematic menu world (village island, distant islands, sea stacks, mountains) and the ocean.
require(script.Parent.Services.MenuVista).build(lobby)
lobby.PrimaryPart = lobby:FindFirstChild("Sanctuary") -- Pivot at the sanctuary for client distance checks.
require(script.Parent.Services.Ocean).setup()
for i = 1, 8 do
	local a = i * math.pi / 4
	G.glow(
		lobby,
		Vector3.new(Config.LobbyX + math.sin(a) * 25, 84, math.cos(a) * 25),
		Color3.fromRGB(131, 220, 255),
		2
	)
end
G.label(
	lobby,
	"SKY SANCTUARY\nYour next ascent begins here",
	Vector3.new(Config.LobbyX, 94, 0),
	Color3.fromRGB(255, 229, 173)
)
local spawn = Instance.new("SpawnLocation")
spawn.Name, spawn.Size, spawn.CFrame = "LobbySpawn", Vector3.new(8, 1, 8), CFrame.new(Config.LobbyX, 80, 0)
spawn.Anchored, spawn.Neutral, spawn.Transparency, spawn.Duration = true, true, 1, 0
spawn.Parent = lobby
workspace.Gravity = Config.Gravity
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density, atmosphere.Offset, atmosphere.Color = 0.28, 0.1, Color3.fromRGB(195, 215, 255)
atmosphere.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity, bloom.Size, bloom.Threshold = 0.3, 20, 1.5
bloom.Parent = Lighting
world:reset(Config.Seed)

local function added(player)
	if #Players:GetPlayers() > Config.MaxPlayers then
		player:Kick("This realm is full.")
		return
	end
	local record = players:add(player)
	task.spawn(function()
		local profile, err = data:load(player)
		if not profile then
			player:Kick(err)
			return
		end
		if not player.Parent then
			data:save(player, true)
			return
		end
		record.Ready = true
		rewards:refresh(player)
		cosmetics:apply(player)
	end)
end
Players.PlayerAdded:Connect(added)
for _, player in Players:GetPlayers() do
	added(player)
end
Players.PlayerRemoving:Connect(function(player)
	local record = players.Records[player]
	if record then
		adventure:cancel(record)
	end
	players:remove(player)
	data:save(player, true)
end)

request.OnServerEvent:Connect(function(player, action, payload)
	local record = players.Records[player]
	if not record or not record.Ready or type(action) ~= "string" or #action > 30 then
		return
	end
	local now = os.clock()
	local bucket = record.RequestBucket or { Tokens = 12, Time = now }
	bucket.Tokens = math.min(12, bucket.Tokens + (now - bucket.Time) * 6)
	bucket.Time = now
	record.RequestBucket = bucket
	if bucket.Tokens < 1 then
		return
	end
	bucket.Tokens -= 1
	if action == "Play" then
		local wasAlive = record.State == "Alive"
		round:queue(record)
		if not wasAlive and record.State == "Alive" then
			local profile = data:get(player)
			if profile then
				profile.Attempts += 1
			end
		end
	elseif action == "Cancel" then
		round:cancel(record)
	elseif action == "Lobby" then
		player.ReplicationFocus = nil
		if record.State == "Alive" then
			players:eliminate(record, "Returned to sanctuary")
		end
		if players:transition(record, "Lobby") then
			players:spawn(record, false)
		end
	elseif action == "Spectate" then
		if record.State == "Eliminated" then
			players:transition(record, "Spectating")
		end
	elseif action == "SpectateTarget" and record.State == "Spectating" and type(payload) == "number" then
		local target = Players:GetPlayerByUserId(payload)
		local targetRecord = target and players.Records[target]
		if targetRecord and targetRecord.State == "Alive" then
			player.ReplicationFocus = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		end
	elseif action == "Ability" then
		abilities:request(record, payload)
	elseif action == "Interact" then
		adventure:request(record, payload)
	elseif action == "UseItem" then
		adventure:use(record, payload)
	elseif action == "UseGlyph" then
		adventure:useGlyph(record, payload)
	elseif action == "CoyoteJump" then
		abilities:coyote(record)
	elseif action == "Purchase" then
		cosmetics:purchase(record, payload)
	elseif action == "Emote" then
		cosmetics:emote(record)
	elseif action == "Leaderboard" and now - (record.LastBoard or -100) > 10 then
		record.LastBoard = now
		task.spawn(function()
			effects:FireClient(player, "Leaderboard", data:leaderboard())
		end)
	end
end)

local tickAccum, snapshotAccum = 0, 0
RunService.Heartbeat:Connect(function(dt)
	tickAccum += dt
	snapshotAccum += dt
	if tickAccum < Config.TickRate then
		return
	end
	local step = math.min(tickAccum, 0.5)
	tickAccum = 0
	local previousRound = round.Number
	round:update(step)
	if round.Number ~= previousRound then
		for _, record in players:active() do
			local profile = data:get(record.Player)
			if profile then
				profile.Attempts += 1
			end
			record.BonusCoins = 0
		end
	end
	if round.State == "Running" then
		abilities:update(players)
	end
	players:oceanSweep()
	data:update()
	if snapshotAccum < Config.SnapshotRate then
		return
	end
	snapshotAccum = 0
	local roster = {}
	for _, record in players.Records do
		table.insert(roster, {
			UserId = record.Player.UserId,
			Name = record.Player.DisplayName,
			State = record.State,
			Altitude = record.Peak,
		})
	end
	for player, record in players.Records do
		local profile = data:get(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local physicalY = if root and record.State == "Alive"
			then root.Position.Y + world.Origin
			else Config.StartY
		local biome = Biomes.at(math.max(0, physicalY - Config.StartY))
		local cooldowns = {}
		local itemCooldowns = {}
		local region = world.Islands[record.Region]
		for name, untilTime in record.Cooldowns do
			cooldowns[name] = math.max(0, untilTime - os.clock())
		end
		for kind, untilTime in record.ItemCooldowns or {} do
			itemCooldowns[kind] = math.max(0, untilTime - os.clock())
		end
		snapshot:FireClient(player, {
			State = record.State,
			Round = round.State,
			RoundNumber = round.Number,
			Ready = record.Ready,
			Countdown = math.max(0, math.ceil(round.Ends - os.clock())),
			Queued = round:queued(),
			Altitude = math.max(0, math.floor(physicalY - Config.StartY - 3)),
			Verified = record.Peak,
			Distance = physicalY - wave.Height,
			Wave = wave.Height,
			Survival = if record.State == "Alive" then math.floor(os.clock() - record.Started) else 0,
			Biome = biome.Id,
			BiomeName = biome.Name,
			Origin = world.Origin,
			RegionName = if region then region.Model:GetAttribute("RegionName") else "Sky Sanctuary",
			RegionIndex = record.Region or 0,
			Stability = if region then region.Model:GetAttribute("Stability") or Config.RegionLifetime else 0,
			Bag = record.Bag or { Timber = 0, Crystal = 0, Herb = 0 },
			Seal = adventure:sealStatus(record),
			Objectives = objectives:status(record),
			Repair = if region then region.Repair or 0 else 0,
			PortalOpen = region and region.Model:GetAttribute("PortalOpen") or false,
			Event = events.Name,
			EventPhase = events.Phase,
			Sheltered = root and world:sheltered(root.Position) or false,
			Transit = record.Transit or false,
			Health = player.Character
					and player.Character:FindFirstChildOfClass("Humanoid")
					and player.Character:FindFirstChildOfClass("Humanoid").Health
				or 0,
			MaxHealth = player.Character
					and player.Character:FindFirstChildOfClass("Humanoid")
					and player.Character:FindFirstChildOfClass("Humanoid").MaxHealth
				or 100,
			PowerStatus = {
				Shield = if os.clock() < record.ShieldUntil then record.ShieldHealth or 0 else 0,
				Glide = math.max(0, (record.GlideUntil or 0) - os.clock()),
				GlideSpeed = record.GlideSpeed or Config.Ability.Glide.Speed,
				Overcharge = math.max(0, (record.OverchargeUntil or 0) - os.clock()),
			},
			EventRemaining = if events.Until
				then math.max(0, math.ceil(events.Until - (os.clock() - round.Started)))
				else 0,
			Cooldowns = cooldowns,
			ItemCooldowns = itemCooldowns,
			Profile = profile,
			Roster = roster,
			Result = record.Result,
			Persistent = data.Enabled,
		})
	end
end)
game:BindToClose(function()
	for _, record in players:active() do
		players:eliminate(record, "Server closed")
	end
	data:shutdown()
end)
if RunService:IsStudio() then
	task.defer(function()
		local tests = game:GetService("ServerScriptService"):FindFirstChild("Tests")
		if tests and tests:FindFirstChild("StudioSmoke") then
			require(tests.StudioSmoke).run(world)
		end
	end)
end
print("Floating Realms " .. Config.Version .. " initialized. Persistence: " .. tostring(data.Enabled))
