--!nonstrict
-- Realm Destroyer and Sky Balloon HUD: a top-centre boss bar (HP, exposed weak point, incoming
-- attack, raze timer and the fight-or-escape choice), the crossbow FIRE button, the balloon
-- boarding/flight card, and the Bestiary page. Everything reads server snapshots only.
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Dragon = require(Shared.DragonConfig)
local Balloon = require(Shared.BalloonConfig)
local Hud = {}
local RED, GOLD = Color3.fromRGB(255, 92, 72), Color3.fromRGB(255, 213, 141)
function Hud.build(ui)
	local K = ui.Kit
	local make, text, palette = K.Make, K.Text, K.Palette
	local function stroke(label)
		label.TextStrokeTransparency, label.TextStrokeColor3 = 0.25, Color3.fromRGB(8, 10, 20)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.Font = Enum.Font.GothamBlack
		return label
	end
	ui.Boss = make("Frame", {
		Name = "DragonBossBar",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(440, 78),
		BackgroundTransparency = 1,
	}, ui.Gui)
	ui.BossScale = make("UIScale", { Scale = 1 }, ui.Boss)
	ui.BossName = stroke(text(ui.Boss, "REALM DESTROYER", 15, UDim2.new(), UDim2.new(1, 0, 0, 18), RED))
	local track = make("Frame", {
		Position = UDim2.fromOffset(0, 21),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundColor3 = Color3.fromRGB(10, 12, 22),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, ui.Boss)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	make("UIStroke", { Color = RED, Transparency = 0.55, Thickness = 1 }, track)
	ui.BossFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(214, 40, 34),
		BorderSizePixel = 0,
	}, track)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, ui.BossFill)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 130, 70), Color3.fromRGB(170, 20, 24)),
		Rotation = 90,
	}, ui.BossFill)
	ui.BossHP = stroke(text(track, "", 12, UDim2.new(), UDim2.fromScale(1, 1), palette.Text))
	ui.BossInfo = stroke(text(ui.Boss, "", 13, UDim2.fromOffset(0, 40), UDim2.new(1, 0, 0, 36), GOLD))
	ui.BossInfo.TextWrapped = true
	-- Crossbow trigger (all platforms; keyboard G and controller R1 also fire).
	ui.FireButton = K.Button(ui.Gui, "FIRE", UDim2.new(1, -112, 1, -236), UDim2.fromOffset(96, 64), function()
		if ui.OnFire then
			ui.OnFire()
		end
	end, true)
	ui.FireButton.Name = "DragonbaneFire"
	ui.FireButton.TextSize = 13
	ui.FireButton.Visible = false
	-- Harpoon throw (keyboard T, controller L2).
	ui.ThrowButton = K.Button(
		ui.Gui,
		"THROW",
		UDim2.new(1, -112, 1, -308),
		UDim2.fromOffset(96, 64),
		function()
			if ui.OnThrow then
				ui.OnThrow()
			end
		end,
		true
	)
	ui.ThrowButton.Name = "DragonbaneThrow"
	ui.ThrowButton.TextSize = 13
	ui.ThrowButton.Visible = false
	-- Balloon boarding / flight card.
	ui.BalloonCard =
		stroke(text(ui.Gui, "", 16, UDim2.new(0.5, -210, 0, 92), UDim2.fromOffset(420, 40), GOLD))
	ui.BalloonCard.Name = "BalloonCard"
	ui.BalloonCard.TextWrapped = true
	ui.BalloonCard.Visible = false
