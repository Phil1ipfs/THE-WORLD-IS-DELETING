--!nonstrict
-- Dragonbane equipment placed while a region is generated (before scenery claims the land).
--   Raid and encounter regions (Crystal Kingdom onward): a Dragonbane Forge that crafts the
--   crossbow and fletches bolts from Timber and Crystals.
--   Encounter regions: a repairable Ballista and a Crystal Cannon on the mainland.
-- Visuals are native parts attached to their supporting ground (they collapse with it).
-- Turret parts are listed with offsets from a pivot so the dragon system can aim them.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Dragon = require(Shared.DragonConfig)
local Config = require(Shared.GameConfig)
local Random = require(Shared.Random)
local SoundBank = require(Shared.SoundBank)
local G = require(script.Parent.Geometry)
local Armory = {}
local C = Color3.fromRGB
local WOOD, DARK, BRASS, STONE = C(112, 78, 48), C(64, 44, 30), C(196, 152, 74), C(120, 116, 110)
local EMBER, CRYSTAL = C(255, 140, 60), C(130, 220, 255)
local mainland = { Mainland = true }
-- Floating status sign; returns its TextLabel so the dragon system can rewrite it.
local function sign(parent, position, text, color)
	local anchor = G.part(parent, "ArmorySign", Vector3.one, CFrame.new(position), color, nil, false)
	anchor.Transparency, anchor.CanQuery = 1, false
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.MaxDistance, gui.AlwaysOnTop = UDim2.fromOffset(240, 56), 85, false
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Font, label.TextSize, label.TextColor3 = Enum.Font.GothamBold, 16, color
	label.TextStrokeTransparency, label.Text = 0.35, text
	label.Parent = gui
	return label, anchor
end
-- Turret helper: builds parts relative to a pivot and remembers their offsets.
local function turret(B, pivot)
	local t = { Pivot = pivot, Parts = {}, Offsets = {} }
	function t.part(name, size, offset, color, material, o)
		local p = B.part(name, size, pivot * offset, color, material, o)
		table.insert(t.Parts, p)
		t.Offsets[p] = offset
		return p
	end
	return t
end
-- Walkable emplacement decks count as safe footing for interactions (GroundProbe).
local function deck(p)
	p:SetAttribute("Ground", true)
	return p
end
local function forge(B, base, accent)
	deck(
		B.part(
			"ForgeAnvil",
			Vector3.new(3, 2.2, 2),
			base * CFrame.new(0, 1.1, 0),
			STONE,
			"Slate",
			{ Collide = true }
		)
	)
	B.part("ForgeAnvil", Vector3.new(4.2, 0.8, 2.3), base * CFrame.new(0, 2.6, 0), C(60, 60, 66), "Metal")
	local brazier = B.part(
		"ForgeBrazier",
		Vector3.new(1.4, 2.6, 2.6),
		base * CFrame.new(3.8, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2),
		C(70, 60, 56),
		"Metal",
		{ Shape = "Cylinder", Collide = true }
	)
	local ember =
		B.part("ForgeEmber", Vector3.new(1.8, 0.7, 1.8), base * CFrame.new(3.8, 1.5, 0), EMBER, "Neon")
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name, sparks.Texture = "ForgeSparks", "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color, sparks.LightEmission, sparks.Rate = ColorSequence.new(C(255, 180, 90)), 0.9, 4
	sparks.Lifetime, sparks.Speed = NumberRange.new(0.6, 1.1), NumberRange.new(2, 5)
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = ember
	B.light(ember, EMBER, 14, 0.9)
	-- Rack with two display crossbows.
	B.part("ForgeRack", Vector3.new(4.4, 3.4, 0.4), base * CFrame.new(-1, 1.7, 2.2), WOOD, "WoodPlanks")
	for k = -1, 1, 2 do
		local mount = base * CFrame.new(-1 + k * 1.1, 2.2, 1.95)
		B.part("RackCrossbow", Vector3.new(0.35, 2.4, 0.35), mount, DARK, "Wood")
		B.part(
			"RackCrossbow",
			Vector3.new(2, 0.25, 0.3),
			mount * CFrame.new(0, 0.8, 0),
			C(150, 30, 26),
			"Wood"
		)
		B.part("RackCrossbow", Vector3.new(0.25, 0.4, 0.25), mount * CFrame.new(0, 1.3, 0), accent, "Neon")
	end
	return { Brazier = brazier, Ember = ember }
