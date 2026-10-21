--!nonstrict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Biomes = require(Shared.BiomeConfig)
local Items = require(Shared.ItemConfig)
local Seal = require(Shared.SealConfig)
local Realms = require(Shared.RealmConfig)
local DragonHud = require(script.Parent.DragonHud)
local ShopView = require(script.Parent.ShopView)
local UI = {}
UI.__index = UI
local palette = {
	Ink = Color3.fromRGB(17, 22, 40),
	Panel = Color3.fromRGB(29, 36, 57),
	Muted = Color3.fromRGB(168, 182, 207),
	Text = Color3.fromRGB(239, 243, 255),
	Gold = Color3.fromRGB(255, 213, 141),
	Blue = Color3.fromRGB(131, 218, 247),
	Red = Color3.fromRGB(255, 122, 154),
}
local function make(class, properties, parent)
	local instance = Instance.new(class)
	for key, value in properties do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end
local function text(parent, value, size, position, dimensions, color)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		Font = Enum.Font.GothamMedium,
		TextColor3 = color or palette.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = position,
		Size = dimensions,
	}, parent)
end
local function decorate(panel)
	make("UICorner", { CornerRadius = UDim.new(0, 18) }, panel)
	make("UIStroke", { Color = palette.Blue, Transparency = 0.75, Thickness = 1 }, panel)
	make("UIGradient", { Color = ColorSequence.new(palette.Panel, palette.Ink), Rotation = 80 }, panel)
end
local function button(parent, value, position, size, callback, primary)
	local b = make("TextButton", {
		Text = value,
		Position = position,
		Size = size,
		BackgroundColor3 = if primary then palette.Gold else palette.Panel,
		TextColor3 = if primary then palette.Ink else palette.Text,
		TextSize = 17,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = true,
		Selectable = true,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, b)
	local stroke = make("UIStroke", { Color = palette.Blue, Transparency = 0.8 }, b)
	-- Hover lifts the button and brightens its edge; press squashes it; click pulses.
	local scale = make("UIScale", { Name = "Feedback", Scale = 1 }, b)
	local function to(target, edge)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = target }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = edge }):Play()
	end
	pcall(function()
		b.MouseEnter:Connect(function()
			to(1.03, 0.35)
		end)
		b.MouseLeave:Connect(function()
			to(1, 0.8)
		end)
		b.MouseButton1Down:Connect(function()
			to(0.96, 0.2)
		end)
		b.MouseButton1Up:Connect(function()
			to(1.03, 0.35)
		end)
	end)
	b.Activated:Connect(function(...)
		scale.Scale = 0.95
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		callback(...)
	end)
	return b
