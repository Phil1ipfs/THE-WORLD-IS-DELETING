--!nonstrict
-- Symbol dials: rotate each pillar until its front face matches the carved mural clue.
local Common = require(script.Parent.Common)
local Dials = {}
local C = Color3.fromRGB
Dials.Symbols = { "Sun", "Leaf", "Moon", "Star" }
local colors = {
	Sun = C(255, 205, 90),
	Leaf = C(120, 220, 110),
	Moon = C(210, 220, 255),
	Star = C(150, 200, 255),
}
-- Emblem drawn on a face CFrame (facing -Z); returns parts for PivotTo moves.
local function emblem(B, symbol, cf, name)
	local color = colors[symbol]
	local parts = {}
	local function add(size, offset, shape)
		table.insert(parts, B.part(name, size, cf * offset, color, "Neon", { Shape = shape, Shadow = false }))
	end
	if symbol == "Sun" then
		add(Vector3.new(0.2, 1.3, 1.3), CFrame.Angles(0, math.pi / 2, 0), "Cylinder")
		for k = 1, 4 do
			add(Vector3.new(0.25, 0.5, 0.15), CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, 0.95, 0))
		end
	elseif symbol == "Leaf" then
		add(Vector3.new(0.9, 1.6, 0.15), CFrame.Angles(0, 0, math.pi / 4))
		add(Vector3.new(0.15, 1.8, 0.18), CFrame.new())
	elseif symbol == "Moon" then
		add(Vector3.new(0.2, 1.5, 1.5), CFrame.Angles(0, math.pi / 2, 0), "Cylinder")
		table.insert(
			parts,
			B.part(
				name,
				Vector3.new(0.22, 1.3, 1.3),
				cf * CFrame.new(0.45, 0.3, -0.02) * CFrame.Angles(0, math.pi / 2, 0),
				C(60, 60, 70),
				"Slate",
				{ Shape = "Cylinder", Shadow = false }
			)
		)
	else
		add(Vector3.new(0.3, 1.8, 0.15), CFrame.new())
		add(Vector3.new(1.8, 0.3, 0.15), CFrame.new())
		add(Vector3.new(0.3, 1.3, 0.15), CFrame.Angles(0, 0, math.pi / 4))
	end
	return parts
end
function Dials.build(ctx, act)
	local site = ctx.S:find(ctx.Rng, 12, (ctx.Land or { Mainland = true, Outskirts = true }), 50)
	if not site then
		return false
	end
	act.Site = site
	local rng, B = ctx.Rng, ctx.B
	local yaw = rng:range(0, math.pi * 2)
	local forward = Vector3.new(math.sin(yaw), 0, math.cos(yaw))
	local right = Vector3.new(forward.Z, 0, -forward.X)
	act.Target, act.Dials = {}, {}
	B.Ground = ctx.Ground(site.X, site.Z)
	-- Mural: the clue showing the three target symbols.
	-- The mural stands behind and above the dials, facing the player in the same left-to-right order.
	local muralPos = Vector3.new(site.X, 0, site.Z) + forward * 6.5
	local muralCenter = ctx.World(muralPos.X, muralPos.Z, 8)
	local muralCf = CFrame.lookAt(muralCenter, muralCenter - forward)
	B.part("DialMural", Vector3.new(12, 5, 1.2), muralCf, C(170, 160, 140), "Slate", { Collide = true })
	B.part("DialMural", Vector3.new(13, 1, 2), muralCf * CFrame.new(0, 3, 0), C(130, 120, 104), "Slate")
	for _, side in { -1, 1 } do
		B.part(
			"DialMural",
			Vector3.new(1.4, 6, 1.4),
			muralCf * CFrame.new(side * 5, -5.5, 0.2),
			C(130, 120, 104),
			"Slate",
			{ Collide = true }
		)
	end
	for k = 1, 3 do
		local symbol = Dials.Symbols[rng:integer(1, 4)]
		act.Target[k] = symbol
		emblem(B, symbol, muralCf * CFrame.new((k - 2) * 3.6, 0, -0.65), "DialClue")
	end
	for k = 1, 3 do
		local p = Vector3.new(site.X, 0, site.Z) + right * ((k - 2) * 5) + forward * 2
		local base = CFrame.lookAt(ctx.World(p.X, p.Z, 3), ctx.World(p.X, p.Z, 3) - forward)
		B.part(
			"DialBase",
			Vector3.new(3.6, 1, 3.6),
			CFrame.new(ctx.World(p.X, p.Z, 0.5)),
			C(110, 104, 98),
			"Slate"
		)
		local model = Instance.new("Model")
		model.Name = "SymbolDial"
		model.Parent = ctx.Region.Model
		local pillar = B.part(
			"SymbolDial",
			Vector3.new(2.6, 4, 2.6),
			base,
			C(196, 186, 168),
			"Marble",
			{ Collide = true, Parent = model }
		)
		model.PrimaryPart = pillar
		for face = 0, 3 do
			local symbol = Dials.Symbols[face + 1]
			for _, part in
				emblem(
					B,
					symbol,
					base * CFrame.Angles(0, face * math.pi / 2, 0) * CFrame.new(0, 0, -1.35),
					"SymbolDial"
				)
			do
				part.Parent = model
			end
		end
		-- Face index currently pointing toward the mural side (back toward -forward).
		local start = rng:integer(0, 3)
		if Dials.Symbols[start + 1] == act.Target[k] then
			start = (start + 1) % 4
		end
		local dial = { Model = model, LocalBase = base - ctx.Region.Center, Region = ctx.Region, Face = 0 }
		table.insert(act.Dials, dial)
		for _ = 1, start do
			Dials.turn(dial)
		end
		Common.prompt(
			ctx,
			act,
			"Turn" .. k,
			p.X - forward.X * 2.4,
			p.Z - forward.Z * 2.4,
			2,
			"Turn dial",
			0.2
		)
	end
	act.Goal = 3
	act.Hint = "Match the dials to the carved mural behind them (left to right)."
end
function Dials.turn(dial)
	dial.Face = (dial.Face + 1) % 4
	dial.Model:PivotTo((dial.LocalBase + dial.Region.Center) * CFrame.Angles(0, -dial.Face * math.pi / 2, 0))
end
local function matches(act)
	local count = 0
	for k, dial in act.Dials do
		if Dials.Symbols[dial.Face + 1] == act.Target[k] then
			count += 1
		end
	end
	return count
end
function Dials.interact(svc, act, record, spec)
	if spec.Action == "Vault" then
		return svc:openChest(act, record)
	end
	if act.Done then
		return false
	end
	local index = tonumber(spec.Action:sub(5))
	local dial = index and act.Dials[index]
	if not dial then
		return false
	end
	Dials.turn(dial)
	svc:participate(act, record)
	act.Progress = matches(act)
	if act.Progress == 3 then
		svc:complete(act, "The dials lock into place with a deep chime!", "Puzzler")
	else
		svc:update(act)
	end
	return true
end
function Dials.status(act)
	return if act.Done then "Solved" else string.format("%d/3 aligned", act.Progress)
end
return Dials