end
local function clock(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
function Hud.update(ui, data)
	local dragon = data.Dragon or {}
	local alive = data.State == "Alive"
	local fighting = alive and dragon.Encounter == true
	ui.Boss.Visible = fighting
	ui.BossScale.Scale = if ui.CompactAdventure then 0.8 else 1
	if fighting then
		local ratio = math.clamp((dragon.HP or 0) / math.max(1, dragon.MaxHP or 1), 0, 1)
		TweenService:Create(ui.BossFill, TweenInfo.new(0.25), { Size = UDim2.fromScale(ratio, 1) }):Play()
		ui.BossHP.Text = string.format("%d / %d", dragon.HP or 0, dragon.MaxHP or 0)
		ui.BossName.Text = "REALM DESTROYER"
			.. (if (dragon.Tier or 1) > 1 then "  ·  FURY " .. dragon.Tier else "")
		local line
		if dragon.Exposed and dragon.Exposed ~= "" then
			line = "WEAK POINT EXPOSED: " .. string.upper(dragon.Exposed) .. " · STRIKE NOW"
			ui.BossInfo.TextColor3 = GOLD
		elseif dragon.Attack and dragon.Phase == "Windup" then
			line = string.upper(dragon.Attack) .. " INCOMING · LEAVE THE GLOWING ZONE"
			ui.BossInfo.TextColor3 = RED
		else
			line = "Wait for a glowing weak point · use the ballista and crystal cannon"
			ui.BossInfo.TextColor3 = GOLD
		end
		ui.BossInfo.Text = line
			.. "\nREALM FALLS IN "
			.. clock(dragon.RazeIn)
			.. " · FIGHT, OR BOARD THE SKY BALLOON"
	end
	ui.FireButton.Visible = alive and dragon.Crossbow ~= nil and not ui.Panel.Visible
	if dragon.Crossbow then
		ui.FireButton.Text = "FIRE · G / R1\n" .. dragon.Crossbow .. " bolts"
		ui.FireButton.AutoButtonColor = dragon.Crossbow > 0
	end
	ui.ThrowButton.Visible = alive and dragon.Harpoons ~= nil and not ui.Panel.Visible
	if dragon.Harpoons then
		ui.ThrowButton.Text = "THROW · T / L2\n" .. dragon.Harpoons .. " harpoons"
		ui.ThrowButton.AutoButtonColor = dragon.Harpoons > 0
	end
	local ride = alive and data.Balloon or nil
	ui.BalloonCard.Visible = ride ~= nil
	if ride then
		ui.BalloonCard.Text = if ride.Phase == "Boarding"
			then string.format(
				"SKY BALLOON · DEPARTING IN %d · %d/%d ABOARD",
				ride.Departs or 0,
				ride.Riders or 1,
				Balloon.Capacity
			)
			else string.format(
				"SKY BALLOON · ASCENDING TO THE NEXT REALM · %d%%",
				math.floor((ride.Progress or 0) * 100)
			)
	end
end
-- Bestiary page (persistent discovery progress for the Realm Destroyer and catalogued creatures).
function Hud.page(ui, paragraph)
	local profile = ui.Data and ui.Data.Profile or {}
	local palette = ui.Kit.Palette
	local entry = Dragon.Bestiary
	local stage = profile.Bestiary and profile.Bestiary.RealmDestroyer or 0
	local pips = ""
	for i = 1, #Dragon.Discovery do
		pips ..= if i <= stage then "◆ " else "◇ "
	end
	paragraph(string.upper(entry.Name) .. "\n" .. entry.Category .. "  ·  " .. entry.Rarity, 52, RED)
	paragraph(
		"DISCOVERY "
			.. stage
			.. "/"
			.. #Dragon.Discovery
			.. "  "
			.. pips
			.. "\n"
			.. (if stage > 0 then Dragon.Discovery[stage] else "Not yet sighted. Climb higher."),
		46,
		GOLD
	)
	paragraph(if stage > 0 then entry.Lore else "???", 48, palette.Muted)
	local function list(title, items, height)
		paragraph(title .. "\n• " .. table.concat(items, "\n• "), height)
	end
	list("ENCOUNTERS", entry.Realms, 104)
	if stage >= 2 then
		list("ABILITIES", entry.Abilities, 150)
	else
		paragraph("ABILITIES\nSurvive one of its raids to learn more.", 46, palette.Muted)
	end
	if stage >= 3 then
		list("WEAK POINTS", entry.WeakPoints, 112)
	else
		paragraph(
			"WEAK POINTS\nFace it in battle to learn them. Weak points glow mid-attack.",
			46,
			palette.Muted
		)
	end
	list("REWARDS", entry.RewardText, 104)
	paragraph(
		string.format(
			"Your trophies: %d Dragon Scales · %d Emberheart Shards · repelled %d time%s",
			profile.DragonScales or 0,
			profile.Emberhearts or 0,
			profile.DragonKills or 0,
			if (profile.DragonKills or 0) == 1 then "" else "s"
		),
		44,
		GOLD
	)
	local catalogued = 0
	for id in profile.Bestiary or {} do
		if id ~= Dragon.Id then
			catalogued += 1
		end
	end
	paragraph(
		"Realm creatures catalogued: " .. catalogued .. " (defeat a creature to record it)",
		40,
		palette.Muted
	)
end
return Hud
