--!nonstrict
-- The Lost Shepherd: talk to him, find his three lost sheep across the realm, protect the group
-- from creatures and escort everyone to the rescue beacon. Server-authoritative progression;
-- rewards are granted exactly once through ObjectiveService:complete.
local Common = require(script.Parent.Common)
local Animated = require(script.Parent.Animated)
local Rig = require(script.Parent.Parent.Parent.Services.NpcRig)
local Flock = {}
local C = Color3.fromRGB
local SHEEP = 3
local function sheepSpecs()
	local wool, wool2, face, leg = C(246, 244, 236), C(232, 228, 216), C(52, 46, 44), C(60, 54, 50)
	local s = {
		{
			"Core",
			Vector3.new(2.6, 2.1, 3.4),
			CFrame.new(0, 2.1, 0),
			wool,
			"Fabric",
			Mesh = "Sphere",
			Anim = { Kind = "Bob", Amp = 0.05, Speed = 6 },
		},
		{ "Wool", Vector3.new(1.8, 1.7, 1.8), CFrame.new(0.6, 2.7, -0.8), wool2, "Fabric", Mesh = "Sphere" },
		{ "Wool", Vector3.new(1.8, 1.7, 1.8), CFrame.new(-0.6, 2.7, 0.6), wool2, "Fabric", Mesh = "Sphere" },
		{ "Wool", Vector3.new(1.6, 1.5, 1.6), CFrame.new(0, 2.5, 1.4), wool, "Fabric", Mesh = "Sphere" },
		{ "Wool", Vector3.new(1.5, 1.4, 1.5), CFrame.new(0, 2.6, -1.5), wool, "Fabric", Mesh = "Sphere" },
		{
			"Head",
			Vector3.new(1, 1.1, 1.3),
			CFrame.new(0, 2.5, -2.1),
			face,
			"SmoothPlastic",
			Mesh = "Sphere",
			Anim = { Kind = "Head", Amp = 0.35 },
		},
		{ "WoolCap", Vector3.new(1, 0.6, 0.9), CFrame.new(0, 3.05, -1.9), wool, "Fabric", Mesh = "Sphere" },
		{
			"Ear",
			Vector3.new(0.7, 0.18, 0.35),
			CFrame.new(0.65, 2.75, -1.95) * CFrame.Angles(0, 0, -0.4),
			face,
			"SmoothPlastic",
		},
		{
			"Ear",
			Vector3.new(0.7, 0.18, 0.35),
			CFrame.new(-0.65, 2.75, -1.95) * CFrame.Angles(0, 0, 0.4),
			face,
			"SmoothPlastic",
		},
		{
			"Eye",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(0.28, 2.7, -2.7),
			C(255, 255, 255),
			"SmoothPlastic",
			Shape = "Ball",
		},
		{
			"Eye",
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(-0.28, 2.7, -2.7),
			C(255, 255, 255),
			"SmoothPlastic",
			Shape = "Ball",
		},
		{
			"Tail",
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(0, 2.4, 1.9),
			wool,
			"Fabric",
			Mesh = "Sphere",
			Anim = { Kind = "Tail", Pivot = Vector3.new(0, 2.4, 1.7), Amp = 0.6, Speed = 7 },
		},
	}
	for i, p in { { 0.7, -1 }, { -0.7, -1 }, { 0.7, 1 }, { -0.7, 1 } } do
		table.insert(s, {
			"Leg",
			Vector3.new(1.2, 0.36, 0.36),
			CFrame.new(p[1], 0.6, p[2]) * CFrame.Angles(0, 0, math.pi / 2),
			leg,
			"SmoothPlastic",
			Shape = "Cylinder",
			Anim = {
				Kind = "Leg",
				Pivot = Vector3.new(p[1], 1.2, p[2]),
				Amp = 0.6,
				Speed = 10,
				Phase = if i == 1 or i == 4 then 0 else math.pi,
			},
		})
	end
	return s
