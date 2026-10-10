--!nonstrict
-- Procedural prop library built from native parts. Every prop is anchored, attached to its
-- supporting ground for collapse, and (unless collidable) flagged Detail for client culling.
-- WedgePart geometry: vertical face at local +Z, slope descending toward local -Z.
local Props = {}
local function material(name)
	return if typeof(name) == "EnumItem" then name else Enum.Material[name or "SmoothPlastic"]
end
local function rgb(t)
	return if typeof(t) == "Color3" then t else Color3.fromRGB(t[1], t[2], t[3])
end
-- attach(part, ground) registers collapse ownership; ground is set per placement.
function Props.builder(model, attach, rng)
	local B = { Model = model, Ground = nil, Rng = rng, Count = 0, Lights = 0, LightBudget = 14 }
	function B.part(name, size, cf, color, mat, o)
		o = o or {}
		local p = Instance.new(o.Class or "Part")
		p.Name, p.Anchored, p.Size, p.CFrame = name, true, size, cf
		p.Color, p.Material = rgb(color), material(mat)
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if o.Shape then
			p.Shape = Enum.PartType[o.Shape]
		end
		local collide = o.Collide == true
		p.CanCollide, p.CanQuery, p.CanTouch = collide, collide, false
		p.CastShadow = o.Shadow ~= false and (collide or size.Magnitude > 6)
		p.Transparency = o.Transparency or 0
		if o.Mesh then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType[o.Mesh]
			mesh.Parent = p
		end
		p.Parent = o.Parent or B.Model
		B.Count += 1
		attach(p, B.Ground, not collide)
		return p
	end
	-- Ellipsoid via a sphere mesh: organic foliage without perfect balls.
	function B.blob(name, size, cf, color, mat, o)
		o = o or {}
		o.Mesh = "Sphere"
		return B.part(name, size, cf, color, mat or "Grass", o)
	end
	-- Cylinder spanning two points (Roblox cylinders run along local X).
	function B.limb(name, a, b, diameter, color, mat, o)
		local length = (b - a).Magnitude
		local direction = (b - a) / math.max(length, 1e-6)
		-- lookAt is degenerate for vertical spans; map the cylinder's X axis straight up instead.
		local cf = if math.abs(direction.Y) > 0.999
			then CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, math.pi / 2)
			else CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
		o = o or {}
		o.Shape = "Cylinder"
		return B.part(name, Vector3.new(length, diameter, diameter), cf, color, mat or "Wood", o)
	end
	-- Four wedges around an axis approximate a cone or pyramid tier.
	function B.cone(name, base, radius, height, color, mat, rotation, o)
		for k = 0, 3 do
			local cf = CFrame.new(base + Vector3.new(0, height / 2, 0))
				* CFrame.Angles(0, (rotation or 0) + k * math.pi / 2, 0)
				* CFrame.new(0, 0, -radius / 2)
			local opts = table.clone(o or {})
			opts.Class = "WedgePart"
			B.part(name, Vector3.new(radius * 1.35, height, radius), cf, color, mat, opts)
		end
	end
	function B.light(parent, color, range, brightness)
		if B.Lights >= B.LightBudget then
			return nil
		end
		B.Lights += 1
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = rgb(color), range, brightness, false
		light.Parent = parent
		return light
	end
	function B.emitter(parent, texture, color, rate, life, size, speed, extra)
		local e = Instance.new("ParticleEmitter")
		e.Texture = texture
		e.Color = ColorSequence.new(rgb(color))
		e.Rate, e.Lifetime = rate, NumberRange.new(life[1], life[2])
		e.Size = if typeof(size) == "NumberSequence" then size else NumberSequence.new(size)
		e.Speed = NumberRange.new(speed[1], speed[2])
		for key, value in extra or {} do
			e[key] = value
		end
		e.Parent = parent
		return e
	end
	return B
end
local function jitter(rng, v)
	return rng:range(-v, v)
