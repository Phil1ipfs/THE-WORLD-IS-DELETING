--!nonstrict
local G = require(script.Parent.Geometry)
local Fractures = {}
function Fractures.distance(part, positions)
	local distance = math.huge
	for _, position in positions do
		distance = math.min(distance, (part.Position - position).Magnitude)
	end
	return distance
end
-- Four crooked, noncolliding seams follow a real surface, rather than neon warning bars.
function Fractures.draw(parent, surface, focus, floor)
	local size = surface.Size
	local axis = if floor or size.Y <= math.min(size.X, size.Z)
		then "Y"
		elseif size.X < size.Z then "X"
		else "Z"
	local localFocus = surface.CFrame:PointToObjectSpace(focus)
	local sign = if floor or localFocus[axis] >= 0 then 1 else -1
	local points = {}
	for _, v in { { -0.43, -0.44 }, { -0.14, -0.12 }, { 0.08, -0.19 }, { 0.2, 0.22 }, { 0.43, 0.44 } } do
		local point = if axis == "Y"
			then Vector3.new(v[1] * size.X, sign * (size.Y / 2 + 0.055), v[2] * size.Z)
			elseif axis == "X" then Vector3.new(
				sign * (size.X / 2 + 0.055),
				v[2] * size.Y,
				v[1] * size.Z
			)
			else Vector3.new(v[1] * size.X, v[2] * size.Y, sign * (size.Z / 2 + 0.055))
		table.insert(points, point)
	end
	local cracks, offsets = {}, {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local offset = CFrame.lookAt((a + b) / 2, b)
		local crack = G.part(
			parent,
			"EarthquakeCrack",
			Vector3.new(0.22 + i * 0.035, 0.12, (b - a).Magnitude + 0.08),
			surface.CFrame * offset,
			if surface.Material == Enum.Material.Basalt
				then Color3.fromRGB(182, 148, 112)
				else Color3.fromRGB(51, 43, 38),
			Enum.Material.Slate,
			false
		)
		crack.CastShadow = false
		crack:SetAttribute("Hazard", "Earthquake")
		table.insert(cracks, crack)
		table.insert(offsets, offset)
	end
	return cracks, offsets
end
return Fractures
