--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Shop = require(Shared.ShopConfig)
local Dragon = require(Shared.DragonConfig)
local Cosmetics = {}
Cosmetics.__index = Cosmetics
function Cosmetics.new(data, rewards, effects)
	return setmetatable({ Data = data, Rewards = rewards, Effects = effects }, Cosmetics)
end
function Cosmetics:apply(player)
	local profile = self.Data:get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not profile or not root then
		return
	end
	-- Collect top-level cosmetic objects first, then destroy (their marked children go with them).
	local doomed = {}
	for _, object in character:GetDescendants() do
		if
			object:GetAttribute("Cosmetic") and not (object.Parent and object.Parent:GetAttribute("Cosmetic"))
		then
			table.insert(doomed, object)
		end
	end
	for _, object in doomed do
		object:Destroy()
	end
	local item
	for _, candidate in Shop do
		if candidate.Id == profile.Equipped then
			item = candidate
		end
	end
	if not item or item.Kind == "Emote" then
		return
	end
	local color = Color3.fromRGB(item.Color[1], item.Color[2], item.Color[3])
	local function mark(object, parent)
		object:SetAttribute("Cosmetic", true)
		object.Parent = parent
		return object
	end
	if item.Kind == "Trail" then
		local a = mark(Instance.new("Attachment"), root)
		a.Position = Vector3.new(0, 1, 0)
		local b = mark(Instance.new("Attachment"), root)
		b.Position = Vector3.new(0, -1, 0)
		local trail = mark(Instance.new("Trail"), root)
		trail.Attachment0, trail.Attachment1, trail.Color, trail.Lifetime =
			a, b, ColorSequence.new(color), 0.6
		trail.LightEmission = 0.8
	elseif item.Kind == "Effect" then
		local attachment = mark(Instance.new("Attachment"), root)
		local emitter = mark(Instance.new("ParticleEmitter"), attachment)
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color, emitter.Rate, emitter.Lifetime = ColorSequence.new(color), 5, NumberRange.new(0.7, 1.2)
		emitter.Speed, emitter.Size = NumberRange.new(1, 2), NumberSequence.new(0.2)
		emitter.LightEmission = 0.7
	elseif item.Kind == "Skin" then
		local highlight = mark(Instance.new("Highlight"), character)
		highlight.FillTransparency, highlight.OutlineColor, highlight.OutlineTransparency = 1, color, 0.15
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	elseif item.Kind == "Wings" then
		-- Small scaled dragon wings welded to the back: massless, non-colliding parts.
		local back = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or root
		-- Dragon drops get dark bone; coin wings (Gale Wings) get pale, feather-like spars.
		local bone = if item.Drop then Color3.fromRGB(60, 26, 24) else color:Lerp(Color3.new(1, 1, 1), 0.6)
		local function piece(name, size, offset, tint, class)
			local p = mark(Instance.new(class or "Part"), character)
			p.Name, p.Size, p.Color = name, size, tint
			p.Material = if class == "WedgePart" then Enum.Material.Fabric else Enum.Material.Slate
			p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
			p.CFrame = back.CFrame * offset
			local weld = mark(Instance.new("WeldConstraint"), p)
			weld.Part0, weld.Part1 = back, p
			return p
		end
		for _, side in { -1, 1 } do
			local shoulder = CFrame.new(side * 0.6, 0.6, 0.65) * CFrame.Angles(0, side * 0.35, side * -0.5)
			piece(
				"DragonwingBone",
				Vector3.new(0.18, 0.18, 2.2),
				shoulder * CFrame.new(side * 1, 0.4, 0) * CFrame.Angles(0, side * math.pi / 2, 0),
				bone
			)
			piece(
				"DragonwingMembrane",
				Vector3.new(0.06, 1.6, 2.2),
				shoulder * CFrame.new(side * 1.1, -0.3, 0.1) * CFrame.Angles(0, side * math.pi / 2, math.pi),
				color,
				"WedgePart"
			)
			piece(
				"DragonwingClaw",
				Vector3.new(0.2, 0.2, 0.4),
				shoulder * CFrame.new(side * 2.2, 0.45, 0),
				Color3.fromRGB(230, 214, 180)
			)
		end
	end
end
-- Dragon-themed drops: owned via a Realm Destroyer drop, or crafted from persistent materials.
function Cosmetics:craft(record, profile, item)
	local cost = Dragon.Rewards.CraftCost
	if (profile.DragonScales or 0) < cost.DragonScales or (profile.Emberhearts or 0) < cost.Emberhearts then
		self.Effects:FireClient(
			record.Player,
			"Notice",
			string.format(
				"%s: rare Realm Destroyer drop, or craft with %d Dragon Scales + %d Emberheart Shards (you have %d + %d).",
				item.Name,
				cost.DragonScales,
				cost.Emberhearts,
				profile.DragonScales or 0,
				profile.Emberhearts or 0
			)
		)
		return false
	end
	profile.DragonScales -= cost.DragonScales
	profile.Emberhearts -= cost.Emberhearts
	profile.Owned[item.Id] = true
	self.Effects:FireClient(record.Player, "Notice", item.Name .. " crafted from dragon trophies!")
	return true
end
function Cosmetics:purchase(record, id)
	if type(id) ~= "string" or #id > 30 then
		return
	end
	local profile = self.Data:get(record.Player)
	if not profile then
		return
	end
	if id == "none" then
		profile.Equipped = "none"
		self:apply(record.Player)
		self.Rewards:refresh(record.Player)
		self.Effects:FireClient(record.Player, "Notice", "Cosmetic unequipped.")
		return
	end
	local item
	for _, candidate in Shop do
		if candidate.Id == id then
			item = candidate
		end
	end
	if not item then
		return
	end
	if not profile.Owned[id] then
		if item.Drop then
			if not self:craft(record, profile, item) then
				return
			end
		elseif item.Unlock then
			if not (profile.Achievements and profile.Achievements[item.Unlock]) then
				self.Effects:FireClient(record.Player, "Notice", "Unlock this with an achievement.")
				return
			end
			profile.Owned[id] = true
		elseif profile.Coins < item.Price then
			self.Effects:FireClient(
				record.Player,
				"Notice",
				"Not enough coins: "
					.. item.Name
					.. " costs "
					.. item.Price
					.. " (you have "
					.. profile.Coins
					.. ")."
			)
			return
		end
		profile.Coins -= item.Price
		profile.Owned[id] = true
		self.Effects:FireClient(record.Player, "Shop", { Kind = "Bought", Id = id, Name = item.Name })
	end
	-- Emotes are owned, not worn: buying one must not strip the equipped cosmetic.
	if item.Kind == "Emote" then
		self.Rewards:refresh(record.Player)
		return
	end
	profile.Equipped = id
	self:apply(record.Player)
	self.Rewards:refresh(record.Player)
	self.Effects:FireClient(record.Player, "Shop", { Kind = "Equipped", Id = id, Name = item.Name })
end
function Cosmetics:emote(record)
	local profile = self.Data:get(record.Player)
	if not profile or not profile.Owned.wave then
		return
	end
	self.Effects:FireAllClients("Emote", record.Player.UserId)
end
return Cosmetics
