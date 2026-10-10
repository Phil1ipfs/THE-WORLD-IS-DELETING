--!nonstrict
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").GameConfig)
local Round = {}
Round.__index = Round
function Round.new(world, wave, players, effects)
	return setmetatable({
		State = "Waiting",
		World = world,
		Wave = wave,
		Players = players,
		Effects = effects,
		Number = 0,
		Started = 0,
		Ends = 0,
	}, Round)
end
function Round:queue(record)
	if not record.Ready then
		return
	end
	if record.State == "Lobby" or record.State == "Eliminated" or record.State == "Spectating" then
		self.Players:transition(record, "Queued")
	end
	-- The countdown starts on the click itself (no wait for the next tick).
	if self.State == "Waiting" and record.State == "Queued" then
		self.State, self.Ends = "Intermission", os.clock() + Config.Intermission
	end
	if
		self.State == "Running"
		and os.clock() - self.Started < Config.JoinWindow
		and self.Wave.Height < Config.StartY - 12
	then
		self.Players:begin(record)
	end
end
-- Leaves the queue; an empty intermission returns to Waiting on the next update.
function Round:cancel(record)
	if record.State == "Queued" then
		return self.Players:transition(record, "Lobby")
	end
	return false
end
function Round:queued()
	local count = 0
	for _, record in self.Players.Records do
		if record.State == "Queued" and record.Ready then
			count += 1
		end
	end
	return count
end
function Round:update(dt)
	local now = os.clock()
	local queued = {}
	for _, record in self.Players.Records do
		if record.State == "Queued" and record.Ready then
			table.insert(queued, record)
		end
	end
	if self.State == "Waiting" and #queued > 0 then
		self.State, self.Ends = "Intermission", now + Config.Intermission
	elseif self.State == "Intermission" and #queued == 0 then
		self.State = "Waiting"
	elseif self.State == "Intermission" and now >= self.Ends then
		self.Number += 1
		self.World:reset(Config.Seed + self.Number * 1709)
		self.Wave:reset()
		if self.Events then
			self.Events:reset()
		end
		if self.Objectives then
			self.Objectives:reset()
		end
		self.State, self.Started = "Running", now
		for _, record in queued do
			self.Players:begin(record)
		end
	elseif self.State == "Running" then
		local elapsed = now - self.Started
		if self.Adventure then
			self.Adventure:update()
		end
		if self.Objectives then
			self.Objectives:tick(dt)
		end
		if self.Events then
			self.Events:update(elapsed)
		end
		local leaderY = Config.StartY
		for _, record in self.Players:active() do
			leaderY = math.max(leaderY, Config.StartY + record.Peak)
		end
		self.Wave:update(dt, elapsed, self.World.Origin, leaderY)
		local highest = self.Players:update(self.Wave.Height)
		self.World:consume(self.Wave.Height)
		self.World:generate(highest)
		if
			highest - self.World.Origin > Config.RebaseAt
			and self.Wave.Height - self.World.Origin > Config.RebaseAmount + 80
		then
			self.World:rebase(Config.RebaseAmount)
			self.Players:rebase(Config.RebaseAmount)
			self.Wave:update(0, elapsed, self.World.Origin, highest)
			self.Effects:FireAllClients("Rebase", Config.RebaseAmount)
		end
		if #self.Players:active() == 0 then
			if self.Events then
				self.Events:reset()
			end
			self.State = "Waiting"
			self.Effects:FireAllClients("RoundEnd")
		end
	end
end
return Round
