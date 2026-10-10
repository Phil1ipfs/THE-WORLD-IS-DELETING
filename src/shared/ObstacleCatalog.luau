--!strict
local Catalog = {}
Catalog.Names = {
	"MovingPlatforms",
	"RotatingBeams",
	"CollapsingBridge",
	"DisappearingPlatforms",
	"SwingingObstacles",
	"WindTunnel",
	"GravityZone",
	"FallingRocks",
	"CrumblingStairs",
	"SlidingPlatforms",
	"JumpPad",
	"FloatingElevator",
	"TimedGate",
	"LaserBarrier",
	"MovingWall",
	"SpiralTower",
	"TiltingPlatform",
	"IceSurface",
	"LavaStones",
	"Portal",
}
function Catalog.choose(rng: { next: (any) -> number }, previous: string?, preferred: { string }?): string
	local weights, total = {}, 0
	for _, name in Catalog.Names do
		local weight = if name == previous then 0 else 1
		if preferred and table.find(preferred, name) then
			weight *= 3
		end
		total += weight
		table.insert(weights, total)
	end
	local pick = rng:next() * total
	for i, threshold in weights do
		if pick < threshold then
			return Catalog.Names[i]
		end
	end
	return Catalog.Names[#Catalog.Names]
end
return table.freeze(Catalog)
