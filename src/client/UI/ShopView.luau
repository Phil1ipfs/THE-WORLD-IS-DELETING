--!nonstrict
-- Sky boutique page: balance header (coins, dragon trophies), category tabs, and a two-column
-- grid of item cards with a colour swatch preview, rarity, description and one clear action:
-- BUY / EQUIP / EQUIPPED / CLAIM / CRAFT / LOCKED. Purchases stay server-validated
-- (CosmeticService); the page re-renders when the server confirms.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.ShopConfig)
local Objectives = require(Shared.ObjectiveConfig)
local Dragon = require(Shared.DragonConfig)
local View = {}
local C = Color3.fromRGB
View.Tabs = {
	{ "All", "ALL" },
	{ "Trail", "TRAILS" },
	{ "Effect", "AURAS" },
	{ "Skin", "SKINS" },
	{ "Wings", "WINGS" },
	{ "Emote", "EMOTES" },
}
View.Rarity = {
	Common = C(176, 196, 214),
	Rare = C(110, 190, 255),
	Epic = C(200, 140, 255),
	Mythic = C(255, 110, 80),
}
local glyph = { Trail = "≋", Effect = "✦", Skin = "◆", Wings = "⋀⋀", Emote = "✋" }
local kindName = { Trail = "Trail", Effect = "Aura", Skin = "Silhouette", Wings = "Wings", Emote = "Emote" }
-- Action state for one item: text, enabled, primary.
function View.state(item, profile)
	profile = profile or {}
	local owned = profile.Owned and profile.Owned[item.Id]
	if owned and profile.Equipped == item.Id then
		return if item.Kind == "Emote" then "OWNED ✓" else "EQUIPPED ✓", false, false
	elseif owned then
		return if item.Kind == "Emote" then "OWNED ✓" else "EQUIP", item.Kind ~= "Emote", false
	elseif item.Drop then
		local cost = Dragon.Rewards.CraftCost
		local scales, shards = profile.DragonScales or 0, profile.Emberhearts or 0
		local ready = scales >= cost.DragonScales and shards >= cost.Emberhearts
		return string.format(
			"%s %d/%d SCALES · %d/%d SHARDS",
			if ready then "CRAFT" else "DROP ·",
			scales,
			cost.DragonScales,
			shards,
			cost.Emberhearts
		),
			ready,
			ready
	elseif item.Unlock then
		local achieved = profile.Achievements and profile.Achievements[item.Unlock]
		if achieved then
			return "CLAIM", true, true
		end
		local info = Objectives.Achievements[item.Unlock]
		return "LOCKED · " .. string.upper(info and info.Name or item.Unlock), false, false
	end
	local affordable = (profile.Coins or 0) >= item.Price
	return (if affordable then "BUY · " else "NEED ") .. item.Price .. " COINS", affordable, affordable
