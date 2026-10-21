--!nonstrict
-- R15-structured NPC rig: HumanoidRootPart, Humanoid (R15), Animator and the standard 15 body
-- parts joined by correctly named Motor6Ds (Root, Waist, Neck, shoulders, elbows, wrists,
-- hips, knees, ankles), so Roblox R15 animations drive it. The root is anchored and moved by
-- the server; limbs are unanchored and follow through the joints. Body parts are stylised
-- blocks (a convincing prototype); swapping in MeshPart limbs keeps the same joints.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AnimationConfig = require(Shared.AnimationConfig)
local Rig = {}
local C = Color3.fromRGB
local function part(model, name, size, cf, color, material, extra)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Material = Enum.Material[material or "SmoothPlastic"]
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for key, value in extra or {} do
		p[key] = value
	end
	p.Parent = model
	return p
end
local function joint(name, part0, part1, at)
	local m = Instance.new("Motor6D")
	m.Name, m.Part0, m.Part1 = name, part0, part1
	m.C0 = part0.CFrame:Inverse() * at
	m.C1 = part1.CFrame:Inverse() * at
	m.Parent = part1
	return m
end
local function weld(item, to)
	item.Anchored, item.Massless, item.CanCollide, item.CanQuery = false, true, false, false
	local w = Instance.new("Weld")
	w.Part0, w.Part1 = to, item
	w.C0 = to.CFrame:Inverse() * item.CFrame
	w.Parent = item
	return item
end
-- outfit: { Skin, Tunic, Undershirt, Pants, Boots, Hood, Belt } colors; s = body scale.
function Rig.build(parent, base, outfit, s, name)
	s = s or 0.88
	local model = Instance.new("Model")
	model.Name = name or "NPC"
	local o = outfit
	local foot, lowerLeg, upperLeg, lowerTorso, upperTorso = 0.35 * s, 1.15 * s, 1.15 * s, 0.45 * s, 1.55 * s
	local hip = foot + lowerLeg + upperLeg
	local function at(x, y, z)
		return base * CFrame.new(x * s, y, z * s)
	end
	local root = part(
		model,
		"HumanoidRootPart",
		Vector3.new(2, 2, 1) * s,
		at(0, hip + s, 0),
		C(255, 255, 255),
		nil,
		{ Transparency = 1, Anchored = true, CanQuery = true }
	)
	local lt = part(
		model,
		"LowerTorso",
		Vector3.new(1.9 * s, lowerTorso, 1 * s),
		at(0, hip + lowerTorso / 2, 0),
		o.Belt,
		"Leather"
	)
	local ut = part(
		model,
		"UpperTorso",
		Vector3.new(2 * s, upperTorso, 1.05 * s),
		at(0, hip + lowerTorso + upperTorso / 2, 0),
		o.Tunic,
		"Fabric"
	)
	local headY = hip + lowerTorso + upperTorso + 0.62 * s
	local head = part(model, "Head", Vector3.new(1.2, 1.2, 1.2) * s, at(0, headY, 0), o.Skin)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType, mesh.Scale, mesh.Parent = Enum.MeshType.Head, Vector3.new(1.25, 1.25, 1.25), head
	local shoulderY = hip + lowerTorso + upperTorso - 0.25 * s
	local limbs = {}
	for _, side in { "Left", "Right" } do
		local x = if side == "Left" then -1 else 1
		local ua = part(
			model,
			side .. "UpperArm",
			Vector3.new(0.8 * s, 1.1 * s, 0.8 * s),
			at(x * 1.42, shoulderY - 0.45 * s, 0),
			o.Tunic,
			"Fabric"
		)
		local la = part(
			model,
			side .. "LowerArm",
			Vector3.new(0.72 * s, 1 * s, 0.72 * s),
			at(x * 1.42, shoulderY - 1.45 * s, 0),
			o.Undershirt,
			"Fabric"
		)
		local hand = part(
			model,
			side .. "Hand",
			Vector3.new(0.65 * s, 0.4 * s, 0.65 * s),
			at(x * 1.42, shoulderY - 2.15 * s, 0),
			o.Skin
		)
		local ul = part(
			model,
			side .. "UpperLeg",
			Vector3.new(0.85 * s, upperLeg, 0.85 * s),
			at(x * 0.48, foot + lowerLeg + upperLeg / 2, 0),
			o.Pants,
			"Fabric"
		)
		local ll = part(
			model,
			side .. "LowerLeg",
			Vector3.new(0.8 * s, lowerLeg, 0.8 * s),
			at(x * 0.48, foot + lowerLeg / 2, 0),
			o.Boots,
			"Leather"
		)
		local f = part(
			model,
			side .. "Foot",
			Vector3.new(0.82 * s, foot, 1.15 * s),
			at(x * 0.48, foot / 2, -0.12),
			o.Boots,
			"Leather"
		)
		limbs[side] = { UpperArm = ua, LowerArm = la, Hand = hand, UpperLeg = ul, LowerLeg = ll, Foot = f }
		joint(side .. "Shoulder", ut, ua, at(x * 1.25, shoulderY, 0))
		joint(side .. "Elbow", ua, la, at(x * 1.42, shoulderY - 0.95 * s, 0))
		joint(side .. "Wrist", la, hand, at(x * 1.42, shoulderY - 1.95 * s, 0))
		joint(side .. "Hip", lt, ul, at(x * 0.48, hip, 0))
		joint(side .. "Knee", ul, ll, at(x * 0.48, foot + lowerLeg, 0))
		joint(side .. "Ankle", ll, f, at(x * 0.48, foot, 0))
	end
	joint("Root", root, lt, at(0, hip, 0))
	joint("Waist", lt, ut, at(0, hip + lowerTorso, 0))
	joint("Neck", ut, head, at(0, hip + lowerTorso + upperTorso, 0))
	local hum = Instance.new("Humanoid")
	pcall(function()
		hum.RigType = Enum.HumanoidRigType.R15
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HipHeight = hip
	end)
	hum.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = hum
	model.PrimaryPart = root
	model.Parent = parent
	return {
		Model = model,
		Root = root,
		Humanoid = hum,
		Animator = animator,
		Head = head,
		UpperTorso = ut,
		LowerTorso = lt,
		Limbs = limbs,
		Scale = s,
		RootHeight = hip + s, -- Root center above the feet.
		Weld = weld,
		Part = function(n, size, cf, color, material, extra)
			return part(model, n, size, cf, color, material, extra)
		end,
	}
