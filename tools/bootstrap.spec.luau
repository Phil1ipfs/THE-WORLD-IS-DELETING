--!nonstrict
-- Executes the actual server entrypoint with fixture events. No real networking.
local Harness = require("./OfflineHarness")
local luau = require("@lune/luau")
local h = Harness.new()
local r = h.Roblox
local eventMap, latest, closeHandler = {}, {}, nil
local function signalFor(instance, key)
	eventMap[instance] = eventMap[instance] or {}
	if not eventMap[instance][key] then
		local callbacks = {}
		eventMap[instance][key] = {
			Connect = function(_, fn)
				table.insert(callbacks, fn)
				return { Disconnect = function() end }
			end,
			Fire = function(_, ...)
				for _, fn in callbacks do
					fn(...)
				end
			end,
		}
	end
	return eventMap[instance][key]
end
for _, pair in
	{
		{ "Players", "PlayerAdded" },
		{ "Players", "PlayerRemoving" },
		{ "RunService", "Heartbeat" },
		{ "RemoteEvent", "OnServerEvent" },
	}
do
	local key = pair[2]
	r.implementProperty(pair[1], key, function(instance)
		return signalFor(instance, key)
	end)
end
r.implementMethod("Players", "GetPlayers", function(instance)
	return instance:GetChildren()
end)
r.implementMethod("Players", "GetPlayerByUserId", function(instance, id)
	for _, p in instance:GetChildren() do
		if p.UserId == id then
			return p
		end
	end
end)
r.implementMethod("RemoteEvent", "FireClient", function(instance, player, payload)
	if instance.Name == "Snapshot" then
		latest[player.UserId] = payload
	end
end)
r.implementMethod("RemoteEvent", "FireAllClients", function() end)
r.implementMethod("DataModel", "BindToClose", function(_, fn)
	closeHandler = fn
end)
local player = h:player(777)
local main = h.Server.Main
local env = table.clone(h.Environment)
env.script, env.require = main, h.Load
luau.load(main.Source, { debugName = "Offline server bootstrap", environment = env })()
assert(h.Workspace:FindFirstChild("SkySanctuary"))
assert(h.Workspace:FindFirstChild("DeletionWave"))
assert(player.Character and player:GetAttribute("State") == "Lobby")
local network = h.Game:GetService("ReplicatedStorage").Network
local heartbeat = h.Game:GetService("RunService").Heartbeat
network.Request.OnServerEvent:Fire(player, "Play")
for _ = 1, 165 do
	h:advance(0.1)
	heartbeat:Fire(0.1)
end
assert(player:GetAttribute("State") == "Alive")
assert(latest[777] and latest[777].State == "Alive" and latest[777].Profile.Attempts == 1)
-- The real snapshot path carries the realm objective tracker.
assert(latest[777].Objectives and #latest[777].Objectives.Activities >= 3, "Snapshot lacks realm objectives")
assert(latest[777].Objectives.Region == "Havenwood Reach")
-- Round start must leave the regions registered with the dragon (omen silhouette in realm 1).
local dragonState = h.Game:GetService("ReplicatedStorage"):FindFirstChild("RealmDestroyer")
assert(
	dragonState and dragonState:GetAttribute("Visible"),
	"Realm Destroyer omen is not flying during a round"
)
assert(dragonState:GetAttribute("Mode") == "Ambient", "Realm 1 must only show the distant omen")
local root = player.Character.HumanoidRootPart
local region = h.Workspace.FloatingRealms.Region_0
local function walkNear(node)
	local start = root.Position
	local finish = node.Position + r.Vector3.new(0, 1.5, 0)
	for i = 1, 20 do
		root.Position = start:Lerp(finish, i / 20)
		h:advance(0.2)
		heartbeat:Fire(0.2)
	end
end
for _, glyph in { "Sun", "Leaf", "Moon" } do
	local key = region:FindFirstChild(glyph .. "Key")
	assert(key, "Missing collectible key in built place")
	walkNear(key)
	network.Request.OnServerEvent:Fire(player, "Interact", key:GetAttribute("InteractionId"))
	h:advance(0.6)
	heartbeat:Fire(0.6)
	assert(latest[777].Seal[glyph], "Key collection did not reach the real snapshot path")
end
walkNear(region.Seal)
assert(latest[777].Seal.Nearby and latest[777].Seal.Progress == 0)
for i, glyph in { "Sun", "Leaf", "Moon" } do
	network.Request.OnServerEvent:Fire(player, "UseGlyph", glyph)
	h:advance(0.6)
	heartbeat:Fire(0.6)
	assert(latest[777].Seal.Progress == i, "UseGlyph remote failed to operate the altar")
end
assert(latest[777].Seal.Open and latest[777].PortalOpen)
local dock = region:FindFirstChild("Balloon")
local from = root.Position
local destination = dock.Position + r.Vector3.new(0, 1.5, 0)
for i = 1, 20 do
	root.Position = from:Lerp(destination, i / 20)
	h:advance(0.2)
	heartbeat:Fire(0.2)
end
dock.ProximityPrompt.Triggered:Fire(player)
h:advance(0.5)
heartbeat:Fire(0.5)
assert(latest[777].Transit and latest[777].Balloon, "Main-loop balloon boarding failed")
assert(latest[777].Balloon.Phase == "Boarding" and latest[777].Balloon.Departs <= 5)
for _ = 1, 205 do
	h:advance(0.1)
	heartbeat:Fire(0.1)
end
assert(latest[777].Verified >= 128 and not latest[777].Transit, "Main-loop balloon progression failed")
assert(latest[777].Dragon and latest[777].Dragon.Mode, "Snapshot lacks the dragon view")
network.Request.OnServerEvent:Fire(player, "Lobby")
h:advance(0.5)
heartbeat:Fire(0.5)
assert(player:GetAttribute("State") == "Lobby" and latest[777].Profile.Best >= 128)
assert(closeHandler)
closeHandler()
print(
	"PASS actual server entrypoint: queue, spawn, key collection/use remotes, seal snapshots, Sky Balloon ascent, return, rewards and shutdown (offline fixture)"
)