end
-- Shared widget kit for companion HUD modules (DragonHud).
UI.Kit = { Make = make, Text = text, Button = button, Palette = palette }
function UI.new(request, settings)
	local self = setmetatable({
		Request = request,
		Settings = settings,
		AbilityButtons = {},
		State = nil,
		Page = "Menu",
		Data = nil,
	}, UI)
	self.Gui = make("ScreenGui", {
		Name = "FloatingRealmsUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	-- Main menu: full-screen layer over the cinematic sanctuary camera. A soft left-side shade
	-- keeps text readable without boxing the scene in; content sits in one fading CanvasGroup.
	self.Menu = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, self.Gui)
	self.MenuShade = make("Frame", {
		Size = UDim2.fromScale(0.62, 1),
		BackgroundColor3 = Color3.fromRGB(8, 12, 26),
		BorderSizePixel = 0,
	}, self.Menu)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.55, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, self.MenuShade)
	self.MenuContent = make("CanvasGroup", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 72, 0.5, 0),
		Size = UDim2.fromOffset(440, 540),
		BackgroundTransparency = 1,
	}, self.Menu)
	self.MenuScale = make("UIScale", { Scale = 1 }, self.MenuContent)
	local kicker = text(
		self.MenuContent,
		"FLOATING REALMS  ·  SURVIVAL ADVENTURE",
		13,
		UDim2.new(),
		UDim2.new(1, 0, 0, 18),
		palette.Blue
	)
	kicker.Font = Enum.Font.GothamBold
	self.TitleAccent = make("Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.fromOffset(72, 3),
		BackgroundColor3 = palette.Gold,
		BorderSizePixel = 0,
	}, self.MenuContent)
	make("UIGradient", {
		Color = ColorSequence.new(palette.Gold, Color3.fromRGB(196, 120, 255)),
	}, self.TitleAccent)
	self.TitleLines = {}
	for i, line in { "THE WORLD", "IS DELETING" } do
		local label = text(
			self.MenuContent,
			line,
			58,
			UDim2.fromOffset(0, 36 + (i - 1) * 62),
			UDim2.new(1, 0, 0, 64),
			Color3.new(1, 1, 1)
		)
		label.Font = Enum.Font.GothamBlack
		make("UIGradient", {
			Color = if i == 1
				then ColorSequence.new(Color3.fromRGB(255, 255, 255), palette.Gold)
				else ColorSequence.new(palette.Gold, Color3.fromRGB(205, 120, 255)),
			Rotation = 90,
		}, label)
		make("UIStroke", {
			Color = if i == 1 then palette.Gold else Color3.fromRGB(190, 110, 255),
			Thickness = 2,
			Transparency = 0.7,
		}, label)
		self.TitleLines[i] = label
	end
	-- "Deletion" accent: a violet scan bar that sweeps across the second title line.
	self.TitleGlitch = make("Frame", {
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.fromOffset(4, 52),
		BackgroundColor3 = Color3.fromRGB(205, 120, 255),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, self.MenuContent)
	self.Tagline = text(
		self.MenuContent,
		"Climb beyond the clouds. Explore, rescue and survive before the world below disappears.",
		16,
		UDim2.fromOffset(0, 168),
		UDim2.new(1, -20, 0, 44),
		palette.Muted
	)
	self.Tagline.TextWrapped = true
	self.Play = button(
		self.MenuContent,
		"BEGIN ASCENT",
		UDim2.fromOffset(0, 230),
		UDim2.new(1, 0, 0, 70),
		function()
			if self.State == "Lobby" and self.Data and self.Data.Ready then
				request:FireServer("Play")
			end
		end,
		true
	)
	self.Play.TextSize, self.Play.Font = 24, Enum.Font.GothamBlack
	self.Play:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 16)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 226, 160), Color3.fromRGB(255, 176, 88)),
		Rotation = 90,
	}, self.Play)
	self.PlayShine = make("Frame", {
		Size = UDim2.new(0, 60, 1, 0),
		Position = UDim2.fromScale(-0.2, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Rotation = 12,
	}, self.Play)
	self.Play.ClipsDescendants = true
	self.PlayHint = text(
		self.MenuContent,
		"5-second queue  ·  solo or with friends",
		12,
		UDim2.fromOffset(0, 306),
		UDim2.new(1, 0, 0, 18),
		palette.Muted
	)
	self.PlayHint.TextXAlignment = Enum.TextXAlignment.Center
	local items = {
		{ "How to Play", "Help", "?", "Controls, realms & tips" },
		{ "Settings", "Settings", "⚙", "Audio, camera, detail" },
		{ "Cosmetic Shop", "Shop", "💎", "Trails, auras & unlocks" },
		{ "Leaderboards", "Leaderboard", "🏆", "Highest ascenders" },
		{ "Bestiary", "Bestiary", "🐉", "Realm Destroyer & creatures" },
	}
	self.MenuCards = {}
	for i, item in items do
		local column, rowIndex = (i - 1) % 2, math.floor((i - 1) / 2)
		local card = button(
			self.MenuContent,
			"",
			UDim2.fromOffset(column * 226, 336 + rowIndex * 58),
			UDim2.fromOffset(214, 52),
			function()
				self:open(item[2])
				if item[2] == "Leaderboard" then
					request:FireServer("Leaderboard")
				end
			end
		)
		card.Name = item[2] .. "Card"
		card:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 14)
		make("UIGradient", {
			Color = ColorSequence.new(palette.Panel:Lerp(palette.Blue, 0.12), palette.Ink),
			Rotation = 90,
		}, card)
		local icon = text(card, item[3], 24, UDim2.fromOffset(14, 0), UDim2.new(0, 30, 1, 0), palette.Gold)
		icon.Font, icon.TextXAlignment = Enum.Font.GothamBlack, Enum.TextXAlignment.Center
		local title = text(card, item[1], 16, UDim2.fromOffset(52, 6), UDim2.new(1, -60, 0, 22))
		title.Font = Enum.Font.GothamBold
		text(card, item[4], 12, UDim2.fromOffset(52, 28), UDim2.new(1, -60, 0, 18), palette.Muted)
		self.MenuCards[item[2]] = card
	end
	self.StatusDot = make("Frame", {
		Position = UDim2.fromOffset(0, 516),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = palette.Gold,
		BorderSizePixel = 0,
	}, self.MenuContent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, self.StatusDot)
	self.Status = text(
		self.MenuContent,
		"Connecting to the realm…",
		13,
		UDim2.fromOffset(16, 509),
		UDim2.new(1, -16, 0, 22),
		palette.Muted
	)
	self.Status.TextWrapped = true
	self.Version = text(
		self.Menu,
		"v" .. Config.Version,
		11,
		UDim2.new(1, -96, 1, -28),
		UDim2.fromOffset(84, 18),
		palette.Muted
	)
	self.Version.TextXAlignment = Enum.TextXAlignment.Right
	-- Queue countdown card: server-synchronized 5 → 4 → 3 → 2 → 1 → START.
	self.Queue = make("CanvasGroup", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.7, 0.5),
		Size = UDim2.fromOffset(320, 250),
		BackgroundColor3 = palette.Ink,
		BackgroundTransparency = 0.12,
		ZIndex = 4,
	}, self.Gui)
	decorate(self.Queue)
	-- A UIGradient on a CanvasGroup tints every child (it darkened the countdown text and
	-- Cancel button); the card uses a solid fill instead.
	self.Queue:FindFirstChildOfClass("UIGradient"):Destroy()
	self.Queue.BackgroundColor3 = Color3.fromRGB(16, 21, 40)
	self.Queue:FindFirstChildOfClass("UIStroke").Color = palette.Gold
	self.Queue:FindFirstChildOfClass("UIStroke").Transparency = 0.4
	self.QueueScale = make("UIScale", { Scale = 1 }, self.Queue)
	self.QueueTitle = text(
		self.Queue,
		"ASCENT BEGINS IN",
		14,
		UDim2.fromOffset(0, 18),
		UDim2.new(1, 0, 0, 20),
		palette.Blue
	)
	self.QueueTitle.Font, self.QueueTitle.TextXAlignment = Enum.Font.GothamBlack, Enum.TextXAlignment.Center
	self.QueueNumber =
		text(self.Queue, "5", 92, UDim2.fromOffset(0, 40), UDim2.new(1, 0, 0, 100), palette.Gold)
	self.QueueNumber.Font, self.QueueNumber.TextXAlignment = Enum.Font.GothamBlack, Enum.TextXAlignment.Center
	self.QueueNumberScale = make("UIScale", { Scale = 1 }, self.QueueNumber)
	self.QueueBar = make("Frame", {
		Position = UDim2.fromOffset(30, 148),
		Size = UDim2.new(1, -60, 0, 6),
		BackgroundColor3 = palette.Panel,
		BorderSizePixel = 0,
	}, self.Queue)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, self.QueueBar)
	self.QueueFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = palette.Gold,
		BorderSizePixel = 0,
	}, self.QueueBar)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, self.QueueFill)
	self.QueueInfo =
		text(self.Queue, "", 13, UDim2.fromOffset(16, 162), UDim2.new(1, -32, 0, 30), palette.Muted)
	self.QueueInfo.TextXAlignment, self.QueueInfo.TextWrapped = Enum.TextXAlignment.Center, true
	self.QueueCancel = button(
		self.Queue,
		"Cancel",
		UDim2.new(0.5, -70, 0, 198),
		UDim2.fromOffset(140, 36),
		function()
			if self.State == "Queued" then
				request:FireServer("Cancel")
			end
		end
	)
	self.QueueCancel.TextSize = 14
	-- Full-screen fade used for menu → match transitions.
	self.Fade = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 6, 14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 30,
		Visible = false,
	}, self.Gui)
	self.FadeLabel = text(self.Fade, "", 18, UDim2.fromScale(0, 0.5), UDim2.new(1, 0, 0, 30), palette.Gold)
	self.FadeLabel.TextXAlignment, self.FadeLabel.ZIndex = Enum.TextXAlignment.Center, 31
	self.FadeLabel.Font = Enum.Font.GothamBlack
	self.Panel = make("Frame", {
		ZIndex = 5,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 510),
		BackgroundColor3 = palette.Ink,
	}, self.Gui)
	decorate(self.Panel)
	self.PanelScale = make("UIScale", { Scale = 1 }, self.Panel)
	self.PanelTitle =
		text(self.Panel, "", 26, UDim2.fromOffset(26, 22), UDim2.new(1, -88, 0, 40), palette.Gold)
	button(self.Panel, "×", UDim2.new(1, -66, 0, 20), UDim2.fromOffset(42, 42), function()
		if self.State == "Eliminated" then
			self.Request:FireServer("Lobby")
		end
		self:open("Menu")
	end)
	self.Body = make("ScrollingFrame", {
		Position = UDim2.fromOffset(24, 78),
		Size = UDim2.new(1, -48, 1, -102),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, self.Panel)
	-- Floating HUD (right side, below the Roblox player list): no container panel; every
	-- element is text with strokes or a compact bar, laid out on a transparent frame.
	self.Hud = make("Frame", {
		Visible = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0.3, 0),
		Size = UDim2.fromOffset(250, 214),
		BackgroundTransparency = 1,
	}, self.Gui)
	self.HudScale = make("UIScale", { Scale = 1 }, self.Hud)
	local function hudText(value, size, y, height, color, font, align)
		local label = text(self.Hud, value, size, UDim2.fromOffset(0, y), UDim2.new(1, 0, 0, height), color)
		label.Font = font or Enum.Font.GothamBold
		label.TextXAlignment = align or Enum.TextXAlignment.Right
		label.TextStrokeTransparency, label.TextStrokeColor3 = 0.35, Color3.fromRGB(8, 10, 20)
		return label
	end
	self.Biome = hudText("HAVENWOOD REACH", 13, 0, 18, palette.Blue, Enum.Font.GothamBlack)
	self.Biome.TextTruncate = Enum.TextTruncate.AtEnd
	self.Altitude = hudText("0m ALTITUDE", 22, 17, 28, palette.Gold, Enum.Font.GothamBlack)
	-- Retired readouts kept hidden (developer diagnostics only).
	self.Best = hudText("", 11, 0, 1, palette.Muted)
	self.Best.Visible = false
	self.Time = hudText("", 11, 0, 1, palette.Muted)
	self.Time.Visible = false
	local function barLabel(caption, y)
		return hudText(caption, 11, y, 16, palette.Muted, Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
	end
	local function bar(y)
		local track = make("Frame", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = Color3.fromRGB(10, 12, 22),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
		}, self.Hud)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
		make("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.82, Thickness = 1 }, track)
		local fill = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(80, 230, 100),
			BorderSizePixel = 0,
		}, track)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
		make("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 205)),
			Rotation = 90,
		}, fill)
		return track, fill
	end
	barLabel("HEALTH", 50)
	self.Health = hudText("100/100", 13, 49, 17, palette.Text, Enum.Font.GothamBlack)
	self.HealthBar, self.HealthFill = bar(68)
	self.ShieldFill = make("Frame", {
		Size = UDim2.fromScale(0, 0.35),
		Position = UDim2.fromScale(0, 0.65),
		BackgroundColor3 = Color3.fromRGB(130, 220, 255),
		BorderSizePixel = 0,
	}, self.HealthBar)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, self.ShieldFill)
	barLabel("DELETION", 100)
	self.Distance = hudText("120m BELOW", 13, 99, 17, palette.Text, Enum.Font.GothamBlack)
	self.DeletionBar, self.DeletionFill = bar(118)
	self.DeletionFill.BackgroundColor3 = Color3.fromRGB(60, 220, 255)
	-- Current primary objective (optional activities live in the collapsible tracker below).
	self.ObjectiveIcon = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0, 160),
		Size = UDim2.fromOffset(8, 8),
		Rotation = 45,
		BackgroundColor3 = palette.Gold,
		BorderSizePixel = 0,
	}, self.Hud)
	self.ObjectiveCaption = hudText("CURRENT OBJECTIVE", 11, 152, 16, palette.Gold, Enum.Font.GothamBlack)
	self.ObjectiveCaption.Size = UDim2.new(1, -16, 0, 16)
	self.Objective = hudText("Climb to the next realm", 15, 170, 40, palette.Text, Enum.Font.GothamBlack)
	self.Objective.TextWrapped = true
	self.Objective.TextYAlignment = Enum.TextYAlignment.Top
	self.Danger = text(self.Gui, "", 16, UDim2.new(0.05, 0, 0, 128), UDim2.new(0.9, 0, 0, 32), palette.Red)
	self.Danger.TextXAlignment = Enum.TextXAlignment.Center
	self.Danger.TextWrapped = true
	self.Danger.Font = Enum.Font.GothamBlack
	self.Danger.TextStrokeTransparency, self.Danger.TextStrokeColor3 = 0.2, Color3.fromRGB(8, 10, 20)
	self.Danger.BackgroundColor3 = palette.Ink
	self.EventMeter = make("Frame", {
		Position = UDim2.new(0.05, 0, 0, 161),
		Size = UDim2.new(0.9, 0, 0, 3),
		BackgroundColor3 = palette.Blue,
		BorderSizePixel = 0,
		Visible = false,
	}, self.Gui)
	-- Realm title card shown when entering a new realm or region.
	self.Banner = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(520, 120),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 4,
	}, self.Gui)
	self.BannerTitle = text(self.Banner, "", 38, UDim2.new(), UDim2.new(1, 0, 0, 48), palette.Gold)
	self.BannerTitle.Font, self.BannerTitle.TextXAlignment = Enum.Font.GothamBlack, Enum.TextXAlignment.Center
	self.BannerTitle.TextStrokeTransparency = 0.4
	self.BannerSub = text(self.Banner, "", 18, UDim2.fromOffset(0, 48), UDim2.new(1, 0, 0, 24), palette.Text)
	self.BannerSub.TextXAlignment, self.BannerSub.TextStrokeTransparency = Enum.TextXAlignment.Center, 0.5
	self.BannerLore =
		text(self.Banner, "", 14, UDim2.fromOffset(0, 76), UDim2.new(1, 0, 0, 40), palette.Muted)
	self.BannerLore.TextXAlignment, self.BannerLore.TextWrapped = Enum.TextXAlignment.Center, true
	self.BannerLore.TextStrokeTransparency = 0.6
	self.BannerScale = make("UIScale", { Scale = 1 }, self.Banner)
	-- Objective tracker (right side): realm objectives, live event, perks and relics.
	self.Tracker = make("Frame", {
		Visible = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 176),
		Size = UDim2.fromOffset(250, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = palette.Ink,
		BackgroundTransparency = 1, -- Floating: no card behind the objective list.
	}, self.Gui)
	-- No panel; rows use text strokes for readability over the world.
	make("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, self.Tracker)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, self.Tracker)
	self.TrackerScale = make("UIScale", { Scale = 1 }, self.Tracker)
	self.TrackerHeader = make("TextButton", {
		Text = "OPTIONAL ACTIVITIES  [-]",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		TextColor3 = palette.Gold,
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 0,
	}, self.Tracker)
	self.TrackerHeader.Activated:Connect(function()
		self.TrackerCollapsed = not self.TrackerCollapsed
		if self.Data then
			self:objectives(self.Data)
		end
	end)
	self.TrackerRows = {}
	for i = 1, 11 do
		local row = text(self.Tracker, "", 12, UDim2.new(), UDim2.new(1, 0, 0, 16), palette.Text)
		row.LayoutOrder, row.TextWrapped = i, true
		row.TextXAlignment = Enum.TextXAlignment.Right
		row.TextStrokeTransparency, row.TextStrokeColor3 = 0.35, Color3.fromRGB(8, 10, 20)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.RichText = true
		self.TrackerRows[i] = row
	end
	-- Notification feed: rewards, objectives, events. Newest on top, fades out.
	self.Feed = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -150),
		Size = UDim2.fromOffset(320, 120),
		BackgroundTransparency = 1,
	}, self.Gui)
	make("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, self.Feed)
	self.FeedCount = 0
	-- Achievement popup.
	self.Achievement = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 250),
		Size = UDim2.fromOffset(340, 64),
		BackgroundColor3 = palette.Ink,
		Visible = false,
		ZIndex = 6,
	}, self.Gui)
	decorate(self.Achievement)
	self.Achievement:FindFirstChildOfClass("UIStroke").Color = palette.Gold
	self.Achievement:FindFirstChildOfClass("UIStroke").Transparency = 0.2
	self.AchievementTitle =
		text(self.Achievement, "", 16, UDim2.fromOffset(16, 8), UDim2.new(1, -32, 0, 22), palette.Gold)
	self.AchievementTitle.Font, self.AchievementTitle.ZIndex = Enum.Font.GothamBlack, 6
	self.AchievementText =
		text(self.Achievement, "", 12, UDim2.fromOffset(16, 32), UDim2.new(1, -32, 0, 24), palette.Muted)
	self.AchievementText.TextWrapped, self.AchievementText.ZIndex = true, 6
	-- Damage / healing screen flash.
	self.Flash = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 60, 70),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Active = false,
	}, self.Gui)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}, self.Flash)
	self.CooldownTotals = {}
	self.Adventure =
		text(self.Gui, "", 13, UDim2.new(0.05, 0, 0, 166), UDim2.new(0.9, 0, 0, 76), palette.Gold)
	self.Adventure.TextWrapped = true
	self.Adventure.TextXAlignment = Enum.TextXAlignment.Left
	self.Controls = make("Frame", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(340, 104),
		BackgroundTransparency = 1,
	}, self.Gui)
	self.ItemButtons = {}
	for i, kind in { "Herb", "Crystal", "Timber" } do
		local itemKind = kind
		self.ItemButtons[kind] = button(
			self.Controls,
			kind,
			UDim2.fromOffset((i - 1) * 114, 0),
			UDim2.fromOffset(106, 38),
			function()
				request:FireServer("UseItem", itemKind)
			end
		)
		self.ItemButtons[kind].TextSize = 12
	end
	-- Reuse the item-row footprint near the altar, including on short mobile screens.
	self.GlyphButtons = {}
	for i, glyph in Seal.Order do
		local key = glyph
		local b = button(
			self.Controls,
			glyph,
			UDim2.fromOffset((i - 1) * 114, 0),
			UDim2.fromOffset(106, 38),
			function()
				if self.State == "Alive" and not self.Panel.Visible then
					request:FireServer("UseGlyph", key)
				end
			end
		)
		b.TextSize, b.Visible = 12, false
		b.TextColor3 = Color3.fromRGB(table.unpack(Seal.Keys[glyph].Color))
		self.GlyphButtons[glyph] = b
	end
	self.Interact = button(
		self.Gui,
		"E / X · Collect",
		UDim2.new(0.5, 0, 1, -136),
		UDim2.fromOffset(260, 36),
		function()
			if self.OnInteract then
				self.OnInteract()
			end
		end,
		true
	)
	self.Interact.AnchorPoint = Vector2.new(0.5, 1)
	self.Interact.TextSize = 13
	self.Interact.Visible = false
	local labels =
		{ { "Dash", "Q / R2" }, { "DoubleJump", "Z / Y" }, { "Shield", "R / B" }, { "Glide", "F / L1" } }
	for i, entry in labels do
		local abilityName = entry[1]
		self.AbilityButtons[abilityName] = button(
			self.Controls,
			abilityName .. "\n" .. entry[2],
			UDim2.fromOffset((i - 1) * 85, 46),
			UDim2.fromOffset(78, 58),
			function()
				request:FireServer("Ability", abilityName)
			end
		)
		self.AbilityButtons[abilityName].TextSize = 12
		self.AbilityButtons[abilityName]:SetAttribute("Shortcut", entry[2])
	end
	-- Cooldown sweep overlays and resource color chips.
	local itemColors = {
		Herb = Color3.fromRGB(120, 220, 110),
		Crystal = Color3.fromRGB(139, 210, 255),
		Timber = Color3.fromRGB(196, 150, 96),
	}
	local function overlay(b)
		local shade = make("Frame", {
			Name = "Cooldown",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color3.fromRGB(8, 10, 20),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, b)
		make("UICorner", { CornerRadius = UDim.new(0, 12) }, shade)
		b.ZIndex = 1
		return shade
	end
	self.CooldownShades = {}
	for name, b in self.AbilityButtons do
		self.CooldownShades[name] = overlay(b)
	end
	for kind, b in self.ItemButtons do
		self.CooldownShades[kind] = overlay(b)
		local chip = make("Frame", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = itemColors[kind],
			BorderSizePixel = 0,
		}, b)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, chip)
		b:FindFirstChildOfClass("UIStroke").Color = itemColors[kind]
		b:FindFirstChildOfClass("UIStroke").Transparency = 0.45
	end
	self.Pause = button(self.Gui, "☰", UDim2.fromOffset(16, 66), UDim2.fromOffset(44, 42), function()
		self:open("Settings")
	end)
	self.Pause.Visible = false
	self.Spectator = make("Frame", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(340, 100),
		BackgroundColor3 = palette.Ink,
	}, self.Gui)
	decorate(self.Spectator)
	self.SpectatorName = text(
		self.Spectator,
		"Following the ascent",
		14,
		UDim2.fromOffset(16, 10),
		UDim2.new(1, -32, 0, 24),
		palette.Blue
	)
	button(self.Spectator, "Next player", UDim2.fromOffset(12, 46), UDim2.fromOffset(150, 40), function()
		if self.OnNextSpectator then
			self.OnNextSpectator()
		end
	end)
	button(self.Spectator, "Sanctuary", UDim2.fromOffset(176, 46), UDim2.fromOffset(150, 40), function()
		request:FireServer("Lobby")
	end)
	self.Toast = text(self.Gui, "", 16, UDim2.fromScale(0.05, 0.75), UDim2.new(0.9, 0, 0, 36), palette.Gold)
	self.Toast.TextXAlignment = Enum.TextXAlignment.Center
	self.Toast.TextWrapped = true
	self.Toast.ZIndex = 3
	DragonHud.build(self)
	local function resize()
		local viewport = workspace.CurrentCamera.ViewportSize
		self.CompactAdventure = viewport.Y < 500
		self.Adventure.Size = UDim2.new(0.9, 0, 0, if self.CompactAdventure then 42 else 76)
		self.Adventure.TextSize = if self.CompactAdventure then 11 else 13
		local scale = math.min(1, (viewport.X - 24) / 420, (viewport.Y - 32) / 510)
		self.PanelScale.Scale = scale
		-- Menu: left hero column on wide screens, centered with a full shade on narrow/portrait ones.
		self.MenuNarrow = viewport.X < 760
		self.MenuScale.Scale = math.min(1, (viewport.X - 24) / 440, (viewport.Y - 24) / 550)
		self.MenuContent.AnchorPoint = if self.MenuNarrow then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5)
		self.MenuContent.Position = if self.MenuNarrow
			then UDim2.fromScale(0.5, 0.5)
			else UDim2.new(0, math.clamp(viewport.X * 0.06, 24, 96), 0.5, 0)
		self.MenuShade.Size = UDim2.fromScale(if self.MenuNarrow then 1 else 0.62, 1)
		self.Queue.Position = UDim2.fromScale(if self.MenuNarrow then 0.5 else 0.72, 0.5)
		self.QueueScale.Scale = math.min(1, (viewport.X - 24) / 320, (viewport.Y - 24) / 250)
		self.Controls.Size = UDim2.fromOffset(math.min(340, viewport.X - 20), 104)
		local controlScale = self.Controls:FindFirstChildOfClass("UIScale")
			or make("UIScale", {}, self.Controls)
		controlScale.Scale = math.min(1, (viewport.X - 30) / 340)
		local bottom = if UserInputService.TouchEnabled and not self.CompactAdventure then 116 else 16
		self.Controls.Position = UDim2.new(0.5, 0, 1, -bottom)
		self.Interact.Position = UDim2.new(0.5, 0, 1, -bottom - 112)
		self.Interact.Size = UDim2.fromOffset(math.min(260, viewport.X - 32), 36)
		self.Toast.Position = UDim2.new(0.05, 0, 0, if self.CompactAdventure then 212 else 250)
		self.Toast.Size = UDim2.new(if self.CompactAdventure then 0.27 else 0.9, 0, 0, 40)
		self.Toast.TextSize = if self.CompactAdventure then 12 else 15
		-- Tracker shrinks and collapses on short or narrow screens; feed sits above the controls.
		local narrow = viewport.X < 900
		self.TrackerScale.Scale = if self.CompactAdventure or narrow then 0.82 else 1
		-- Floating HUD under the player list; the optional-activities tracker sits right below it.
		local hudScale = if self.CompactAdventure then 0.72 elseif narrow then 0.86 else 1
		self.HudScale.Scale = hudScale
		local hudTop = if self.CompactAdventure then 8 else math.floor(viewport.Y * 0.3)
		self.Hud.Position = UDim2.new(1, -18, 0, hudTop)
		self.Tracker.AnchorPoint = Vector2.new(1, 0)
		self.Tracker.Position = UDim2.new(1, -18, 0, hudTop + math.floor(222 * hudScale))
		self.TrackerCollapsed = if self.TrackerCollapsed == nil then true else self.TrackerCollapsed
		self.Adventure.Size =
			UDim2.new(if narrow then 0.9 else 0.6, 0, 0, if self.CompactAdventure then 42 else 76)
		self.Feed.Position = UDim2.new(0, 12, 1, -bottom - 120)
		self.BannerScale.Scale = math.min(1, (viewport.X - 24) / 520)
		self.Achievement.Position = UDim2.new(0.5, 0, 0, if self.CompactAdventure then 60 else 250)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	resize()
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = self.Play
	end
	return self
