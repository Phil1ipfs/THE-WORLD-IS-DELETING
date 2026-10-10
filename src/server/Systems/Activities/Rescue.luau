--!nonstrict
-- Survivor rescue: find the survivor, free them (cut vines / thaw with an herb), then escort
-- them across intact ground to the rescue beacon. Anyone can take over the escort.
-- Failure: the survivor's ground is deleted beneath them.
local Common = require(script.Parent.Common)
local Rescue = {}
local C = Color3.fromRGB
local outfits = {
	Shepherd = { C(120, 160, 90), C(170, 130, 80), "Lost Shepherd" },
	Botanist = { C(90, 140, 110), C(220, 200, 150), "Trapped Botanist" },
	FrozenScout = { C(80, 110, 160), C(200, 200, 210), "Frozen Scout" },
	Survivor = { C(150, 110, 80), C(110, 100, 90), "Ruins Survivor" },
	StarKeeper = { C(180, 150, 220), C(255, 236, 170), "Star Keeper" },
	LastSurvivor = { C(90, 80, 120), C(200, 180, 230), "Last Survivor" },
	Traveler = { C(130, 120, 160), C(210, 180, 120), "Lost Traveler" },
}
local function survivor(ctx, act, x, z)
	local outfit = outfits[act.Def.Id] or outfits.Traveler
	local skin = C(234, 196, 160)
	local model = Common.figure(ctx, "Survivor", ctx.World(x, z, 0), {
		{ "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), outfit[1], Enum.Material.Fabric },
		{
			"Head",
			Vector3.new(1.3, 1.3, 1.3),
			CFrame.new(0, 4.7, 0),
			skin,
			Enum.Material.SmoothPlastic,
			nil,
			"Head",
		},
		{ "Leg", Vector3.new(0.9, 2, 0.9), CFrame.new(-0.5, 1, 0), C(70, 60, 54), Enum.Material.Fabric },
		{ "Leg", Vector3.new(0.9, 2, 0.9), CFrame.new(0.5, 1, 0), C(70, 60, 54), Enum.Material.Fabric },
		{
			"Arm",
			Vector3.new(0.8, 2, 0.8),
			CFrame.new(-1.45, 3, 0) * CFrame.Angles(0, 0, 0.2),
			outfit[1],
			Enum.Material.Fabric,
		},
		{
			"Arm",
			Vector3.new(0.8, 2, 0.8),
			CFrame.new(1.45, 3, 0) * CFrame.Angles(0, 0, -0.2),
			outfit[1],
			Enum.Material.Fabric,
		},
		{
			"Hat",
			Vector3.new(2, 0.3, 2),
			CFrame.new(0, 5.45, 0),
			outfit[2],
			Enum.Material.Fabric,
			"Cylinder",
		},
		{
			"Pack",
			Vector3.new(1.6, 1.8, 0.8),
			CFrame.new(0, 3.1, 0.85),
			C(110, 80, 50),
			Enum.Material.Leather,
		},
		{
			"Lantern",
			Vector3.new(0.5, 0.7, 0.5),
			CFrame.new(1.6, 2, -0.3),
			C(255, 210, 120),
			Enum.Material.Neon,
		},
	})
	for _, p in model:GetChildren() do
		if p.Name == "Hat" then
			p.CFrame = p.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		elseif p.Name == "Head" then
			local face = Instance.new("Decal")
			face.Texture, face.Face, face.Parent = "rbxasset://textures/face.png", Enum.NormalId.Front, p
		end
	end
	local bill = Instance.new("BillboardGui")
	bill.Size, bill.StudsOffset, bill.MaxDistance, bill.AlwaysOnTop =
		UDim2.fromOffset(180, 40), Vector3.new(0, 4, 0), 160, true
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Font, label.TextSize =
		UDim2.fromScale(1, 1), 1, Enum.Font.GothamBold, 14
	label.TextColor3, label.TextStrokeTransparency, label.Text = C(255, 230, 160), 0.3, outfit[3] .. "\nHELP!"
	label.Parent = bill
	bill.Adornee, bill.Parent = model:FindFirstChild("Head"), model
	act.Label, act.Name = label, outfit[3]
	return model
end
function Rescue.build(ctx, act, position)
	local site = position
		or ctx.S:find(ctx.Rng, 5, { Mainland = true, Outskirts = true }, 40, function(x, z)
			local b = ctx.Region.Beacon - ctx.Region.Center
			return math.sqrt((x - b.X) ^ 2 + (z - b.Z) ^ 2) + ctx.Rng:range(0, 30)
		end)
	if not site then
		return false
	end
	act.Local = Vector3.new(site.X, 0, site.Z)
	act.Model = survivor(ctx, act, site.X, site.Z)
	act.State = "Trapped"
	act.Bound = act.Def.Bound or 0
	act.Thaw = act.Def.Thaw == true
	act.Goal = 1
	local B = ctx.B
	B.Ground = ctx.Ground(site.X, site.Z)
	act.Bonds = {}
	if act.Bound > 0 then
		for k = 1, act.Bound do
			local vine = B.part(
				"RescueVine",
				Vector3.new(0.6, 6, 0.6),
				CFrame.new(ctx.World(site.X + math.cos(k * 2.1) * 1.6, site.Z + math.sin(k * 2.1) * 1.6, 3))
					* CFrame.Angles(0.3, k, 0.25),
				C(60, 110, 50),
				"Grass"
			)
			table.insert(act.Bonds, vine)
		end
	elseif act.Thaw then
		local ice = B.part(
			"RescueIce",
			Vector3.new(5, 7, 5),
			CFrame.new(ctx.World(site.X, site.Z, 3.5)),
			C(180, 220, 250),
			"Ice",
			{ Transparency = 0.45 }
		)
		table.insert(act.Bonds, ice)
	end
	local text = if act.Bound > 0
		then "Cut the vines"
		elseif act.Thaw then "Thaw with 1 herb"
		else "Lead to safety"
	act.Spec = Common.prompt(ctx, act, "Help", site.X, site.Z, 2.5, text, 0.5)
	act.Spec.Ground = true -- Moves with the survivor; loss is handled by Rescue.update.
	act.Hint = if act.Bound > 0
		then "Cut the vines (" .. act.Bound .. " times), then lead them to the rescue beacon."
		elseif act.Thaw then "Use an herb to thaw them, then lead them to the rescue beacon."
		else "Lead them to the rescue beacon beside the causeway. Stay close!"
end
local function moveModel(act, now)
	local region = act.Region
	local stride = if act.State == "Following" then math.sin(now * 10) * 0.35 else 0
	local cf = CFrame.new(region.Center + act.Local + Vector3.new(0, math.abs(stride) * 0.4, 0))
		* CFrame.Angles(0, act.Yaw or 0, 0)
	act.Model:PivotTo(cf)
	act.Spec.Part.CFrame = cf * CFrame.new(0, 2.5, 0)
end
function Rescue.interact(svc, act, record)
	if act.Done or act.State == "Lost" then
		return false
	end
	if act.State == "Trapped" and (act.Bound > 0 or act.Thaw) then
		if act.Bound > 0 then
			act.Bound -= 1
			local vine = table.remove(act.Bonds)
			if vine and vine.Parent then
				vine.Parent = nil
			end
			svc:participate(act, record)
			if act.Bound > 0 then
				svc:notice(record, "Vines cut. " .. act.Bound .. " left.")
				return true
			end
		elseif act.Thaw then
			if (record.Bag.Herb or 0) < 1 then
				svc:notice(record, "You need 1 herb to thaw them.")
				return false
			end
			record.Bag.Herb -= 1
			for _, p in act.Bonds do
				if p.Parent then
					p.Parent = nil
				end
			end
			act.Bonds = {}
		end
		act.State = "Waiting"
		act.Label.Text = act.Name .. "\nFollow you to the beacon?"
		act.Spec.Prompt.ActionText = "Lead to safety"
		svc:update(act)
		return true
	end
	act.State, act.Escort = "Following", record
	svc:participate(act, record)
	act.Label.Text = act.Name .. "\nFollowing " .. record.Player.DisplayName
	act.Spec.Prompt.ActionText = "Take over escort"
	svc:notice(record, act.Name .. " is following you. Reach the rescue beacon by the causeway!")
	svc:update(act)
	return true
end
function Rescue.update(svc, act, dt, now)
	if act.Done or act.State == "Lost" or not act.Model.Parent then
		return
	end
	local region = act.Region
	if not Common.support(region, act.Local.X, act.Local.Z) then
		act.State = "Lost"
		act.Spec.Prompt.Enabled = false
		act.Model.Parent = nil
		svc:fail(act, act.Name .. " was lost to the deletion.")
		return
	end
	if act.State == "Following" then
		local record = act.Escort
		local root, hum = Common.root(record)
		if record.State ~= "Alive" or not root or not hum or hum.Health <= 0 or record.Transit then
			act.State, act.Escort = "Waiting", nil
			act.Label.Text = act.Name .. "\nWaiting for help"
			act.Spec.Prompt.ActionText = "Lead to safety"
		else
			local target = root.Position - region.Center - root.CFrame.LookVector * 4
			local delta = Vector3.new(target.X - act.Local.X, 0, target.Z - act.Local.Z)
			if delta.Magnitude > 70 then
				act.State, act.Escort = "Waiting", nil
				act.Label.Text = act.Name .. "\nYou left me behind!"
				act.Spec.Prompt.ActionText = "Lead to safety"
				svc:notice(record, act.Name .. " lost sight of you. Go back for them.")
			elseif delta.Magnitude > 3 then
				local step = delta.Unit * math.min(delta.Magnitude - 2, 22 * dt)
				local nextLocal = act.Local + step
				if Common.support(region, nextLocal.X, nextLocal.Z) then
					act.Local = nextLocal
				end
				act.Yaw = math.atan2(-delta.X, -delta.Z)
			end
		end
		local beacon = region.Beacon - region.Center
		if Vector3.new(beacon.X - act.Local.X, 0, beacon.Z - act.Local.Z).Magnitude < 12 then
			act.State = "Saved"
			act.Label.Text = act.Name .. "\nSafe! Thank you!"
			act.Spec.Prompt.Enabled = false
			svc:complete(act, act.Name .. " reached the rescue beacon!", "Rescuer")
		end
	end
	moveModel(act, now)
end
function Rescue.status(act)
	return if act.Done
		then "Rescued"
		elseif act.State == "Lost" then "Lost"
		elseif act.State == "Following" then "Escorting"
		elseif act.State == "Trapped" then (if act.Bound > 0
			then "Trapped: cut " .. act.Bound .. " vines"
			elseif act.Thaw then "Frozen: needs an herb"
			else "Needs help")
		else "Waiting"
end
return Rescue
