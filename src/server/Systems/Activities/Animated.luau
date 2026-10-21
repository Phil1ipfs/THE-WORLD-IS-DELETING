--!nonstrict
-- Procedurally animated multi-part figures (creatures, sheep). Parts are anchored and placed
-- every tick relative to a root CFrame, with per-part motion: legs swing from hip pivots,
-- wings flap, tails sway, shards orbit, heads bob. Server-owned; moved in one BulkMoveTo.
local Animated = {}
-- spec: { Name, Size, At (CFrame offset), Color, Material, Shape?, Mesh?, Transparency?,
--         Anim? = { Kind, Pivot (Vector3 offset of the joint), Amp, Speed, Phase } }
function Animated.build(parent, position, specs, scale)
	scale = scale or 1
	local model = Instance.new("Model")
	local fig = { Model = model, Parts = {}, Specs = {}, Scale = scale, Time = 0 }
	for _, spec in specs do
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = spec[1], true, false, false, false
		p.Size = spec[2] * scale
		p.Color = spec[4]
		p.Material = if typeof(spec[5]) == "EnumItem"
			then spec[5]
			else Enum.Material[spec[5] or "SmoothPlastic"]
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CastShadow = p.Size.Magnitude > 3
		p.Transparency = spec.Transparency or 0
		if spec.Shape then
			p.Shape = Enum.PartType[spec.Shape]
		end
		if spec.Mesh then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Parent = Enum.MeshType[spec.Mesh], p
		end
		local at = spec[3]
		p.CFrame = CFrame.new(position) * CFrame.new(at.Position * scale) * (at - at.Position)
		p.Parent = model
		table.insert(fig.Parts, p)
		table.insert(fig.Specs, spec)
		p:SetAttribute("BaseTransparency", p.Transparency)
	end
	model.PrimaryPart = fig.Parts[1]
	model.Parent = parent
	return fig
end
local function motion(anim, t, gait)
	local kind, amp = anim.Kind, (anim.Amp or 0.5)
	local wave = math.sin(t * (anim.Speed or 8) + (anim.Phase or 0))
	if kind == "Leg" then
		return CFrame.Angles(wave * amp * gait, 0, 0)
	elseif kind == "Wing" then
		return CFrame.Angles(0, 0, wave * amp * (0.4 + gait))
	elseif kind == "Tail" then
		return CFrame.Angles(0, wave * amp, 0)
	elseif kind == "Bob" then
		return CFrame.new(0, wave * amp, 0)
	elseif kind == "Orbit" then
		return CFrame.Angles(0, t * (anim.Speed or 2) + (anim.Phase or 0), 0)
	elseif kind == "Jaw" then
		return CFrame.Angles(math.max(0, wave) * amp, 0, 0)
	elseif kind == "Head" then
		return CFrame.Angles(wave * amp * 0.4, math.sin(t * 0.7 + (anim.Phase or 0)) * amp, 0)
	end
	return CFrame.new()
end
-- gait: 0 idle .. 1 full stride; pose: extra root-relative CFrame (lean, crouch, burrow).
function Animated.place(fig, root, dt, gait, pose)
	fig.Time += dt * (0.6 + (gait or 0))
	local t, s = fig.Time, fig.Scale
	local parts, frames = {}, {}
	root = if pose then root * pose else root
	for i, part in fig.Parts do
		if part.Parent then
			local spec = fig.Specs[i]
			local at = spec[3]
			local offset = CFrame.new(at.Position * s) * (at - at.Position)
			local anim = spec.Anim
			if anim then
				local pivot = (anim.Pivot or Vector3.zero) * s
				if anim.Kind == "Orbit" then
					offset = motion(anim, t, gait or 0) * offset
				else
					offset = CFrame.new(pivot) * motion(anim, t, gait or 0) * CFrame.new(-pivot) * offset
				end
			end
			table.insert(parts, part)
			table.insert(frames, root * offset)
		end
	end
	local ok = pcall(function()
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	if not ok then
		for i, part in parts do
			part.CFrame = frames[i]
		end
	end
end
-- Fade and sink (death / burrow); alpha 0 = normal, 1 = gone.
function Animated.fade(fig, alpha)
	for _, part in fig.Parts do
		if part.Parent then
			local base = part:GetAttribute("BaseTransparency") or 0
			part.Transparency = base + (1 - base) * alpha
		end
	end
end
function Animated.tint(fig, names, color)
	for i, part in fig.Parts do
		if part.Parent and names[fig.Specs[i][1]] then
			part:SetAttribute("BaseColor", part:GetAttribute("BaseColor") or part.Color)
			part.Color = color or part:GetAttribute("BaseColor")
		end
	end
end
return Animated