end
function UI:notice(message)
	self.Toast.Text = message
	local token = os.clock()
	self.ToastToken = token
	task.delay(3, function()
		if self.ToastToken == token then
			self.Toast.Text = ""
		end
	end)
end
-- Menu open/close: fade and slide the content group instead of popping.
function UI:showMenu(visible)
	if self.Menu.Visible == visible and self.MenuShown ~= nil then
		return
	end
	self.MenuShown = visible
	if visible then
		self.Menu.Visible = true
		self.MenuContent.GroupTransparency = 1
		local base = self.MenuContent.Position
		self.MenuContent.Position = base + UDim2.fromOffset(-24, 0)
		TweenService:Create(self.MenuContent, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {
			GroupTransparency = 0,
			Position = base,
		}):Play()
	else
		self.Menu.Visible = false
	end
end
-- Per-frame menu animation (title glow pulse, deletion scan bar, button shine).
function UI:animate(dt)
	self.AnimTime = (self.AnimTime or 0) + dt
	local t = self.AnimTime
	if self.Menu.Visible then
		for i, label in self.TitleLines do
			label:FindFirstChildOfClass("UIStroke").Transparency = 0.62 + math.sin(t * 1.6 + i) * 0.12
		end
		local sweep = (t * 0.35) % 1.4
		self.TitleGlitch.Position = UDim2.fromOffset(sweep * 420, 104)
		self.TitleGlitch.BackgroundTransparency = if sweep > 1 then 1 else 0.35 + math.sin(t * 30) * 0.15
		self.TitleAccent.Size = UDim2.fromOffset(72 + math.sin(t * 1.2) * 16, 3)
		local shine = (t * 0.45) % 1.8 - 0.3
		self.PlayShine.Position = UDim2.fromScale(shine, 0)
	end
	-- Critical deletion danger: a subtle pulse on the bar (no flashing text).
	if self.DangerLevel == "Critical" then
		self.DeletionFill.BackgroundTransparency = 0.12 + math.sin(t * 6) * 0.12
	else
		self.DeletionFill.BackgroundTransparency = 0
	end
	if self.Queue.Visible then
		self.QueueNumberScale.Scale += (1 - self.QueueNumberScale.Scale) * math.min(1, dt * 10)
	end