end
-- Leaning rack of crystal-tipped Dragonbane Harpoons.
local function rack(B, base, accent)
	B.part(
		"RackFrame",
		Vector3.new(5, 0.5, 1.2),
		base * CFrame.new(0, 0.25, 0.8),
		WOOD,
		"WoodPlanks",
		{ Collide = true }
	)
	B.part("RackFrame", Vector3.new(5, 0.4, 0.4), base * CFrame.new(0, 3.6, 1.2), DARK, "Wood")
	for _, x in { -2.3, 2.3 } do
		B.part("RackFrame", Vector3.new(0.5, 3.8, 0.5), base * CFrame.new(x, 1.9, 1.2), DARK, "Wood")
	end
	for k = -1, 1 do
		local lean = base * CFrame.new(k * 1.3, 2.2, 0.6) * CFrame.Angles(-0.28, 0, 0)
		B.part("RackHarpoon", Vector3.new(0.3, 4.6, 0.3), lean, C(96, 70, 46), "Wood")
		B.part("RackHarpoonTip", Vector3.new(0.5, 1, 0.5), lean * CFrame.new(0, 2.7, 0), accent, "Neon")
		for _, side in { -1, 1 } do
			B.part(
				"RackHarpoonBarb",
				Vector3.new(0.15, 0.6, 0.15),
				lean * CFrame.new(side * 0.3, 2.1, 0) * CFrame.Angles(0, 0, side * 0.6),
				C(200, 200, 210),
				"Metal"
			)
		end
	end
	return {}
end
-- Looping 3D world sound from the SoundBank (tagged so clients route it through SFX volume).
function Armory.loop(parent, key)
	if not parent then
		return nil
	end
	local recipe = SoundBank.Loops[key]
	local sound = SoundBank.make(function(class)
		return Instance.new(class)
	end, recipe, parent, key)
	pcall(function()
		game:GetService("CollectionService"):AddTag(sound, "RealmSound")
	end)
	sound:Play()
	return sound
end
local function ballista(B, base)
	deck(
		B.part(
			"BallistaBase",
			Vector3.new(6, 0.8, 6),
			base * CFrame.new(0, 0.4, 0),
			WOOD,
			"WoodPlanks",
			{ Collide = true }
		)
	)
	B.part(
		"BallistaPost",
		Vector3.new(1.4, 3.2, 1.4),
		base * CFrame.new(0, 2.4, 0),
		DARK,
		"Wood",
		{ Collide = true }
	)
	local t = turret(B, base * CFrame.new(0, 4.4, 0))
	t.part("BallistaStock", Vector3.new(1, 0.8, 7.5), CFrame.new(0, 0, 0.4), WOOD, "Wood")
	for _, side in { -1, 1 } do
		t.part(
			"BallistaArm",
			Vector3.new(0.5, 0.5, 4.6),
			CFrame.new(side * 2.2, 0.1, -2.4) * CFrame.Angles(0, side * 1.15, 0),
			DARK,
			"Wood"
		)
	end
	t.part(
		"BallistaString",
		Vector3.new(0.12, 0.12, 4.2),
		CFrame.new(0, 0.1, 0.2) * CFrame.Angles(0, math.pi / 2, 0),
		C(220, 210, 180),
		"Fabric"
	)
	t.part(
		"BallistaWinch",
		Vector3.new(2.6, 0.7, 0.7),
		CFrame.new(0, -0.2, 3.6),
		BRASS,
		"Metal",
		{ Shape = "Cylinder" }
	)
	t.Bolt =
		t.part("BallistaBolt", Vector3.new(0.3, 0.3, 6.5), CFrame.new(0, 0.6, -0.6), C(90, 70, 50), "Wood")
	t.Tip = t.part(
		"BallistaBolt",
		Vector3.new(0.6, 0.6, 1),
		CFrame.new(0, 0.6, -4.1),
		C(255, 214, 120),
		"Neon",
		{ Class = "WedgePart" }
	)
	return t
end
local function cannon(B, base)
	deck(
		B.part(
			"CannonMount",
			Vector3.new(5, 1.4, 5),
			base * CFrame.new(0, 0.7, 0),
			STONE,
			"Cobblestone",
			{ Collide = true }
		)
	)
	for _, side in { -1, 1 } do
		B.part("CannonCheek", Vector3.new(0.8, 2.6, 3), base * CFrame.new(side * 1.9, 2.6, 0), BRASS, "Metal")
	end
	local t = turret(B, base * CFrame.new(0, 3.4, 0))
	t.part(
		"CannonBarrel",
		Vector3.new(7, 2.2, 2.2),
		CFrame.new(0, 0, -1) * CFrame.Angles(0, math.pi / 2, 0),
		BRASS,
		"Metal",
		{ Shape = "Cylinder" }
	)
	for k = 0, 2 do
		t.part(
			"CannonRing",
			Vector3.new(0.35, 2.6, 2.6),
			CFrame.new(0, 0, 1.2 - k * 2.2) * CFrame.Angles(0, math.pi / 2, 0),
			CRYSTAL,
			"Neon",
			{ Shape = "Cylinder" }
		)
	end
	t.Muzzle = t.part(
		"CannonCrystal",
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(0, 0, -4.6),
		CRYSTAL,
		"Glass",
		{ Shape = "Ball" }
	)
	t.part(
		"CannonBreech",
		Vector3.new(1.8, 1.8, 1.8),
		CFrame.new(0, 0, 2.6),
		BRASS,
		"Metal",
		{ Shape = "Ball" }
	)
	return t
end
-- Dragon Preview: Studio only, enabled by the Workspace attribute DragonPreview (set in
-- default.project.json). Live servers always use the real realm progression.
function Armory.preview()
	local ok, studio = pcall(function()
		return game:GetService("RunService"):IsStudio()
	end)
	return ok and studio == true and workspace:GetAttribute("DragonPreview") == true
