--!nonstrict
-- Sky Balloon: the server-owned ride to the next region (replaces the 0.6 sky elevator).
-- Station states: Docked -> Boarding (shared 5 s countdown; more riders may join) -> Flight
-- -> Returning (turnaround) -> Docked. One flight per station at a time, so a departure can
-- never be triggered twice. Riders are anchored, flagged in Transit (no abilities, no movement
-- audit, no wave/ocean checks) and released through PlayerManager:transfer on arrival, which is
-- the only place progression (Region, Peak, activation) changes. Death, leaving, returning to
-- the sanctuary or losing the target region releases a rider safely.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.BalloonConfig)
local BalloonModel = require(script.Parent.Parent.Services.BalloonModel)
local Balloon = {}
Balloon.__index = Balloon
function Balloon.new(world, players, effects)
	return setmetatable({
		World = world,
		Players = players,
		Effects = effects,
		Stations = {}, -- region -> station
		Riders = {}, -- record -> station
	}, Balloon)
end
local function rootOf(record)
	local character = record.Player.Character
	return character and character:FindFirstChild("HumanoidRootPart"),
		character and character:FindFirstChildOfClass("Humanoid")
end
function Balloon:notice(record, text)
	self.Effects:FireClient(record.Player, "Notice", text)
end
-- Called when the station prompt is registered (region attach).
function Balloon:attach(region, spec)
	if not region.Balloon or self.Stations[region] then
		return
	end
	local station = {
		Region = region,
		Spec = spec,
		Index = region.Index,
		Local = region.Balloon.Local,
		Variant = region.Balloon.Variant,
		Built = region.Balloon.Built,
		State = "Docked",
		Riders = {},
	}
	spec.Prompt.ObjectText = "Sky Balloon"
	self.Stations[region] = station
	self:sign(station)
end
-- World CFrame of the gondola base at this station (follows rebasing through region.Center).
function Balloon:base(station)
	return CFrame.new(self.World:point(station.Index)) * station.Local
end
function Balloon:sign(station, text)
	local built = station.Built
	if built and built.Label and built.Label.Parent then
		built.Label.Text = text
			or (
				"SKY BALLOON\n"
				.. (
					if station.State == "Docked"
						then "Board for the next realm"
						elseif station.State == "Boarding" then "Departing soon: board now!"
						else "Away: next balloon docking soon"
				)
			)
	end
	local prompt = station.Spec.Prompt
	if prompt then
		prompt.ActionText = if station.State == "Docked"
			then "Board the Sky Balloon"
			elseif station.State == "Boarding" then "Board now (departing)"
			else "Balloon away"
	end
