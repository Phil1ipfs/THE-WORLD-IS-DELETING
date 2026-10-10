--!nonstrict
-- Procedural wooden suspension bridge between two deck endpoints (any elevation difference).
-- Curve: quadratic Bezier whose midpoint sags gently below the chord, so the deck hangs
-- naturally without a roller-coaster dip. Visual planks have gaps and jitter; thin invisible
-- collision segments follow the curve and are the gameplay (deletion) cells. Visual parts carry
-- a "Sway" attribute (0..1 along the span) that clients use for visual-only swaying.
local Bridge = {}
local C = Color3.fromRGB
Bridge.Pitch = 2.2 -- plank depth + gap
Bridge.PlankDepth = 1.72
local function point(a, c, b, t)
	local u = 1 - t
	return a * (u * u) + c * (2 * u * t) + b * (t * t)
end
function Bridge.sag(a, b)
	local span = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	return math.clamp(span * 0.025, 1.5, 8)
end
-- Arc-length samples of the deck curve.
function Bridge.curve(a, b, sag)
	local control = (a + b) / 2 - Vector3.new(0, 2 * sag, 0)
	local samples, length = { { T = 0, S = 0, P = a } }, 0
	local steps = math.max(24, math.ceil((b - a).Magnitude / 1.5))
	for i = 1, steps do
		local t = i / steps
		local p = point(a, control, b, t)
		length += (p - samples[#samples].P).Magnitude
		table.insert(samples, { T = t, S = length, P = p })
	end
	return samples, length
end
local function at(samples, s)
	for i = 2, #samples do
		local q = samples[i]
		if q.S >= s then
			local p = samples[i - 1]
			local f = if q.S > p.S then (s - p.S) / (q.S - p.S) else 0
			return p.P:Lerp(q.P, f), (q.P - p.P).Unit, p.T + (q.T - p.T) * f
		end
	end
	local last, before = samples[#samples], samples[#samples - 1]
	return last.P, (last.P - before.P).Unit, 1
end
-- Explicit frame (LookVector = tangent, RightVector = lateral), built with fromMatrix so it is
-- identical in Roblox and in the offline fixture.
local function frame(position, tangent)
	local look = tangent.Unit
	if math.abs(look.Y) > 0.98 then
		look = (look + Vector3.new(0.05, 0, 0)).Unit
	end
	local right = look:Cross(Vector3.new(0, 1, 0)).Unit
	local up = right:Cross(look).Unit
	return CFrame.fromMatrix(position, right, up, -look)
end
-- opts: Parent, A, B, Width, Name, Region, Rng, Sag?, Ground(collider)->(), Attach(part, collider)
function Bridge.build(opts)
	local a, b, width, rng = opts.A, opts.B, opts.Width or 9, opts.Rng
	local sag = opts.Sag or Bridge.sag(a, b)
	local samples, length = Bridge.curve(a, b, sag)
	local result = { Colliders = {}, Parts = {}, Length = length, Sag = sag }
	local function part(name, size, cf, color, material, collide, class)
		local p = Instance.new(class or "Part")
		p.Name, p.Anchored, p.Size, p.CFrame, p.Color = name, true, size, cf, color
		p.Material = Enum.Material[material]
		p.CanCollide, p.CanQuery, p.CanTouch = collide == true, collide == true, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CastShadow = collide == true or size.Magnitude > 4
		if opts.Region then
			p:SetAttribute("Region", opts.Region)
		end
		p.Parent = opts.Parent
		table.insert(result.Parts, p)
		return p
	end
	local function rope(name, p0, p1, diameter, collide)
		local mid, len = (p0 + p1) / 2, (p1 - p0).Magnitude
		local cf = frame(mid, (p1 - p0).Unit) * CFrame.Angles(0, math.pi / 2, 0)
		local r =
			part(name, Vector3.new(len + 0.1, diameter, diameter), cf, C(176, 146, 98), "Fabric", collide)
		r.Shape = Enum.PartType.Cylinder
		return r
	end
	-- Collision: invisible segments (≈10 studs) whose top surface follows the deck curve.
	local segments = math.max(2, math.ceil(length / 10))
	for i = 1, segments do
		local p0 = at(samples, length * (i - 1) / segments)
		local p1 = at(samples, length * i / segments)
		local cf = frame((p0 + p1) / 2, (p1 - p0).Unit)
		local collider = part(
			opts.Name,
			Vector3.new(width, 1, (p1 - p0).Magnitude + 0.35),
			cf * CFrame.new(0, -0.5, 0),
			C(120, 88, 58),
			"WoodPlanks",
			true
		)
		collider.Transparency = 1
		collider:SetAttribute("Invisible", true)
		collider:SetAttribute("Ground", true)
		collider:SetAttribute("Phase", "Stable")
		if opts.Ground then
			opts.Ground(collider)
		end
		result.Colliders[i] = collider
	end
	local function owner(s)
		return result.Colliders[math.clamp(math.floor(s / length * segments) + 1, 1, segments)]
	end
	local function visual(p, s, sway)
		if opts.Attach then
			opts.Attach(p, owner(s))
		end
		if sway then
			local _, tangent, t = at(samples, s)
			p:SetAttribute("Sway", t)
			p:SetAttribute("SwayDir", frame(Vector3.zero, tangent).RightVector)
		end
		return p
	end
	-- Planks: separate boards with small gaps, irregular size, rotation and tone.
	local count = math.floor(length / Bridge.Pitch)
	local offset = (length - count * Bridge.Pitch) / 2 + Bridge.Pitch / 2
	for k = 0, count - 1 do
		local s = offset + k * Bridge.Pitch
		local p, tangent = at(samples, s)
		local depth = Bridge.PlankDepth * rng:range(0.92, 1.06)
		local cf = frame(p, tangent)
			* CFrame.new(rng:range(-0.12, 0.12), -0.19, 0)
			* CFrame.Angles(rng:range(-0.02, 0.02), rng:range(-0.035, 0.035), rng:range(-0.025, 0.025))
		local tone =
			C(132, 96, 62):Lerp(if k % 3 == 0 then C(96, 68, 46) else C(160, 122, 82), rng:range(0, 0.6))
		visual(
			part(
				"BridgePlank",
				Vector3.new(width * rng:range(0.94, 1.03), 0.36, depth),
				cf,
				tone,
				if k % 4 == 0 then "Wood" else "WoodPlanks",
				false
			),
			s,
			true
		)
	end
	-- Rope handrails, lower guide ropes and vertical hangers following the deck curve.
	local railStep = 7
	local railCount = math.max(2, math.ceil(length / railStep))
	for _, side in { -1, 1 } do
		local previousTop, previousLow
		for k = 0, railCount do
			local s = length * k / railCount
			local p, tangent = at(samples, s)
			local f = frame(p, tangent)
			local edge = (f * CFrame.new(side * (width / 2 + 0.25), 0, 0)).Position
			-- Handrails hang slightly between hangers like real rope.
			local top = edge + Vector3.new(0, 3.1 - math.sin(math.pi * s / length) * 0.5, 0)
			local low = edge + Vector3.new(0, 1.3, 0)
			if previousTop then
				visual(rope("BridgeRope", previousTop, top, 0.32, true), s, true)
				visual(rope("BridgeRope", previousLow, low, 0.2, false), s, true)
			end
			if k > 0 and k < railCount then
				visual(rope("BridgeHanger", top, edge - Vector3.new(0, 0.2, 0), 0.14, false), s, true)
			end
			previousTop, previousLow = top, low
		end
	end
	-- Wooden anchor posts with caps and rope collars at both ends, plus under-deck beams.
	for _, endpoint in { { a, 0 }, { b, length } } do
		local p, tangent = at(samples, endpoint[2])
		local f = frame(p, tangent)
		for _, side in { -1, 1 } do
			local base = (f * CFrame.new(side * (width / 2 + 0.55), 0, 0)).Position
			local post = part(
				"BridgePost",
				Vector3.new(5.6, 0.95, 0.95),
				CFrame.new(base + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				C(92, 66, 44),
				"Wood",
				true
			)
			post.Shape = Enum.PartType.Cylinder
			visual(post, endpoint[2], false)
			visual(
				part(
					"BridgePostCap",
					Vector3.new(1.3, 0.5, 1.3),
					CFrame.new(base + Vector3.new(0, 4.9, 0)),
					C(72, 52, 36),
					"Wood",
					false
				),
				endpoint[2],
				false
			)
			local collar = part(
				"BridgeRope",
				Vector3.new(0.5, 1.25, 1.25),
				CFrame.new(base + Vector3.new(0, 3.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				C(176, 146, 98),
				"Fabric",
				false
			)
			collar.Shape = Enum.PartType.Cylinder
			visual(collar, endpoint[2], false)
		end
		visual(
			part(
				"BridgeBeam",
				Vector3.new(width + 2.4, 0.7, 0.9),
				f * CFrame.new(0, -0.75, 0),
				C(84, 60, 40),
				"Wood",
				false
			),
			endpoint[2],
			false
		)
	end
	return result
end
return Bridge
