--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Layout = require(Shared.RegionLayout)
local Generator = require(script.Parent.ExplorationGenerator)
local G = require(script.Parent.Parent.Services.Geometry)
local Fractures = require(script.Parent.Parent.Services.SeismicFractures)
local Quake = require(Shared.DisasterConfig).Earthquake
local World = {}
World.__index = World
function World.new(obstacles)
	local self = setmetatable(
		{ Origin = 0, NextIndex = 0, Islands = {}, Obstacles = obstacles, Seed = Config.Seed },
		World
	)
	self.Root = Instance.new("Model")
	self.Root.Name, self.Root.Parent = "FloatingRealms", workspace
	workspace:SetAttribute("WorldOrigin", 0)
	return self
end
function World:dispose(record)
	for _, connection in record.Connections do
		connection:Disconnect()
	end
	if self.OnRegionRemoved then
		self.OnRegionRemoved(record)
	end
	record.Model:Destroy()
	self.Islands[record.Index] = nil
end
function World:reset(seed)
	if self.Obstacles then
		self.Obstacles:clear()
	end
	for _, record in self.Islands do
		self:dispose(record)
	end
	self.Root:ClearAllChildren()
	self.Origin, self.NextIndex, self.Seed = 0, 0, seed
	workspace:SetAttribute("WorldOrigin", 0)
	self:generate(Config.StartY)
end
function World:generate(verifiedY)
	local target = math.floor(math.max(0, verifiedY - Config.StartY) / Config.RegionRise) + 2
	local active = 0
	for _ in self.Islands do
		active += 1
	end
	local budget = 3
	while self.NextIndex <= target and active < Config.MaxActiveRegions and budget > 0 do
		local record = Generator.build(self.Root, self.NextIndex, self.Origin, self.Seed)
		self.Islands[self.NextIndex] = record
		if self.OnRegionAdded then
			self.OnRegionAdded(record)
		end
		self.NextIndex += 1
		active += 1
		budget -= 1
	end
end
function World:point(index)
	local p = Layout.center(index, Config.RegionRadius, Config.RegionRise, Config.StartY)
	return Vector3.new(p.X, p.Y - self.Origin, p.Z)
end
function World:activate(index)
	local region = self.Islands[index]
	if region and not region.Activated then
		region.Activated = os.clock()
		region.Model:SetAttribute("Activated", region.Activated)
	end
end
function World:sheltered(position)
	for _, region in self.Islands do
		for _, zone in region.Shelters do
			if zone.Anchor.Parent and zone.Anchor.CanCollide then
				local d = position - zone.Anchor.Position
				if
					math.abs(d.X) < zone.Half.X
					and d.Y > 0
					and d.Y < zone.Half.Y
					and math.abs(d.Z) < zone.Half.Z
				then
					return true
				end
			end
		end
	end
	return false
end
function World:warnCell(region, cell, now, cause)
	if cell.State ~= "Stable" then
		return
	end
	cell.State, cell.BreakAt = "Cracking", math.max(now + Config.CorruptionWarning, cell.BracedUntil or 0)
	cell.Part:SetAttribute("Phase", "Cracking")
	cell.Part:SetAttribute("CrackCause", cause or "Corruption")
	if cause == "Earthquake" then
		cell.Cracks, cell.CrackOffsets = Fractures.draw(region.Model, cell.Part, cell.Part.Position, true)
		return
	end
	cell.Cracks = {}
	cell.CrackOffsets = {}
	for i = 1, 2 do
		local crack = G.part(
			region.Model,
			"CorruptionCrack",
			Vector3.new(0.25, 0.12, math.min(18, cell.Part.Size.Z)),
			cell.Part.CFrame
				* CFrame.new((i - 1.5) * 4, cell.Part.Size.Y / 2 + 0.12, 0)
				* CFrame.Angles(0, i * 0.8, 0),
			Color3.fromRGB(178, 67, 255),
			Enum.Material.Neon,
			false
		)
		table.insert(cell.Cracks, crack)
		table.insert(cell.CrackOffsets, cell.Part.CFrame:ToObjectSpace(crack.CFrame))
	end
