--!nonstrict
-- All inventory, costs, prompt distances and authorized travel are server-owned.
local Adventure = {}
local G = require(script.Parent.Parent.Services.Geometry)
local Items = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").ItemConfig)
local Seal = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").SealConfig)
local Ground = require(script.Parent.Parent.Services.GroundProbe)
Adventure.__index = Adventure
local caps = { Timber = Items.Timber.Cap, Crystal = Items.Crystal.Cap, Herb = Items.Herb.Cap }
function Adventure.new(world, players, effects, rewards)
	local self = setmetatable(
		{ World = world, Players = players, Effects = effects, Rewards = rewards, Trips = {}, Specs = {} },
		Adventure
	)
	world.OnRegionAdded = function(region)
		self:attach(region)
	end
	world.OnRegionRemoved = function(region)
		for _, record in self.Players.Records do
			if record.Glyphs then
				record.Glyphs[region.Index] = nil
			end
		end
		for _, spec in region.Interactions do
			self.Specs[spec.Id] = nil
		end
		if self.Objectives then
			self.Objectives:detach(region)
		end
		for record, trip in self.Trips do
			if trip.From == region.Index or trip.From + 1 == region.Index then
				self:cancel(record)
			end
		end
	end
	return self
end
function Adventure:notice(record, text)
	self.Effects:FireClient(record.Player, "Notice", text)
end
function Adventure:attach(region)
	region.Repair, region.Charge, region.Glyph = 0, 0, 0
	region.Model:SetAttribute("Repair", 0)
	region.Model:SetAttribute("PortalOpen", false)
	region.Model:SetAttribute("Glyph", 0)
	for _, spec in region.Interactions do
		self:register(region, spec)
	end
	if self.Objectives then
		self.Objectives:attach(region)
	end
end
-- Registers one interaction (also used for prompts created after generation: events, breaches).
function Adventure:register(region, spec)
	if spec.Id then
		return
	end
	if spec.Kind == "Seal" then
		region.Seal = spec
	end
	spec.Stock = if caps[spec.Kind] then 12 else nil
	spec.Claims = {}
	spec.Id = spec.Part:GetAttribute("InteractionId")
	self.Specs[spec.Id] = { Region = region, Spec = spec }
	table.insert(
		region.Connections,
		spec.Prompt.Triggered:Connect(function(player)
			local record = self.Players.Records[player]
			if record then
				self:interact(record, region, spec)
			end
		end)
	)
end
function Adventure:request(record, id)
	if type(id) ~= "string" or #id > 60 then
		return false
	end
	local target = self.Specs[id]
	if not target then
		return false
	end
	return self:interact(record, target.Region, target.Spec)
end
-- Resolve proximity from server positions, independently of the client's tracked region.
function Adventure:nearSeal(record)
	local root = record.Player.Character and record.Player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local nearest, distance = nil, 13
	for _, region in self.World.Islands do
		local spec = region.Seal
		if spec and spec.Part.Parent and spec.Prompt.Enabled then
			local d = (root.Position - spec.Part.Position).Magnitude
			if d <= distance then
				nearest, distance = region, d
			end
		end
	end
	return nearest
end
function Adventure:sealStatus(record)
	local nearby = record.State == "Alive" and not record.Transit and self:nearSeal(record)
	local region = nearby or self.World.Islands[record.Region]
	local keys = region and record.Glyphs and record.Glyphs[region.Index] or {}
	return {
		Sun = keys.Sun == true,
		Leaf = keys.Leaf == true,
		Moon = keys.Moon == true,
		Nearby = nearby ~= nil and nearby ~= false,
		Progress = region and region.Glyph or 0,
		Open = region and region.Model:GetAttribute("PortalOpen") or false,
	}
end
function Adventure:useGlyph(record, glyph)
	if type(glyph) ~= "string" or not Seal.Keys[glyph] then
		return false
	end
	local region = self:nearSeal(record)
	if not region then
		self:notice(record, "Bring your keys to the cave seal altar.")
		return false
	end
	return self:interact(record, region, region.Seal, glyph)
