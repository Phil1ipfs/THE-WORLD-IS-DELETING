--!nonstrict
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.GameConfig)
local Rules = require(Shared.Rules)
local DataManager = {}
DataManager.__index = DataManager
function DataManager.new()
	local enabled = not RunService:IsStudio() or Config.StudioPersistence
	return setmetatable({
		Enabled = enabled,
		Store = if enabled then DataStoreService:GetDataStore("FloatingRealms_v1") else nil,
		Board = if enabled then DataStoreService:GetOrderedDataStore("FloatingRealms_Best_v1") else nil,
		Owner = game.JobId .. ":" .. HttpService:GenerateGUID(false),
		Entries = {},
		Closing = false,
		LastSave = os.clock(),
		BoardCache = {},
		LastBoard = -100,
	}, DataManager)
end
local function retry(callback)
	local last
	for attempt = 1, 3 do
		local ok, value = pcall(callback)
		if ok then
			return true, value
		end
		last = value
		if attempt < 3 then
			task.wait(attempt + math.random() * 0.4)
		end
	end
	return false, last
end
function DataManager:load(player)
	if self.Closing then
		return nil, "Server is closing"
	end
	if not self.Enabled then
		local entry = { Profile = Rules.profile(nil), Busy = false, Persistent = false, Lost = false }
		self.Entries[player] = entry
		return entry.Profile
	end
	local denied = false
	local ok, result = retry(function()
		return self.Store:UpdateAsync("p_" .. player.UserId, function(old)
			old = if type(old) == "table" then old else {}
			if not Rules.canLease(old.Lock, self.Owner, os.time()) then
				denied = true
				return nil
			end
			denied = false
			return {
				Profile = Rules.profile(old.Profile),
				Lock = { Owner = self.Owner, Expires = os.time() + Config.SessionLease },
			}
		end)
	end)
	if not ok or denied or not result then
		warn("Profile load denied", player.UserId, if denied then "session conflict" else tostring(result))
		return nil,
			if denied
				then "Your previous session is still saving. Please rejoin shortly."
				else "Your data could not be loaded safely. Please rejoin."
	end
	local entry = {
		Profile = Rules.profile(result.Profile),
		Busy = false,
		Persistent = true,
		Lost = false,
		Expires = result.Lock.Expires,
	}
	self.Entries[player] = entry
	return entry.Profile
end
function DataManager:get(player)
	local entry = self.Entries[player]
	if entry and entry.Persistent and not entry.Lost and os.time() >= entry.Expires then
		entry.Lost = true
		player:Kick("Your data session could not be renewed. Please rejoin to protect your progress.")
	end
	return if entry and not entry.Lost then entry.Profile else nil
end
function DataManager:save(player, release)
	local entry = self.Entries[player]
	if not entry then
		return true
	end
	local deadline = os.clock() + 12
	while entry.Busy and os.clock() < deadline do
		task.wait(0.1)
	end
	if entry.Busy or entry.Lost then
		if release and entry.Lost then
			self.Entries[player] = nil
		end
		return false
	end
	if self.Entries[player] ~= entry then
		return true
	end
	if not entry.Persistent then
		if release then
			self.Entries[player] = nil
		end
		return true
	end
	entry.Busy = true
	local snapshot = Rules.profile(entry.Profile)
	local lost = false
	local ok, result = retry(function()
		return self.Store:UpdateAsync("p_" .. player.UserId, function(old)
			if type(old) ~= "table" or type(old.Lock) ~= "table" or old.Lock.Owner ~= self.Owner then
				lost = true
				return nil
			end
			return {
				Profile = snapshot,
				Lock = if release
					then nil
					else { Owner = self.Owner, Expires = os.time() + Config.SessionLease },
			}
		end)
	end)
	entry.Busy = false
	if lost then
		entry.Lost = true
		player:Kick("Your data session changed. Please rejoin to keep your progress safe.")
	end
	if not ok or not result then
		warn("Profile save failed", player.UserId, tostring(result))
		return false
	end
	if not release then
		entry.Expires = result.Lock.Expires
	end
	-- Global ranking failures never invalidate a successful profile save.
	if snapshot.Best > (entry.SavedBest or -1) then
		entry.SavedBest = snapshot.Best
		task.spawn(function()
			local boardOk, err = retry(function()
				self.Board:UpdateAsync(tostring(player.UserId), function(old)
					return math.max(old or 0, snapshot.Best)
				end)
			end)
			if not boardOk then
				entry.SavedBest = nil
				warn("Ranking save failed", err)
			end
		end)
	end
	if release then
		self.Entries[player] = nil
	end
	return true
end
function DataManager:update()
	if self.Closing or os.clock() - self.LastSave < Config.AutosaveInterval then
		return
	end
	self.LastSave = os.clock()
	for player in self.Entries do
		task.spawn(function()
			self:save(player, player.Parent == nil)
		end)
	end
end
function DataManager:leaderboard()
	if not self.Enabled then
		return {}
	end
	if os.clock() - self.LastBoard > 60 then
		self.LastBoard = os.clock()
		local ok, pages = pcall(function()
			return self.Board:GetSortedAsync(false, 20)
		end)
		if ok then
			self.BoardCache = pages:GetCurrentPage()
		end
	end
	return self.BoardCache
end
function DataManager:shutdown()
	self.Closing = true
	local pending = 0
	for player in self.Entries do
		pending += 1
		task.spawn(function()
			self:save(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	if pending > 0 then
		warn("Shutdown save deadline exceeded", pending)
	end
end
return DataManager
