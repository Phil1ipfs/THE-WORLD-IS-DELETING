--!strict
-- Pure layout contract for broad connected land and a walkable ascent.
local Layout = {}
type Point = { X: number, Z: number }
function Layout.center(index: number, radius: number, rise: number, startY: number)
	local a = index * math.pi / 2
	return { X = math.cos(a) * radius, Y = startY + index * rise, Z = math.sin(a) * radius }
end
function Layout.size(index: number, seed: number): (number, number, boolean)
	local massive = index > 0 and (index + seed) % 7 == 0
	return if massive then 144 else 108, if massive then 108 else 84, massive
end
local grove: Point, cave: Point = { X = 132, Z = 24 }, { X = -120, Z = -48 }
local function segmentDistance(p: Point, a: Point, b: Point): number
	local abx, abz = b.X - a.X, b.Z - a.Z
	local t =
		math.clamp(((p.X - a.X) * abx + (p.Z - a.Z) * abz) / math.max(1e-6, abx * abx + abz * abz), 0, 1)
	return math.sqrt((p.X - a.X - abx * t) ^ 2 + (p.Z - a.Z - abz * t) ^ 2)
end
local function direction(from: number, to: number): Point
	local a, b = Layout.center(from, 450, 0, 0), Layout.center(to, 450, 0, 0)
	local dx, dz = b.X - a.X, b.Z - a.Z
	local m = math.sqrt(dx * dx + dz * dz)
	return { X = dx / m, Z = dz / m }
end
-- Each realm extends into a broad outskirts lobe chosen away from causeways, grove and cave.
function Layout.outskirts(index: number, seed: number)
	local rx, rz = Layout.size(index, seed)
	local out, incoming = direction(index, index + 1), direction(index - 1, index)
	local world = Layout.center(index, 450, 0, 0)
	local best, bestScore = nil :: any, -math.huge
	for step = 0, 15 do
		local angle = step * math.pi / 8 + ((index * 7 + seed) % 5) * 0.03
		local c, s = math.cos(angle), math.sin(angle)
		local edge = 1 / math.sqrt((c / rx) ^ 2 + (s / rz) ^ 2)
		local radius = 50
		local p = { X = c * (edge + 38), Z = s * (edge + 38) }
		local score = math.min(
			segmentDistance(p, { X = 0, Z = 0 }, { X = out.X * 300, Z = out.Z * 300 }) - radius - 14,
			segmentDistance(p, grove, { X = 66, Z = 24 }) - radius - 40,
			segmentDistance(p, cave, { X = -48, Z = -48 }) - radius - 40,
			segmentDistance(p, cave, grove) - radius - 10
		)
		if index > 0 then
			score = math.min(
				score,
				segmentDistance(p, { X = 0, Z = 0 }, { X = -incoming.X * 300, Z = -incoming.Z * 300 })
					- radius
					- 14
			)
		end
		local far = math.max(math.abs(world.X + p.X), math.abs(world.Z + p.Z)) + radius
		if far > 640 then
			score -= far - 640
		end
		if score > bestScore then
			best, bestScore = { X = p.X, Z = p.Z, Angle = angle, Radius = radius, Clearance = score }, score
		end
	end
	return best
end
-- Satellite landmasses: named sub-areas at different elevations, each reached by a suspension
-- bridge from the mainland. Placed greedily for the largest clearance from causeway corridors,
-- the grove, cave, outskirts, mainland and each other, inside world bounds.
-- Fixed village shelters, elevator and landing that bridges must never cross.
Layout.Obstacles = {
	{ X = -60, Z = -14, R = 17 },
	{ X = 0, Z = -58, R = 17 },
	{ X = 60, Z = -14, R = 17 },
	{ X = -36, Z = 18, R = 8 },
	{ X = 0, Z = 0, R = 18 },
}
Layout.SatelliteKinds = {
	{ Kind = "Highlands", Radius = 66, Height = 30 },
	{ Kind = "Wildwood", Radius = 64, Height = 8 },
	{ Kind = "Ruins", Radius = 54, Height = -8 },
	{ Kind = "Cliffside", Radius = 50, Height = 18 },
}
local function ellipseEdge(angle: number, rx: number, rz: number): number
	local c, s = math.cos(angle), math.sin(angle)
	return 1 / math.sqrt((c / rx) ^ 2 + (s / rz) ^ 2)