end
local function shade(color, amount)
	local c = rgb(color)
	return if amount >= 0 then c:Lerp(Color3.new(1, 1, 1), amount) else c:Lerp(Color3.new(0, 0, 0), -amount)
end
Props.shade = shade
-- Tapered, leaning trunk; returns segment joints and the final growth direction.
local function trunk(B, base, height, radius, segments, lean, color, mat)
	local rng, pos, dir = B.Rng, base, Vector3.yAxis
	local joints = { base }
	for i = 1, segments do
		dir = (dir + Vector3.new(jitter(rng, lean), 0, jitter(rng, lean))).Unit
		local nextPos = pos + dir * (height / segments)
		local d = radius * 2 * (1 - (i - 1) / segments * 0.5)
		B.limb(
			"TreeTrunk",
			pos - dir * 0.3,
			nextPos + dir * 0.3,
			d,
			color,
			mat or "Wood",
			{ Collide = i == 1 }
		)
		pos = nextPos
		table.insert(joints, pos)
	end
	return joints, dir
end
local function flare(B, base, radius, color, count)
	local rng = B.Rng
	for k = 1, count do
		local a = k / count * math.pi * 2 + jitter(rng, 0.3)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		B.limb(
			"TreeRoot",
			base + out * radius * 0.4 + Vector3.new(0, 1.2, 0),
			base + out * (radius * 2.4),
			radius * 0.55,
			color
		)
	end
