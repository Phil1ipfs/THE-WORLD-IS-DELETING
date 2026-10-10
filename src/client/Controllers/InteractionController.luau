--!nonstrict
-- Finds the nearest enabled interaction for the touch/click button and E/X fallback,
-- highlights it, and hides supplies this player already collected (server-authorized).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Interaction = {}
Interaction.__index = Interaction
Interaction.Tag = "RealmInteraction"
function Interaction.new(request, ui)
	return setmetatable(
		{ Request = request, UI = ui, Hidden = {}, ClaimedIds = {}, Accum = 0, Target = nil },
		Interaction
	)
end
function Interaction:syncRound()
	local id = self.UI.Data and self.UI.Data.RoundNumber
	if id ~= nil and id ~= self.RoundNumber then
		self.RoundNumber, self.Hidden, self.ClaimedIds = id, {}, {}
	end
end
function Interaction:collect(payload)
	self:syncRound()
	local node = payload.Node
	local id = payload.Id or (node and node:GetAttribute("InteractionId"))
	if id then
		self.ClaimedIds[id] = true
	end
	if not node or not node.Parent then
		return
	end
	if self.OnCollected and payload.Kind then
		self.OnCollected(node, payload)
	end
	self.Hidden[node] = true
	node.LocalTransparencyModifier = 1
	local prompt = node:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	for _, child in node:GetDescendants() do
		if child:IsA("BasePart") then
			child.LocalTransparencyModifier = 1
		elseif child:IsA("BillboardGui") then
			child.Enabled = false
		end
	end
	if self.Target == node then
		self.Target = nil
		self:highlight(nil)
	end
end
function Interaction:activate()
	if self.Target and self.UI.State == "Alive" and not self.UI.Panel.Visible then
		self.Request:FireServer("Interact", self.Target:GetAttribute("InteractionId"))
	end
end
-- Subtle outline on the item the player will interact with.
function Interaction:highlight(node)
	if not self.Highlight then
		local ok, highlight = pcall(function()
			local h = Instance.new("Highlight")
			h.Name = "InteractionHighlight"
			h.FillColor, h.FillTransparency = Color3.fromRGB(255, 226, 150), 0.82
			h.OutlineColor, h.OutlineTransparency = Color3.fromRGB(255, 236, 180), 0.15
			h.DepthMode = Enum.HighlightDepthMode.Occluded
			h.Parent = workspace
			return h
		end)
		if not ok then
			return
		end
		self.Highlight = highlight
	end
	if node then
		self.Highlight.Adornee = node
	end
	self.Highlight.Enabled = node ~= nil
end
-- Interaction nodes: CollectionService tag index in the engine, full scan as a fallback.
function Interaction:nodes(world)
	local ok, tagged = pcall(function()
		return CollectionService:GetTagged(Interaction.Tag)
	end)
	if ok and type(tagged) == "table" and #tagged > 0 then
		return tagged
	end
	return world:GetDescendants()
end
function Interaction:update(dt)
	self.Accum += dt
	if self.Accum < 0.25 then
		return
	end
	self.Accum = 0
	self:syncRound()
	for node in self.Hidden do
		if not node.Parent then
			self.Hidden[node] = nil
		end
	end
	local root = Players.LocalPlayer.Character
		and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local world = workspace:FindFirstChild("FloatingRealms")
	local nearest, distance = nil, 12
	if root and world and self.UI.State == "Alive" and not self.UI.Panel.Visible then
		for _, node in self:nodes(world) do
			if node:IsA("BasePart") and node.Parent then
				local id = node:GetAttribute("InteractionId")
				if id and self.ClaimedIds[id] and not self.Hidden[node] then
					self:collect({ Node = node })
				end
				if id and not self.Hidden[node] then
					local prompt = node:FindFirstChildOfClass("ProximityPrompt")
					local d = (root.Position - node.Position).Magnitude
					if prompt and prompt.Enabled and d < distance then
						nearest, distance = node, d
					end
				end
			end
		end
	end
	self.Target = nearest
	self.UI.Interact.Visible = nearest ~= nil
	if nearest then
		local prompt = nearest:FindFirstChildOfClass("ProximityPrompt")
		self.UI.Interact.Text = "E / X · " .. prompt.ActionText
	end
	if nearest ~= self.Highlighted then
		self.Highlighted = nearest
		self:highlight(nearest)
	end
end
return Interaction