end
local function shepherd(ctx, x, z)
	local base = CFrame.new(ctx.World(x, z, 0))
	local rig = Rig.build(ctx.Region.Model, base, {
		Skin = C(234, 196, 160),
		Tunic = C(122, 82, 50),
		Undershirt = C(232, 220, 192),
		Pants = C(98, 76, 54),
		Boots = C(64, 44, 30),
		Belt = C(70, 48, 32),
	}, 0.88, "LostShepherd")
	local s = rig.Scale
	local head, ut, lt = rig.Head, rig.UpperTorso, rig.LowerTorso
	local brown = C(102, 70, 44)
	-- Hood and drape.
	rig.Weld(
		rig.Part(
			"Hood",
			Vector3.new(1.45, 1.35, 1.5) * s,
			head.CFrame * CFrame.new(0, 0.12 * s, 0.12 * s),
			brown,
			"Fabric"
		),
		head
	)
	local hoodMesh = Instance.new("SpecialMesh")
	hoodMesh.MeshType, hoodMesh.Parent = Enum.MeshType.Sphere, head.Parent:FindFirstChild("Hood")
	rig.Weld(
		rig.Part(
			"HoodDrape",
			Vector3.new(1.6, 1.3, 0.25) * s,
			ut.CFrame * CFrame.new(0, 0.45 * s, 0.55 * s),
			brown,
			"Fabric"
		),
		ut
	)
	-- Messy hair fringe peeking out of the hood.
	rig.Weld(
		rig.Part(
			"Hair",
			Vector3.new(1.1, 0.25, 0.35) * s,
			head.CFrame * CFrame.new(0, 0.38 * s, -0.5 * s) * CFrame.Angles(0.3, 0, 0.08),
			C(92, 62, 40),
			"Fabric"
		),
		head
	)
	-- Worried face: raised inner brows, wide eyes, small frown.
	for _, side in { -1, 1 } do
		rig.Weld(
			rig.Part(
				"Eye",
				Vector3.new(0.16, 0.2, 0.06) * s,
				head.CFrame * CFrame.new(side * 0.22 * s, 0.1 * s, -0.62 * s),
				C(30, 26, 24)
			),
			head
		)
		rig.Weld(
			rig.Part(
				"Brow",
				Vector3.new(0.3, 0.06, 0.06) * s,
				head.CFrame
					* CFrame.new(side * 0.24 * s, 0.32 * s, -0.62 * s)
					* CFrame.Angles(0, 0, side * 0.35),
				C(70, 48, 32)
			),
			head
		)
	end
	rig.Weld(
		rig.Part(
			"Mouth",
			Vector3.new(0.3, 0.05, 0.05) * s,
			head.CFrame * CFrame.new(0, -0.25 * s, -0.62 * s) * CFrame.Angles(0, 0, 0),
			C(120, 60, 50)
		),
		head
	)
	-- Belt pouch, backpack with bedroll.
	rig.Weld(
		rig.Part(
			"BeltPouch",
			Vector3.new(0.5, 0.55, 0.35) * s,
			lt.CFrame * CFrame.new(0.75 * s, -0.05 * s, -0.55 * s),
			C(110, 76, 46),
			"Leather"
		),
		lt
	)
	rig.Weld(
		rig.Part(
			"Backpack",
			Vector3.new(1.4, 1.5, 0.7) * s,
			ut.CFrame * CFrame.new(0, -0.05 * s, 0.85 * s),
			C(120, 86, 52),
			"Leather"
		),
		ut
	)
	local roll = rig.Part(
		"Bedroll",
		Vector3.new(1.6, 0.55, 0.55) * s,
		ut.CFrame * CFrame.new(0, 0.85 * s, 0.85 * s),
		C(150, 110, 70),
		"Fabric",
		{ Shape = Enum.PartType.Cylinder }
	)
	rig.Weld(roll, ut)
	-- Shepherd's crook in the right hand; lantern in the left.
	local hand = rig.Limbs.Right.Hand
	local staff = rig.Part(
		"Staff",
		Vector3.new(5.6 * s, 0.22, 0.22),
		hand.CFrame * CFrame.new(0, 1.6 * s, -0.1) * CFrame.Angles(0, 0, math.pi / 2),
		C(120, 86, 52),
		"Wood",
		{ Shape = Enum.PartType.Cylinder }
	)
	rig.Weld(staff, hand)
	local crook = rig.Part(
		"Staff",
		Vector3.new(1.1 * s, 0.22, 0.22),
		hand.CFrame * CFrame.new(-0.4 * s, 4.45 * s, -0.1) * CFrame.Angles(0, 0, 0.35),
		C(120, 86, 52),
		"Wood",
		{ Shape = Enum.PartType.Cylinder }
	)
	rig.Weld(crook, hand)
	local left = rig.Limbs.Left.Hand
	rig.Weld(
		rig.Part(
			"Lantern",
			Vector3.new(0.45, 0.6, 0.45),
			left.CFrame * CFrame.new(0, -0.55, -0.1),
			C(60, 50, 40),
			"Metal"
		),
		left
	)
	local glow = rig.Part(
		"LanternGlow",
		Vector3.new(0.3, 0.38, 0.3),
		left.CFrame * CFrame.new(0, -0.55, -0.1),
		C(255, 214, 140),
		"Neon"
	)
	rig.Weld(glow, left)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = C(255, 214, 140), 12, 0.8, false
	light.Parent = glow
	return rig