end
function Adventure:interact(record, region, spec, selectedGlyph)
	local now = os.clock()
	local root = record.Player.Character and record.Player.Character:FindFirstChild("HumanoidRootPart")
	if
		record.State ~= "Alive"
		or not record.Ready
		or record.Transit
		or not root
		or self.World.Islands[region.Index] ~= region
		or not spec.Part.Parent
		or not spec.Prompt.Enabled
		or not table.find(region.Interactions, spec)
		or (root.Position - spec.Part.Position).Magnitude > 13
		or now < (record.InteractAt or 0)
		or (record.LastPosition and (root.Position - record.LastPosition).Magnitude > 12)
	then
		return false
	end
	local hum = record.Player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	local ground = Ground.cast(self.World, root, hum)
	if not ground then
		self:notice(record, "Move onto safe ground to collect or operate this item.")
		return false
	end
	record.InteractAt = now + 0.5
	record.Bag = record.Bag or { Timber = 0, Crystal = 0, Herb = 0 }
	local bag, kind = record.Bag, spec.Kind
	if spec.Activity or spec.Event or spec.Breach then
		return self.Objectives ~= nil and self.Objectives:interact(record, region, spec)
	end
	if caps[kind] then
		local cap = caps[kind] + (if record.Perks and record.Perks.Pack then 3 else 0)
		if spec.Claims[record.Player.UserId] then
			self:notice(record, "You already gathered this supply. Find another nearby.")
			return false
		end
		if spec.Stock <= 0 or bag[kind] >= cap then
			self:notice(record, "Pack full, or cache empty.")
			return false
		end
		spec.Stock -= 1
		spec.Claims[record.Player.UserId] = true
		bag[kind] += 1
		self:notice(
			record,
			"+1 " .. Items[kind].Name .. "  |  " .. Items[kind].Key .. ": " .. Items[kind].Use
		)
		self.Effects:FireClient(
			record.Player,
			"Collected",
			{ Id = spec.Id, Node = spec.Part, Kind = kind, Count = bag[kind], Position = spec.Part.Position }
		)
		spec.Prompt.ObjectText = kind .. " cache · " .. spec.Stock .. " left"
		if spec.Stock == 0 then
			spec.Prompt.Enabled = false
			spec.Part.Transparency = 0.8
		end
	elseif kind == "Repair" then
		for _, part in region.Routes.Loop do
			if
				not part.Parent or (part:GetAttribute("Ground") and part:GetAttribute("Phase") ~= "Stable")
			then
				self:notice(
					record,
					"The shortcut is corrupted. Use the sky causeway, elevator, or cave gate."
				)
				return false
			end
		end
		if region.Repair >= 6 then
			self:notice(record, "Shortcut already repaired.")
			return false
		end
		if bag.Timber < 2 then
			self:notice(record, "Find 2 timber. Shared repair: " .. region.Repair .. "/6")
			return false
		end
		bag.Timber -= 2
		region.Repair += 2
		region.Model:SetAttribute("Repair", region.Repair)
		if region.Repair >= 6 then
			for _, p in region.Routes.Loop do
				if p.Parent and p:GetAttribute("Phase") ~= "Breaking" then
					p.Transparency, p.CanCollide, p.CanQuery = 0, true, true
				end
			end
			self:notice(record, "Bridge repaired! Cave and grove now have a direct route.")
		else
			self:notice(record, "Shared bridge repair: " .. region.Repair .. "/6 timber")
		end
	elseif kind == "Glyph" then
		if not Seal.Keys[spec.Extra] or spec.Claims[record.Player.UserId] then
			return false
		end
		record.Glyphs = record.Glyphs or {}
		local keys = record.Glyphs[region.Index] or {}
		record.Glyphs[region.Index] = keys
		keys[spec.Extra] = true
		spec.Claims[record.Player.UserId] = true
		self:notice(
			record,
			spec.Extra .. " key collected! Bring it to the cave altar; E / X places the next key."
		)
		self.Effects:FireClient(record.Player, "Collected", {
			Id = spec.Id,
			Node = spec.Part,
			Kind = spec.Extra,
			Count = 1,
			Position = spec.Part.Position,
		})
	elseif kind == "Seal" then
		if region.Model:GetAttribute("PortalOpen") then
			self:notice(record, "Seal restored. Use the cave gate to escape upward.")
			return false
		end
		local expected = Seal.Order[region.Glyph + 1]
		local glyph = selectedGlyph or expected
		local keys = record.Glyphs and record.Glyphs[region.Index]
		if not keys or not keys[glyph] then
			self:notice(
				record,
				"Collect the " .. glyph .. " key first. Look for the labeled tablets in this cave."
			)
			return false
		end
		-- Keys remain reusable so a wrong order never permanently locks a shared puzzle.
		region.Glyph = if glyph == expected then region.Glyph + 1 else 0
		region.Model:SetAttribute("Glyph", region.Glyph)
		if region.Glyph == 3 then
			region.Model:SetAttribute("PortalOpen", true)
			spec.Prompt.ActionText = "Seal restored - use cave gate"
			self:notice(record, "Seal restored. Cave gate open to everyone.")
		else
			spec.Prompt.ActionText = "Place " .. Seal.Order[region.Glyph + 1] .. " key"
			self:notice(
				record,
				if glyph == expected
					then "Placed "
						.. glyph
						.. ". Next: "
						.. Seal.Order[region.Glyph + 1]
						.. " (E / X or key button)."
					else "Wrong order. Keys kept. Start again: Sun > Leaf > Moon."
			)
		end
	elseif kind == "Portal" then
		if not region.Model:GetAttribute("PortalOpen") then
			if bag.Crystal < 2 then
				self:notice(record, "Align glyphs, or contribute crystals: " .. region.Charge .. "/4")
				return false
			end
			bag.Crystal -= 2
			region.Charge += 2
			if region.Charge >= 4 then
				region.Model:SetAttribute("PortalOpen", true)
			end
			self:notice(record, "Shared gate charge: " .. region.Charge .. "/4")
			return true
		end
		return self.Players:transfer(record, region.Index + 1)
	elseif kind == "Lift" then
		if not self.World.Islands[region.Index + 1] then
			return false
		end
		record.Transit = true
		root.Anchored = true
		local deck = G.part(
			region.Model,
			"SkyElevatorDeck",
			Vector3.new(10, 1, 10),
			CFrame.new(root.Position - Vector3.new(0, 3.5, 0)),
			Color3.fromRGB(122, 99, 69),
			Enum.Material.WoodPlanks
		)
		self.Trips[record] =
			{ From = region.Index, Started = now, Offset = root.Position - region.Center, Deck = deck }
		self:notice(record, "Sky elevator departing. Stay aboard until arrival.")
	elseif kind == "Heal" then
		if bag.Herb < 1 or not hum or hum.Health >= hum.MaxHealth then
			return false
		end
		bag.Herb -= 1
		hum.Health = math.min(hum.MaxHealth, hum.Health + 35)
	elseif kind == "Discover" then
		record.Discoveries = record.Discoveries or {}
		if record.Discoveries[region.Index] then
			-- Revisiting the shrine offers a blessing: spend relics on a random run perk.
			if self.Objectives and self.Objectives:blessing(record) then
				self:notice(record, "The shrine accepts your relics and grants a blessing.")
				return true
			end
			return false
		end
		record.Discoveries[region.Index] = true
		if self.Rewards then
			self.Rewards:bonus(record, 15)
		end
		self:notice(record, "Forgotten shrine found. The cave seal and elevator offer other escapes.")
	end
	self.Effects:FireClient(record.Player, "Discovery", { Kind = kind, Position = spec.Part.Position })
	return true