end
function View.render(ui)
	local K = ui.Kit
	local make, text, palette = K.Make, K.Text, K.Palette
	local body = ui.Body
	local profile = ui.Data and ui.Data.Profile or {}
	ui.ShopTab = ui.ShopTab or "All"
	-- Balance header.
	local header = make("Frame", {
		Name = "ShopHeader",
		Size = UDim2.new(1, -8, 0, 58),
		BackgroundColor3 = palette.Panel,
		LayoutOrder = 1,
	}, body)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, header)
	make("UIStroke", { Color = palette.Gold, Transparency = 0.6 }, header)
	local coins = text(
		header,
		"◉ " .. (profile.Coins or 0),
		22,
		UDim2.fromOffset(14, 6),
		UDim2.new(0.5, -14, 0, 28),
		palette.Gold
	)
	coins.Name, coins.Font = "Coins", Enum.Font.GothamBlack
	text(
		header,
		"COINS · cosmetics only",
		11,
		UDim2.fromOffset(14, 34),
		UDim2.new(0.5, -14, 0, 16),
		palette.Muted
	)
	local trophies = text(
		header,
		string.format("%d scales\n%d Emberheart shards", profile.DragonScales or 0, profile.Emberhearts or 0),
		12,
		UDim2.new(0.5, 0, 0, 8),
		UDim2.new(0.5, -14, 0, 40),
		C(255, 150, 110)
	)
	trophies.Name, trophies.TextXAlignment, trophies.Font =
		"Trophies", Enum.TextXAlignment.Right, Enum.Font.GothamBold
	-- Category tabs.
	local tabs = make(
		"Frame",
		{ Name = "ShopTabs", Size = UDim2.new(1, -8, 0, 30), BackgroundTransparency = 1, LayoutOrder = 2 },
		body
	)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabs)
	ui.ShopTabButtons = {}
	for i, tab in View.Tabs do
		local id = tab[1]
		local selected = ui.ShopTab == id
		local b = make("TextButton", {
			Name = "Tab_" .. id,
			Text = tab[2],
			Size = UDim2.new(1 / #View.Tabs, -4, 1, 0),
			BackgroundColor3 = if selected then palette.Gold else palette.Panel,
			TextColor3 = if selected then palette.Ink else palette.Text,
			Font = Enum.Font.GothamBlack,
			TextSize = 10,
			LayoutOrder = i,
			AutoButtonColor = true,
		}, tabs)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
		b.Activated:Connect(function()
			ui.ShopTab = id
			ui:refreshShop()
		end)
		ui.ShopTabButtons[id] = b
	end
	-- Item grid.
	local grid = make("Frame", {
		Name = "ShopGrid",
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, body)
	make("UIGridLayout", {
		CellSize = UDim2.new(0.5, -5, 0, 186),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	ui.ShopCards = {}
	local order = 0
	for _, item in Catalog do
		if ui.ShopTab == "All" or item.Kind == ui.ShopTab then
			order += 1
			local rarity = View.Rarity[item.Rarity or "Common"] or View.Rarity.Common
			local color = C(item.Color[1], item.Color[2], item.Color[3])
			local equipped = profile.Equipped == item.Id
			local card = make("Frame", {
				Name = "Item_" .. item.Id,
				BackgroundColor3 = palette.Panel,
				LayoutOrder = order,
			}, grid)
			make("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
			make("UIStroke", {
				Color = if equipped then palette.Gold else rarity,
				Transparency = if equipped then 0 else 0.45,
				Thickness = if equipped then 2 else 1,
			}, card)
			-- Swatch preview: the item's colour with its kind glyph.
			local swatch = make("Frame", {
				Name = "Swatch",
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 0, 56),
				BackgroundColor3 = color,
			}, card)
			make("UICorner", { CornerRadius = UDim.new(0, 10) }, swatch)
			make("UIGradient", {
				Color = ColorSequence.new(
					color:Lerp(Color3.new(1, 1, 1), 0.35),
					color:Lerp(Color3.new(0, 0, 0), 0.45)
				),
				Rotation = 35,
			}, swatch)
			local icon = text(
				swatch,
				glyph[item.Kind] or "✦",
				26,
				UDim2.new(),
				UDim2.fromScale(1, 1),
				C(255, 255, 255)
			)
			icon.TextXAlignment, icon.Font = Enum.TextXAlignment.Center, Enum.Font.GothamBlack
			icon.TextStrokeTransparency = 0.4
			if equipped then
				local badge = text(
					swatch,
					"EQUIPPED",
					10,
					UDim2.fromOffset(6, 4),
					UDim2.fromOffset(70, 14),
					palette.Ink
				)
				badge.BackgroundTransparency, badge.BackgroundColor3 = 0, palette.Gold
				badge.Font, badge.TextXAlignment = Enum.Font.GothamBlack, Enum.TextXAlignment.Center
				make("UICorner", { CornerRadius = UDim.new(0, 6) }, badge)
			end
			local name =
				text(card, item.Name, 14, UDim2.fromOffset(10, 68), UDim2.new(1, -20, 0, 18), palette.Text)
			name.Name, name.Font, name.TextTruncate =
				"ItemName", Enum.Font.GothamBold, Enum.TextTruncate.AtEnd
			local tag = text(
				card,
				string.upper(item.Rarity or "Common")
					.. " · "
					.. string.upper(kindName[item.Kind] or item.Kind),
				10,
				UDim2.fromOffset(10, 86),
				UDim2.new(1, -20, 0, 14),
				rarity
			)
			tag.Font = Enum.Font.GothamBlack
			local desc = text(
				card,
				item.Desc or "",
				11,
				UDim2.fromOffset(10, 102),
				UDim2.new(1, -20, 0, 40),
				palette.Muted
			)
			desc.TextWrapped, desc.TextYAlignment = true, Enum.TextYAlignment.Top
			local label, enabled, primary = View.state(item, profile)
			local action = K.Button(card, label, UDim2.new(0, 8, 1, -38), UDim2.new(1, -16, 0, 30), function()
				if enabled then
					ui.Request:FireServer("Purchase", item.Id)
					ui.ShopPending = item.Id
				end
			end, primary)
			action.Name = "Action"
			action.TextSize, action.TextWrapped = 10, true
			action.AutoButtonColor = enabled
			action.BackgroundTransparency = if enabled then 0 else 0.5
			ui.ShopCards[item.Id] = { Card = card, Action = action, Label = label, Enabled = enabled }
		end
	end
	-- Footer: unequip and emote.
	if profile.Equipped and profile.Equipped ~= "none" then
		local unequip = K.Button(body, "Unequip cosmetic", UDim2.new(), UDim2.new(1, -8, 0, 40), function()
			ui.Request:FireServer("Purchase", "none")
			ui.ShopPending = "none"
		end)
		unequip.Name, unequip.LayoutOrder, unequip.TextSize = "Unequip", 4, 14
	end
	if profile.Owned and profile.Owned.wave then
		local salute = K.Button(body, "Perform Sky Salute", UDim2.new(), UDim2.new(1, -8, 0, 40), function()
			ui.Request:FireServer("Emote")
		end)
		salute.LayoutOrder, salute.TextSize = 5, 14
	end
end
return View
