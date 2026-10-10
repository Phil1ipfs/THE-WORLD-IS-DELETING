--!nonstrict
local Director = {}
local Quake = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").DisasterConfig).Earthquake
Director.__index = Director
local names = { "Storm", "Earthquake", "StructureCollapse", "DeletionSurge" }
function Director.new(world, players, wave, effects)
	return setmetatable({
		World = world,
		Players = players,
		Wave = wave,
		Effects = effects,
		Sequence = 0,
		Next = 35,
		LastDamage = 0,
		Phase = "Calm",
		Name = "Calm",
	}, Director)
end
function Director:reset()
	self.LastDamage = 0
	self.Until = nil
	self.Sequence, self.Next, self.Phase, self.Name = 0, 35, "Calm", "Calm"
	self.Wave.Surge = 1
	workspace:SetAttribute("WorldEvent", "Calm")
	workspace:SetAttribute("EventPhase", "Calm")
end
function Director:update(elapsed)
	if self.Phase == "Calm" and elapsed >= self.Next then
		self.Sequence += 1
		self.Name = names[(self.Sequence - 1) % #names + 1]
		self.Phase, self.Until = "Warning", elapsed + 8
		self.Effects:FireAllClients("WorldEvent", { Name = self.Name, Phase = "Warning" })
	elseif self.Phase == "Warning" and elapsed >= self.Until then
		self.Phase, self.Until = "Active", elapsed + 16
		if self.Name == "DeletionSurge" then
			self.Wave.Surge = 3
		end
		if self.Name == "Earthquake" or self.Name == "StructureCollapse" then
			local visited = {}
			for _, record in self.Players:active() do
				local root = record.Player.Character
					and record.Player.Character:FindFirstChild("HumanoidRootPart")
				if root and not record.Transit then
					visited[record.Region] = visited[record.Region] or {}
					table.insert(visited[record.Region], root.Position)
				end
			end
			local regions = 0
			for _ in visited do
				regions += 1
			end
			for index, positions in visited do
				if self.Name == "Earthquake" then
					self.World:earthquake(
						index,
						positions,
						math.min(Quake.CellsPerRegion, math.floor(Quake.TotalCells / regions)),
						math.min(Quake.SurfaceCount, math.floor(Quake.TotalSurfaces / regions))
					)
				else
					self.World:destabilize(index, 5, true)
				end
			end
		end
		self.Effects:FireAllClients("WorldEvent", { Name = self.Name, Phase = "Active" })
	elseif self.Phase == "Active" and elapsed >= self.Until then
		self.Phase, self.Name, self.Next = "Calm", "Calm", elapsed + 32
		self.Until = nil
		self.Wave.Surge = 1
		self.Effects:FireAllClients("WorldEvent", { Name = "Calm", Phase = "Calm" })
	end
	workspace:SetAttribute("WorldEvent", self.Name)
	workspace:SetAttribute("EventPhase", self.Phase)
	if self.Phase == "Active" and self.Name == "Storm" and elapsed - self.LastDamage >= 2 then
		self.LastDamage = elapsed
		for _, record in self.Players:active() do
			local root = record.Player.Character
				and record.Player.Character:FindFirstChild("HumanoidRootPart")
			if root and not record.Transit and not self.World:sheltered(root.Position) then
				self.Players:damage(record, 8)
			elseif root and not record.Transit and self.Objectives then
				-- Breached shelters leak; fortified shelters heal (see ObjectiveService).
				local leak = self.Objectives:shelterDamage(record, root.Position)
				if leak > 0 then
					self.Players:damage(record, leak)
				end
			end
		end
	end
end
return Director