end
local function canopy(B, center, spread, size, colors, count, mat)
	local rng = B.Rng
	for k = 1, count do
		local a = k / count * math.pi * 2 + jitter(rng, 0.5)
		local r = spread * rng:range(0.25, 1)
		local s = size * rng:range(0.75, 1.2)
		local p = center + Vector3.new(math.cos(a) * r, jitter(rng, size * 0.25), math.sin(a) * r)
		B.blob(
			"TreeCrown",
			Vector3.new(s * rng:range(1, 1.3), s * rng:range(0.6, 0.85), s * rng:range(1, 1.3)),
			CFrame.new(p) * CFrame.Angles(jitter(rng, 0.3), rng:range(0, 6.3), jitter(rng, 0.3)),
			colors[(k % #colors) + 1],
			mat
		)
	end
	B.blob(
		"TreeCrown",
		Vector3.new(size * 1.4, size * 0.9, size * 1.4),
		CFrame.new(center + Vector3.new(0, size * 0.35, 0)),
		colors[1],
		mat
	)
end
local function branches(B, joints, count, length, diameter, color)
	local rng, tips = B.Rng, {}
	for k = 1, count do
		local from = joints[math.clamp(#joints - (k % 2), 2, #joints)]
		local a = k / count * math.pi * 2 + jitter(rng, 0.4)
		local tip = from
			+ Vector3.new(math.cos(a) * length, length * rng:range(0.45, 0.8), math.sin(a) * length)
		B.limb("TreeBranch", from, tip, diameter, color)
		table.insert(tips, tip)
	end
	return tips
end
-- Tree catalogue. pal: Leaf, Leaf2, Bark, Accent, Flowers.
function Props.tree(B, kind, base, scale, pal)
	local rng = B.Rng
	local bark, leaf, leaf2 = rgb(pal.Bark), rgb(pal.Leaf), rgb(pal.Leaf2)
	local s = scale
	if kind == "Ancient" then
		local joints = trunk(B, base, 34 * s, 3.4 * s, 4, 0.08, bark)
		flare(B, base, 3.4 * s, shade(bark, -0.1), 6)
		local tips = branches(B, joints, 6, 13 * s, 1.6 * s, bark)
		for _, tip in tips do
			canopy(B, tip + Vector3.new(0, 2, 0), 4 * s, 10 * s, { leaf, leaf2, shade(leaf, -0.15) }, 3)
			B.limb(
				"TreeVine",
				tip,
				tip - Vector3.new(0, rng:range(6, 11) * s, 0),
				0.3,
				shade(leaf, -0.3),
				"Grass"
			)
		end
		canopy(B, joints[#joints] + Vector3.new(0, 4, 0), 7 * s, 14 * s, { leaf, leaf2 }, 5)
	elseif kind == "Pine" then
		local height = rng:range(18, 26) * s
		local joints = trunk(B, base, height * 0.35, 0.9 * s, 1, 0.02, bark)
		local top = joints[#joints]
		local snowy = pal.Snow
		for tier = 0, 3 do
			local r = (7.5 - tier * 1.6) * s
			local y = top + Vector3.new(0, tier * height * 0.17, 0)
			B.cone(
				"TreeCrown",
				y,
				r,
				height * 0.3,
				if tier % 2 == 0 then leaf else shade(leaf, 0.08),
				"Grass",
				tier * 0.4
			)
			if snowy then
				B.cone(
					"TreeSnow",
					y + Vector3.new(0, height * 0.18, 0),
					r * 0.45,
					height * 0.12,
					Color3.fromRGB(240, 246, 252),
					"Snow",
					tier * 0.4
				)
			end
		end
	elseif kind == "Sapling" then
		local joints = trunk(B, base, 7 * s, 0.45 * s, 2, 0.12, bark)
		canopy(B, joints[#joints] + Vector3.new(0, 1, 0), 1.6 * s, 4.5 * s, { leaf2, leaf }, 3)
	elseif kind == "Dead" then
		local joints = trunk(B, base, rng:range(12, 18) * s, 1.1 * s, 3, 0.22, shade(bark, -0.2))
		for _, tip in branches(B, joints, 5, 6 * s, 0.6 * s, shade(bark, -0.2)) do
			local twig = tip + Vector3.new(jitter(rng, 3), rng:range(1, 3), jitter(rng, 3)) * s
			B.limb("TreeBranch", tip, twig, 0.3 * s, shade(bark, -0.25))
		end
		flare(B, base, 1.1 * s, shade(bark, -0.25), 3)
	elseif kind == "Glow" then
		local joints = trunk(B, base, rng:range(13, 17) * s, 1 * s, 3, 0.1, bark, "Marble")
		local tips = branches(B, joints, 4, 6 * s, 0.6 * s, bark)
		for i, tip in tips do
			canopy(B, tip, 2 * s, 6 * s, { leaf, leaf2 }, 2, "Glass")
			local pod = B.blob(
				"RealmFlora",
				Vector3.new(0.9, 1.4, 0.9) * s,
				CFrame.new(tip - Vector3.new(0, 3 * s, 0)),
				pal.Accent,
				"Neon"
			)
			if i == 1 then
				B.light(pod, pal.Accent, 14, 0.6)
			end
		end
	elseif kind == "Palm" then
		local joints, dir = trunk(B, base, rng:range(16, 22) * s, 0.8 * s, 5, 0.18, bark)
		local top = joints[#joints]
		for k = 1, 7 do
			local a = k / 7 * math.pi * 2 + jitter(rng, 0.2)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local mid = top + out * 4 * s + Vector3.new(0, 1.2 * s, 0)
			local tip = top + out * 8.5 * s - Vector3.new(0, 2.5 * s, 0)
			for _, seg in { { top, mid }, { mid, tip } } do
				local cf = CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2])
				B.part(
					"TreeCrown",
					Vector3.new(2.6 * s, 0.2, (seg[2] - seg[1]).Magnitude + 0.6),
					cf,
					if k % 2 == 0 then leaf else leaf2,
					"Grass"
				)
			end
		end
		for k = 1, 3 do
			B.blob(
				"RealmFlora",
				Vector3.new(1.1, 1.1, 1.1) * s,
				CFrame.new(top + Vector3.new(math.cos(k * 2) * 0.8, -0.8, math.sin(k * 2) * 0.8) * s),
				Color3.fromRGB(110, 84, 46),
				"Wood"
			)
		end
		local _ = dir
	elseif kind == "Fungal" then
		local stalk = rng:range(10, 15) * s
		B.limb(
			"TreeTrunk",
			base,
			base + Vector3.new(0, stalk, 0),
			1.6 * s,
			shade(pal.Leaf2, 0.6),
			"SmoothPlastic",
			{ Collide = true }
		)
		local cap = B.blob(
			"TreeCrown",
			Vector3.new(14, 4.5, 14) * s,
			CFrame.new(base + Vector3.new(0, stalk + 1, 0)),
			pal.Accent,
			"SmoothPlastic"
		)
		B.blob(
			"TreeCrown",
			Vector3.new(11, 2, 11) * s,
			CFrame.new(base + Vector3.new(0, stalk - 0.4, 0)),
			shade(pal.Accent, 0.4),
			"Neon",
			{ Transparency = 0.35 }
		)
		B.light(cap, pal.Accent, 16, 0.5)
	elseif kind == "Crystal" then
		local count = rng:integer(3, 5)
		for k = 1, count do
			local h = rng:range(9, 18) * s * (if k == 1 then 1.3 else 1)
			local tilt = CFrame.Angles(jitter(rng, 0.35), rng:range(0, 6.3), jitter(rng, 0.35))
			Props.shard(B, CFrame.new(base) * tilt, Vector3.new(2.2, h, 2.2) * s, pal.Accent, k == 1)
		end
	else -- Broadleaf
		local joints = trunk(B, base, rng:range(13, 18) * s, 1.2 * s, 3, 0.1, bark)
		flare(B, base, 1.2 * s, shade(bark, -0.1), 3)
		local tips = branches(B, joints, 4, 5 * s, 0.7 * s, bark)
		for _, tip in tips do
			canopy(B, tip + Vector3.new(0, 1, 0), 2 * s, 7 * s, { leaf, leaf2, shade(leaf, -0.1) }, 2)
		end
		canopy(B, joints[#joints] + Vector3.new(0, 2.5, 0), 3.5 * s, 9 * s, { leaf, leaf2 }, 3)
	end
end
-- Faceted crystal: diamond-section prism with a chisel tip.
function Props.shard(B, base, size, color, glow, name)
	local body = B.part(
		name or "RealmFlora",
		Vector3.new(size.X, size.Y * 0.72, size.Z),
		base * CFrame.new(0, size.Y * 0.36, 0) * CFrame.Angles(0, math.pi / 4, 0),
		color,
		"Glass",
		{ Transparency = 0.15 }
	)
	for side = -1, 1, 2 do
		B.part(
			name or "RealmFlora",
			Vector3.new(size.X, size.Y * 0.28, size.Z * 0.5),
			base
				* CFrame.new(0, size.Y * 0.86, 0)
				* CFrame.Angles(0, math.pi / 4 + (if side > 0 then 0 else math.pi), 0)
				* CFrame.new(0, 0, -size.Z * 0.25),
			color,
			"Glass",
			{ Class = "WedgePart", Transparency = 0.15 }
		)
	end
	if glow then
		B.part(
			name or "RealmFlora",
			Vector3.new(size.X * 0.4, size.Y * 0.6, size.Z * 0.4),
			base * CFrame.new(0, size.Y * 0.4, 0) * CFrame.Angles(0, math.pi / 4, 0),
			shade(color, 0.4),
			"Neon",
			{ Transparency = 0.2 }
		)
	end
	return body
end
function Props.rock(B, base, s, color, mat)
	local rng = B.Rng
	local count = if s > 2 then 3 else 2
	for k = 1, count do
		local size = Vector3.new(rng:range(1.6, 2.6), rng:range(1, 1.8), rng:range(1.4, 2.4))
			* s
			* (if k == 1 then 1 else 0.7)
		local offset = if k == 1 then Vector3.zero else Vector3.new(jitter(rng, s), 0, jitter(rng, s))
		B.part(
			"Boulder",
			size,
			CFrame.new(base + offset + Vector3.new(0, size.Y * 0.32, 0))
				* CFrame.Angles(jitter(rng, 0.5), rng:range(0, 6.3), jitter(rng, 0.5)),
			shade(color, jitter(rng, 0.08)),
			mat,
			{ Collide = s >= 3 }
		)
	end
	if s >= 2.5 and rng:next() < 0.6 then
		B.blob(
			"RealmFlora",
			Vector3.new(2.2, 0.35, 1.8) * s * 0.6,
			CFrame.new(base + Vector3.new(0, s * 1.25, 0)),
			Color3.fromRGB(88, 128, 70),
			"Grass"
		)
	end
end
-- Ground cover; names keep RealmFlora/GrassBlade for culling and regression coverage.
function Props.cover(B, kind, base, pal, rockMat)
	local rng = B.Rng
	local leaf, leaf2 = rgb(pal.Leaf), rgb(pal.Leaf2)
	if kind == "Grass" or kind == "TallGrass" then
		local tall = kind == "TallGrass"
		for _ = 1, (if tall then 5 else 4) do
			local h = (if tall then rng:range(2.6, 4) else rng:range(1, 2)) * (pal.GrassScale or 1)
			B.part(
				"GrassBlade",
				Vector3.new(0.12, h, rng:range(0.5, 0.8)),
				CFrame.new(base + Vector3.new(jitter(rng, 0.9), h / 2, jitter(rng, 0.9)))
					* CFrame.Angles(jitter(rng, 0.3), rng:range(0, 6.3), jitter(rng, 0.25)),
				leaf2:Lerp(leaf, rng:next()),
				"Grass",
				{ Class = "WedgePart", Shadow = false }
			)
		end
	elseif kind == "Flower" then
		for _ = 1, 3 do
			local p = base + Vector3.new(jitter(rng, 1.4), 0, jitter(rng, 1.4))
			local h = rng:range(0.9, 1.7)
			B.part(
				"RealmFlora",
				Vector3.new(h, 0.12, 0.12),
				CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				leaf,
				"Grass",
				{ Shape = "Cylinder", Shadow = false }
			)
			local petal = pal.Flowers[rng:integer(1, #pal.Flowers)]
			B.part(
				"RealmFlora",
				Vector3.new(0.18, 0.9, 0.9),
				CFrame.new(p + Vector3.new(0, h, 0)) * CFrame.Angles(0, 0, math.pi / 2 + jitter(rng, 0.3)),
				petal,
				"SmoothPlastic",
				{ Shape = "Cylinder", Shadow = false }
			)
			B.part(
				"RealmFlora",
				Vector3.new(0.35, 0.35, 0.35),
				CFrame.new(p + Vector3.new(0, h + 0.12, 0)),
				Color3.fromRGB(255, 220, 90),
				"SmoothPlastic",
				{ Shape = "Ball", Shadow = false }
			)
		end
	elseif kind == "Bush" then
		for k = 1, 3 do
			local s = rng:range(2.2, 3.6)
			B.blob(
				"RealmFlora",
				Vector3.new(s * 1.2, s * 0.8, s),
				CFrame.new(base + Vector3.new(jitter(rng, 1.4), s * 0.3, jitter(rng, 1.4)))
					* CFrame.Angles(0, rng:range(0, 6.3), 0),
				if k == 2 then leaf2 else leaf
			)
		end
		if rng:next() < 0.4 then
			for _ = 1, 3 do
				B.part(
					"RealmFlora",
					Vector3.new(0.4, 0.4, 0.4),
					CFrame.new(base + Vector3.new(jitter(rng, 1.5), rng:range(1.6, 2.2), jitter(rng, 1.5))),
					pal.Flowers[1],
					"SmoothPlastic",
					{ Shape = "Ball", Shadow = false }
				)
			end
		end
	elseif kind == "Fern" then
		for k = 1, 6 do
			local a = k / 6 * math.pi * 2 + jitter(rng, 0.2)
			local cf = CFrame.new(base + Vector3.new(0, 0.6, 0))
				* CFrame.Angles(0, a, 0)
				* CFrame.Angles(-0.55, 0, 0)
				* CFrame.new(0, 0, -1.3)
			B.part(
				"RealmFlora",
				Vector3.new(0.9, 0.12, 2.8),
				cf,
				if k % 2 == 0 then leaf else leaf2,
				"Grass",
				{ Class = "WedgePart", Shadow = false }
			)
		end
	elseif kind == "Mushroom" then
		local glow = pal.GlowMushrooms
		for _ = 1, rng:integer(2, 4) do
			local p = base + Vector3.new(jitter(rng, 1.2), 0, jitter(rng, 1.2))
			local h = rng:range(0.6, 1.6)
			B.part(
				"RealmFlora",
				Vector3.new(h, 0.35, 0.35),
				CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(232, 222, 200),
				"SmoothPlastic",
				{ Shape = "Cylinder", Shadow = false }
			)
			B.blob(
				"RealmFlora",
				Vector3.new(1.3, 0.6, 1.3) * (h + 0.4) * 0.8,
				CFrame.new(p + Vector3.new(0, h, 0)),
				if glow then pal.Accent else Color3.fromRGB(196, 72, 60),
				if glow then "Neon" else "SmoothPlastic"
			)
		end
	elseif kind == "Vine" then
		for _ = 1, 3 do
			local p = base + Vector3.new(jitter(rng, 1.5), 0, jitter(rng, 1.5))
			B.part(
				"RealmFlora",
				Vector3.new(0.25, 0.25, rng:range(2.5, 4.5)),
				CFrame.new(p + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, rng:range(0, 6.3), 0),
				shade(leaf, -0.2),
				"Grass",
				{ Shadow = false }
			)
		end
		B.blob(
			"RealmFlora",
			Vector3.new(2.4, 0.4, 2),
			CFrame.new(base + Vector3.new(0, 0.15, 0)),
			leaf,
			"Grass"
		)
	elseif kind == "Rock" then
		Props.rock(B, base, rng:range(1, 2.4), pal.Rock, rockMat)
		for _ = 1, 3 do
			B.part(
				"RealmFlora",
				Vector3.new(0.5, 0.35, 0.45) * rng:range(0.7, 1.5),
				CFrame.new(base + Vector3.new(jitter(rng, 3), 0.15, jitter(rng, 3)))
					* CFrame.Angles(jitter(rng, 1), rng:range(0, 6.3), 0),
				shade(pal.Rock, 0.1),
				rockMat,
				{ Shadow = false }
			)
		end
	elseif kind == "CrystalShard" or kind == "VoidShard" or kind == "IceSpike" then
		local color = if kind == "IceSpike" then Color3.fromRGB(196, 232, 255) else rgb(pal.Accent)
		for k = 1, rng:integer(2, 3) do
			Props.shard(
				B,
				CFrame.new(base + Vector3.new(jitter(rng, 1.4), 0, jitter(rng, 1.4)))
					* CFrame.Angles(jitter(rng, 0.4), rng:range(0, 6.3), jitter(rng, 0.4)),
				Vector3.new(0.9, rng:range(1.6, 3.6), 0.9),
				color,
				kind ~= "IceSpike" and k == 1
			)
		end
	elseif kind == "Ember" then
		B.part(
			"RealmFlora",
			Vector3.new(2.4, 0.3, 2),
			CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:range(0, 6.3), 0),
			Color3.fromRGB(50, 40, 40),
			"CrackedLava",
			{ Shadow = false }
		)
		B.part(
			"RealmFlora",
			Vector3.new(1.4, 0.32, 0.25),
			CFrame.new(base + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, rng:range(0, 6.3), 0),
			Color3.fromRGB(255, 110, 40),
			"Neon",
			{ Shadow = false }
		)
	elseif kind == "Snowdrift" then
		B.blob(
			"RealmFlora",
			Vector3.new(rng:range(4, 7), rng:range(0.8, 1.6), rng:range(3, 5)),
			CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:range(0, 6.3), 0),
			Color3.fromRGB(240, 246, 252),
			"Snow"
		)
	elseif kind == "Rubble" then
		for _ = 1, 3 do
			B.part(
				"RealmFlora",
				Vector3.new(rng:range(1, 2.6), rng:range(0.6, 1.4), rng:range(1, 2)),
				CFrame.new(base + Vector3.new(jitter(rng, 2), 0.4, jitter(rng, 2)))
					* CFrame.Angles(jitter(rng, 0.4), rng:range(0, 6.3), jitter(rng, 0.4)),
				shade(pal.Rock, jitter(rng, 0.1)),
				rockMat
			)
		end
	elseif kind == "Column" then
		Props.column(B, base, rng:range(4, 9), pal.Rock, rockMat, true)
	elseif kind == "Gear" then
		Props.gear(
			B,
			CFrame.new(base + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			rng:range(2, 4),
			Color3.fromRGB(150, 120, 70)
		)
	elseif kind == "Pipe" then
		local a = base + Vector3.new(0, 0.8, 0)
		local b = a + Vector3.new(jitter(rng, 5), 0, jitter(rng, 5))
		B.limb("RealmFlora", a, b, 1.2, Color3.fromRGB(120, 110, 100), "CorrodedMetal")
		B.limb(
			"RealmFlora",
			b,
			b + Vector3.new(0, rng:range(2, 4), 0),
			1.2,
			Color3.fromRGB(120, 110, 100),
			"CorrodedMetal"
		)
	elseif kind == "Crate" then
		Props.crate(
			B,
			CFrame.new(base + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, rng:range(0, 6.3), 0),
			2.4
		)
	end
end
function Props.column(B, base, height, color, mat, broken)
	local rng = B.Rng
	B.part(
		"RuinColumn",
		Vector3.new(4, 1, 4),
		CFrame.new(base + Vector3.new(0, 0.5, 0)),
		shade(color, -0.05),
		mat,
		{ Collide = true }
	)
	B.limb(
		"RuinColumn",
		base + Vector3.new(0, 1, 0),
		base + Vector3.new(jitter(rng, 0.2), height, jitter(rng, 0.2)),
		2.6,
		color,
		mat,
		{ Collide = true }
	)
	if not broken then
		B.part(
			"RuinColumn",
			Vector3.new(4, 1.2, 4),
			CFrame.new(base + Vector3.new(0, height + 0.6, 0)),
			shade(color, -0.05),
			mat
		)
	else
		B.part(
			"RealmFlora",
			Vector3.new(3, 1.6, 2.4),
			CFrame.new(base + Vector3.new(3, 0.8, 1)) * CFrame.Angles(0.3, rng:range(0, 6), 0.2),
			color,
			mat
		)
	end
end
function Props.gear(B, cf, radius, color, name)
	local hub = B.part(
		name or "RealmFlora",
		Vector3.new(0.8, radius * 2, radius * 2),
		cf,
		color,
		"Metal",
		{ Shape = "Cylinder" }
	)
	local key = "gear" .. B.Count
	hub:SetAttribute("SpinKey", key)
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		local tooth = B.part(
			name or "RealmFlora",
			Vector3.new(0.7, radius * 0.4, radius * 0.45),
			cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, radius, 0),
			color,
			"Metal"
		)
		tooth:SetAttribute("SpinKey", key)
	end
	return hub
end
function Props.crate(B, cf, s)
	B.part("HouseDetail", Vector3.new(s, s, s), cf, Color3.fromRGB(150, 112, 70), "WoodPlanks")
	for _, y in { -0.42, 0.42 } do
		B.part(
			"HouseDetail",
			Vector3.new(s + 0.08, s * 0.12, s + 0.08),
			cf * CFrame.new(0, y * s, 0),
			Color3.fromRGB(96, 70, 46),
			"Wood"
		)
	end
end
function Props.barrel(B, cf, s)
	B.part(
		"HouseDetail",
		Vector3.new(s * 1.3, s, s),
		cf * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(132, 92, 58),
		"WoodPlanks",
		{ Shape = "Cylinder" }
	)
	for _, y in { -0.4, 0.4 } do
		B.part(
			"HouseDetail",
			Vector3.new(0.12, s + 0.06, s + 0.06),
			cf * CFrame.new(0, y * s * 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(70, 66, 64),
			"Metal",
			{ Shape = "Cylinder" }
		)
	end
end
function Props.lantern(B, base, color, height, name)
	local post = B.part(
		name or "HouseDetail",
		Vector3.new(0.4, height, 0.4),
		CFrame.new(base + Vector3.new(0, height / 2, 0)),
		Color3.fromRGB(60, 48, 40),
		"Wood"
	)
	B.part(
		name or "HouseDetail",
		Vector3.new(1.4, 0.3, 0.3),
		CFrame.new(base + Vector3.new(0.55, height - 0.2, 0)),
		Color3.fromRGB(60, 48, 40),
		"Wood"
	)
	local lamp = B.part(
		name or "HouseDetail",
		Vector3.new(0.8, 1, 0.8),
		CFrame.new(base + Vector3.new(1.1, height - 0.9, 0)),
		color,
		"Neon",
		{ Transparency = 0.15 }
	)
	B.light(lamp, color, 16, 0.8)
	return post, lamp
end
function Props.fence(B, a, b, color)
	local length = (b - a).Magnitude
	local count = math.max(1, math.floor(length / 6))
	for k = 0, count do
		local p = a:Lerp(b, k / count)
		B.part("HouseDetail", Vector3.new(0.5, 3, 0.5), CFrame.new(p + Vector3.new(0, 1.5, 0)), color, "Wood")
	end
	for _, y in { 1.2, 2.4 } do
		B.part(
			"HouseDetail",
			Vector3.new(0.25, 0.35, length),
			CFrame.lookAt((a + b) / 2 + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)),
			color,
			"Wood"
		)
	end
end
function Props.campfire(B, base)
	local rng = B.Rng
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2
		B.part(
			"HouseDetail",
			Vector3.new(0.9, 0.6, 0.8),
			CFrame.new(base + Vector3.new(math.cos(a) * 1.8, 0.3, math.sin(a) * 1.8))
				* CFrame.Angles(0, a, jitter(rng, 0.3)),
			Color3.fromRGB(110, 106, 100),
			"Slate"
		)
	end
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2
		B.limb(
			"HouseDetail",
			base + Vector3.new(math.cos(a) * 1.3, 0.2, math.sin(a) * 1.3),
			base + Vector3.new(0, 1.2, 0),
			0.45,
			Color3.fromRGB(92, 64, 44)
		)
	end
	local core = B.part(
		"HouseDetail",
		Vector3.new(0.8, 0.6, 0.8),
		CFrame.new(base + Vector3.new(0, 0.5, 0)),
		Color3.fromRGB(255, 140, 50),
		"Neon"
	)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor =
		3, 6, Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 60, 30)
	fire.Parent = core
	B.light(core, Color3.fromRGB(255, 160, 80), 18, 1)
end
function Props.log(B, a, b, d, bark, moss)
	local rng = B.Rng
	B.limb("FallenLog", a, b, d, bark, "Wood", { Collide = true })
	for _, p in { a, b } do
		B.part(
			"FallenLog",
			Vector3.new(0.12, d * 0.86, d * 0.86),
			CFrame.lookAt(p, p + (b - a)) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(196, 160, 112),
			"Wood",
			{ Shape = "Cylinder" }
		)
	end
	local mid = a:Lerp(b, rng:range(0.3, 0.7))
	B.limb(
		"TreeBranch",
		mid + Vector3.new(0, d * 0.4, 0),
		mid + Vector3.new(jitter(rng, 2), d + 1.5, jitter(rng, 2)),
		0.4,
		bark
	)
	if moss then
		B.blob(
			"RealmFlora",
			Vector3.new(2.4, 0.5, 1.6),
			CFrame.new(mid + Vector3.new(0, d * 0.48, 0)),
			moss,
			"Grass"
		)
	end
end
return Props
