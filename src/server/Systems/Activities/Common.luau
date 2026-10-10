--!nonstrict
-- Shared helpers for realm activities: prompts, chests, labels, ground support and players.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local G = require(script.Parent.Parent.Parent.Services.Geometry)
local Common = {}
local C = Color3.fromRGB
-- Registers an activity prompt through the region's interaction pipeline, so every use passes
-- AdventureService validation (life, range, trusted position, ground support, debounce).
function Common.prompt(ctx, act, action, x, z, y, text, hold)
	local anchor = ctx.Region.Prompt("Activity", x, z, text, nil, y)
	anchor.Transparency = 1
	anchor.Name = "Activity_" .. act.Type
	anchor:SetAttribute("ActivityId", act.Id)
	anchor:SetAttribute("Action", action)
	local spec = ctx.Region.Interactions[#ctx.Region.Interactions]
	spec.Activity, spec.Action = act, action
	spec.Prompt.ObjectText = act.Title
	spec.Prompt.HoldDuration = hold or 0.25
	spec.Prompt.MaxActivationDistance = 11
	act.Prompts[action] = spec
	return spec
end
function Common.label(ctx, act, text, x, z, y, color)
	local anchor = ctx.Region.Model
	G.label(anchor, text, ctx.World(x, z, y), color or ctx.Accent)
	local sign = anchor:GetChildren()[#anchor:GetChildren()]
	if sign and sign.Name == "Sign" then
		local gui = sign:FindFirstChildOfClass("BillboardGui")
		if gui then
			gui.MaxDistance = 110
		end
		act.Sign = sign
	end
	return sign
end
-- Treasure chest: prompt anchor is the chest body; lid, bands and lock are children.
function Common.chest(ctx, act, action, x, z, y, text, tint)
	local spec = Common.prompt(ctx, act, action, x, z, (y or 0) + 1.1, text or "Open cache", 0.5)
	local body = spec.Part
	body.Transparency, body.Size = 0, Vector3.new(3.4, 2, 2.2)
	body.Color, body.Material = C(124, 84, 50), Enum.Material.WoodPlanks
	body.CFrame = CFrame.new(ctx.World(x, z, (y or 0) + 1)) * CFrame.Angles(0, ctx.Rng:range(0, 6.3), 0)
	local function child(name, size, cf, color, material, shape)
		local p = G.part(body, name, size, cf, color, material, false)
		if shape then
			p.Shape = Enum.PartType[shape]
		end
		return p
	end
	child(
		"ChestLid",
		Vector3.new(1.1, 3.5, 2.3),
		body.CFrame
			* CFrame.new(0, 1.05, 0)
			* CFrame.Angles(0, 0, math.pi / 2)
			* CFrame.Angles(math.pi / 2, 0, 0),
		C(140, 96, 58),
		Enum.Material.WoodPlanks,
		"Cylinder"
	)
	for _, bx in { -1.2, 1.2 } do
		child(
			"ChestBand",
			Vector3.new(0.3, 2.1, 2.3),
			body.CFrame * CFrame.new(bx, 0, 0),
			tint or C(220, 180, 90),
			Enum.Material.Metal
		)
	end
	child(
		"ChestLock",
		Vector3.new(0.6, 0.7, 0.3),
		body.CFrame * CFrame.new(0, 0.6, -1.2),
		tint or C(255, 214, 120),
		Enum.Material.Neon
	)
	local glow = Instance.new("ParticleEmitter")
	glow.Name, glow.Texture = "ChestGlint", "rbxasset://textures/particles/sparkles_main.dds"
	glow.Color, glow.LightEmission, glow.Rate = ColorSequence.new(tint or C(255, 220, 140)), 0.8, 1.5
	glow.Lifetime, glow.Size, glow.Speed =
		NumberRange.new(0.8, 1.4), NumberSequence.new(0.25), NumberRange.new(0.5, 1.5)
	glow.Parent = body
	spec.Chest = true
	return spec
end
-- Supporting terrain under a local point (nil when the cell has fallen).
function Common.support(region, x, z)
	local entry = region.Sites:at(x, z)
	if entry and entry.Cell.Part.Parent and entry.Cell.Part.CanCollide and entry.Cell.State ~= "Breaking" then
		return entry.Cell
	end
	return nil
end
-- Ground height under a local point (satellite sub-areas sit above or below the mainland).
function Common.height(region, x, z)
	return if region.Sites then region.Sites:height(x, z) else 0
end
function Common.root(record)
	local character = record.Player.Character
	return character and character:FindFirstChild("HumanoidRootPart"),
		character and character:FindFirstChildOfClass("Humanoid")
end
-- Alive players near a world position, excluding riders in transit.
function Common.near(svc, position, radius)
	local list = {}
	for _, record in svc.Players:active() do
		local root, hum = Common.root(record)
		if
			root
			and hum
			and hum.Health > 0
			and not record.Transit
			and (root.Position - position).Magnitude <= radius
		then
			table.insert(list, record)
		end
	end
	return list
end
function Common.tint(parts, color, material)
	for _, p in parts do
		if p.Parent then
			p.Color = color
			if material then
				p.Material = material
			end
		end
	end
end
-- Model built from anchored parts and moved with PivotTo; registered for collapse cleanup.
function Common.figure(ctx, name, position, parts)
	local model = Instance.new("Model")
	model.Name = name
	local primary
	for _, spec in parts do
		local p = G.part(model, spec[1], spec[2], CFrame.new(position) * spec[3], spec[4], spec[5], false)
		p.CanQuery = false
		if spec[6] then
			p.Shape = Enum.PartType[spec[6]]
		end
		if spec[7] then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Parent = Enum.MeshType[spec[7]], p
		end
		primary = primary or p
	end
	model.PrimaryPart = primary
	model.Parent = ctx.Region.Model
	return model
end
-- Small stone vault with a collidable door and a chest inside (prompt disabled until opened).
-- yaw orients the doorway; returns door parts and the chest spec.
function Common.vault(ctx, act, x, z, yaw, stone)
	local B = ctx.B
	B.Ground = ctx.Ground(x, z)
	local base = CFrame.new(ctx.World(x, z, 0)) * CFrame.Angles(0, yaw, 0)
	stone = stone or C(150, 140, 126)
	local walls = {
		{ -5, 0, 1, 8, 10 },
		{ 5, 0, 1, 8, 10 },
		{ 0, -5, 10, 8, 1 },
		{ -3.5, 5, 3, 8, 1 },
		{ 3.5, 5, 3, 8, 1 },
		{ 0, 0, 11.4, 1, 11.4, 8.5 },
	}
	for _, w in walls do
		local y = w[6] or 4
		B.part(
			"VaultWall",
			Vector3.new(w[3], w[4], w[5]),
			base * CFrame.new(w[1], y, w[2]),
			stone,
			"Cobblestone",
			{ Collide = true }
		)
	end
	B.part(
		"VaultDetail",
		Vector3.new(5, 1.2, 1.4),
		base * CFrame.new(0, 8.6, 5.4),
		ctx.Accent,
		"Neon",
		{ Transparency = 0.3 }
	)
	local door = B.part(
		"VaultDoor",
		Vector3.new(4, 7.6, 0.6),
		base * CFrame.new(0, 3.8, 5),
		C(90, 70, 50),
		"WoodPlanks",
		{ Collide = true }
	)
	local bands = {}
	for _, dy in { -2.4, 0, 2.4 } do
		table.insert(
			bands,
			B.part(
				"VaultDoor",
				Vector3.new(4.1, 0.4, 0.7),
				base * CFrame.new(0, 3.8 + dy, 5),
				C(70, 70, 76),
				"Metal"
			)
		)
	end
	local inside = base * CFrame.new(0, 0, -2)
	local offset = inside.Position - ctx.Region.Center
	local chest = Common.chest(ctx, act, "Vault", offset.X, offset.Z, 0, "Open vault chest")
	chest.Prompt.Enabled = false
	return {
		Door = door,
		Bands = bands,
		Chest = chest,
		LocalBase = base - ctx.Region.Center,
		Region = ctx.Region,
	}
end
function Common.setDoor(vault, open)
	for _, p in { vault.Door, table.unpack(vault.Bands) } do
		if p.Parent then
			p.CanCollide = not open and p == vault.Door
			p.CanQuery = p.CanCollide
			p.Transparency = if open then 1 else 0
		end
	end
end
-- True when a world position is inside the vault interior.
function Common.inside(vault, position)
	local p = (vault.LocalBase + vault.Region.Center):PointToObjectSpace(position)
	return math.abs(p.X) < 4.6 and math.abs(p.Z) < 4.6 and p.Y > -1 and p.Y < 9
end
local _ = Shared
return Common
