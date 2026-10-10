--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Layout = require(Shared.RegionLayout)
local Biomes = require(Shared.BiomeConfig)
local Realms = require(Shared.RealmConfig)
local Random = require(Shared.Random)
local Seal = require(Shared.SealConfig)
local Services = script.Parent.Parent.Services
local G = require(Services.Geometry)
local Props = require(Services.Props)
local Sites = require(Services.Sites)
local Architecture = require(Services.Architecture)
local Bridge = require(Services.SuspensionBridge)
local Generator = {}
local timber = Color3.fromRGB(109, 78, 53)
local styleFor = {
	Grasslands = "Cottage",
	Crystal = "Pavilion",
	Jungle = "Stilt",
	Volcanic = "Bunker",
	Frozen = "Lodge",
	Ruins = "Stone",
	Storm = "Watch",
	Mechanical = "Workshop",
	Celestial = "Pagoda",
	Void = "Obelisk",
}
local function vector(p)
	return Vector3.new(p.X, p.Y, p.Z)
end
function Generator.build(parent, index, origin, seed)
	local biome = Biomes.at(index * Config.RegionRise)
	local design = Realms.get(biome.Id)
	local grass, rock, gold = G.color(biome.Top), G.color(biome.Rock), G.color(biome.Accent)
	local groundMaterial = if biome.Id == "Frozen"
		then Enum.Material.Snow
		elseif biome.Id == "Mechanical" then Enum.Material.Metal
		elseif biome.Id == "Volcanic" then Enum.Material.Basalt
		elseif biome.Decor == "Crystal" then Enum.Material.Slate
		elseif biome.Id == "Ruins" then Enum.Material.Grass
		else Enum.Material.Grass
	local center = vector(Layout.center(index, Config.RegionRadius, Config.RegionRise, Config.StartY))
		- Vector3.new(0, origin, 0)
	local model = Instance.new("Model")
	model.Name = "Region_" .. index
	model:SetAttribute("Index", index)
	model:SetAttribute("RegionName", Realms.regionName(index, biome.Id))
	model:SetAttribute("LogicalY", center.Y + origin)
	model:SetAttribute("Biome", biome.Id)
	pcall(function()
		-- Distant regions render as streamed imposters on clients.
		model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end)
	model.Parent = parent
	local r = {
		Model = model,
		Index = index,
		Y = center.Y + origin,
		Center = center,
		Side = center,
		Cells = {},
		Structures = {},
		Interactions = {},
		Shelters = {},
		Connections = {},
		Routes = {},
		Activities = {},
		Hazards = {},
		Biome = biome,
		Design = design,
		Seed = seed,
	}
	local rng = Random.new(seed + index * 1709)
	r.Rng = rng
	local function at(x, y, z)
		return center + Vector3.new(x, y, z)
	end
	local function part(name, size, position, color, material, collide)
		local p = G.part(model, name, size, CFrame.new(position), color, material, collide)
		p:SetAttribute("Region", index)
		return p
	end
	local function cell(name, size, position, edge, late)
		local p = part(name, size, position - Vector3.new(0, size.Y / 2, 0), grass, groundMaterial)
		p:SetAttribute("Ground", true)
		p:SetAttribute("Phase", "Stable")
		table.insert(r.Cells, { Part = p, Edge = edge, Late = late or false, State = "Stable" })
		return p
	end
	r.AddCell = cell
	-- Shared prop builder; decoration is attached to its supporting ground for collapse.
	local B = Props.builder(model, function(p, ground, detail)
		p:SetAttribute("Region", index)
		if detail then
			p:SetAttribute("Detail", true)
		end
		table.insert(r.Structures, { Part = p, Ground = ground or r.Landing })
	end, rng)
	r.Props = B
	local undersideMat = if biome.Id == "Frozen"
		then Enum.Material.Glacier
		elseif biome.Id == "Volcanic" or biome.Id == "Void" then Enum.Material.Basalt
		elseif biome.Id == "Ruins" then Enum.Material.Sandstone
		else Enum.Material.Rock
	for _, c in Layout.cells(index, seed) do
		local tint = grass:Lerp(if c.Zone == "Outskirts" then gold else rock, rng:range(0, 0.07))
		local ground = cell("Earth_" .. c.Zone, Vector3.new(24.2, 5, 24.2), at(c.X, c.Y or 0, c.Z), c.Edge)
		ground.Color = tint
		local foundation = part(
			"RockFoundation",
			Vector3.new(22, rng:range(20, 42), 22),
			at(c.X, -24 + (c.Y or 0), c.Z),
			rock,
			undersideMat,
			false
		)
		foundation.CFrame *= CFrame.Angles(0, rng:range(-0.15, 0.15), 0.05)
		table.insert(r.Structures, { Part = foundation, Ground = ground })
		-- Hanging stone drips give each island an irregular floating silhouette.
		if c.Edge > 0.5 and rng:next() < 0.55 then
			local drip = part(
				"RockFoundation",
				Vector3.new(rng:range(10, 16), rng:range(26, 48), rng:range(10, 16)),
				at(c.X + rng:range(-4, 4), -44 - rng:range(0, 14) + (c.Y or 0), c.Z + rng:range(-4, 4)),
				rock:Lerp(Color3.new(0, 0, 0), rng:range(0.05, 0.2)),
				undersideMat,
				false
			)
			drip.CastShadow = false
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, drip
			table.insert(r.Structures, { Part = drip, Ground = ground })
		end
	end
	r.Landing = cell("Landing", Vector3.new(36, 6, 36), center + Vector3.new(0, 0.15, 0), 0, true)
	r.Landing.Color = grass
	r.Sites = Sites.new(r)
	local S = r.Sites
	local function walkway(name, a, b, width, late, enabled, sag)
		-- Crossings between landmasses are rope suspension bridges with plank decks.
		if
			enabled ~= false
			and (
				name == "SkyCauseway"
				or name == "ForestBridge"
				or name == "CaveBridge"
				or name == "SatelliteBridge"
			)
		then
			local built = Bridge.build({
				Parent = model,
				A = a,
				B = b,
				Width = if name == "SkyCauseway" then 11 else 9,
				Name = name,
				Region = index,
				Rng = rng,
				Sag = sag,
				Ground = function(collider)
					collider:SetAttribute("BridgeKey", tostring(a))
					table.insert(r.Cells, {
						Part = collider,
						Edge = if name == "SatelliteBridge" then 0.9 else 0.35,
						Late = late,
						State = "Stable",
					})
				end,
				Attach = function(p, collider)
					table.insert(r.Structures, { Part = p, Ground = collider })
				end,
			})
			return built.Parts
		end
		local count = math.ceil((b - a).Magnitude / 22)
		local parts = {}
		for i = 1, count do
			local p0, p1 = a:Lerp(b, (i - 1) / count), a:Lerp(b, i / count)
			local cf = CFrame.lookAt((p0 + p1) / 2, p1)
			local p = part(
				name,
				Vector3.new(width, 1.5, (p1 - p0).Magnitude + 0.5),
				cf.Position,
				timber,
				Enum.Material.WoodPlanks
			)
			p.CFrame = cf - cf.UpVector * 0.75
			p:SetAttribute("Ground", true)
			p:SetAttribute("Phase", "Stable")
			table.insert(r.Cells, { Part = p, Edge = 0.35, Late = late, State = "Stable" })
			table.insert(parts, p)
			for _, side in (if name == "CausewayApproach" or name == "CausewayArrival" then {} else { -1, 1 }) do
				local rail =
					part("BridgeRail", Vector3.new(0.6, 3, p.Size.Z), p.Position, timber, Enum.Material.Wood)
				rail.CFrame = cf * CFrame.new(side * (width / 2 + 0.1), 1.5, 0)
				table.insert(r.Structures, { Part = rail, Ground = p })
				table.insert(parts, rail)
				if i % 2 == 1 then
					local post = part(
						"BridgeRail",
						Vector3.new(0.9, 4, 0.9),
						p.Position,
						timber:Lerp(Color3.new(0, 0, 0), 0.25),
						Enum.Material.Wood
					)
					post.CFrame = cf * CFrame.new(side * (width / 2 + 0.1), 1.6, -p.Size.Z / 2 + 0.6)
					table.insert(r.Structures, { Part = post, Ground = p })
					table.insert(parts, post)
				end
			end
		end
		if enabled == false then
			for _, p in parts do
				p.Transparency, p.CanCollide, p.CanQuery = 0.85, false, false
			end
		end
		return parts
	end
	r.Routes.Grove = walkway("ForestBridge", at(66, 0.2, 24), at(132, 0.2, 24), 14, false, nil, 0.2)
	r.Routes.Cave = walkway("CaveBridge", at(-48, 0.2, -48), at(-120, 0.2, -48), 14, false, nil, 0.2)
	r.Routes.Loop = walkway("RepairableBridge", at(-120, 0.2, -48), at(132, 0.2, 24), 12, true, false)
	local nextCenter = vector(Layout.center(index + 1, Config.RegionRadius, Config.RegionRise, Config.StartY))
		- Vector3.new(0, origin, 0)
	local direction = Vector3.new(nextCenter.X - center.X, 0, nextCenter.Z - center.Z).Unit
	local departure = center + direction * 150 + Vector3.new(0, 0.3, 0)
	local arrival = nextCenter - direction * 150 + Vector3.new(0, 0.3, 0)
	r.Routes.Approach = walkway("CausewayApproach", center + Vector3.new(0, 0.3, 0), departure, 16, true)
	r.Routes.Ascent = walkway("SkyCauseway", departure, arrival, 16, true)
	r.Routes.Arrival = walkway("CausewayArrival", arrival, nextCenter + Vector3.new(0, 0.3, 0), 16, true)
	for _, p in r.Routes.Arrival do
		p:SetAttribute("Region", index + 1)
	end
	-- Reserve shelters, routes and the established points of interest before scattering content.
	S:reserve(0, 0, 20)
	for _, h in { { -60, -16 }, { 0, -60 }, { 60, -16 } } do
		S:reserve(h[1], h[2] + 2, 19)
		S:reserveSegment(0, 0, h[1], h[2] + 16, 3)
	end
	S:reserve(-36, 18, 6)
	S:reserve(0, 12, 4)
	S:reserveSegment(0, 0, direction.X * 160, direction.Z * 160, 11)
	if index > 0 then
		local previous =
			vector(Layout.center(index - 1, Config.RegionRadius, Config.RegionRise, Config.StartY))
		local incoming = Vector3.new(center.X - previous.X, 0, center.Z - previous.Z).Unit
		S:reserveSegment(0, 0, -incoming.X * 160, -incoming.Z * 160, 11)
	end
	S:reserveSegment(66, 24, 132, 24, 9)
	S:reserveSegment(-48, -48, -120, -48, 9)
	S:reserveSegment(-120, -48, 132, 24, 8)
	local lobe = Layout.outskirts(index, seed)
	r.Outskirts = { X = lobe.X, Z = lobe.Z }
	S:reserveSegment(0, 0, lobe.X * 0.8, lobe.Z * 0.8, 3)
	-- Satellite sub-areas: rope suspension bridges from the mainland, each with a signpost.
	r.Satellites = Layout.satellites(index, seed)
	r.Routes.Satellites = {}
	for _, sat in r.Satellites do
		sat.Name = Realms.subAreaName(biome.Id, sat.Kind)
		r.Routes.Satellites[sat.Kind] = walkway(
			"SatelliteBridge",
			at(sat.StartX, 0.2, sat.StartZ),
			at(sat.EndX, sat.Height + 0.2, sat.EndZ),
			9,
			false
		)
		S:reserveSegment(sat.StartX, sat.StartZ, sat.EndX, sat.EndZ, 6)
		S:reserve(sat.StartX, sat.StartZ, 7)
		S:reserve(sat.EndX, sat.EndZ, 7)
		local head = S:at(sat.StartX, sat.StartZ)
		B.Ground = if head then head.Cell.Part else r.Landing
		local side = Vector3.new(-math.sin(sat.Angle), 0, math.cos(sat.Angle)) * 7
		local postBase = at(sat.StartX, 0, sat.StartZ) + side
		B.part(
			"Signpost",
			Vector3.new(0.6, 6, 0.6),
			CFrame.new(postBase + Vector3.new(0, 3, 0)),
			timber,
			Enum.Material.Wood,
			{ Collide = true }
		)
		B.part(
			"Signpost",
			Vector3.new(4.4, 1.3, 0.3),
			CFrame.lookAt(
				postBase + Vector3.new(0, 5, 0),
				postBase + Vector3.new(0, 5, 0) + Vector3.new(math.cos(sat.Angle), 0, math.sin(sat.Angle))
			) * CFrame.Angles(0, math.pi / 2, 0),
			timber:Lerp(Color3.fromRGB(200, 170, 120), 0.4),
			Enum.Material.WoodPlanks
		)
		G.label(
			model,
			string.upper(sat.Name) .. "\n" .. Realms.SubAreaPurpose[sat.Kind],
			postBase + Vector3.new(0, 8.5, 0),
			gold
		)
	end
	local beacon = direction * 30 + Vector3.new(-direction.Z, 0, direction.X) * 16
	r.Beacon = at(beacon.X, 0, beacon.Z)
	S:reserve(beacon.X, beacon.Z, 5)
	local function prompt(kind, x, z, text, extra, y)
		local anchor = part(
			kind,
			Vector3.new(2, 2, 2),
			at(x, (y or 2) + S:height(x, z), z),
			if kind == "Timber" then timber else gold,
			Enum.Material.SmoothPlastic,
			false
		)
		local extras = {}
		local function fixture(...)
			local p = part(...)
			table.insert(extras, p)
			return p
		end
		local p = Instance.new("ProximityPrompt")
		anchor:SetAttribute("InteractionId", index .. ":" .. (#r.Interactions + 1))
		anchor:SetAttribute("ItemKind", kind)
		anchor:SetAttribute(
			"Collectible",
			kind == "Timber" or kind == "Crystal" or kind == "Herb" or kind == "Glyph"
		)
		anchor:AddTag("RealmInteraction")
		anchor.CanQuery = true
		p.ActionText, p.ObjectText = text, kind
		p.MaxActivationDistance, p.HoldDuration, p.RequiresLineOfSight =
			12, if anchor:GetAttribute("Collectible") then 0 else 0.25, false
		p.Enabled, p.ClickablePrompt = true, true
		p.KeyboardKeyCode, p.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
		p.Style = Enum.ProximityPromptStyle.Default
		p.Parent = anchor
		local function child(name, size, cf, color, material, o)
			o = o or {}
			local c = G.part(anchor, name, size, cf, color, material, false)
			c.CastShadow = o.Shadow == true
			if o.Shape then
				c.Shape = Enum.PartType[o.Shape]
			end
			if o.Mesh then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType, mesh.Parent = Enum.MeshType[o.Mesh], c
			end
			if o.Class then
				c:Destroy()
				c = Instance.new(o.Class)
				c.Name, c.Size, c.CFrame, c.Color, c.Material = name, size, cf, color, material
				c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow =
					true, false, false, false, false
				c.Parent = anchor
			end
			c.Transparency = o.Transparency or 0
			return c
		end
		local base = anchor.CFrame
		if kind == "Glyph" then
			local key = Seal.Keys[extra]
			local tint = G.color(key.Color)
			anchor.Name = extra .. "Key"
			anchor.Color, anchor.Material = Color3.fromRGB(214, 206, 190), Enum.Material.Marble
			anchor.Size = Vector3.new(2.8, 3.4, 0.6)
			child(
				"KeyPlinth",
				Vector3.new(3.4, 0.8, 1.4),
				base * CFrame.new(0, -2, 0),
				rock,
				Enum.Material.Slate
			)
			child(
				"KeyFrame",
				Vector3.new(3.1, 3.7, 0.4),
				base * CFrame.new(0, 0, 0.2),
				Color3.fromRGB(170, 150, 110),
				Enum.Material.Wood
			)
			if extra == "Sun" then
				child(
					"KeyEmblem",
					Vector3.new(0.2, 1.5, 1.5),
					base * CFrame.new(0, 0.2, -0.36) * CFrame.Angles(0, math.pi / 2, 0),
					tint,
					Enum.Material.Neon,
					{ Shape = "Cylinder" }
				)
				for k = 1, 8 do
					child(
						"KeyEmblem",
						Vector3.new(0.18, 0.5, 0.12),
						base
							* CFrame.new(0, 0.2, -0.36)
							* CFrame.Angles(0, 0, k * math.pi / 4)
							* CFrame.new(0, 1.05, 0),
						tint,
						Enum.Material.Neon
					)
				end
			elseif extra == "Leaf" then
				for side = -1, 1, 2 do
					child(
						"KeyEmblem",
						Vector3.new(0.12, 1.1, 0.8),
						base
							* CFrame.new(0, 0.2 + side * 0.55, -0.36)
							* CFrame.Angles(0, -math.pi / 2, if side > 0 then 0 else math.pi)
							* CFrame.new(0, 0, 0),
						tint,
						Enum.Material.Neon,
						{ Class = "WedgePart" }
					)
				end
				child(
					"KeyEmblem",
					Vector3.new(0.12, 2.2, 0.12),
					base * CFrame.new(0, 0.2, -0.38),
					tint:Lerp(Color3.new(0, 0, 0), 0.3),
					Enum.Material.Neon
				)
			else
				child(
					"KeyEmblem",
					Vector3.new(0.2, 1.7, 1.7),
					base * CFrame.new(0, 0.2, -0.36) * CFrame.Angles(0, math.pi / 2, 0),
					tint,
					Enum.Material.Neon,
					{ Shape = "Cylinder" }
				)
				child(
					"KeyEmblem",
					Vector3.new(0.22, 1.5, 1.5),
					base * CFrame.new(0.45, 0.4, -0.4) * CFrame.Angles(0, math.pi / 2, 0),
					Color3.fromRGB(214, 206, 190),
					Enum.Material.Marble,
					{ Shape = "Cylinder" }
				)
			end
			G.label(
				anchor,
				extra .. " KEY\nCollect for the cave altar",
				anchor.Position + Vector3.new(0, 3.2, 0),
				tint
			)
		elseif kind == "Seal" then
			anchor.Size, anchor.Material, anchor.Color = Vector3.new(6, 2, 4), Enum.Material.Slate, rock
			child(
				"AltarStep",
				Vector3.new(8, 0.8, 6),
				base * CFrame.new(0, -1.3, 0),
				rock:Lerp(Color3.new(0, 0, 0), 0.15),
				Enum.Material.Slate
			)
			child(
				"AltarTop",
				Vector3.new(6.4, 0.4, 4.4),
				base * CFrame.new(0, 1.15, 0),
				Color3.fromRGB(196, 186, 168),
				Enum.Material.Marble
			)
			for i, glyph in Seal.Order do
				local socket = child(
					"SealSocket",
					Vector3.new(0.3, 1.1, 1.1),
					base * CFrame.new((i - 2) * 1.9, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2),
					G.color(Seal.Keys[glyph].Color):Lerp(Color3.new(0, 0, 0), 0.6),
					Enum.Material.Slate,
					{ Shape = "Cylinder" }
				)
				socket:SetAttribute("SocketIndex", i)
			end
			G.label(
				anchor,
				"SEAL ALTAR\nUse keys: Sun > Leaf > Moon",
				anchor.Position + Vector3.new(0, 4, 0),
				gold
			)
		elseif kind == "Crystal" then
			anchor.Material, anchor.Color = Enum.Material.Glass, Color3.fromRGB(139, 210, 255)
			anchor.Size, anchor.Transparency = Vector3.new(1.3, 2.6, 1.3), 0.1
			anchor.CFrame = CFrame.new(at(x, S:height(x, z) + 1.55, z))
				* CFrame.Angles(rng:range(-0.2, 0.2), rng:range(0, 6.3), rng:range(-0.2, 0.2))
				* CFrame.Angles(0, math.pi / 4, 0)
			base = anchor.CFrame
			for side = -1, 1, 2 do
				child(
					"CrystalFacet",
					Vector3.new(1.3, 0.9, 0.65),
					base
						* CFrame.new(0, 1.75, 0)
						* CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
						* CFrame.new(0, 0, -0.325),
					anchor.Color,
					Enum.Material.Glass,
					{ Class = "WedgePart" }
				)
			end
			child(
				"CrystalCore",
				Vector3.new(0.5, 2.2, 0.5),
				base,
				Color3.fromRGB(190, 240, 255),
				Enum.Material.Neon,
				{ Transparency = 0.15 }
			)
			for k = 1, 2 do
				local offset = CFrame.new(if k == 1 then 1.1 else -0.9, -0.5, if k == 1 then 0.4 else -0.6)
					* CFrame.Angles(if k == 1 then 0.45 else -0.4, 0, if k == 1 then -0.35 else 0.4)
				child(
					"CrystalShard",
					Vector3.new(0.7, 1.6, 0.7),
					base * offset,
					Color3.fromRGB(160, 200, 255),
					Enum.Material.Glass,
					{ Transparency = 0.1 }
				)
			end
			child(
				"CrystalBase",
				Vector3.new(2.6, 0.7, 2.2),
				CFrame.new(at(x, S:height(x, z) + 0.3, z)) * CFrame.Angles(0, rng:range(0, 3), 0),
				rock,
				Enum.Material.Slate
			)
		elseif kind == "Herb" then
			anchor.Color, anchor.Material = Color3.fromRGB(96, 150, 72), Enum.Material.Grass
			anchor.Size, anchor.Shape = Vector3.new(1.6, 0.25, 0.25), Enum.PartType.Cylinder
			anchor.CFrame = CFrame.new(at(x, S:height(x, z) + 0.9, z)) * CFrame.Angles(0, 0, math.pi / 2)
			local root = CFrame.new(at(x, S:height(x, z) + 0.15, z))
			child(
				"HerbSoil",
				Vector3.new(2.2, 0.4, 2.2),
				root,
				Color3.fromRGB(86, 66, 46),
				Enum.Material.Ground,
				{ Mesh = "Sphere" }
			)
			for k = 1, 7 do
				local a = k / 7 * math.pi * 2
				local lift = if k % 2 == 0 then 0.55 else 0.3
				child(
					"HerbLeaf",
					Vector3.new(0.75, 0.12, 1.7),
					root
						* CFrame.Angles(0, a, 0)
						* CFrame.new(0, 0.35 + lift, -0.8)
						* CFrame.Angles(lift * 0.9, 0, 0),
					Color3.fromRGB(88, 170, 82):Lerp(Color3.fromRGB(150, 210, 110), (k % 3) / 3),
					Enum.Material.Grass,
					{ Mesh = "Sphere" }
				)
			end
			for k = 1, 3 do
				child(
					"HerbBloom",
					Vector3.new(0.35, 0.35, 0.35),
					root * CFrame.Angles(0, k * 2.1, 0) * CFrame.new(0, 1.7, -0.25),
					Color3.fromRGB(236, 236, 255):Lerp(Color3.fromRGB(190, 150, 255), k / 3),
					Enum.Material.SmoothPlastic,
					{ Shape = "Ball" }
				)
			end
		elseif kind == "Timber" then
			local yaw = rng:range(0, 6.3)
			anchor.Size, anchor.Shape, anchor.Material, anchor.Color =
				Vector3.new(3.6, 1.2, 1.2), Enum.PartType.Cylinder, Enum.Material.Wood, timber
			anchor.CFrame = CFrame.new(at(x, S:height(x, z) + 0.65, z))
				* CFrame.Angles(0, yaw, 0)
				* CFrame.new(0, 0, -0.6)
			base = anchor.CFrame
			child(
				"TimberLog",
				Vector3.new(3.4, 1.1, 1.1),
				base * CFrame.new(0.1, 0, 1.2),
				timber:Lerp(Color3.new(0, 0, 0), 0.1),
				Enum.Material.Wood,
				{ Shape = "Cylinder" }
			)
			child(
				"TimberLog",
				Vector3.new(3.2, 1.05, 1.05),
				base * CFrame.new(0, 0.95, 0.6),
				timber:Lerp(Color3.fromRGB(150, 110, 70), 0.3),
				Enum.Material.Wood,
				{ Shape = "Cylinder" }
			)
			for _, offset in { CFrame.new(1.82, 0, 0), CFrame.new(1.72, 0, 1.2), CFrame.new(1.62, 0.95, 0.6) } do
				child(
					"TimberRings",
					Vector3.new(0.08, 0.95, 0.95),
					base * offset,
					Color3.fromRGB(214, 176, 124),
					Enum.Material.Wood,
					{ Shape = "Cylinder" }
				)
			end
			for _, bx in { -0.9, 0.9 } do
				child(
					"TimberRope",
					Vector3.new(0.2, 2.2, 2.6),
					base * CFrame.new(bx, 0.45, 0.6),
					Color3.fromRGB(176, 150, 100),
					Enum.Material.Fabric,
					{ Transparency = 0.0, Mesh = "Sphere" }
				)
			end
		elseif kind == "Portal" then
			for _, xoff in { -5, 5 } do
				fixture(
					"GatePillar",
					Vector3.new(2, 12, 2),
					anchor.Position + Vector3.new(xoff, 4, 0),
					rock,
					Enum.Material.Slate
				)
				fixture(
					"GateStone",
					Vector3.new(2.8, 1.2, 2.8),
					anchor.Position + Vector3.new(xoff, -1.4, 0),
					rock:Lerp(Color3.new(0, 0, 0), 0.2),
					Enum.Material.Slate
				)
			end
			fixture(
				"GateLintel",
				Vector3.new(12, 2, 2),
				anchor.Position + Vector3.new(0, 10, 0),
				rock,
				Enum.Material.Slate
			)
			fixture(
				"GateLintel",
				Vector3.new(2, 2.4, 2.4),
				anchor.Position + Vector3.new(0, 10.4, 0),
				gold,
				Enum.Material.Marble
			)
			local veil = fixture(
				"PortalVeil",
				Vector3.new(8, 9.5, 0.3),
				anchor.Position + Vector3.new(0, 4.3, 0),
				Color3.fromRGB(178, 132, 255),
				Enum.Material.Neon,
				false
			)
			veil.Transparency, veil.CastShadow = 0.82, false
			local swirl = Instance.new("ParticleEmitter")
			swirl.Name, swirl.Texture = "PortalSwirl", "rbxasset://textures/particles/sparkles_main.dds"
			swirl.Color, swirl.LightEmission = ColorSequence.new(Color3.fromRGB(200, 160, 255)), 0.8
			swirl.Rate, swirl.Lifetime, swirl.Speed = 2, NumberRange.new(1, 2), NumberRange.new(1, 3)
			swirl.Size = NumberSequence.new(0.3)
			swirl.Parent = veil
			G.glow(model, anchor.Position + Vector3.new(0, 3, 0), Color3.fromRGB(178, 132, 255), 1)
		elseif kind == "Lift" then
			anchor.Transparency = 1
			for _, sx in { -5, 5 } do
				for _, sz in { -5, 5 } do
					fixture(
						"LiftPost",
						Vector3.new(0.8, 14, 0.8),
						anchor.Position + Vector3.new(sx, 5, sz),
						timber,
						Enum.Material.Wood,
						false
					)
				end
			end
			fixture(
				"LiftBeam",
				Vector3.new(11, 0.8, 0.8),
				anchor.Position + Vector3.new(0, 12, -5),
				timber,
				Enum.Material.Wood,
				false
			)
			fixture(
				"LiftBeam",
				Vector3.new(11, 0.8, 0.8),
				anchor.Position + Vector3.new(0, 12, 5),
				timber,
				Enum.Material.Wood,
				false
			)
			local rope = fixture(
				"LiftRope",
				Vector3.new(0.25, 60, 0.25),
				anchor.Position + Vector3.new(0, 42, 0),
				Color3.fromRGB(176, 150, 100),
				Enum.Material.Fabric,
				false
			)
			rope.CastShadow = false
			local wheel = fixture(
				"LiftWheel",
				Vector3.new(0.8, 4, 4),
				anchor.Position + Vector3.new(0, 12.6, 0),
				Color3.fromRGB(150, 120, 70),
				Enum.Material.Metal,
				false
			)
			wheel.Shape = Enum.PartType.Cylinder
			wheel:SetAttribute("Spin", 0.6)
			G.label(
				anchor,
				"SKY ELEVATOR\nRide to the next realm",
				anchor.Position + Vector3.new(0, 6, 0),
				gold
			)
		elseif kind == "Heal" then
			anchor.Size, anchor.Material, anchor.Color = Vector3.new(3.4, 1.2, 3.4), Enum.Material.Slate, rock
			anchor.Shape = Enum.PartType.Cylinder
			anchor.CFrame = CFrame.new(at(x, S:height(x, z) + 0.9, z)) * CFrame.Angles(0, 0, math.pi / 2)
			child(
				"SpringWater",
				Vector3.new(0.2, 2.8, 2.8),
				CFrame.new(at(x, S:height(x, z) + 1.55, z)) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(120, 230, 170),
				Enum.Material.Neon,
				{ Shape = "Cylinder", Transparency = 0.35 }
			)
		elseif kind == "Discover" then
			anchor.Size, anchor.Material, anchor.Color =
				Vector3.new(2.6, 3, 2.6), Enum.Material.Marble, Color3.fromRGB(214, 206, 190)
			child(
				"ShrineOrb",
				Vector3.new(1.4, 1.4, 1.4),
				base * CFrame.new(0, 2.4, 0),
				gold,
				Enum.Material.Neon,
				{ Shape = "Ball", Transparency = 0.1 }
			)
		elseif kind == "Repair" then
			for k = 1, 4 do
				child(
					"RepairPlank",
					Vector3.new(4, 0.3, 0.9),
					base * CFrame.new(0, -0.6 + k * 0.32, (k - 2.5) * 0.4) * CFrame.Angles(0, k * 0.3, 0),
					timber,
					Enum.Material.WoodPlanks
				)
			end
			anchor.Transparency = 1
			G.label(
				anchor,
				"BROKEN SHORTCUT\nContribute 2 timber",
				anchor.Position + Vector3.new(0, 4, 0),
				gold
			)
		end
		table.insert(
			r.Interactions,
			{ Kind = kind, Part = anchor, Prompt = p, Extra = extra, Extras = extras }
		)
		return anchor
	end
	r.Prompt = prompt
	-- Realm-styled shelters (shell footprint unchanged so shelter detection is preserved).
	local style = styleFor[biome.Id] or "Cottage"
	for _, h in { { -60, -16 }, { 0, -60 }, { 60, -16 } } do
		local x, z = h[1], h[2]
		local floor = cell("VillageFloor", Vector3.new(26, 1, 22), at(x, 0.25, z), 0.3, true)
		B.Ground = floor
		local breaches = Architecture.house(
			B,
			at(x, 0, z),
			style,
			function(name, size, position, color, material)
				local p = part(name, size, position, color, Enum.Material[material])
				table.insert(r.Structures, { Part = p, Ground = floor })
				return p
			end,
			gold
		)
		table.insert(
			r.Shelters,
			{ Anchor = floor, Half = Vector3.new(12, 16, 10), Breaches = breaches, Name = "House" }
		)
	end
	local caveFloor = cell("CaveFloor", Vector3.new(44, 2, 44), at(-120, 0.3, -48), 0.55, true)
	for _, box in { { -22, 9, 0, 3, 18, 44 }, { 0, 9, -22, 44, 18, 3 }, { 0, 19, 0, 48, 3, 48 } } do
		local p = part(
			"CaveRock",
			Vector3.new(box[4], box[5], box[6]),
			at(-120 + box[1], box[2], -48 + box[3]),
			rock,
			Enum.Material.Slate
		)
		table.insert(r.Structures, { Part = p, Ground = caveFloor })
	end
	-- Cave mound, stalactites and glow: reads as a rock outcrop instead of a box.
	B.Ground = caveFloor
	for k = 1, 7 do
		local a = k / 7 * math.pi
		B.blob(
			"CaveDetail",
			Vector3.new(rng:range(16, 24), rng:range(10, 16), rng:range(16, 24)),
			CFrame.new(at(-120 - math.cos(a) * 18, 18 + rng:range(-1, 3), -48 - math.sin(a) * 18))
				* CFrame.Angles(0, rng:range(0, 6), 0),
			rock:Lerp(grass, if k % 3 == 0 then 0.25 else 0),
			Enum.Material.Rock,
			{ Shadow = true }
		)
	end
	for k = 1, 9 do
		local px, pz =
			-138 + (k % 3) * 14 + rng:range(-3, 3), -64 + math.floor((k - 1) / 3) * 14 + rng:range(-3, 3)
		B.part(
			"CaveDetail",
			Vector3.new(1.4, rng:range(3, 6), 1.4),
			CFrame.new(at(px, 16.5, pz)) * CFrame.Angles(math.pi, rng:range(0, 6), 0),
			rock,
			Enum.Material.Slate,
			{ Class = "WedgePart" }
		)
	end
	for k = 1, 4 do
		local mush = B.blob(
			"CaveDetail",
			Vector3.new(1.2, 0.5, 1.2),
			CFrame.new(at(-139, 1.6 + k * 2.2, -66 + k * 7)),
			gold,
			Enum.Material.Neon
		)
		if k == 2 then
			B.light(mush, gold, 18, 0.6)
		end
	end
	table.insert(
		r.Shelters,
		{ Anchor = caveFloor, Half = Vector3.new(21, 21, 21), Breaches = {}, Name = "Cave" }
	)
	G.label(model, "ANCIENT SEAL\nSun → Leaf → Moon", at(-120, 12, -66), gold)
	for i, glyph in Seal.Order do
		prompt("Glyph", -138 + i * 9, -60, "Collect " .. glyph .. " key", glyph)
	end
	prompt("Seal", -132, -45, "Place next seal key")
	prompt("Portal", -120, -38, "Escape through seal")
	prompt("Repair", -92, -48, "Contribute 2 timber")
	prompt("Lift", -36, 18, "Ride sky elevator")
	prompt("Heal", 0, -58, "Use healing herb")
	prompt("Discover", 132, 24, "Search forgotten shrine")
	B.Ground = r.Landing
	for _, offset in { { -12, -12 }, { 12, -12 }, { -12, 12 }, { 12, 12 } } do
		local pillar = part(
			"ShrinePillar",
			Vector3.new(3, 12, 3),
			at(132 + offset[1], 6, 24 + offset[2]),
			rock,
			Enum.Material.Slate
		)
		table.insert(r.Structures, { Part = pillar, Ground = r.Landing })
		B.part(
			"ShrineDetail",
			Vector3.new(4, 1, 4),
			CFrame.new(at(132 + offset[1], 12.5, 24 + offset[2])),
			rock:Lerp(Color3.new(1, 1, 1), 0.2),
			Enum.Material.Marble
		)
		B.part(
			"ShrineDetail",
			Vector3.new(4, 1, 4),
			CFrame.new(at(132 + offset[1], 0.5, 24 + offset[2])),
			rock:Lerp(Color3.new(0, 0, 0), 0.2),
			Enum.Material.Slate
		)
	end
	local lookout = cell("LookoutDeck", Vector3.new(16, 2, 16), at(132, 24, 30), 0.8)
	local ladder = Instance.new("TrussPart")
	ladder.Name, ladder.Size, ladder.CFrame =
		"LookoutClimb", Vector3.new(2, 24, 2), CFrame.new(at(132, 12, 36))
	ladder.Anchored, ladder.Material, ladder.Color = true, Enum.Material.Wood, timber
	ladder:SetAttribute("Region", index)
	ladder.Parent = model
	table.insert(r.Structures, { Part = ladder, Ground = lookout })
	G.label(model, "GROVE LOOKOUT\nClimb for a view of the escape routes", at(132, 29, 30), gold)
	-- Supplies: timber in the woodland, herbs among grove flora, crystals around the cave walls.
	for _, spot in
		{
			{ -137, -66 },
			{ -128, -67 },
			{ -104, -66 },
			{ -100, -58 },
			{ -138, -54 },
			{ -138, -32 },
			{ -125, -29 },
			{ -109, -29 },
			{ -100, -40 },
			{ -112, -50 },
		}
	do
		prompt("Crystal", spot[1], spot[2], "Gather crystal")
	end
	local herbSpots = {}
	for k, angle in { 22.5, 67.5, 112.5, 247.5, 292.5, 337.5, 0, 315 } do
		local radius = if k > 6 then 30 else 18
		local a = math.rad(angle)
		local hx, hz = 132 + math.cos(a) * radius, 24 + math.sin(a) * radius
		prompt("Herb", hx, hz, "Gather herb")
		table.insert(herbSpots, { X = hx, Z = hz })
	end
	r.HerbSpots = herbSpots
	for _, spec in r.Interactions do
		local o = spec.Part.Position - center
		S:reserve(o.X, o.Z, 2.5)
	end
	for _, x in { -84, 84 } do
		local water = part(
			"Waterfall",
			Vector3.new(10, 65, 1.5),
			at(x, -32, 65),
			Color3.fromRGB(143, 211, 232),
			Enum.Material.Glass,
			false
		)
		water.Transparency = 0.45
		water.CastShadow = false
		local mist = Instance.new("ParticleEmitter")
		mist.Name, mist.Texture = "WaterfallMist", "rbxasset://textures/particles/smoke_main.dds"
		mist.Rate, mist.Lifetime, mist.Speed = 3, NumberRange.new(2, 3), NumberRange.new(2, 4)
		mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
		mist.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		mist.EmissionDirection = Enum.NormalId.Bottom
		mist.Parent = water
	end
	G.label(
		model,
		string.upper(model:GetAttribute("RegionName"))
			.. "\n"
			.. string.upper(biome.Name)
			.. " • Explore • Find a way upward",
		at(0, 10, 12),
		gold
	)
	G.label(model, "SKY CAUSEWAY\nWalk upward · Lift west · Gate in cave", at(-12, 7, 0), gold)
	-- Rescue beacon: signal fire where escorted survivors reach safety.
	B.Ground = r.Landing
	local beaconBase = r.Beacon
	B.part(
		"RescueBeacon",
		Vector3.new(3, 4, 3),
		CFrame.new(beaconBase + Vector3.new(0, 2, 0)),
		rock,
		Enum.Material.Slate
	)
	Props.campfire(B, beaconBase + Vector3.new(0, 4, 0))
	G.label(model, "RESCUE BEACON\nLead survivors here", beaconBase + Vector3.new(0, 9, 0), gold)
	local Scenery = require(Services.RealmAssets)
	Scenery.prepare(r, biome, seed)
	-- Realm activities claim their sites before scenery fills the remaining land.
	require(script.Parent.Activities.Builder).build(r)
	-- Timber caches scatter through the remaining woodland once activities have claimed space.
	local timberSpots = {}
	for i = 1, 18 do
		local site = S:find(rng, 3.2, Sites.Land, 60, function(px, pz)
			return -math.abs(pz - 40) - math.abs(px + 10) * 0.25 + rng:range(0, 30)
		end)
		local px, pz =
			if site then site.X else -54 + (i % 6) * 18,
			if site then site.Z else 28 + math.floor((i - 1) / 6) * 12
		prompt("Timber", px, pz, "Scavenge timber")
		table.insert(timberSpots, { X = px, Z = pz })
	end
	-- Each satellite sub-area holds extra supplies that reward the detour.
	local extraSupplies = {
		Wildwood = { "Timber", "Timber", "Herb" },
		Highlands = { "Crystal", "Crystal" },
		Ruins = { "Crystal", "Timber" },
		Cliffside = { "Herb", "Herb", "Timber" },
	}
	local verbs = { Timber = "Scavenge timber", Crystal = "Gather crystal", Herb = "Gather herb" }
	for _, sat in r.Satellites do
		for _, kind in extraSupplies[sat.Kind] or {} do
			local site = S:find(rng, 3, { [sat.Kind] = true }, 30)
			if site then
				prompt(kind, site.X, site.Z, verbs[kind])
				if kind == "Timber" then
					table.insert(timberSpots, { X = site.X, Z = site.Z })
				end
			end
		end
	end
	r.TimberSpots = timberSpots
	-- Every interaction, its child visuals and fixtures collapse with the nearest supporting ground.
	for _, spec in r.Interactions do
		if not spec.Ground then
			local ground, distance = r.Landing, math.huge
			for _, c in r.Cells do
				local d = (c.Part.Position - spec.Part.Position).Magnitude
				if d < distance then
					ground, distance = c.Part, d
				end
			end
			spec.Ground = ground
			table.insert(r.Structures, { Part = spec.Part, Ground = ground })
			for _, child in spec.Part:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(r.Structures, { Part = child, Ground = ground })
				end
			end
			for _, extra in spec.Extras or {} do
				table.insert(r.Structures, { Part = extra, Ground = ground })
			end
		end
	end
	Scenery.build(r, biome, seed)
	r.Parts = model:GetDescendants()
	return r
end
return Generator