end
-- Queue card: authoritative countdown from snapshots; also handles honest waiting states.
function UI:queue(data)
	local queued = data.State == "Queued"
	if queued and not self.Queue.Visible then
		self.Queue.Visible, self.Queue.GroupTransparency = true, 1
		TweenService:Create(self.Queue, TweenInfo.new(0.3), { GroupTransparency = 0 }):Play()
		self.LastCount = nil
	elseif not queued and self.Queue.Visible and not self.Starting then
		self.Queue.Visible = false
	end
	self.MenuContent.Visible = not (queued and self.MenuNarrow)
	if not queued then
		return
	end
	local count = data.Queued or 1
	if data.Round == "Intermission" or data.Round == "Waiting" then
		local n = math.clamp(data.Countdown or Config.Intermission, 0, Config.Intermission)
		self.QueueTitle.Text = "ASCENT BEGINS IN"
		self.QueueNumber.Text = tostring(math.max(1, n))
		self.QueueFill.Size = UDim2.fromScale(n / Config.Intermission, 1)
		self.QueueInfo.Text = string.format(
			"%d explorer%s ready · friends can still join",
			count,
			if count == 1 then "" else "s"
		)
		if n ~= self.LastCount then
			self.LastCount = n
			self.QueueNumberScale.Scale = 1.35
			if self.OnCountdown then
				self.OnCountdown(n)
			end
		end
	else
		self.QueueTitle.Text = "ASCENT IN PROGRESS"
		self.QueueNumber.Text = "…"
		self.QueueFill.Size = UDim2.fromScale(1, 1)
		self.QueueInfo.Text = "Its opening window has closed. You will start the next ascent when it ends."
	end