end
local function seat(record, i, base)
	local root = rootOf(record)
	if root then
		local offset = Config.Seats[(i - 1) % #Config.Seats + 1]
		root.CFrame = base * CFrame.new(offset[1], 4.2, offset[2])
		root.AssemblyLinearVelocity = Vector3.zero
		record.LastPosition, record.LastCheck = root.Position, os.clock()
	end
end
-- AdventureService has already validated life, range, trusted position and ground support.
function Balloon:interact(record, region, spec)
	local station = self.Stations[region]
	if not station or station.Spec ~= spec then
		return false
	end
	if self.Riders[record] then
		return false
	end
	local now = os.clock()
	if station.State == "Flight" or station.State == "Returning" then
		self:notice(
			record,
			"The Sky Balloon is away. The next one docks in "
				.. math.max(1, math.ceil((station.ReturnAt or now + Config.Flight) - now))
				.. "s, or walk the sky causeway."
		)
		return false
	end
	if record.Region ~= region.Index then
		self:notice(record, "This balloon serves explorers of this realm. Climb on from where you are.")
		return false
	end
	local target = self.World.Islands[region.Index + 1]
	if not target or not target.Landing.Parent or not target.Landing.CanCollide then
		self:notice(record, "The next realm is out of reach. Take the sky causeway.")
		return false
	end
	if #station.Riders >= Config.Capacity then
		self:notice(record, "The balloon is full. Wait for the next one or take the causeway.")
		return false
	end
	local root = rootOf(record)
	if not root then
		return false
	end
	table.insert(station.Riders, record)
	self.Riders[record] = station
	record.Transit = true
	root.Anchored = true
	if station.State == "Docked" then
		station.State, station.DepartAt = "Boarding", now + Config.Countdown
		-- Everyone nearby learns that boarding is open, not only the first rider.
		for _, other in self.Players:active() do
			local otherRoot = rootOf(other)
			if other ~= record and otherRoot and (otherRoot.Position - root.Position).Magnitude < 160 then
				self:notice(other, "The Sky Balloon departs in " .. Config.Countdown .. "s. Board now!")
			end
		end
	end
	seat(record, #station.Riders, self:base(station))
	self:notice(
		record,
		"Aboard the Sky Balloon. Departing in "
			.. math.max(1, math.ceil(station.DepartAt - now))
			.. "s. Stay aboard until arrival."
	)
	self.Effects:FireClient(record.Player, "Balloon", { Phase = "Boarded", Departs = station.DepartAt - now })
	self:sign(station)
	return true
end
-- Releases one rider (death, leaving, sanctuary, cancelled flight). Never grants progression.
function Balloon:release(record)
	local station = self.Riders[record]
	self.Riders[record] = nil
	if station then
		local i = table.find(station.Riders, record)
		if i then
			table.remove(station.Riders, i)
		end
	end
	local root = rootOf(record)
	if root then
		root.Anchored = false
	end
	record.Transit = nil
	return station ~= nil
end
function Balloon:status(record)
	local station = self.Riders[record]
	if not station then
		return nil
	end
	local now = os.clock()
	return {
		Phase = station.State,
		Departs = if station.State == "Boarding" then math.max(0, math.ceil(station.DepartAt - now)) else 0,
		Progress = if station.State == "Flight"
			then math.clamp((now - station.Started) / station.Duration, 0, 1)
			else 0,
		Riders = #station.Riders,
	}
end
local function setPropulsion(built, on)
	if built and built.Propulsion and built.Propulsion.Parent then
		built.Propulsion.Enabled = on
	end
end
function Balloon:depart(station, now)
	local target = self.World.Islands[station.Index + 1]
	if not target or not target.Landing.Parent or not target.Landing.CanCollide then
		for _, record in table.clone(station.Riders) do
			self:release(record)
			self:notice(record, "The way ahead collapsed. The balloon stays docked.")
		end
		station.State = "Docked"
		self:sign(station)
		return
	end
	station.State, station.Started = "Flight", now
	station.Duration = if station.Region.ExpressLift then Config.ExpressFlight else Config.Flight
	station.From = self:base(station)
	-- The flying balloon belongs to the world, so its departure region may delete beneath it.
	-- World:reset clears the world root (destroying the folder), so recreate it when needed.
	if not self.Flights or self.Flights.Parent ~= self.World.Root then
		self.Flights = Instance.new("Folder")
		self.Flights.Name = "BalloonFlights"
		self.Flights.Parent = self.World.Root
	end
	if station.Built and station.Built.Model.Parent then
		station.Built.Model.Parent = self.Flights
	end
	setPropulsion(station.Built, true)
	for _, record in station.Riders do
		self.Effects:FireClient(record.Player, "Balloon", { Phase = "Depart", Duration = station.Duration })
		self:notice(record, "Lift-off! Ascending to the next realm.")
	end
	self:sign(station, "SKY BALLOON\nAscending to the next realm")
end
function Balloon:arrive(station, now)
	local index = station.Index + 1
	for _, record in table.clone(station.Riders) do
		self:release(record)
		if self.Players:transfer(record, index) then
			local region = self.World.Islands[index]
			self.Effects:FireClient(record.Player, "Balloon", { Phase = "Arrive" })
			self:notice(
				record,
				"Touched down"
					.. (if region then " at " .. region.Model:GetAttribute("RegionName") else "")
					.. ". Progress saved to this realm."
			)
		end
	end
	setPropulsion(station.Built, false)
	station.State, station.ReturnAt = "Returning", now + Config.Turnaround
	if station.Built then
		station.Built.Model:Destroy()
		station.Built = nil
	end
end
function Balloon:dock(station)
	local region = station.Region
	local anchor = station.Spec.Part
	if self.World.Islands[station.Index] ~= region or not anchor.Parent then
		station.State = "Lost"
		return
	end
	station.Built = BalloonModel.build(region.Model, self:base(station), station.Variant)
	station.State = "Docked"
	self:sign(station)
end
function Balloon:update()
	local now = os.clock()
	for region, station in self.Stations do
		-- Riders who died, left or lost their character are released (never transferred).
		for _, record in table.clone(station.Riders) do
			local root, hum = rootOf(record)
			if record.State ~= "Alive" or not root or not hum or hum.Health <= 0 then
				self:release(record)
			end
		end
		if station.State == "Boarding" then
			local stationGone = self.World.Islands[station.Index] ~= region or not station.Spec.Part.Parent
			if #station.Riders == 0 or stationGone then
				for _, record in table.clone(station.Riders) do
					self:release(record)
				end
				station.State = if stationGone then "Lost" else "Docked"
				self:sign(station)
			else
				local base = self:base(station)
				for i, record in station.Riders do
					seat(record, i, base)
				end
				self:sign(
					station,
					"SKY BALLOON\nDeparting in "
						.. math.max(1, math.ceil(station.DepartAt - now))
						.. "  ·  "
						.. #station.Riders
						.. "/"
						.. Config.Capacity
						.. " aboard"
				)
				if now >= station.DepartAt then
					self:depart(station, now)
				end
			end
		elseif station.State == "Flight" then
			local target = self.World.Islands[station.Index + 1]
			if not target or not target.Landing.Parent then
				-- Destination deleted mid-flight: drop riders safely back on the departure landing
				-- if it still exists, otherwise release them where they are.
				local source = self.World.Islands[station.Index]
				for _, record in table.clone(station.Riders) do
					self:release(record)
					local root = rootOf(record)
					if root and source and source.Landing.Parent and source.Landing.CanCollide then
						root.CFrame = CFrame.new(self.World:point(station.Index) + Vector3.new(0, 4, 0))
						record.LastPosition, record.LastCheck = root.Position, now
					end
					self:notice(record, "The destination fell away. The balloon turned back.")
				end
				setPropulsion(station.Built, false)
				if station.Built then
					station.Built.Model:Destroy()
					station.Built = nil
				end
				station.State, station.ReturnAt = "Returning", now + Config.Turnaround
			else
				local t = math.clamp((now - station.Started) / station.Duration, 0, 1)
				local eased = t * t * (3 - 2 * t)
				local a = station.From.Position
				local b = self.World:point(station.Index + 1) + Vector3.new(0, 0.15, 0)
				-- Rebasing shifts physical Y; keep the departure point in the current frame.
				a = Vector3.new(a.X, self:base(station).Position.Y, a.Z)
				local position = a:Lerp(b, eased) + Vector3.new(0, math.sin(t * math.pi) * Config.Climb, 0)
				local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
				local heading = if flat.Magnitude > 1 then flat.Unit else Vector3.new(0, 0, -1)
				local base = CFrame.lookAt(position, position + heading)
					* CFrame.Angles(0, 0, math.sin(now * 1.3) * 0.03)
				if station.Built and station.Built.Model.Parent then
					station.Built.Model:PivotTo(base)
				end
				for i, record in station.Riders do
					seat(record, i, base)
				end
				if t >= 1 then
					self:arrive(station, now)
				end
			end
		elseif station.State == "Returning" and now >= (station.ReturnAt or 0) then
			self:dock(station)
		end
		if station.State == "Lost" then
			self.Stations[region] = nil
		end
	end
end
-- Region removed: release boarding riders there; flights to a removed region abort in update.
function Balloon:detach(region)
	local station = self.Stations[region]
	if not station then
		return
	end
	if station.State == "Boarding" then
		for _, record in table.clone(station.Riders) do
			self:release(record)
		end
	end
	if station.State ~= "Flight" then
		self.Stations[region] = nil
	else
		station.Detached = true
	end
	-- A flight already under way keeps its riders and lands normally (its model lives in Flights).
end
-- Round reset: release everyone and forget every station.
function Balloon:reset()
	for record in table.clone(self.Riders) do
		self:release(record)
	end
	for _, station in self.Stations do
		if station.Built and self.Flights and station.Built.Model.Parent == self.Flights then
			station.Built.Model:Destroy()
		end
	end
	table.clear(self.Stations)
end
return Balloon
