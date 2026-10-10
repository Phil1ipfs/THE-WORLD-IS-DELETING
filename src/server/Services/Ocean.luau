--!nonstrict
-- The lower world: removes template baseplates and fills a Terrain water ocean at OceanY.
-- Clients add a camera-following horizon surface (OceanView) beyond streamed terrain.
-- The ocean is lethal: PlayerManager applies a server-side height boundary at OceanY.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").GameConfig)
local Ocean = {}
Ocean.Color = Color3.fromRGB(38, 132, 150)
-- Studio templates insert a gray checkerboard Baseplate; it must never show beneath the realms.
function Ocean.removeBaseplates(root)
	local removed = 0
	for _, child in (root or workspace):GetChildren() do
		if child:IsA("BasePart") and (child.Name == "Baseplate" or child.Name == "BasePlate") then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end
function Ocean.setup(terrain)
	terrain = terrain or workspace:FindFirstChildOfClass("Terrain")
	local removed = Ocean.removeBaseplates()
	if not terrain then
		return removed, 0
	end
	pcall(function()
		terrain.WaterColor = Ocean.Color
		terrain.WaterTransparency = 0.35
		terrain.WaterReflectance = 0.55
		terrain.WaterWaveSize = 0.18
		terrain.WaterWaveSpeed = 9
	end)
	-- Fill in 1024-stud chunks: a thin, uniform slab compresses well and streams near players.
	local chunk, depth = 1024, 16
	local minX, maxX = -1536, Config.LobbyX + 1184
	local fills = 0
	for x = minX, maxX - chunk, chunk do
		for z = -Config.OceanHalfZ, Config.OceanHalfZ - chunk, chunk do
			local ok = pcall(function()
				terrain:FillBlock(
					CFrame.new(x + chunk / 2, Config.OceanY - depth / 2, z + chunk / 2),
					Vector3.new(chunk, depth, chunk),
					Enum.Material.Water
				)
			end)
			fills += if ok then 1 else 0
		end
	end
	workspace:SetAttribute("OceanY", Config.OceanY)
	return removed, fills
end
-- True when a physical position has reached the ocean (with a small surface margin).
function Ocean.reached(position)
	return position.Y <= Config.OceanY + 1.5
end
return Ocean