end
-- Queue → match: START flash, short fade to black with the realm name, then fade in.
function UI:startTransition(data)
	self.Starting = true
	self.Queue.Visible = true
	self.QueueTitle.Text, self.QueueNumber.Text = "GO!", "START"
	self.QueueNumberScale.Scale = 1.3
	self.QueueFill.Size = UDim2.fromScale(0, 1)
	if self.OnCountdown then
		self.OnCountdown(0)
	end
	self.Fade.Visible, self.Fade.BackgroundTransparency = true, 1
	self.FadeLabel.Text = string.upper(data.RegionName or "Havenwood Reach")
	self.FadeLabel.TextTransparency = 1
	TweenService:Create(self.Fade, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(self.FadeLabel, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	task.delay(0.55, function()
		self.Starting = false
		self.Queue.Visible = false
		TweenService
			:Create(self.Fade, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
			:Play()
		TweenService:Create(self.FadeLabel, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
		task.delay(0.95, function()
			if not self.Starting then
				self.Fade.Visible = false
			end
		end)
	end)
end
-- NPC dialogue: floating speaker and line above the controls, advancing every few seconds.
function UI:dialogue(payload)
	if not self.Dialogue then
		self.Dialogue = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -250),
			Size = UDim2.fromOffset(560, 64),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, self.Gui)
		self.DialogueSpeaker = text(self.Dialogue, "", 14, UDim2.new(), UDim2.new(1, 0, 0, 18), palette.Gold)
		self.DialogueLine =
			text(self.Dialogue, "", 17, UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 44), palette.Text)
		for _, label in { self.DialogueSpeaker, self.DialogueLine } do
			label.TextXAlignment, label.Font = Enum.TextXAlignment.Center, Enum.Font.GothamBlack
			label.TextStrokeTransparency, label.TextStrokeColor3 = 0.25, Color3.fromRGB(8, 10, 20)
			label.TextWrapped = true
		end
	end
	local token = os.clock()
	self.DialogueToken = token
	self.Dialogue.Visible = true
	self.DialogueSpeaker.Text = string.upper(payload.Speaker or "")
	local lines = payload.Lines or {}
	local function show(i)
		if self.DialogueToken ~= token then
			return
		end
		if i > #lines then
			self.Dialogue.Visible = false
			return
		end
		self.DialogueLine.Text = "{201C}" .. lines[i] .. "{201D}"
		self.DialogueLine.TextTransparency = 1
		TweenService:Create(self.DialogueLine, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		task.delay(3.4, function()
			show(i + 1)
		end)
	end
	show(1)
end
-- Feed entry that slides in and fades after a few seconds (max five visible).
function UI:feed(message, color)
	self.FeedCount += 1
	local entry = make("TextLabel", {
		Text = message,
		Size = UDim2.new(1, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = palette.Ink,
		BackgroundTransparency = 0.25,
		TextColor3 = color or palette.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = -self.FeedCount,
	}, self.Feed)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, entry)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, entry)
	local entries = {}
	for _, child in self.Feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(entries, child)
		end
	end
	table.sort(entries, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 6, #entries do
		entries[i]:Destroy()
	end
	task.delay(4, function()
		if entry.Parent then
			TweenService
				:Create(entry, TweenInfo.new(0.6), { TextTransparency = 1, BackgroundTransparency = 1 })
				:Play()
			task.delay(0.7, function()
				if entry.Parent then
					entry:Destroy()
				end
			end)
		end
	end)
	return entry
end
function UI:banner(title, subtitle, lore)
	self.BannerTitle.Text, self.BannerSub.Text, self.BannerLore.Text = title, subtitle or "", lore or ""
	self.Banner.Visible = true
	for _, label in { self.BannerTitle, self.BannerSub, self.BannerLore } do
		label.TextTransparency = 1
		TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 0 }):Play()
	end
	local token = os.clock()
	self.BannerToken = token
	task.delay(3.6, function()
		if self.BannerToken == token then
			for _, label in { self.BannerTitle, self.BannerSub, self.BannerLore } do
				TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
			end
			task.delay(0.9, function()
				if self.BannerToken == token then
					self.Banner.Visible = false
				end
			end)
		end
	end)