end
local function bill(adornee, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.MaxDistance, gui.AlwaysOnTop =
		UDim2.fromOffset(200, 40), Vector3.new(0, 3.2, 0), 140, true
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Font, label.TextSize =
		UDim2.fromScale(1, 1), 1, Enum.Font.GothamBold, 14
	label.TextColor3, label.TextStrokeTransparency, label.Text = color, 0.3, text
	label.Parent = gui
	gui.Adornee, gui.Parent = adornee, adornee
	return label
end
function Flock.build(ctx, act)
	local S, rng, region = ctx.S, ctx.Rng, ctx.Region
	local core = { Mainland = true, Outskirts = true }
	local beacon = region.Beacon - region.Center
	local site = S:find(rng, 5, core, 50, function(x, z)
		return math.sqrt((x - beacon.X) ^ 2 + (z - beacon.Z) ^ 2) + rng:range(0, 20)
	end)
	if not site then
		return false
	end
	act.Site = site
	act.Rig = shepherd(ctx, site.X, site.Z)
	act.Model = act.Rig.Model
	act.Label = bill(act.Rig.Head, "Lost Shepherd\nHas anyone seen my sheep?", C(255, 230, 160))
	act.Shepherd = { Local = Vector3.new(site.X, 0, site.Z), Yaw = 0, State = "Waiting", Kind = "Shepherd" }
	act.Spec = Common.prompt(ctx, act, "Talk", site.X, site.Z, 3, "Talk to the shepherd", 0.3)
	act.Spec.Ground = true
	act.Sheep = {}
	local placed = { Vector3.new(site.X, 0, site.Z) }
	for k = 1, SHEEP do
		local spot = S:find(rng, 3, core, 60, function(x, z)
			local nearest = math.huge
			for _, p in placed do
				nearest = math.min(nearest, math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2))
			end
			return math.min(nearest, 90) + rng:range(0, 10)
		end)
		if not spot then
			return false
		end
		table.insert(placed, Vector3.new(spot.X, 0, spot.Z))
		local fig = Animated.build(region.Model, ctx.World(spot.X, spot.Z, 0), sheepSpecs(), 0.9)
		fig.Model.Name = "LostSheep"
		local sheep = {
			Figure = fig,
			Local = Vector3.new(spot.X, 0, spot.Z),
			Yaw = rng:range(0, 6.3),
			State = "Lost",
			Kind = "Sheep",
			Index = k,
		}
		sheep.Spec = Common.prompt(ctx, act, "Sheep" .. k, spot.X, spot.Z, 2.5, "Rescue the sheep", 0.4)
		sheep.Spec.Ground = true
		sheep.Spec.Prompt.Enabled = false
		sheep.Label = bill(fig.Parts[1], "Lost sheep", C(240, 240, 255))
		sheep.Label.Parent.Enabled = false
		act.Sheep[k] = sheep
	end
	act.State = "Waiting"
	act.Goal = SHEEP
	act.Hint = "Talk to the Lost Shepherd, find his three sheep, then lead everyone to the rescue beacon."
	-- Followers can be targeted by creatures; a hit scatters a sheep or staggers the shepherd.
	region.Followers = region.Followers or {}
	for _, member in { act.Shepherd, table.unpack(act.Sheep) } do
		table.insert(region.Followers, {
			Active = function()
				return member.State == "Following" and not act.Done and not act.Failed
			end,
			Position = function()
				return region.Center
					+ Vector3.new(
						member.Local.X,
						Common.height(region, member.Local.X, member.Local.Z) + 2,
						member.Local.Z
					)
			end,
			Hit = function(creature)
				member.ScaredUntil = os.clock() + 2
				if member.Kind == "Sheep" then
					member.State, member.Escort = "Lost", nil
					local away = member.Local
						+ Vector3.new(math.cos(member.Index * 2) * 14, 0, math.sin(member.Index * 2) * 14)
					if Common.support(region, away.X, away.Z) then
						member.Local = away
					end
					member.Spec.Prompt.Enabled = true
					member.Label.Text = "Scared sheep!"
					member.Label.Parent.Enabled = true
					act.Scattered = (act.Scattered or 0) + 1
					act.Notify = "A " .. creature.Def.Name .. " scattered a sheep! Find it again."
				end
			end,
		})
	end
