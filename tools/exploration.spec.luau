--!nonstrict
-- Executes production geometry and mechanics. Analytic fixture checks are not Studio physics.
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r = h.Roblox
local V = r.Vector3
local Config = h.Load(h.Shared.GameConfig)
local Layout = h.Load(h.Shared.RegionLayout)
local World = h.Load(h.Server.Systems.WorldManager)
local Players = h.Load(h.Server.Systems.PlayerManager)
local Adventure = h.Load(h.Server.Systems.AdventureService)
local Events = h.Load(h.Server.Systems.WorldEventDirector)
local Wave = h.Load(h.Server.Systems.DeletionController)
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	assert(ok, "FAIL " .. name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end
local function system()
	local world = World.new()
	local players = Players.new(world, h.Effects)
	local adventure = Adventure.new(world, players, h.Effects)
	world:reset(3489)
	local p = h:player(100 + passed)
	local rec = players:add(p)
	rec.Ready = true
	players:transition(rec, "Queued")
	players:begin(rec)
	return world, players, adventure, rec
end
local function dispose(w, p, a, rec)
	a:cancel(rec)
	p:remove(rec.Player)
	rec.Player:Destroy()
	for _, region in w.Islands do
		w:dispose(region)
	end
	w.Root:Destroy()
end
local function find(region, kind, extra)
	for _, spec in region.Interactions do
		if spec.Kind == kind and (not extra or spec.Extra == extra) then
			return spec
		end
	end
	error("Missing interaction " .. kind)
end
local function move(rec, spec)
	local pos = spec.Part.Position + V.new(0, 1.5, 0)
	rec.Player.Character.HumanoidRootPart.Position = pos
	rec.LastPosition, rec.LastCheck = pos, h.Time
	h:advance(0.6)
end
test("Large deterministic regions contain a village, cave, grove and three ascent choices", function()
	local w, p, a, rec = system()
	local region = w.Islands[0]
	assert(#region.Cells > 90 and #region.Interactions > 35)
	assert(#region.Shelters >= 4 and #region.Routes.Ascent > 15)
	for _, kind in { "Lift", "Portal", "Repair", "Glyph", "Heal", "Discover", "Timber", "Crystal", "Herb" } do
		assert(find(region, kind))
	end
	for index = 0, 100 do
		local c = Layout.center(index, Config.RegionRadius, Config.RegionRise, Config.StartY)
		local d = Layout.center(index + 1, Config.RegionRadius, Config.RegionRise, Config.StartY)
		assert(Layout.slope(c, d) < 15)
		assert(#Layout.cells(index, 3489) > 50)
	end
	local other = h.Load(h.Server.Systems.ExplorationGenerator).build(w.Root, 0, 0, 3489)
	assert(#region.Model:GetDescendants() == #other.Model:GetDescendants())
	assert(region.Cells[20].Part.CFrame == other.Cells[20].Part.CFrame)
	other.Model:Destroy()
	dispose(w, p, a, rec)
end)
test("All ten realms generate themed ground, foliage, detailed homes and supported supplies", function()
	local biomes = h.Load(h.Shared.BiomeConfig)
	local generator = h.Load(h.Server.Systems.ExplorationGenerator)
	local folder = r.Instance.new("Folder")
	folder.Parent = h.Workspace
	for i, biome in biomes.List do
		local index = math.ceil((i - 1) * 320 / Config.RegionRise)
		local region = generator.build(folder, index, 0, 3489)
		assert(region.Model:GetAttribute("SceneryTheme") == biome.Id)
		assert(region.Landing.Color == r.Color3.fromRGB(table.unpack(biome.Top)))
		if biome.Id == "Frozen" then
			assert(region.Landing.Material == r.Enum.Material.Snow)
		end
		if biome.Id == "Mechanical" then
			assert(region.Landing.Material == r.Enum.Material.Metal)
		end
		local details, crowns, flora = 0, 0, 0
		for _, part in region.Model:GetDescendants() do
			if part.Name == "HouseDetail" then
				details += 1
				assert(not part.CanCollide)
			end
			if part.Name == "TreeCrown" then
				crowns += 1
			end
			if part.Name == "GrassBlade" or part.Name == "RealmFlora" then
				flora += 1
			end
		end
		assert(details >= 48 and crowns >= 8 and flora >= 40, "Realm scenery missing: " .. biome.Id)
		for _, spec in region.Interactions do
			if spec.Part:GetAttribute("Collectible") then
				local attached = false
				for _, structure in region.Structures do
					if structure.Part == spec.Part then
						attached = structure.Ground:GetAttribute("Ground")
					end
				end
				assert(attached, "Resource is not attached to collapsing ground")
			end
		end
		region.Model:Destroy()
	end
	folder:Destroy()
end)

test("Scavenging rejects distant, displaced, dead and repeated prompt requests", function()
	local w, p, a, rec = system()
	local region = w.Islands[0]
	local timber = find(region, "Timber")
	assert(not a:interact(rec, region, timber) and rec.Bag.Timber == 0)
	rec.Player.Character.HumanoidRootPart.Position = timber.Part.Position + V.new(0, 1.5, 0)
	assert(not a:interact(rec, region, timber), "Teleported prompt accepted before movement validation")
	move(rec, timber)
	assert(a:interact(rec, region, timber) and rec.Bag.Timber == 1 and timber.Stock == 11)
	assert(not a:interact(rec, region, timber) and rec.Bag.Timber == 1)
	h:advance(0.6)
	assert(not a:interact(rec, region, timber), "One supply was farmed repeatedly")
	for _, spec in region.Interactions do
		if spec.Kind == "Timber" and spec ~= timber then
			move(rec, spec)
			a:interact(rec, region, spec)
		end
	end
	assert(rec.Bag.Timber == 12 and timber.Stock == 11, "Inventory cap or once-per-player gathering failed")
	p:eliminate(rec, "test")
	h:advance(0.6)
	assert(not a:interact(rec, region, timber))
	dispose(w, p, a, rec)
end)
test("Shared bridge contributions consume resources and open a continuous shortcut", function()
	local w, p, a, rec = system()
	local region = w.Islands[0]
	local repair = find(region, "Repair")
	move(rec, repair)
	assert(not a:interact(rec, region, repair) and region.Repair == 0)
	rec.Bag.Timber = 6
	for _ = 1, 3 do
		move(rec, repair)
		assert(a:interact(rec, region, repair))
	end
	assert(rec.Bag.Timber == 0 and region.Repair == 6)
	for _, part in region.Routes.Loop do
		assert(part.CanCollide and part.Transparency == 0)
	end
	move(rec, repair)
	assert(not a:interact(rec, region, repair))
	dispose(w, p, a, rec)
end)
test("Collected cave keys operate the altar and unlock authorized upward escape", function()
	local w, p, a, rec = system()
	local region = w.Islands[0]
	for _, glyph in { "Sun", "Leaf", "Moon" } do
		local spec = find(region, "Glyph", glyph)
		move(rec, spec)
		assert(a:interact(rec, region, spec))
	end
	assert(
		region.Glyph == 0 and not region.Model:GetAttribute("PortalOpen"),
		"Picking up keys solved the puzzle without using them"
	)
	move(rec, find(region, "Seal"))
	assert(a:useGlyph(rec, "Moon") and region.Glyph == 0)
	for _, glyph in { "Sun", "Leaf", "Moon" } do
		h:advance(0.6)
		assert(a:useGlyph(rec, glyph))
	end
	assert(region.Model:GetAttribute("PortalOpen"))
	local portal = find(region, "Portal")
	move(rec, portal)
	assert(a:interact(rec, region, portal))
	assert(rec.Region == 1 and rec.Peak == 128 and w.Islands[1].Activated)
	assert((rec.Player.Character.HumanoidRootPart.Position - w:point(1)).Magnitude < 5)
	assert(not p:transfer(rec, 3), "Server transfer skipped a region")
	dispose(w, p, a, rec)
end)
test("Emergency crystals, healing and discovery have bounded server-owned effects", function()
	local w, p, a, rec = system()
	local region = w.Islands[0]
	rec.Bag.Crystal = 4
	local portal = find(region, "Portal")
	for _ = 1, 2 do
		move(rec, portal)
		assert(a:interact(rec, region, portal))
	end
	assert(region.Model:GetAttribute("PortalOpen") and rec.Bag.Crystal == 0)
	local herb = find(region, "Herb")
	move(rec, herb)
	assert(a:interact(rec, region, herb))
	rec.Player.Character.Humanoid.Health = 45
	local healer = find(region, "Heal")
	move(rec, healer)
	assert(a:interact(rec, region, healer))
	assert(rec.Player.Character.Humanoid.Health == 80 and rec.Bag.Herb == 0)
	local shrine = find(region, "Discover")
	move(rec, shrine)
	assert(a:interact(rec, region, shrine))
	move(rec, shrine)
	assert(not a:interact(rec, region, shrine))
	dispose(w, p, a, rec)
end)
test("Elevator moves a real deck, survives rebasing and releases riders at arrival or death", function()
	local w, p, a, rec = system()
	local lift = find(w.Islands[0], "Lift")
	move(rec, lift)
	assert(
		a:interact(rec, w.Islands[0], lift) and rec.Transit and rec.Player.Character.HumanoidRootPart.Anchored
	)
	local deck = a.Trips[rec].Deck
	h:advance(7)
	a:update()
	assert(deck.Parent and deck.Position.Y > Config.StartY + 50)
	w:rebase(1024)
	p:rebase(1024)
	h:advance(7.1)
	a:update()
	assert(
		not rec.Transit
			and not rec.Player.Character.HumanoidRootPart.Anchored
			and rec.Region == 1
			and rec.Peak == 128
	)
	assert(not deck.Parent)
	local nextLift = find(w.Islands[1], "Lift")
	move(rec, nextLift)
	assert(a:interact(rec, w.Islands[1], nextLift))
	p:eliminate(rec, "test")
	a:update()
	assert(not rec.Transit and not rec.Player.Character.HumanoidRootPart.Anchored)
	dispose(w, p, a, rec)
end)
test("Corruption warns before ground falls, carries structures and preserves early escape", function()
	local w, p, a, rec = system()
	local region = w.Islands[0]
	w:destabilize(0, 1)
	local cell = region.Cells[1]
	assert(cell.State == "Cracking" and cell.Part.CanCollide and #cell.Cracks == 2)
	h:advance(Config.CorruptionWarning - 1)
	w:consume(-100)
	assert(cell.Part.CanCollide)
	h:advance(1.1)
	w:consume(-100)
	assert(cell.State == "Breaking" and not cell.Part.CanCollide)
	local before = cell.Part.Position.Y
	h:advance(1)
	w:consume(-100)
	assert(cell.Part.Position.Y < before and cell.Part.Transparency > 0)
	h:advance(2.1)
	w:consume(-100)
	assert(cell.State == "Gone" and not cell.Part.Parent)
	assert(region.Landing.CanCollide)
	-- The causeway survives early corruption: every part remains and its walking colliders stay
	-- solid (bridge planks and hangers are visual-only by design).
	for _, part in region.Routes.Ascent do
		assert(part.Parent and (not part:GetAttribute("Ground") or part.CanCollide))
	end
	dispose(w, p, a, rec)
end)
test("Storm shelter prevents damage, earthquake preserves causeway, and surges increase pressure", function()
	local w, p, a, rec = system()
	local wave = Wave.new()
	local events = Events.new(w, p, wave, h.Effects)
	events:reset()
	events:update(35)
	assert(events.Name == "Storm" and events.Phase == "Warning")
	events:update(43)
	assert(rec.Player.Character.Humanoid.Health == 92)
	local floor = w.Islands[0].Shelters[2].Anchor
	rec.Player.Character.HumanoidRootPart.Position = floor.Position + V.new(0, 4, 0)
	assert(w:sheltered(rec.Player.Character.HumanoidRootPart.Position))
	events:update(45)
	assert(rec.Player.Character.Humanoid.Health == 92)
	events:update(59)
	events:update(91)
	events:update(99)
	assert(events.Name == "Earthquake" and events.Phase == "Active")
	for _, part in w.Islands[0].Routes.Ascent do
		assert(part:GetAttribute("Phase") ~= "Cracking")
	end
	events:update(115)
	events:update(147)
	events:update(155)
	assert(events.Name == "StructureCollapse")
	local damaged = false
	for _, part in w.Islands[0].Routes.Cave do
		if part:GetAttribute("Phase") == "Cracking" then
			damaged = true
		end
	end
	assert(damaged)
	events:update(171)
	events:update(203)
	events:update(211)
	assert(events.Name == "DeletionSurge" and wave.Surge == 3)
	local before = wave.Height
	wave:update(1, 300, 0, Config.StartY)
	assert(wave.Height - before > Config.WaveBaseSpeed * 2)
	events:update(227)
	assert(wave.Surge == 1)
	wave.Part:Destroy()
	dispose(w, p, a, rec)
end)
test("Continuous causeways have supported surfaces and clear headroom in all orientations", function()
	local w, p, a, rec = system()
	w:generate(Config.StartY + Config.RegionRise * 3)
	local params = { FilterDescendantsInstances = { w.Root } }
	for index = 0, 4 do
		local region = w.Islands[index]
		params.FilterDescendantsInstances = { region.Model, w.Islands[index + 1].Model }
		for _, route in { region.Routes.Approach, region.Routes.Ascent, region.Routes.Arrival } do
			for _, part in route do
				if part:GetAttribute("Ground") then
					local foot = part.CFrame:PointToWorldSpace(V.new(0, part.Size.Y / 2, 0))
					local hit = h.Workspace:Raycast(foot + V.new(0, 3, 0), V.new(0, -7, 0), params)
					assert(hit and hit.Instance:GetAttribute("Ground"), "Unsupported causeway")
					for _, x in { -0.9, 0.9 } do
						for _, z in { -0.9, 0.9 } do
							local obstruction =
								h.Workspace:Raycast(foot + V.new(x, 0.7, z), V.new(0, 5.3, 0), params)
							assert(
								not obstruction,
								"Causeway headroom blocked by "
									.. tostring(obstruction and obstruction.Instance)
							)
						end
					end
				end
			end
		end
	end
	for _, route in { w.Islands[0].Routes.Approach, w.Islands[0].Routes.Ascent, w.Islands[0].Routes.Arrival } do
		for _, part in route do
			if part:GetAttribute("Ground") then
				local foot = part.CFrame:PointToWorldSpace(V.new(0, part.Size.Y / 2, 0))
				rec.Player.Character.HumanoidRootPart.Position = foot + V.new(0, 3, 0)
				h:advance(0.7)
				p:update(-100)
			end
		end
	end
	assert(rec.Region == 1 and rec.Peak >= 128 and rec.Strikes == 0, "Walking ascent failed validation")
	dispose(w, p, a, rec)
end)
test("Supported altitude replaces rune ordering while impossible displacement is rolled back", function()
	local w, p, a, rec = system()
	local root = rec.Player.Character.HumanoidRootPart
	h:advance(4)
	local pos = root.Position
	root.Position = pos + V.new(180, 100, 0)
	p:update(-100)
	assert(rec.Strikes == 1 and root.Position == pos and rec.Peak == 0)
	local ability = h.Load(h.Server.Systems.AbilityService).new(h.Effects)
	ability:request(rec, "Shield")
	p:damage(rec, 30)
	assert(rec.Player.Character.Humanoid.Health == 100)
	assert(p:transfer(rec, 1))
	h:advance(0.2)
	p:update(-100)
	assert(rec.Peak >= 128 and rec.Region == 1)
	dispose(w, p, a, rec)
end)
print(
	string.format(
		"%d exploration integration tests passed (offline fixtures; Studio validation pending)",
		passed
	)
)