end
function UI:flash(color, strength)
	self.Flash.BackgroundColor3 = color
	self.Flash.BackgroundTransparency = 1 - (strength or 0.25)
	TweenService:Create(self.Flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
end
-- Server objective/reward/achievement events.
function UI:event(action, payload)
	if action == "Objective" then
		local colors = {
			Complete = Color3.fromRGB(150, 240, 150),
			Failed = palette.Red,
			Event = palette.Gold,
			Discovered = palette.Blue,
			Progress = palette.Text,
		}
		local prefix = ({
			Complete = "COMPLETE  ",
			Failed = "FAILED  ",
			Event = "EVENT  ",
			Discovered = "SECRET  ",
			Progress = "",
		})[payload.Kind] or ""
		self:feed(
			prefix .. (payload.Title or "") .. (if payload.Text then " — " .. payload.Text else ""),
			colors[payload.Kind]
		)
		if payload.Kind == "Complete" or payload.Kind == "Event" then
			self:notice(payload.Text or payload.Title)
		end
	elseif action == "Reward" then
		local parts = {}
		if (payload.Coins or 0) > 0 then
			table.insert(parts, "+" .. payload.Coins .. " coins")
		end
		if (payload.XP or 0) > 0 then
			table.insert(parts, "+" .. payload.XP .. " XP")
		end
		for _, kind in { "Relic", "Crystal", "Timber", "Herb" } do
			if (payload[kind] or 0) > 0 then
				table.insert(parts, "+" .. payload[kind] .. " " .. kind:lower())
			end
		end
		if #parts > 0 then
			self:feed(table.concat(parts, "  ·  "), palette.Gold)
		end
	elseif action == "Perk" then
		self:feed("PERK  " .. payload.Name .. " — " .. payload.Text, Color3.fromRGB(200, 160, 255))
		self:notice("New perk: " .. payload.Name .. " (" .. payload.Text .. ")")
	elseif action == "Achievement" then
		self.AchievementTitle.Text = "ACHIEVEMENT  ·  " .. payload.Name
		self.AchievementText.Text = payload.Text
			.. (if payload.Unlock then "  ·  Cosmetic unlocked in the Sky boutique" else "")
		self.Achievement.Visible = true
		local token = os.clock()
		self.AchievementToken = token
		task.delay(4.5, function()
			if self.AchievementToken == token then
				self.Achievement.Visible = false
			end
		end)
	elseif action == "Dragon" then
		local kind = payload.Kind
		if kind == "Encounter" then
			self:banner(
				"THE REALM DESTROYER",
				"Fight with Dragonbane weapons, or reach the Sky Balloon",
				"Shoot glowing weak points. Leave glowing ground. Jump shockwaves. The realm falls in "
					.. math.floor((payload.RazeIn or 150) / 60)
					.. " minutes."
			)
			self:flash(Color3.fromRGB(255, 90, 50), 0.3)
		elseif kind == "Repelled" then
			self:banner("REALM DESTROYER REPELLED", "It flees, wounded. It will return.", "")
		elseif kind == "Escaped" then
			self:feed("You escaped the Realm Destroyer: no boss rewards this time", palette.Muted)
		elseif kind == "Raze" then
			self:flash(Color3.fromRGB(255, 80, 40), 0.35)
		elseif kind == "Crossbow" then
			self:feed(
				"DRAGONBANE CROSSBOW  ·  " .. (payload.Bolts or 0) .. " bolts  ·  G / R1 / FIRE",
				palette.Gold
			)
		elseif kind == "Roar" and payload.Distant and not self.HeardRoar then
			self.HeardRoar = true
			self:feed("A distant roar shakes the sky. Something vast circles the realms…", palette.Red)
		elseif kind == "Interrupted" then
			self:feed("Crystal blast! Its heart is exposed!", palette.Blue)
		end
	elseif action == "DragonTrophy" then
		self:feed(
			string.format(
				"DRAGON TROPHIES  +%d scales%s  ·  total %d scales, %d shards",
				payload.Scales or 0,
				if (payload.Emberhearts or 0) > 0
					then ", +" .. payload.Emberhearts .. " Emberheart Shard"
					else "",
				payload.TotalScales or 0,
				payload.TotalEmberhearts or 0
			),
			Color3.fromRGB(255, 150, 90)
		)
		if payload.Cosmetic then
			self.AchievementTitle.Text = "RARE DROP  ·  " .. payload.Cosmetic
			self.AchievementText.Text = "Equip it in the Sky boutique"
			self.Achievement.Visible = true
			local token = os.clock()
			self.AchievementToken = token
			task.delay(5, function()
				if self.AchievementToken == token then
					self.Achievement.Visible = false
				end
			end)
		end
	elseif action == "Shop" then
		if payload.Kind == "Bought" then
			self:feed("PURCHASED  " .. (payload.Name or ""), palette.Gold)
		elseif payload.Kind == "Equipped" then
			self:notice((payload.Name or "Cosmetic") .. " equipped")
		end
	elseif action == "Bestiary" then
		self:feed(
			string.format(
				"BESTIARY  %s  %d/%d  ·  %s",
				payload.Name or "",
				payload.Stage or 0,
				payload.Of or 4,
				payload.Text or ""
			),
			palette.Blue
		)
	elseif action == "Hurt" then
		self:flash(Color3.fromRGB(255, 60, 70), math.clamp((payload.Amount or 5) / 40, 0.1, 0.35))
	elseif action == "Collected" then
		self:feed(
			"+1 "
				.. (if payload.Kind == "Timber"
						or payload.Kind == "Crystal"
						or payload.Kind == "Herb"
					then payload.Kind
					else payload.Kind .. " key")
				.. "  ("
				.. (payload.Count or 1)
				.. " in pack)",
			palette.Blue
		)
	end
end
local typeIcons = {
	Repair = "FIX",
	Rescue = "SAVE",
	Hunt = "HUNT",
	Plates = "PUZZLE",
	Dials = "PUZZLE",
	Beams = "PUZZLE",
	Mining = "MINE",
	Cache = "LOOT",
	Rings = "FLY",
	Artifacts = "FIND",
	Gate = "VAULT",
	Survey = "MAP",
	Flock = "SAVE",
}
-- Objective tracker rows: realm, main objective, activities (nearest first), event, perks.
function UI:objectives(data)
	local info = data.Objectives
	self.Tracker.Visible = data.State == "Alive" and info ~= nil and not self.Panel.Visible
	if not info then
		return
	end
	local rows = {}
	local accent = self.ThemeColor or palette.Blue
	local function hex(c)
		return string.format(
			"#%02X%02X%02X",
			math.floor(c.R * 255),
			math.floor(c.G * 255),
			math.floor(c.B * 255)
		)
	end
	table.insert(
		rows,
		string.format(
			'<font color="%s"><b>REGION COLLAPSES IN %ds</b></font>',
			hex(accent),
			info.TimeLeft or 0
		)
	)
	if self.TrackerCollapsed then
		local open = 0
		for _, act in info.Activities do
			if not act.Done and not act.Failed then
				open += 1
			end
		end
		table.insert(rows, string.format("%d optional activities open · tap to expand", open))
	else
		local list = table.clone(info.Activities)
		table.sort(list, function(a, b)
			if a.Done ~= b.Done then
				return not a.Done
			end
			return (a.Distance or 9999) < (b.Distance or 9999)
		end)
		for _, act in list do
			local mark = if act.Done
				then '<font color="#96F096">+</font>'
				elseif act.Failed then '<font color="#FF7A9A">x</font>'
				else '<font color="#A8B6CF">•</font>'
			local where = if act.Distance and not act.Done then string.format("  %dm", act.Distance) else ""
			table.insert(
				rows,
				string.format(
					'%s <font color="#FFD58D"><b>%s</b></font> %s  <font color="#A8B6CF">%s%s</font>',
					mark,
					typeIcons[act.Type] or "•",
					act.Title,
					act.Progress or "",
					where
				)
			)
		end
	end
	if info.Event then
		table.insert(
			rows,
			string.format(
				'<font color="#FFD58D">EVENT</font>  %s  (%ds)',
				info.Event.Title,
				info.Event.Remaining
			)
		)
	end
	if info.Carrying then
		table.insert(rows, '<font color="#83DAF7">Carrying an artifact: bring it to the pedestal</font>')
	end
	if #info.Perks > 0 or (info.Relics or 0) > 0 then
		table.insert(
			rows,
			string.format(
				'<font color="#C8A0FF">Relics %d</font>  %s',
				info.Relics or 0,
				table.concat(info.Perks, " · ")
			)
		)
	end
	for i, row in self.TrackerRows do
		row.Text = rows[i] or ""
		row.Visible = rows[i] ~= nil
	end
	self.TrackerHeader.Text = if self.TrackerCollapsed
		then "OPTIONAL ACTIVITIES  [+]"
		else "OPTIONAL ACTIVITIES  [-]"
end
function UI:open(page)
	self.Page = page
	local inMenu = self.State == "Lobby" or self.State == "Queued" or self.State == nil
	self:showMenu(page == "Menu" and inMenu)
	self.Panel.Visible = page ~= "Menu"
	if page == "Menu" then
		return
	end
	self.Panel.Position = UDim2.fromScale(0.5, 0.52)
	TweenService:Create(
		self.Panel,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.5) }
	):Play()
	self.Body:ClearAllChildren()
	make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, self.Body)
	self.PanelTitle.Text = ({
		Help = "Your ascent",
		Settings = "Settings",
		Shop = "Sky boutique",
		Bestiary = "Bestiary",
		Leaderboard = "Highest ascenders",
		Elimination = "The ascent ends",
	})[page] or page
	local function paragraph(value, height, color)
		local label = text(self.Body, value, 16, UDim2.new(), UDim2.new(1, -8, 0, height), color)
		label.TextWrapped, label.TextYAlignment = true, Enum.TextYAlignment.Top
		return label
	end
	local function row(label, callback, primary)
		return button(self.Body, label, UDim2.new(), UDim2.new(1, -8, 0, 46), callback, primary)
	end
	if page == "Help" then
		paragraph(
			"Explore villages, forests and caves. Press E, controller X, or the gold interaction button to collect nearby supplies. Each supply can be gathered once per player per round. Walk upward along the broad sky causeway.",
			84
		)
		paragraph(
			"Purple cracks warn before ground sections fall. The outskirts disappear first. Storms damage exposed survivors: shelter inside village houses or the cave. Earthquakes destroy alternate paths. Escape before the deletion wave reaches you.",
			100,
			palette.Muted
		)
		paragraph(
			"Use your pack anywhere: H heals 40 HP with one herb; C spends a crystal to strengthen powers for 12s; V spends 2 timber to brace nearby ground for 18s. Controller: D-pad Up / Right / Left. Touch: tap the item buttons. Braces cannot stop the deletion wave.",
			110
		)
		paragraph(
			"Q / Z / R / F: Gust Dash, Sky Leap, Aegis, Wind Sail. Controller R2 / Y / B / L1. Dash lasts 1s (about 62 studs on clear level ground). Jump again in midair for Sky Leap. Aegis absorbs 60 damage; Wind Sail slows your fall and lets you steer. F folds it.",
			110
		)
		paragraph(
			"Collect the labeled Sun, Leaf and Moon keys in each cave. At the SEAL ALTAR, E / X places the next collected key, or use 1 / 2 / 3 and the key buttons. Order: Sun > Leaf > Moon. Keys stay in your pouch; wrong order resets the seal. Everyone can use the opened gate. Alternatively contribute 4 crystals. Repair the shortcut with 6 timber or board the Sky Balloon (E / X at its dock; it departs 5 seconds after the first rider boards, and friends can join).",
			170
		)
		paragraph(
			"THE REALM DESTROYER: a giant red dragon circles the realms. From the Floating Jungle it attacks. Fight it or escape: forge a Dragonbane Crossbow (2 timber + 1 crystal; G / R1 / FIRE), take heavy Dragonbane Harpoons from the rack beside the forge (3 timber + 1 crystal; T / L2 / THROW; a hit on a glowing weak point pins it open longer), repair the ballista with timber, and load the crystal cannon with crystals. Shoot the GLOWING weak point during its attacks. Leave glowing ground before it strikes; jump its shockwaves; hide behind walls from its wing gust. Or board the Sky Balloon before the realm burns.",
			190,
			palette.Red
		)
		paragraph(
			"Every realm offers optional activities (top right): repairs, rescues, creature lairs, puzzles, caches, air courses and vaults. They pay coins, XP, relics and run perks, but the ground keeps deleting: decide when to leave. Watch for live events: supply drops, rare relics, roaming guardians and lost travelers.",
			120,
			palette.Gold
		)
		paragraph(
			"Creatures glow red before attacking: step away, raise Aegis, then Gust Dash through them or drop onto them. Storms tear breaches in shelters; patch them (E / X) or the storm leaks in. Spend 2 relics at a realm shrine you already discovered for a random perk, or keep them: unspent relics pay out when your run ends.",
			120
		)
		paragraph(
			"Queue for the next shared round, or join during its opening window. Eliminated players can spectate or return to the sanctuary.",
			80,
			palette.Muted
		)
	elseif page == "Settings" then
		for _, setting in
			{
				{ "Music", "Music" },
				{ "Sound effects", "SFX" },
				{ "Camera effects", "Camera" },
				{ "Weather & detail", "Detail" },
			}
		do
			local key, label = setting[2], setting[1]
			local b
			b = row(label .. ": " .. (if self.Settings[key] then "ON" else "OFF"), function()
				self.Settings[key] = not self.Settings[key]
				b.Text = label .. ": " .. (if self.Settings[key] then "ON" else "OFF")
			end)
		end
		paragraph(
			"Your preferences apply for this visit. Reduce scenery and particles for performance. Storm clouds, light rain and warnings remain visible for survival.",
			64,
			palette.Muted
		)
		row("Return to sanctuary", function()
			self.Request:FireServer("Lobby")
			self:open("Menu")
		end)
	elseif page == "Shop" then
		ShopView.render(self)
	elseif page == "Bestiary" then
		DragonHud.page(self, paragraph)
	elseif page == "Leaderboard" then
		paragraph("THIS SERVER", 22, palette.Blue)
		local roster = table.clone(self.Data and self.Data.Roster or {})
		table.sort(roster, function(a, b)
			return a.Altitude > b.Altitude
		end)
		for i, player in roster do
			paragraph(string.format("%d. %s — %dm", i, player.Name, player.Altitude), 30)
		end
		paragraph("GLOBAL PERSONAL BESTS", 22, palette.Blue)
		if not self.GlobalBoard or #self.GlobalBoard == 0 then
			paragraph("Global rankings are currently unavailable.", 64, palette.Muted)
		end
		for i, entry in self.GlobalBoard or {} do
			paragraph(string.format("%d. User %s — %dm", i, entry.key, entry.value), 30)
		end
	elseif page == "Elimination" then
		local r = self.Result or self.Data and self.Data.Result or {}
		paragraph(string.format("%dm\nHighest verified altitude", r.Altitude or 0), 78, palette.Gold).TextSize =
			28
		paragraph(
			string.format(
				"Previous record: %dm\nCoins earned: %d\nSurvival: %ds\n%s",
				r.Previous or 0,
				r.Coins or 0,
				r.Duration or 0,
				r.Reason or ""
			),
			112
		)
		row("Queue for next ascent", function()
			self.Request:FireServer("Play")
			self:open("Menu")
		end, true)
		row("Spectate survivors", function()
			self.Request:FireServer("Spectate")
			self.Panel.Visible = false
		end)
		row("Return to sanctuary", function()
			self.Request:FireServer("Lobby")
			self:open("Menu")
		end)
	end
	if GuiService:IsTenFootInterface() or UserInputService.GamepadEnabled then
		local first = self.Body:FindFirstChildWhichIsA("TextButton")
		if first then
			GuiService.SelectedObject = first
		end
	end
