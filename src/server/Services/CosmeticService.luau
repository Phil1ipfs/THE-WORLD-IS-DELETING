--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Shop = require(Shared.ShopConfig)
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
	for _, object in character:GetDescendants() do
		if object:GetAttribute("Cosmetic") then
			object:Destroy()
		end
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
	end
end
function Cosmetics:purchase(record, id)
	if type(id) ~= "string" or #id > 30 then
		return
	end
	local profile = self.Data:get(record.Player)
	if not profile then
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
		if item.Unlock then
			if not (profile.Achievements and profile.Achievements[item.Unlock]) then
				self.Effects:FireClient(record.Player, "Notice", "Unlock this with an achievement.")
				return
			end
			profile.Owned[id] = true
		elseif profile.Coins < item.Price then
			self.Effects:FireClient(record.Player, "Notice", "Not enough coins")
			return
		end
		profile.Coins -= item.Price
		profile.Owned[id] = true
	end
	profile.Equipped = id
	self:apply(record.Player)
	self.Rewards:refresh(record.Player)
end
function Cosmetics:emote(record)
	local profile = self.Data:get(record.Player)
	if not profile or not profile.Owned.wave then
		return
	end
	self.Effects:FireAllClients("Emote", record.Player.UserId)
end
return Cosmetics