end
-- Plays a named animation (Walk/Idle/Cheer) from AnimationConfig; returns false when the rig
-- must fall back to procedural posing (no IDs configured or no animation runtime).
function Rig.play(rig, key)
	if rig.Current == key then
		return rig.Tracks ~= nil
	end
	rig.Current = key
	local id = AnimationConfig.UseDefaults and AnimationConfig.R15[key]
	if not id or id == "" then
		rig.Tracks = nil
		return false
	end
	local ok = pcall(function()
		rig.Tracks = rig.Tracks or {}
		for _, track in rig.Tracks do
			track:Stop(0.2)
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local track = rig.Animator:LoadAnimation(animation)
		track.Looped = key ~= "Cheer"
		track:Play(0.2)
		rig.Tracks = { track }
	end)
	if not ok then
		rig.Tracks = nil
	end
	return ok
end
-- Procedural fallback: swing hips/shoulders through the Motor6D transforms (C0 offsets).
function Rig.pose(rig, t, gait, fear)
	if rig.Tracks then
		return
	end
	rig.BaseC0 = rig.BaseC0 or {}
	for _, side in { "Left", "Right" } do
		local x = if side == "Left" then 1 else -1
		for _, pair in
			{
				{ rig.Limbs[side].UpperLeg, side .. "Hip", 0.6 },
				{ rig.Limbs[side].UpperArm, side .. "Shoulder", -0.5 },
			}
		do
			local motor = pair[1]:FindFirstChild(pair[2])
			if motor then
				rig.BaseC0[motor] = rig.BaseC0[motor] or motor.C0
				local swing = math.sin(t * 8) * pair[3] * x * gait
				local shake = if fear then math.sin(t * 40) * 0.05 else 0
				motor.C0 = rig.BaseC0[motor] * CFrame.Angles(swing + shake, 0, 0)
			end
		end
	end
end
return Rig