end
-- Re-renders the open shop in place (keeps the scroll position, no panel animation).
function UI:refreshShop()
	if self.Page ~= "Shop" or not self.Panel.Visible then
		return
	end
	local scroll = self.Body.CanvasPosition
	self.Body:ClearAllChildren()
	make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, self.Body)
	ShopView.render(self)
	self.Body.CanvasPosition = scroll
end
-- Cooldown sweep: the dark overlay drains from full to empty as the cooldown ends.
function UI:sweep(name, remaining)
	local shade = self.CooldownShades and self.CooldownShades[name]
	if not shade then
		return
	end
	local total = self.CooldownTotals[name] or 0
	if remaining <= 0 then
		if total > 0 and self.Data and self.Data.State == "Alive" then
			local stroke = shade.Parent:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = 0
				TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 0.6 }):Play()
			end
		end
		self.CooldownTotals[name] = 0
		shade.Size = UDim2.fromScale(1, 0)
		return
	end
	total = math.max(total, remaining)
	self.CooldownTotals[name] = total
	shade.Size = UDim2.fromScale(1, math.clamp(remaining / total, 0, 1))
end
function UI:updateStorm(data, weather)
	if data.State ~= "Alive" then
		return
	end
	if data.Distance < Config.WaveWarningDistance then
		return
	end
	if data.Event == "Storm" and data.EventPhase == "Active" then
		self.Danger.Text = (if weather.Phase == "Extreme" then "EXTREME STORM" else "HEAVY STORM")
			.. (if (weather.Hurricane or 0) > 0.35 then " | HURRICANE" else "")
			.. (if data.Sheltered then " · YOU ARE SHELTERED" else " · FIND A HOUSE OR CAVE")
	elseif data.Event == "Earthquake" and data.EventPhase == "Active" then
		self.Danger.Text = "EARTHQUAKE | LEAVE FRACTURED GROUND"
	elseif
		weather.Phase == "Recovery"
		and data.EventPhase == "Calm"
		and data.Distance >= Config.WaveWarningDistance
	then
		self.Danger.Text = "STORM PASSING · THE SKY IS CLEARING"
		self.Danger.BackgroundTransparency = 1
	end
