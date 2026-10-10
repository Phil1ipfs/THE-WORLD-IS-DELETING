--!nonstrict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Rules)
local RewardManager = {}
RewardManager.__index = RewardManager
function RewardManager.new(data, effects)
	return setmetatable({ Data = data, Effects = effects }, RewardManager)
end
function RewardManager:refresh(player)
	local profile = self.Data:get(player)
	if not profile then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	for name, value in { Best = profile.Best, Coins = profile.Coins, Level = Rules.level(profile.XP) } do
		local stat = stats:FindFirstChild(name)
		if not stat then
			stat = Instance.new("IntValue")
			stat.Name = name
			stat.Parent = stats
		end
		stat.Value = value
	end
end
function RewardManager:finish(record)
	if record.Rewarded then
		return
	end
	record.Rewarded = true
	local profile = self.Data:get(record.Player)
	if not profile then
		return
	end
	local previous = profile.Best
	local reward = Rules.reward(record.Peak, record.Finished or 0)
	profile.Best = math.max(profile.Best, record.Peak)
	profile.Coins += reward.Coins
	profile.XP += reward.XP
	profile.Survival += math.floor(record.Finished or 0)
	self:refresh(record.Player)
	record.Result = {
		Altitude = record.Peak,
		Previous = previous,
		Coins = reward.Coins + (record.BonusCoins or 0),
		Duration = math.floor(record.Finished or 0),
		Reason = record.Reason,
	}
	self.Effects:FireClient(record.Player, "Eliminated", record.Result)
end
function RewardManager:bonus(record, amount)
	local profile = self.Data:get(record.Player)
	if not profile or record.State ~= "Alive" then
		return
	end
	profile.Coins += amount
	record.BonusCoins = (record.BonusCoins or 0) + amount
	self:refresh(record.Player)
end
return RewardManager
