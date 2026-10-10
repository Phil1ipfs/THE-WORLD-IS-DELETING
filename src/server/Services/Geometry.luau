--!nonstrict
local Geometry = {}
function Geometry.color(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
function Geometry.part(parent, name, size, cf, color, material, collidable)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = collidable ~= false
	part.CanTouch = false
	part.CanQuery = collidable ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end
function Geometry.glow(parent, position, color, size)
	local crystal = Geometry.part(
		parent,
		"Crystal",
		Vector3.new(size, size * 3, size),
		CFrame.new(position) * CFrame.Angles(0.15, size, 0.2),
		color,
		Enum.Material.Neon,
		false
	)
	crystal.Shape = Enum.PartType.Ball
	local lights = parent:GetAttribute("PointLightCount") or 0
	if lights < 2 then
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = color, 12, 0.5
		light.Parent = crystal
		parent:SetAttribute("PointLightCount", lights + 1)
	end
	return crystal
end
function Geometry.label(parent, text, position, color)
	local anchor = Geometry.part(parent, "Sign", Vector3.one, CFrame.new(position), color, nil, false)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 60)
	gui.MaxDistance = 75
	gui.AlwaysOnTop = false
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextSize = 17
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
end
return Geometry
