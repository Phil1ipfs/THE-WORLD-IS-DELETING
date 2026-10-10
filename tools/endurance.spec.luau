--!nonstrict
-- Synthetic time advancement exercises real world lifecycle code; no physics or FPS.
local Harness = require("./OfflineHarness")
local h = Harness.new()
local Config = h.Load(h.Shared.GameConfig)
local Obstacles = h.Load(h.Server.Systems.ObstacleGenerator)
local World = h.Load(h.Server.Systems.WorldManager)
local Deletion = h.Load(h.Server.Systems.DeletionController)
local obstacles = Obstacles.new(h.Effects)
local world = World.new(obstacles)
local wave = Deletion.new()
world:reset(Config.Seed)
local maxActive, rebases = 0, 0
for tick = 1, 6000 do
	local elapsed = tick * 0.5
	h:advance(0.5)
	local highest = Config.StartY + elapsed * 3 -- Synthetic walking/exploration pace.
	wave:update(0.5, elapsed, world.Origin, highest)
	world:consume(wave.Height)
	world:generate(highest)
	world:activate(math.floor((highest - Config.StartY) / Config.RegionRise))
	if highest - world.Origin > Config.RebaseAt and wave.Height - world.Origin > Config.RebaseAmount + 80 then
		world:rebase(Config.RebaseAmount)
		rebases += 1
	end
	local active = 0
	for _ in world.Islands do
		active += 1
	end
	maxActive = math.max(maxActive, active)
	assert(active <= Config.MaxActiveRegions, "Streaming budget exceeded")
	assert(
		Config.StartY + (world.NextIndex - 1) * Config.RegionRise >= highest + Config.RegionRise,
		"Leader reached the end of the generated path"
	)
	assert(highest - world.Origin < Config.RebaseAt + 160, "Physical coordinates escaped rebase band")
end
assert(rebases >= 7 and world.NextIndex > 70)
print(
	string.format(
		"PASS synthetic 50-minute exploration: %d generated regions, peak %d active, %d rebases; no physics/FPS measurement",
		world.NextIndex,
		maxActive,
		rebases
	)
)