end
-- Called by ExplorationGenerator after realm activities, before timber caches and scenery.
-- Every region gets a forge and harpoon rack (weapons are visible from the first island);
-- encounter regions add the ballista and crystal cannon.
function Armory.build(r, prompt)
	local stage = Dragon.stage(r.Index, Config.RegionRise, Armory.preview())
	local S, B = r.Sites, r.Props
	local rng = Random.new((r.Seed or 0) + r.Index * 7907 + 11)
	local accent = G.color(r.Biome.Accent)
	local placed = {}
	local function find(radius, ideal)
		local site = S:find(rng, radius, mainland, 70, function(x, z)
			local d = math.sqrt(x * x + z * z)
			local value = -math.abs(d - ideal) + rng:range(0, 6)
			for _, other in placed do
				if math.sqrt((x - other.X) ^ 2 + (z - other.Z) ^ 2) < 30 then
					value -= 60
				end
			end
			return value
		end)
		if site then
			table.insert(placed, site)
		end
		return site
	end
	local armory = { Stage = stage }
	local function station(kind, site, text, build)
		local ground = S:at(site.X, site.Z)
		B.Ground = if ground then ground.Cell.Part else r.Landing
		local yaw = math.atan2(site.X, site.Z) -- Face outward, toward the open sky.
		local base = CFrame.new(r.Center + Vector3.new(site.X, S:height(site.X, site.Z), site.Z))
			* CFrame.Angles(0, yaw, 0)
		local anchor = prompt(kind, site.X, site.Z, text, nil, 2.2)
		anchor.Transparency, anchor.Name = 1, "Dragonbane" .. kind
		local spec = r.Interactions[#r.Interactions]
		spec.Dragonbane = kind
		spec.Prompt.ObjectText = if kind == "HarpoonRack"
			then "Dragonbane Harpoons"
			elseif Dragon.Weapons[kind] then Dragon.Weapons[kind].Name
			else "Dragonbane Forge"
		spec.Prompt.HoldDuration = 0.3
		local entry = { Spec = spec, Ground = B.Ground, Site = site, Built = build(B, base, accent) }
		if entry.Built and entry.Built.Parts then
			entry.Built.Local = CFrame.new(r.Center):ToObjectSpace(entry.Built.Pivot)
		end
		local signAnchor
		entry.Label, signAnchor = sign(r.Model, base.Position + Vector3.new(0, 8.5, 0), text, accent)
		table.insert(r.Structures, { Part = signAnchor, Ground = B.Ground })
		armory[kind] = entry
		return entry
	end
	local forgeSite = find(4.5, 30)
	if forgeSite then
		local entry = station("Forge", forgeSite, "DRAGONBANE FORGE\nCrossbow: 2 timber + 1 crystal", forge)
		Armory.loop(entry.Built.Ember, "ForgeFire")
		-- Harpoon rack about ten studs from the forge.
		local rackSite = S:find(rng, 3.5, mainland, 70, function(x, z)
			local d = math.sqrt((x - forgeSite.X) ^ 2 + (z - forgeSite.Z) ^ 2)
			return -math.abs(d - 10) + rng:range(0, 2)
		end)
		if
			not rackSite
			or math.sqrt((rackSite.X - forgeSite.X) ^ 2 + (rackSite.Z - forgeSite.Z) ^ 2) >= 24
		then
			-- Crowded land: try a ring of spots hugging the forge instead.
			rackSite = nil
			for _, distance in { 8, 11, 14 } do
				for k = 0, 11 do
					local a = k * math.pi / 6
					local x, z = forgeSite.X + math.cos(a) * distance, forgeSite.Z + math.sin(a) * distance
					if not rackSite and S:fits(x, z, 3, mainland) then
						S:reserve(x, z, 3)
						rackSite = { X = x, Z = z }
					end
				end
			end
		end
		if rackSite then
			station("HarpoonRack", rackSite, "HARPOON RACK\n3 harpoons: 3 timber + 1 crystal", rack)
		end
	end
	if stage == "Encounter" then
		local ballistaSite = find(4.5, 48)
		if ballistaSite then
			station("Ballista", ballistaSite, "BROKEN BALLISTA\nRepair with 4 timber", ballista)
		end
		local cannonSite = find(4.5, 48)
		if cannonSite then
			station("Cannon", cannonSite, "CRYSTAL CANNON\n1 crystal per shot", cannon)
		end
	end
	B.Ground = r.Landing
	r.Armory = armory
	return armory
end
-- World pivot of a turret; stored relative to the region centre so rebasing keeps it valid.
function Armory.pivot(t, center)
	return CFrame.new(center) * t.Local
end
-- Places turret parts for an aim rotation relative to the pivot (identity = resting).
function Armory.aim(t, center, rotation)
	local pivot = Armory.pivot(t, center)
	for _, p in t.Parts do
		if p.Parent then
			p.CFrame = pivot * rotation * t.Offsets[p]
		end
	end
end
return Armory