end
function Layout.satellites(index: number, seed: number): { any }
	local rx, rz = Layout.size(index, seed)
	local out, incoming = direction(index, index + 1), direction(index - 1, index)
	local world = Layout.center(index, 450, 0, 0)
	local lobe = Layout.outskirts(index, seed)
	local placed: { any } = {}
	local order: { any } = table.clone(Layout.SatelliteKinds)
	local shift = (index + seed) % #order
	for _ = 1, shift do
		table.insert(order, table.remove(order, 1))
	end
	for _, spec in order do
		local best, bestScore = nil :: any, 0
		for step = 0, 31 do
			local angle = step * math.pi / 16 + ((seed + index * 3) % 7) * 0.02
			for _, extra in { 34, 58, 82 } do
				local edge = ellipseEdge(angle, rx, rz)
				local d = edge + spec.Radius + extra
				local p = { X = math.cos(angle) * d, Z = math.sin(angle) * d }
				local r = spec.Radius
				local startPoint = { X = math.cos(angle) * edge * 0.8, Z = math.sin(angle) * edge * 0.8 }
				local endPoint = { X = p.X - math.cos(angle) * r * 0.5, Z = p.Z - math.sin(angle) * r * 0.5 }
				local path = math.huge
				for _, o in Layout.Obstacles do
					path = math.min(path, segmentDistance(o, startPoint, endPoint) - o.R - 5)
				end
				local score = math.min(
					segmentDistance(p, { X = 0, Z = 0 }, { X = out.X * 420, Z = out.Z * 420 }) - r - 20,
					math.sqrt((p.X - grove.X) ^ 2 + (p.Z - grove.Z) ^ 2) - r - 64,
					math.sqrt((p.X - cave.X) ^ 2 + (p.Z - cave.Z) ^ 2) - r - 64,
					math.sqrt((p.X - lobe.X) ^ 2 + (p.Z - lobe.Z) ^ 2) - r - lobe.Radius - 30,
					path,
					1300 - (math.max(math.abs(world.X + p.X), math.abs(world.Z + p.Z)) + r)
				)
				if index > 0 then
					score = math.min(
						score,
						segmentDistance(p, { X = 0, Z = 0 }, { X = -incoming.X * 420, Z = -incoming.Z * 420 })
							- r
							- 20
					)
				end
				for _, other in placed do
					score = math.min(
						score,
						math.sqrt((p.X - other.X) ^ 2 + (p.Z - other.Z) ^ 2) - r - other.Radius - 40
					)
				end
				if score > bestScore then
					best, bestScore =
						{
							Kind = spec.Kind,
							X = math.floor(p.X / 12 + 0.5) * 12,
							Z = math.floor(p.Z / 12 + 0.5) * 12,
							Radius = r,
							Height = spec.Height,
							Angle = angle,
							Clearance = score,
							-- Bridge from well inside the mainland edge to just inside the island rim.
							StartX = math.cos(angle) * edge * 0.8,
							StartZ = math.sin(angle) * edge * 0.8,
						}, score
				end
			end
		end
		if best then
			best.EndX = best.X - math.cos(best.Angle) * best.Radius * 0.5
			best.EndZ = best.Z - math.sin(best.Angle) * best.Radius * 0.5
			table.insert(placed, best)
		end
	end
	return placed
end
function Layout.cells(index: number, seed: number)
	local cells = {}
	local rx, rz = Layout.size(index, seed)
	local used: { [string]: boolean } = {}
	local function key(x: number, z: number): string
		return math.floor(x + 0.5) .. ":" .. math.floor(z + 0.5)
	end
	for x = -rx, rx, 24 do
		for z = -rz, rz, 24 do
			local d = (x / rx) ^ 2 + (z / rz) ^ 2
			local edge = 1 + math.sin(x * 0.07 + seed) * 0.07 + math.cos(z * 0.09) * 0.06
			if d <= edge then
				table.insert(
					cells,
					{ X = x, Z = z, Edge = math.clamp(math.sqrt(d), 0, 1), Zone = "Mainland" }
				)
				used[key(x, z)] = true
			end
		end
	end
	for _, node in { { X = 132, Z = 24, Zone = "Grove" }, { X = -120, Z = -48, Zone = "Cave" } } do
		for x = -24, 24, 24 do
			for z = -24, 24, 24 do
				table.insert(cells, { X = node.X + x, Z = node.Z + z, Edge = 0.8, Zone = node.Zone })
			end
		end
	end
	-- Outskirts share the mainland lattice; a four-connected neck guarantees walkable access.
	local lobe = Layout.outskirts(index, seed)
	local function snap(v: number, start: number): number
		return start + math.floor((v - start) / 24 + 0.5) * 24
	end
	local function add(x: number, z: number, edge: number)
		if used[key(x, z)] then
			return
		end
		for _, node in { grove, cave } do
			if math.abs(x - node.X) < 54 and math.abs(z - node.Z) < 54 then
				return
			end
		end
		used[key(x, z)] = true
		table.insert(cells, { X = x, Z = z, Edge = edge, Zone = "Outskirts" })
	end
	local cx, cz = snap(lobe.X, -rx), snap(lobe.Z, -rz)
	for x = cx - 48, cx + 48, 24 do
		for z = cz - 48, cz + 48, 24 do
			local d = math.sqrt((x - lobe.X) ^ 2 + (z - lobe.Z) ^ 2)
			if d <= lobe.Radius + math.sin(x * 0.11 + z * 0.05 + seed) * 8 then
				add(x, z, math.clamp(0.86 + d / 400, 0, 1))
			end
		end
	end
	local x, z = cx, cz
	local tx, tz = snap(0, -rx), snap(0, -rz)
	for _ = 1, 24 do
		if used[key(x, z)] and (x ~= cx or z ~= cz) and (x / rx) ^ 2 + (z / rz) ^ 2 <= 0.8 then
			break
		end
		add(x, z, 0.9)
		if x == tx and z == tz then
			break
		elseif math.abs(x - tx) >= math.abs(z - tz) then
			x += if tx > x then 24 else -24
		else
			z += if tz > z then 24 else -24
		end
	end
	for _, sat in Layout.satellites(index, seed) do
		for dx = -96, 96, 24 do
			for dz = -96, 96, 24 do
				local d = math.sqrt(dx * dx + dz * dz)
				if d <= sat.Radius - 4 + math.sin(dx * 0.13 + dz * 0.07 + seed) * 6 then
					table.insert(cells, {
						X = sat.X + dx,
						Z = sat.Z + dz,
						Y = sat.Height,
						Edge = math.clamp(0.92 + d / 900, 0, 1),
						Zone = sat.Kind,
					})
				end
			end
		end
	end
	return cells
end
function Layout.slope(a: { X: number, Y: number, Z: number }, b: { X: number, Y: number, Z: number }): number
	return math.deg(math.atan2(math.abs(b.Y - a.Y), math.sqrt((b.X - a.X) ^ 2 + (b.Z - a.Z) ^ 2)))
end
return table.freeze(Layout)