end
function Adventure:use(record, kind)
	local item = type(kind) == "string" and Items[kind]
	local now = os.clock()
	local root = record.Player.Character and record.Player.Character:FindFirstChild("HumanoidRootPart")
	local hum = record.Player.Character and record.Player.Character:FindFirstChildOfClass("Humanoid")
	if
		not item
		or record.State ~= "Alive"
		or not record.Ready
		or record.Transit
		or not root
		or not hum
		or hum.Health <= 0
		or (record.LastPosition and (root.Position - record.LastPosition).Magnitude > 16)
	then
		return false
	end
	record.ItemCooldowns = record.ItemCooldowns or {}
	if now < (record.ItemCooldowns[kind] or 0) then
		self:notice(record, "That supply is recharging.")
		return false
	end
	if not record.Bag or record.Bag[kind] < item.Cost then
		self:notice(record, "Need " .. item.Cost .. " " .. item.Name .. ". Explore for supplies.")
		return false
	end
	if kind == "Herb" then
		if hum.Health >= hum.MaxHealth then
			self:notice(record, "Health is already full. Herb kept.")
			return false
		end
		hum.Health = math.min(hum.MaxHealth, hum.Health + 40)
	elseif kind == "Crystal" then
		if now < (record.OverchargeUntil or 0) then
			self:notice(record, "Powers are already overcharged.")
			return false
		end
		record.OverchargeUntil = now + 12
		for name, untilTime in record.Cooldowns do
			record.Cooldowns[name] = math.max(now, untilTime - 3)
		end
	elseif kind == "Timber" then
		if not Ground.cast(self.World, root, hum) or not self.World:brace(root.Position, now) then
			self:notice(record, "Stand on intact ground to brace it.")
			return false
		end
		-- Bracing inside a breached shelter also boards up every storm breach in it.
		if self.Objectives then
			self.Objectives:braceShelter(record, root.Position)
		end
	end
	record.Bag[kind] -= item.Cost
	record.ItemCooldowns[kind] = now + item.Cooldown
	self:notice(
		record,
		if kind == "Herb"
			then "Restored 40 health."
			elseif kind == "Crystal" then "OVERCHARGED · stronger powers for 12 seconds; cooldowns reduced."
			else "Ground braced for 18 seconds. The deletion wave remains lethal."
	)
	self.Effects:FireAllClients("ItemUsed", {
		UserId = record.Player.UserId,
		Kind = kind,
		Duration = if kind == "Crystal" then 12 else 1.2,
		Position = root.Position,
	})
	return true