end
function World:earthquake(index, positions, count, surfaceCount)
	local region = self.Islands[index]
	if not region then
		return 0, 0
	end
	positions = positions or { region.Center }
	local candidates = {}
	for _, cell in region.Cells do
		if not cell.Late and cell.State == "Stable" and cell.Part.Parent and cell.Part.CanCollide then
			local distance = Fractures.distance(cell.Part, positions)
			if distance < 130 then
				table.insert(candidates, { Cell = cell, Distance = distance })
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	local now, broken = os.clock(), 0
	for i = 1, math.min(count or Quake.CellsPerRegion, #candidates) do
		self:warnCell(region, candidates[i].Cell, now, "Earthquake")
		broken += 1
	end
	-- Refuge floors and walls show damage but remain usable until normal corruption reaches them.
	local surfaces = {}
	for _, cell in region.Cells do
		if cell.Late and (cell.Part.Name == "VillageFloor" or cell.Part.Name == "CaveFloor") then
			table.insert(surfaces, cell.Part)
		end
	end
	for _, structure in region.Structures do
		local part = structure.Part
		if part.Parent and (part.Name == "VillageWall" or part.Name == "CaveRock") then
			table.insert(surfaces, part)
		end
	end
	table.sort(surfaces, function(a, b)
		return Fractures.distance(a, positions) < Fractures.distance(b, positions)
	end)
	region.SeismicSurfaces = region.SeismicSurfaces or {}
	local marked = 0
	for _, surface in surfaces do
		if marked >= (surfaceCount or Quake.SurfaceCount) then
			break
		end
		if
			surface.Parent
			and surface.CanCollide
			and Fractures.distance(surface, positions) < 110
			and now >= (surface:GetAttribute("SeismicUntil") or 0)
		then
			local focus, distance = positions[1], math.huge
			for _, p in positions do
				local d = (surface.Position - p).Magnitude
				if d < distance then
					focus, distance = p, d
				end
			end
			local cracks, offsets = Fractures.draw(region.Model, surface, focus, false)
			for i, crack in cracks do
				table.insert(region.SeismicSurfaces, {
					Part = crack,
					Source = surface,
					Offset = offsets[i],
					Until = now + Quake.SurfaceLifetime,
				})
			end
			surface:SetAttribute("SeismicUntil", now + Quake.SurfaceLifetime)
			marked += 1
		end
	end
	return broken, marked
end
function World:destabilize(index, count, structures)
	local region = self.Islands[index]
	if not region then
		return
	end
	if not structures then
		for _, cell in region.Cells do
			if count > 0 and not cell.Late and cell.State == "Stable" then
				self:warnCell(region, cell, os.clock())
				count -= 1
			end
		end
		return
	end
	-- Structure collapse spreads round-robin across alternate bridges (never the causeway), so
	-- several crossings are damaged instead of one long bridge absorbing every crack.
	local groups, order = {}, {}
	for _, cell in region.Cells do
		local name = cell.Part.Name
		if
			not cell.Late
			and cell.State == "Stable"
			and (name == "ForestBridge" or name == "CaveBridge" or name == "SatelliteBridge")
		then
			local key = name .. (cell.Part:GetAttribute("BridgeKey") or "")
			if not groups[key] then
				groups[key] = {}
				table.insert(order, key)
			end
			table.insert(groups[key], cell)
		end
	end
	local round = 1
	while count > 0 do
		local any = false
		for _, key in order do
			local cell = groups[key][round]
			if cell and count > 0 then
				self:warnCell(region, cell, os.clock())
				count -= 1
				any = true
			end
		end
		if not any then
			break
		end
		round += 1
	end
end
function World:consume(waveY)
	local now = os.clock()
	for _, region in self.Islands do
		-- Index structures by supporting ground so collapse work scales with falling cells only.
		if region.IndexedCount ~= #region.Structures then
			region.IndexedCount, region.ByGround = #region.Structures, {}
			for _, s in region.Structures do
				local list = region.ByGround[s.Ground]
				if not list then
					list = {}
					region.ByGround[s.Ground] = list
				end
				table.insert(list, s)
			end
		end
		local age = if region.Activated then now - region.Activated else 0
		region.Model:SetAttribute("Stability", math.max(0, math.ceil(Config.RegionLifetime - age)))
		for _, cell in region.Cells do
			if cell.State == "Gone" then
				continue
			end
			local p = cell.Part
			local logicalY = p.Position.Y + p.Size.Y / 2 + self.Origin
			local deadline = Config.RegionLifetime - cell.Edge * 75 + (if cell.Late then 40 else 0)
			if
				cell.State == "Stable"
				and (
					(region.Activated and age >= deadline and now >= (cell.BracedUntil or 0))
					or waveY >= logicalY - 12
				)
			then
				self:warnCell(region, cell, now)
			end
			if cell.State == "Cracking" and now >= cell.BreakAt then
				if self.Effects and now > (region.LastCollapseSound or 0) + 2 then
					region.LastCollapseSound = now
					self.Effects:FireAllClients("Collapse", p.Position)
				end
				cell.State, cell.FallAt, cell.FallFrom = "Breaking", now, p.CFrame
				p:SetAttribute("Phase", "Breaking")
				p.CanCollide, p.CanQuery = false, false
			end
			if cell.State == "Breaking" then
				local alpha = math.clamp((now - cell.FallAt) / 3, 0, 1)
				p.CFrame = cell.FallFrom - Vector3.new(0, alpha * 28, 0)
				p.Transparency = if p:GetAttribute("Invisible") then 1 else alpha
				for _, s in region.ByGround[p] or {} do
					if s.Part.Parent then
						s.From = s.From or s.Part.CFrame
						s.Part.CFrame, s.Part.Transparency = s.From - Vector3.new(0, alpha * 28, 0), alpha
						s.Part.CanCollide, s.Part.CanQuery = false, false
					end
				end
				for i, crack in cell.Cracks or {} do
					crack.CFrame = p.CFrame * cell.CrackOffsets[i]
					crack.Transparency = alpha
				end
				if alpha >= 1 then
					cell.State = "Gone"
					for _, crack in cell.Cracks or {} do
						crack:Destroy()
					end
					for _, s in region.ByGround[p] or {} do
						if s.Part.Parent then
							s.Part:Destroy()
						end
					end
					p:Destroy()
				end
			end
		end
		for i = #(region.SeismicSurfaces or {}), 1, -1 do
			local seam = region.SeismicSurfaces[i]
			if not seam.Part.Parent or not seam.Source.Parent or now >= seam.Until then
				seam.Part:Destroy()
				table.remove(region.SeismicSurfaces, i)
			else
				seam.Part.CFrame = seam.Source.CFrame * seam.Offset
			end
		end
		if
			(region.Activated and age > Config.RegionLifetime + 80)
			or waveY > region.Y + Config.RegionRise + 30
		then
			self:dispose(region)
		end
	end
end
function World:brace(position, now)
	local count = 0
	for _, region in self.Islands do
		for _, cell in region.Cells do
			if
				count < 6
				and cell.State ~= "Gone"
				and cell.State ~= "Breaking"
				and cell.Part.CanCollide
				and (cell.Part.Position - position).Magnitude < 22
			then
				cell.BracedUntil = now + 18
				cell.Part:SetAttribute("BracedUntil", cell.BracedUntil)
				if cell.State == "Cracking" then
					cell.BreakAt = math.max(cell.BreakAt, now + 18)
				end
				-- Visible wooden reinforcement: crossed planks pinned by corner stakes, with a
				-- faint warm seam so braced ground reads clearly from a distance.
				local top = cell.Part.CFrame * CFrame.new(0, cell.Part.Size.Y / 2, 0)
				local span = math.min(18, cell.Part.Size.X * 0.8)
				local braces = {}
				for _, angle in { 0.785, -0.785 } do
					table.insert(
						braces,
						G.part(
							region.Model,
							"TimberBrace",
							Vector3.new(span, 0.35, 1.3),
							top * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, angle, 0),
							Color3.fromRGB(140, 100, 62),
							Enum.Material.WoodPlanks,
							false
						)
					)
				end
				for _, corner in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
					local offset = span * 0.35
					table.insert(
						braces,
						G.part(
							region.Model,
							"TimberBrace",
							Vector3.new(0.7, 2.2, 0.7),
							top
								* CFrame.new(corner[1] * offset, 0.6, corner[2] * offset)
								* CFrame.Angles(0.15 * corner[2], 0, -0.15 * corner[1]),
							Color3.fromRGB(110, 78, 50),
							Enum.Material.Wood,
							false
						)
					)
				end
				table.insert(
					braces,
					G.part(
						region.Model,
						"TimberBrace",
						Vector3.new(span * 0.5, 0.12, 0.3),
						top * CFrame.new(0, 0.42, 0),
						Color3.fromRGB(255, 204, 120),
						Enum.Material.Neon,
						false
					)
				)
				for _, brace in braces do
					brace.CastShadow = false
					table.insert(region.Structures, { Part = brace, Ground = cell.Part })
					game:GetService("Debris"):AddItem(brace, 18)
				end
				count += 1
			end
		end
	end
	return count > 0
end
function World:rebase(amount)
	local shift = Vector3.new(0, amount, 0)
	for _, record in self.Islands do
		record.Model:PivotTo(record.Model:GetPivot() - shift)
		record.Center -= shift
		record.Side -= shift
		for _, cell in record.Cells do
			if cell.FallFrom then
				cell.FallFrom -= shift
			end
		end
		for _, s in record.Structures do
			if s.From then
				s.From -= shift
			end
		end
	end
	self.Origin += amount
	workspace:SetAttribute("WorldOrigin", self.Origin)
end
return World