end
function UI:update(data)
	local oldState = self.State
	self.Data, self.State = data, data.State
	self.Hud.Visible = data.State == "Alive"
	self.Controls.Visible = data.State == "Alive" and not self.Panel.Visible
	self.Pause.Visible = data.State == "Alive"
	self.Spectator.Visible = data.State == "Spectating"
	if oldState ~= data.State then
		if data.State == "Eliminated" then
			self:open("Elimination")
		elseif data.State == "Lobby" or data.State == "Queued" then
			self:open("Menu")
		else
			self.Panel.Visible = false
			self:showMenu(false)
			self.Page = "Menu"
		end
		if data.State == "Alive" and (oldState == "Queued" or oldState == "Lobby") then
			self:startTransition(data)
		end
	end
	self:queue(data)
	self.Play.Text = if not data.Ready
		then "LOADING YOUR PROFILE…"
		elseif data.State == "Queued" then "QUEUED · " .. (if data.Round == "Running"
			then "NEXT ASCENT"
			else math.max(1, data.Countdown or 0) .. "s")
		else "BEGIN ASCENT"
	self.Status.Text = if data.State == "Queued"
		then (if data.Round == "Running"
			then "Waiting for the survivors' round to end"
			else string.format("Ascent begins in %ds", data.Countdown))
		elseif not data.Ready then "Loading your profile safely…"
		elseif
			data.Round == "Running"
		then "An ascent is underway: join within its opening window, or start the next one"
		else (if data.Persistent
			then "Ready · Your progress saves automatically"
			else "Ready · Studio session, progress is not saved")
	self.StatusDot.BackgroundColor3 = if data.Ready then Color3.fromRGB(120, 230, 140) else palette.Gold
	self.Play.AutoButtonColor = data.Ready and data.State == "Lobby"
	self.Altitude.Text = string.format("%dm ALTITUDE", data.Altitude)
	self.Biome.Text = string.upper(data.RegionName or "Realm")
		.. "  ·  "
		.. (data.BiomeName or data.Biome or "")
	if self.LastBiome ~= data.Biome then
		self.LastBiome = data.Biome
		for _, biome in Biomes.List do
			if biome.Id == data.Biome then
				local accent = Color3.fromRGB(biome.Accent[1], biome.Accent[2], biome.Accent[3])
				self.ThemeColor = accent
				self.ObjectiveIcon.BackgroundColor3 = accent
				self.Panel:FindFirstChildOfClass("UIStroke").Color = accent
				self.Biome.TextColor3, self.Adventure.TextColor3 = accent, accent
				self.EventMeter.BackgroundColor3 = accent
			end
		end
	end
	local powers = data.PowerStatus or { Shield = 0, Glide = 0, Overcharge = 0 }
	self.Health.Text = string.format(
		"%d/%d%s",
		math.ceil(data.Health or 100),
		data.MaxHealth or 100,
		if powers.Shield > 0 then "  +" .. math.ceil(powers.Shield) .. " AEGIS" else ""
	)
	-- Health: bright green when healthy, orange at moderate, strong red at critical.
	local ratio = math.clamp((data.Health or 100) / math.max(1, data.MaxHealth or 100), 0, 1)
	local healthColor = if ratio > 0.6
		then Color3.fromRGB(70, 232, 96)
		elseif ratio > 0.3 then Color3.fromRGB(255, 168, 36)
		else Color3.fromRGB(255, 52, 60)
	TweenService:Create(self.HealthFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = healthColor,
	}):Play()
	self.ShieldFill.Size = UDim2.fromScale(math.clamp(powers.Shield / 90, 0, 1), 0.35)
	if self.LastHealth and (data.Health or 0) > self.LastHealth + 5 and data.State == "Alive" then
		self:flash(Color3.fromRGB(120, 240, 140), 0.18)
	end
	self.LastHealth = data.Health
	self.Health.TextColor3 = if ratio <= 0.3 then palette.Red else palette.Text
	-- Deletion danger from the real wave distance: SAFE (cyan), WARNING (orange), CRITICAL (red).
	local distance = math.max(0, math.floor(data.Distance))
	local critical, warning = Config.WaveWarningDistance, Config.WaveWarningDistance * 2
	self.DangerLevel = if distance < critical
		then "Critical"
		elseif distance < warning then "Warning"
		else "Safe"
	self.Distance.Text = string.format("%dm BELOW", distance)
	local dangerColor = if self.DangerLevel == "Critical"
		then Color3.fromRGB(255, 46, 56)
		elseif self.DangerLevel == "Warning" then Color3.fromRGB(255, 140, 30)
		else Color3.fromRGB(60, 220, 255)
	TweenService:Create(self.DeletionFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(math.clamp(1 - data.Distance / (critical * 4), 0.03, 1), 1),
		BackgroundColor3 = dangerColor,
	}):Play()
	self.Distance.TextColor3 = if self.DangerLevel == "Safe" then palette.Text else dangerColor
	self.Danger.Text = if data.State == "Alive" and data.Distance < Config.WaveWarningDistance
		then "THE VOID IS CLOSE — KEEP CLIMBING"
		else ""
	local seal = data.Seal or {}
	-- Current primary objective (optional activities stay in the collapsible tracker).
	local objective = "Climb to the next realm: sky causeway, Sky Balloon or cave seal"
	local info = data.Objectives
	if data.Balloon then
		objective = "Ride the Sky Balloon to the next realm"
	elseif data.Dragon and data.Dragon.Encounter then
		objective = "Repel the Realm Destroyer, or escape on the Sky Balloon"
	elseif info and info.Carrying then
		objective = "Carry the artifact to its pedestal"
	elseif seal.Nearby and not seal.Open then
		objective = "Place the seal keys in order: Sun, Leaf, Moon"
	elseif data.PortalOpen then
		objective = "The cave gate is open: escape upward"
	elseif self.DangerLevel ~= "Safe" then
		objective = "Escape upward before the deletion reaches you"
	end
	if objective ~= self.Objective.Text then
		self.Objective.Text = objective
		self.Objective.TextTransparency = 1
		TweenService:Create(self.Objective, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	end
	local keysLine = string.format(
		"KEYS Sun [%s] Leaf [%s] Moon [%s] | Seal %d/3",
		if seal.Sun then "+" else "-",
		if seal.Leaf then "+" else "-",
		if seal.Moon then "+" else "-",
		seal.Progress or 0
	)
	-- Only shown when it matters: keys owned, the altar nearby, or a shared repair under way.
	local relevant = seal.Sun or seal.Leaf or seal.Moon or seal.Nearby or (data.Repair or 0) > 0
	self.Adventure.Visible = data.State == "Alive" and relevant == true
	self.Adventure.Text = keysLine
		.. (
			if (data.Repair or 0) > 0 then string.format("\nShortcut repair %d/6 timber", data.Repair) else ""
		)
	local bag = data.Bag or { Timber = 0, Crystal = 0, Herb = 0 }
	local usingSeal = seal.Nearby and not seal.Open
	for glyph, b in self.GlyphButtons do
		b.Visible = usingSeal == true
		local owned = seal[glyph] == true
		local nextKey = Seal.Order[(seal.Progress or 0) + 1] == glyph
		b.Text = glyph
			.. " KEY | "
			.. Seal.Keys[glyph].Shortcut
			.. "\n"
			.. (if not owned then "COLLECT FIRST" elseif nextKey then "PLACE NEXT" else "COLLECTED")
		b.BackgroundTransparency = if owned and nextKey then 0 else 0.55
	end
	if data.State == "Alive" and data.EventPhase == "Warning" then
		self.Danger.Text = string.upper(data.Event or "Event")
			.. " IN "
			.. (data.EventRemaining or 8)
			.. "s — GET UNDER COVER"
	end
	if data.State == "Alive" and data.Event == "Storm" and data.EventPhase == "Active" then
		self.Danger.Text = if data.Sheltered
			then "STORM ACTIVE · YOU ARE SHELTERED"
			else "STORM ACTIVE · FIND A HOUSE OR CAVE"
	end
	if
		data.State == "Alive"
		and data.Event == "Earthquake"
		and data.Distance >= Config.WaveWarningDistance
	then
		if data.EventPhase == "Warning" then
			self.Danger.Text = "EARTHQUAKE IN " .. (data.EventRemaining or 8) .. "s | REACH INTACT GROUND"
		elseif data.EventPhase == "Active" then
			self.Danger.Text = "EARTHQUAKE | LEAVE FRACTURED GROUND"
		end
	end
	self.EventMeter.Visible = data.State == "Alive" and data.EventPhase == "Warning"
	self.EventMeter.Size = UDim2.new(0.9 * math.clamp((data.EventRemaining or 8) / 8, 0, 1), 0, 0, 3)
	self.Danger.BackgroundTransparency = 1
	for kind, b in self.ItemButtons do
		b.Visible = not usingSeal
		local item = Items[kind]
		local itemRemaining = (data.ItemCooldowns or {})[kind] or 0
		local purpose = if kind == "Herb"
			then "HEAL"
			elseif kind == "Crystal" then "OVERCHARGE"
			else "BRACE (2)"
		if kind == "Crystal" and powers.Overcharge > 0 then
			purpose = "BOOST " .. math.ceil(powers.Overcharge) .. "s"
		elseif itemRemaining > 0 then
			purpose = string.format("%.1fs", itemRemaining)
		end
		b.Text = string.format("%s %d · %s\n%s", kind, bag[kind], item.Key, purpose)
		b.BackgroundTransparency = if bag[kind] >= item.Cost and itemRemaining <= 0 then 0 else 0.55
		self:sweep(kind, itemRemaining)
	end
	for name, b in self.AbilityButtons do
		local remaining = data.Cooldowns[name] or 0
		local label = Config.Ability[name].Label
		local active = if name == "Glide" then powers.Glide elseif name == "Shield" then powers.Shield else 0
		b.Text = label
			.. "\n"
			.. (if active > 0
				then "ACTIVE " .. math.ceil(active)
				elseif remaining > 0 then string.format("%.1fs", remaining)
				else "READY")
			.. "\n"
			.. b:GetAttribute("Shortcut")
		if powers.Overcharge > 0 then
			b.TextColor3 = palette.Gold
		else
			b.TextColor3 = palette.Text
		end
		b.BackgroundColor3 = if remaining > 0 then palette.Ink else palette.Panel
		self:sweep(name, remaining)
	end
	if data.State == "Alive" and data.RegionName and data.RegionName ~= self.LastRegionName then
		self.LastRegionName = data.RegionName
		local realm = Realms.get(data.Biome or "Grasslands")
		self:banner(string.upper(data.RegionName), data.BiomeName, realm.Lore)
	elseif data.State ~= "Alive" then
		self.LastRegionName = nil
	end
	DragonHud.update(self, data)
	-- Live shop: re-render when coins, ownership or the equipped item change.
	local profile = data.Profile
	if profile then
		local owned = 0
		for _ in profile.Owned or {} do
			owned += 1
		end
		local signature = string.format(
			"%d|%s|%d|%d|%d",
			profile.Coins or 0,
			tostring(profile.Equipped),
			owned,
			profile.DragonScales or 0,
			profile.Emberhearts or 0
		)
		if signature ~= self.ShopSignature then
			self.ShopSignature = signature
			self:refreshShop()
		end
	end
	self:objectives(data)
end
return UI