end
local function dialogue(svc, record, lines)
	svc.Effects:FireClient(record.Player, "Dialogue", { Speaker = "Lost Shepherd", Lines = lines })
end
local function remaining(act, record)
	local root = Common.root(record)
	local lines = {}
	for _, sheep in act.Sheep do
		if sheep.State == "Lost" and root then
			local w = act.Region.Center + sheep.Local
			local d = w - root.Position
			local names =
				{ "east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast" }
			local dir = names[(math.floor(math.atan2(d.Z, d.X) / (math.pi * 2) * 8 + 0.5) % 8) + 1]
			table.insert(
				lines,
				string.format(
					"One wandered %s, about %dm away.",
					dir,
					math.floor(Vector3.new(d.X, 0, d.Z).Magnitude)
				)
			)
		end
	end
	return lines
end
function Flock.interact(svc, act, record, spec)
	if act.Done or act.Failed then
		return false
	end
	if spec.Action == "Talk" then
		svc:participate(act, record)
		if act.State == "Waiting" then
			act.State = "Searching"
			act.Shepherd.State, act.Shepherd.Escort = "Following", record
			for _, sheep in act.Sheep do
				sheep.Spec.Prompt.Enabled = true
				sheep.Label.Parent.Enabled = true
			end
			act.Label.Text = "Lost Shepherd\nFollowing " .. record.Player.DisplayName
			spec.Prompt.ActionText = "Ask where the sheep are"
			local lines = {
				"Oh, thank the skies! The ground cracked and my three sheep bolted.",
				"Please find them before the deletion takes them. I'll follow you.",
			}
			for _, line in remaining(act, record) do
				table.insert(lines, line)
			end
			dialogue(svc, record, lines)
		else
			act.Shepherd.State, act.Shepherd.Escort = "Following", record
			local lines = remaining(act, record)
			if #lines == 0 then
				lines = { "That's all of them! Lead us to the rescue beacon by the causeway." }
			end
			dialogue(svc, record, lines)
		end
		svc:update(act)
		return true
	end
	local index = tonumber(spec.Action:sub(6))
	local sheep = index and act.Sheep[index]
	if not sheep or sheep.State ~= "Lost" or act.State == "Waiting" then
		return false
	end
	sheep.State, sheep.Escort = "Following", record
	sheep.Spec.Prompt.Enabled = false
	sheep.Label.Text = "Following " .. record.Player.DisplayName
	svc:participate(act, record)
	svc.Effects:FireAllClients("Bleat", { Position = act.Region.Center + sheep.Local })
	local found = 0
	for _, s in act.Sheep do
		found += if s.State == "Following" then 1 else 0
	end
	act.Progress = found
	svc:notice(record, string.format("Sheep rescued (%d/%d). It follows you.", found, SHEEP))
	if found == SHEEP then
		act.State = "Escort"
		dialogue(
			svc,
			record,
			{ "All three! You're a hero.", "Now lead us to the rescue beacon beside the causeway." }
		)
	end
	svc:update(act)
	return true
