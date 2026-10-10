--!nonstrict
-- Standalone Luau tests: exercise the SAME pure modules used by the server.
local Config = require("../src/shared/GameConfig")
local Route = require("../src/shared/Route")
local RNG = require("../src/shared/Random")
local Catalog = require("../src/shared/ObstacleCatalog")
local Difficulty = require("../src/shared/DifficultyConfig")
local Biomes = require("../src/shared/BiomeConfig")
local Rules = require("../src/shared/Rules")
local Layout = require("../src/shared/RegionLayout")
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		error("FAIL " .. name .. ": " .. tostring(err), 0)
	end
	passed += 1
	print("PASS " .. name)
end
test("Legacy optional obstacle layout: 100,000 jumps reachable with speed reserve", function()
	assert(Route.validate(0, 100000, Config))
end)
test("Impossible height and distance are rejected", function()
	local a = Route.point(0, Config)
	assert(not Route.reachable(a, { X = a.X, Y = a.Y + 9, Z = a.Z, Step = 1 }, Config))
	assert(not Route.reachable(a, { X = a.X + 100, Y = a.Y, Z = a.Z, Step = 1 }, Config))
end)
test("Seed reproducibility and bounded random range", function()
	local a, b = RNG.new(71), RNG.new(71)
	for _ = 1, 10000 do
		assert(a:next() == b:next())
		local n = a:integer(2, 6)
		b:integer(2, 6)
		assert(n >= 2 and n <= 6)
	end
end)
test("20 mechanics all selected without adjacent repetition", function()
	assert(#Catalog.Names == 20)
	local rng, previous, seen = RNG.new(123), nil, {}
	for _ = 1, 20000 do
		local name = Catalog.choose(rng, previous, { "JumpPad", "Portal" })
		assert(name ~= previous)
		seen[name] = true
		previous = name
	end
	for _, name in Catalog.Names do
		assert(seen[name], name .. " unreachable in selection")
	end
end)
test("Difficulty increases smoothly and caps individual mechanics", function()
	local previous = 0
	for height = 0, 100000, 10 do
		local d = Difficulty.at(height)
		assert(d.Intensity >= previous and d.Intensity <= 1)
		assert(d.Intensity - previous < 0.01 and d.Speed <= 1.4 and d.LandingScale >= 0.82)
		assert(d.Combinations <= 3)
		previous = d.Intensity
	end
end)
test("10 biomes cycle with transition blend", function()
	assert(#Biomes.List == 10)
	for i = 1, 10 do
		local b = Biomes.at((i - 1) * 320)
		assert(b.Id == Biomes.List[i].Id)
	end
	local b, nextBiome, blend = Biomes.at(300)
	assert(b.Id == "Grasslands" and nextBiome.Id == "Crystal" and blend > 0)
	assert(Biomes.at(3200).Id == "Grasslands")
end)
test("Deletion grace, monotonic advance and bounded pressure", function()
	local h = Config.WaveStart
	assert(Rules.wave(h, 10, 0, Config) == h)
	for i = 1, 10000 do
		local n = Rules.wave(h, 0.1, Config.WaveGrace + i * 0.1, Config)
		assert(n > h and n - h <= Config.WaveMaxSpeed * 0.1 + 0.00001)
		h = n
	end
	assert(Rules.wave(h, -1, 2000, Config) == h)
end)
test("State transitions reject invalid reentry and rewards are bounded", function()
	assert(Rules.canTransition("Lobby", "Queued"))
	assert(Rules.canTransition("Queued", "Alive"))
	assert(Rules.canTransition("Alive", "Eliminated"))
	assert(not Rules.canTransition("Alive", "Queued"))
	assert(not Rules.canTransition("Lobby", "Alive"))
	assert(not Rules.canTransition("Invalid", "Alive"))
	assert(Rules.reward(-100, -10).Coins == 0)
	assert(Rules.reward(120, 60).Coins == 13)
	assert(Rules.level(0) == 1 and Rules.level(320) == 3)
end)
test("Profile migration rejects malformed numbers and unknown cosmetics", function()
	local p = Rules.profile({
		Best = 0 / 0,
		Coins = math.huge,
		XP = -5,
		Owned = { azure = true, hacked = true },
		Equipped = "hacked",
	})
	assert(p.Best == 0 and p.Coins == 0 and p.XP == 0)
	assert(p.Owned.azure and not p.Owned.hacked and p.Equipped == "none")
	assert(Rules.profile(nil).Schema == 1)
	assert(Rules.profile({ Coins = 34.7 }).Coins == 34)
end)
test("Persistence lease ownership and expiry", function()
	assert(Rules.canLease(nil, "A", 100))
	assert(Rules.canLease({ Owner = "A", Expires = 200 }, "A", 100))
	assert(not Rules.canLease({ Owner = "B", Expires = 200 }, "A", 100))
	assert(Rules.canLease({ Owner = "B", Expires = 100 }, "A", 100))
end)
test("Coordinate rebasing preserves logical route connectivity", function()
	local origin = 0
	for step = 1, 200000 do
		local p = Route.point(step, Config)
		if p.Y - origin > Config.RebaseAt then
			origin += Config.RebaseAmount
		end
		local physicalY = p.Y - origin
		assert(math.abs(physicalY + origin - p.Y) < 1e-8)
		assert(physicalY <= Config.RebaseAt and physicalY > 0)
	end
end)
test("Exploration mainland cells remain connected across seeds and size classes", function()
	for _, seed in { 1, 71, 3490 } do
		for index = 0, 7 do
			local nodes = {}
			local count, start = 0, nil
			for _, cell in Layout.cells(index, seed) do
				if cell.Zone == "Mainland" then
					local key = cell.X .. ":" .. cell.Z
					nodes[key] = cell
					start = start or key
					count += 1
				end
			end
			local queue, seen = { start }, { [start] = true }
			local n = 1
			while n <= #queue do
				local cell = nodes[queue[n]]
				for _, d in { { 24, 0 }, { -24, 0 }, { 0, 24 }, { 0, -24 } } do
					local key = (cell.X + d[1]) .. ":" .. (cell.Z + d[2])
					if nodes[key] and not seen[key] then
						seen[key] = true
						table.insert(queue, key)
					end
				end
				n += 1
			end
			assert(#queue == count, "Disconnected mainland terrain")
			assert(count * 24 * 24 > 20000, "Starter land area too small")
		end
	end
end)
test("Realm outskirts extend the walkable mainland away from routes and inside world bounds", function()
	for _, seed in { 1, 71, 3489, 3490, 784219 } do
		for index = 0, 11 do
			local nodes, count, outskirts, start = {}, 0, 0, nil
			for _, cell in Layout.cells(index, seed) do
				if cell.Zone == "Mainland" or cell.Zone == "Outskirts" then
					local key = cell.X .. ":" .. cell.Z
					assert(not nodes[key], "Duplicate terrain cell " .. key)
					nodes[key] = cell
					start = start or key
					count += 1
					outskirts += if cell.Zone == "Outskirts" then 1 else 0
				end
			end
			local queue, seen, n = { start }, { [start] = true }, 1
			while n <= #queue do
				local cell = nodes[queue[n]]
				for _, d in { { 24, 0 }, { -24, 0 }, { 0, 24 }, { 0, -24 } } do
					local key = (cell.X + d[1]) .. ":" .. (cell.Z + d[2])
					if nodes[key] and not seen[key] then
						seen[key] = true
						table.insert(queue, key)
					end
				end
				n += 1
			end
			assert(#queue == count, "Outskirts disconnected from mainland")
			assert(outskirts >= 8, "Outskirts too small")
			local lobe = Layout.outskirts(index, seed)
			assert(lobe.Clearance > 0, "Outskirts overlap a causeway, grove or cave route")
			local c = Layout.center(index, Config.RegionRadius, Config.RegionRise, Config.StartY)
			assert(math.max(math.abs(c.X + lobe.X), math.abs(c.Z + lobe.Z)) + lobe.Radius + 30 < 700)
		end
	end
end)
test("Satellite sub-areas expand every region, stay clear of routes and are bridge-reachable", function()
	local total, base = 0, 0
	for _, seed in { 1, 71, 3489, 784219 } do
		for index = 0, 11 do
			local satellites = Layout.satellites(index, seed)
			assert(#satellites >= 3, "Region " .. index .. " has only " .. #satellites .. " sub-areas")
			local cells = Layout.cells(index, seed)
			local byKey, zones = {}, {}
			for _, cell in cells do
				byKey[cell.X .. ":" .. cell.Z] = cell
				zones[cell.Zone] = (zones[cell.Zone] or 0) + 1
				total += 1
				if
					cell.Zone == "Mainland"
					or cell.Zone == "Outskirts"
					or cell.Zone == "Grove"
					or cell.Zone == "Cave"
				then
					base += 1
				end
			end
			local c = Layout.center(index, Config.RegionRadius, Config.RegionRise, Config.StartY)
			for _, sat in satellites do
				assert(sat.Clearance > 0 and (zones[sat.Kind] or 0) >= 9, sat.Kind .. " too small or crowded")
				assert(math.max(math.abs(c.X + sat.X), math.abs(c.Z + sat.Z)) + sat.Radius <= 1300)
				local function landAt(x, z, zone)
					for _, cell in cells do
						if
							(not zone or cell.Zone == zone)
							and math.abs(cell.X - x) <= 12.05
							and math.abs(cell.Z - z) <= 12.05
						then
							return cell
						end
					end
					return nil
				end
				local start = landAt(sat.StartX, sat.StartZ)
				assert(
					start and (start.Zone == "Mainland" or start.Zone == "Outskirts"),
					"Bridge start not on the mainland"
				)
				assert(landAt(sat.EndX, sat.EndZ, sat.Kind), "Bridge end not on " .. sat.Kind)
				local span = math.sqrt((sat.EndX - sat.StartX) ^ 2 + (sat.EndZ - sat.StartZ) ^ 2)
				assert(
					span > 20 and math.deg(math.atan2(math.abs(sat.Height), span)) < 26,
					"Bridge too short or steep"
				)
				-- Internal connectivity of the island cells.
				local start2
				local nodes, count = {}, 0
				for _, cell in cells do
					if cell.Zone == sat.Kind then
						nodes[cell.X .. ":" .. cell.Z] = cell
						start2 = start2 or cell.X .. ":" .. cell.Z
						count += 1
					end
				end
				local queue, seen, n = { start2 }, { [start2] = true }, 1
				while n <= #queue do
					local cell = nodes[queue[n]]
					for _, d in { { 24, 0 }, { -24, 0 }, { 0, 24 }, { 0, -24 } } do
						local key = (cell.X + d[1]) .. ":" .. (cell.Z + d[2])
						if nodes[key] and not seen[key] then
							seen[key] = true
							table.insert(queue, key)
						end
					end
					n += 1
				end
				assert(#queue == count, sat.Kind .. " island is fragmented")
			end
			local _ = byKey
		end
	end
	assert(total / base >= 1.45, string.format("Expansion only %.2fx the original land cells", total / base))
end)
test("Region ascent remains bounded and slopes allow walking without jumping", function()
	for index = 0, 1000 do
		local a = Layout.center(index, Config.RegionRadius, Config.RegionRise, Config.StartY)
		local b = Layout.center(index + 1, Config.RegionRadius, Config.RegionRise, Config.StartY)
		local distance = math.sqrt((b.X - a.X) ^ 2 + (b.Z - a.Z) ^ 2) - 300
		assert(math.deg(math.atan2(b.Y - a.Y, distance)) < 25)
		assert(math.abs(a.X) <= Config.RegionRadius and math.abs(a.Z) <= Config.RegionRadius)
	end
end)
print(string.format("%d core tests passed", passed))