end
function Adventure:cancel(record)
	local trip = self.Trips[record]
	if trip and trip.Deck.Parent then
		trip.Deck:Destroy()
	end
	local root = record.Player.Character and record.Player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
	end
	record.Transit = nil
	self.Trips[record] = nil
end
function Adventure:update()
	for record, trip in self.Trips do
		local root = record.Player.Character and record.Player.Character:FindFirstChild("HumanoidRootPart")
		local source = self.World.Islands[trip.From]
		local target = self.World.Islands[trip.From + 1]
		if record.State ~= "Alive" or not root or not source or not target then
			self:cancel(record)
			continue
		end
		local t = math.clamp((os.clock() - trip.Started) / (if source.ExpressLift then 8 else 14), 0, 1)
		local a = source.Center + trip.Offset
		local b = self.World:point(trip.From + 1) + Vector3.new(0, 4, 0)
		root.CFrame = CFrame.new(a:Lerp(b, t) + Vector3.new(0, math.sin(t * math.pi) * 32, 0))
		trip.Deck.CFrame = root.CFrame * CFrame.new(0, -3.5, 0)
		record.LastPosition, record.LastCheck = root.Position, os.clock()
		if t >= 1 then
			self:cancel(record)
			self.Players:transfer(record, trip.From + 1)
		end
	end
end
return Adventure
