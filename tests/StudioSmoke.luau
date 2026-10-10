--!nonstrict
-- Executes only in Roblox Studio after server initialization; not an automated playtest.
local Smoke = {}
function Smoke.run(world)
	local server = game:GetService("ServerScriptService"):WaitForChild("Server")
	local count = 0
	for _, module in server:GetDescendants() do
		if module:IsA("ModuleScript") then
			assert(require(module) ~= nil)
			count += 1
		end
	end
	assert(workspace:FindFirstChild("SkySanctuary"), "Lobby missing")
	assert(workspace:FindFirstChild("DeletionWave"), "Wave missing")
	assert(world.Islands[0] and world.Islands[1], "Initial islands missing")
	assert(world.Islands[0].Model:FindFirstChild("Landing"), "Landing missing")
	assert(#world.Islands[0].Cells > 90, "Exploration terrain missing")
	assert(#world.Islands[0].Shelters >= 4, "Village/cave shelters missing")
	assert(#world.Islands[0].Interactions > 35, "Scavenging/escape interactions missing")
	assert(#world.Islands[0].Activities >= 3, "Realm activities missing")
	assert(world.Islands[0].Model:GetAttribute("Landmark"), "Realm landmark missing")
	assert(
		world.Islands[0].Routes.Ascent and world.Islands[0].Routes.Arrival,
		"Connected walking ascent missing"
	)
	local remote = game:GetService("ReplicatedStorage"):WaitForChild("Network")
	assert(
		remote:FindFirstChild("Request")
			and remote:FindFirstChild("Snapshot")
			and remote:FindFirstChild("Effects")
	)
	print("[Studio smoke] " .. count .. " server modules initialized; lobby, world and network exist")
end
return Smoke