end
local function steer(region, member, goal, speed, dt)
	local delta = Vector3.new(goal.X - member.Local.X, 0, goal.Z - member.Local.Z)
	if delta.Magnitude < 0.6 then
		return 0
	end
	local dir = delta.Unit
	for _, angle in { 0, 0.7, -0.7, 1.4, -1.4 } do
		local d = CFrame.Angles(0, angle, 0):VectorToWorldSpace(dir)
		local nextLocal = member.Local + d * math.min(delta.Magnitude, speed * dt)
		local here = Common.height(region, member.Local.X, member.Local.Z)
		if
			Common.support(region, nextLocal.X, nextLocal.Z)
			and math.abs(Common.height(region, nextLocal.X, nextLocal.Z) - here) < 4
		then
			member.Local = nextLocal
			member.Yaw = math.atan2(-d.X, -d.Z)
			return 1
		end
	end
	return 0
end
local function threatened(region, member)
	local world = region.Center + member.Local
	local lists = { region.Ecology or {} }
	for _, act in region.Activities do
		if act.Creatures then
			table.insert(lists, act.Creatures)
		end
	end
	for _, list in lists do
		for _, c in list do
			if c.State ~= "Gone" and c.State ~= "Dying" and c.State ~= "Hidden" then
				local p = region.Center + c.Local
				if (Vector3.new(p.X, 0, p.Z) - Vector3.new(world.X, 0, world.Z)).Magnitude < 16 then
					return c
				end
			end
		end
	end
	return nil
