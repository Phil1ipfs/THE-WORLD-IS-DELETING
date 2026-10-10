--!nonstrict
-- Region-local placement: finds supported ground away from shelters, routes, prompts and props.
-- Coordinates are relative to the region center; terrain cells sit on a 12-stud lattice.
local Sites = {}
Sites.__index = Sites
local function key(x, z)
	return x .. ":" .. z
end
function Sites.new(region)
	local self = setmetatable({ Region = region, Map = {}, Circles = {}, Segments = {} }, Sites)
	for _, cell in region.Cells do
		local name = cell.Part.Name
		if name:sub(1, 6) == "Earth_" then
			local offset = cell.Part.Position - region.Center
			local x, z = math.floor(offset.X / 12 + 0.5) * 12, math.floor(offset.Z / 12 + 0.5) * 12
			local top = cell.Part.Position.Y + cell.Part.Size.Y / 2 - region.Center.Y
			self.Map[key(x, z)] =
				{ Cell = cell, Zone = name:sub(7), X = x, Z = z, Height = math.floor(top + 0.5) }
		end
	end
	return self
end
-- Terrain entry supporting a local point, or nil over the void.
function Sites:at(x, z)
	local bx, bz = math.floor(x / 12) * 12, math.floor(z / 12) * 12
	for _, cx in { bx, bx + 12, bx - 12 } do
		for _, cz in { bz, bz + 12, bz - 12 } do
			local entry = self.Map[key(cx, cz)]
			if entry and math.abs(x - cx) <= 12.05 and math.abs(z - cz) <= 12.05 then
				return entry
			end
		end
	end
	return nil
end
function Sites:reserve(x, z, r)
	table.insert(self.Circles, { X = x, Z = z, R = r })
end
function Sites:reserveSegment(ax, az, bx, bz, halfWidth)
	table.insert(self.Segments, { AX = ax, AZ = az, BX = bx, BZ = bz, W = halfWidth })
end
local function segmentDistance(x, z, s)
	local abx, abz = s.BX - s.AX, s.BZ - s.AZ
	local t = math.clamp(((x - s.AX) * abx + (z - s.AZ) * abz) / math.max(1e-6, abx * abx + abz * abz), 0, 1)
	return math.sqrt((x - s.AX - abx * t) ^ 2 + (z - s.AZ - abz * t) ^ 2)
end
function Sites:clear(x, z, r)
	for _, c in self.Circles do
		if (x - c.X) ^ 2 + (z - c.Z) ^ 2 < (r + c.R) ^ 2 then
			return false
		end
	end
	for _, s in self.Segments do
		if segmentDistance(x, z, s) < r + s.W then
			return false
		end
	end
	return true
end
-- Center and eight rim samples must be supported by allowed zones.
function Sites:supported(x, z, r, zones)
	for k = 0, 8 do
		local px, pz = x, z
		if k > 0 then
			local a = k / 8 * math.pi * 2
			px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		end
		local entry = self:at(px, pz)
		if not entry or (zones and not zones[entry.Zone]) or entry.Cell.Edge > (self.MaxEdge or 2) then
			return false
		end
	end
	return true
end
function Sites:fits(x, z, r, zones)
	return self:supported(x, z, r, zones) and self:clear(x, z, r)
end
-- Satellite sub-areas (RegionLayout.SatelliteKinds) count as open land for content placement.
Sites.Satellites = { Highlands = true, Wildwood = true, Ruins = true, Cliffside = true }
local all = { Mainland = true, Outskirts = true, Grove = true, Cave = true }
Sites.Land = { Mainland = true, Outskirts = true }
Sites.Core = { Mainland = true, Outskirts = true }
for zone in Sites.Satellites do
	all[zone], Sites.Land[zone] = true, true
end
-- Seeded search over terrain cells; optional score prefers e.g. outskirts or distance.
function Sites:find(rng, r, zones, tries, score)
	local entries = {}
	for _, entry in self.Map do
		if (zones or all)[entry.Zone] then
			table.insert(entries, entry)
		end
	end
	table.sort(entries, function(a, b)
		return if a.X == b.X then a.Z < b.Z else a.X < b.X
	end)
	if #entries == 0 then
		return nil
	end
	local best, bestScore
	for _ = 1, tries or 40 do
		local entry = entries[rng:integer(1, #entries)]
		local x, z = entry.X + rng:range(-8, 8), entry.Z + rng:range(-8, 8)
		if self:fits(x, z, r, zones) then
			local value = if score then score(x, z, entry) else 0
			if not best or value > bestScore then
				best, bestScore = { X = x, Z = z, Entry = self:at(x, z) }, value
			end
			if not score then
				break
			end
		end
	end
	if best then
		self:reserve(best.X, best.Z, r)
	end
	return best
end
-- Ground height (relative to the region center) under a local point; 0 over the void.
function Sites:height(x, z)
	local entry = self:at(x, z)
	return if entry then entry.Height else 0
end
-- World position on the terrain top surface.
function Sites:world(x, z, y)
	return self.Region.Center + Vector3.new(x, (y or 0) + self:height(x, z), z)
end
return Sites