end
function Flock.update(svc, act, dt, now)
	if act.Failed or act.Gone then
		return
	end
	local region = act.Region
	if act.Notify then
		for _, record in svc:inRegion(region) do
			svc:notice(record, act.Notify)
		end
		act.Notify = nil
		act.Progress = 0
		for _, s in act.Sheep do
			act.Progress += if s.State == "Following" then 1 else 0
		end
		if act.State == "Escort" and act.Progress < SHEEP then
			act.State = "Searching"
		end
		svc:update(act)
	end
	-- Order in the line: shepherd right behind the leader, sheep trailing.
	local members = { act.Shepherd, table.unpack(act.Sheep) }
	for i, member in members do
		if not Common.support(region, member.Local.X, member.Local.Z) then
			act.Failed = true
			svc:fail(
				act,
				(if member.Kind == "Sheep" then "A sheep" else "The shepherd")
					.. " fell with the deleted ground."
			)
			return
		end
		local gait, scared = 0, false
		if act.Done then
			member.State = "Celebrating"
		elseif member.State == "Following" then
			local record = member.Escort
			local root = record and Common.root(record)
			local threat = threatened(region, member)
			scared = threat ~= nil or now < (member.ScaredUntil or 0)
			if not root or record.State ~= "Alive" or record.Transit then
				member.Waiting = true
			else
				local spacing = if member.Kind == "Shepherd" then 4.5 else 6 + i * 2.5
				local side = if member.Kind == "Sheep" then (member.Index - 2) * 2.5 else 0
				local goal = root.Position
					- region.Center
					- root.CFrame.LookVector * spacing
					+ root.CFrame.RightVector * side
				local distance = Vector3.new(goal.X - member.Local.X, 0, goal.Z - member.Local.Z).Magnitude
				member.Waiting = distance > 70
				if not member.Waiting and not scared then
					gait = steer(region, member, goal, 21, dt)
				end
			end
			if member.Kind == "Shepherd" then
				act.Label.Text = if scared
					then "Lost Shepherd\nA monster! Help!"
					elseif member.Waiting then "Lost Shepherd\nWait for me!"
					else "Lost Shepherd\nFollowing "
						.. (member.Escort and member.Escort.Player.DisplayName or "")
			end
		end
		-- Place: shepherd rig (anchored root) or sheep figure, aligned to the ground.
		local ground = Common.height(region, member.Local.X, member.Local.Z)
		if member.Kind == "Shepherd" then
			local hop = if member.State == "Celebrating" then math.abs(math.sin(now * 6)) * 1.4 else 0
			local look = if scared then math.sin(now * 3) * 0.6 else 0
			local cf = CFrame.new(
				region.Center + Vector3.new(member.Local.X, ground + act.Rig.RootHeight + hop, member.Local.Z)
			) * CFrame.Angles(0, member.Yaw + look, 0)
			act.Rig.Root.CFrame = cf
			local key = if member.State == "Celebrating" then "Cheer" elseif gait > 0 then "Walk" else "Idle"
			Rig.play(act.Rig, key)
			Rig.pose(act.Rig, now, gait, scared)
			act.Spec.Part.CFrame = cf * CFrame.new(0, 1, 0)
		else
			local shake = if scared then CFrame.Angles(0, 0, math.sin(now * 40) * 0.06) else nil
			local hop = if member.State == "Celebrating"
				then CFrame.new(0, math.abs(math.sin(now * 7 + member.Index)) * 0.8, 0)
				else shake
			local root = CFrame.new(region.Center + Vector3.new(member.Local.X, ground, member.Local.Z))
				* CFrame.Angles(0, member.Yaw, 0)
			Animated.place(member.Figure, root, dt, gait, hop)
			member.Spec.Part.CFrame = root * CFrame.new(0, 2.5, 0)
			if gait == 0 and member.State == "Lost" and now >= (member.NextBleat or 0) then
				member.NextBleat = now + 6 + member.Index * 2
				svc.Effects:FireAllClients(
					"Bleat",
					{ Position = region.Center + member.Local + Vector3.new(0, 2, 0) }
				)
			end
		end
	end
	-- Completion: shepherd and every sheep gathered at the beacon.
	if act.State == "Escort" and not act.Done then
		local beacon = region.Beacon - region.Center
		local all = true
		for _, member in members do
			if
				member.State ~= "Following"
				or Vector3.new(beacon.X - member.Local.X, 0, beacon.Z - member.Local.Z).Magnitude > 15
			then
				all = false
			end
		end
		if all then
			act.State = "Saved"
			act.DoneAt = now
			act.Label.Text = "Lost Shepherd\nThank you, friend!"
			for record in act.Participants do
				dialogue(svc, record, {
					"We made it! My flock is safe because of you.",
					"Take this, and may the sky hold beneath your feet.",
				})
			end
			svc.Effects:FireAllClients("ChestOpened", { Position = region.Beacon + Vector3.new(0, 3, 0) })
			svc:complete(act, "The shepherd and his flock reached the rescue beacon!", "Rescuer")
		end
	end
	-- Graceful despawn after the celebration.
	if act.Done and act.DoneAt and now - act.DoneAt > 8 then
		local alpha = math.clamp((now - act.DoneAt - 8) / 2, 0, 1)
		for _, sheep in act.Sheep do
			Animated.fade(sheep.Figure, alpha)
		end
		for _, p in act.Rig.Model:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				p.Transparency = math.max(p.Transparency, alpha)
			end
		end
		if alpha >= 1 then
			act.Gone = true
			act.Rig.Model.Parent = nil
			for _, sheep in act.Sheep do
				sheep.Figure.Model.Parent = nil
				sheep.Spec.Prompt.Enabled = false
			end
			act.Spec.Prompt.Enabled = false
		end
	end
end
function Flock.status(act)
	if act.Done then
		return "Rescued"
	elseif act.Failed then
		return "Lost"
	elseif act.State == "Waiting" then
		return "Talk to the shepherd"
	elseif act.State == "Escort" then
		return "Escort to the beacon"
	end
	return string.format("%d/%d sheep found", act.Progress, SHEEP)
end
return Flock
