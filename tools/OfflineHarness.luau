--!nonstrict
-- Lune fixture for executing production modules with Roblox datatypes and Instances.
-- These shims do NOT provide Roblox physics, replication, rendering or live services.
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Harness = {}
local pivots, signals = {}, {}
local proxies, natives = {}, {}
local replicationFocus = {}
local wrap, unwrap
unwrap = function(value)
	if type(value) == "table" then
		if natives[value] then
			return natives[value]
		end
		local result = {}
		for key, item in value do
			result[key] = unwrap(item)
		end
		return result
	end
	return value
end
wrap = function(value)
	if typeof(value) == "Instance" then
		if proxies[value] then
			return proxies[value]
		end
		local proxy = {}
		proxies[value], natives[proxy] = proxy, value
		return setmetatable(proxy, {
			__index = function(_, key)
				if key == "ReplicationFocus" and value:IsA("Player") then
					return replicationFocus[value]
				end
				if key == "Position" and value:IsA("BasePart") then
					return value.CFrame.Position
				end
				if key == "FloorMaterial" and value:IsA("Humanoid") then
					return if value:GetAttribute("Airborne")
						then roblox.Enum.Material.Air
						else roblox.Enum.Material.Slate
				end
				local member = value[key]
				if type(member) == "function" then
					return function(_, ...)
						local args = table.pack(...)
						for i = 1, args.n do
							args[i] = unwrap(args[i])
						end
						return wrap(member(value, table.unpack(args, 1, args.n)))
					end
				end
				return wrap(member)
			end,
			__newindex = function(_, key, item)
				if key == "ReplicationFocus" and value:IsA("Player") then
					replicationFocus[value] = item
				elseif key == "Position" and value:IsA("BasePart") then
					value.CFrame = value.CFrame - value.CFrame.Position + item
				else
					value[key] = unwrap(item)
				end
			end,
			__tostring = function()
				return tostring(value)
			end,
		})
	elseif type(value) == "table" then
		local result = {}
		for key, item in value do
			result[key] = wrap(item)
		end
		return result
	end
	return value
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			callbacks[fn] = true
			return {
				Disconnect = function()
					callbacks[fn] = nil
				end,
			}
		end,
		Fire = function(_, ...)
			for fn in callbacks do
				fn(...)
			end
		end,
	}
end
roblox.implementMethod("Instance", "WaitForChild", function(instance, name)
	return assert(instance:FindFirstChild(name), instance:GetFullName() .. "." .. name .. " missing")
end)
roblox.implementProperty("Instance", "DescendantAdded", function(instance)
	signals[instance] = signals[instance] or signal()
	return signals[instance]
end)
roblox.implementProperty("Humanoid", "Died", function(instance)
	signals[instance] = signals[instance] or signal()
	return signals[instance]
end)
roblox.implementProperty("ProximityPrompt", "Triggered", function(instance)
	signals[instance] = signals[instance] or signal()
	return signals[instance]
end)
roblox.implementProperty("Humanoid", "StateChanged", function(instance)
	signals[instance] = signals[instance] or signal()
	return signals[instance]
end)
roblox.implementProperty("GuiButton", "Activated", function(instance)
	signals[instance] = signals[instance] or signal()
	return signals[instance]
end)
roblox.implementProperty("Player", "CharacterAdded", function(instance)
	signals[instance] = signals[instance] or signal()
	return signals[instance]
end)
roblox.implementProperty("UserInputService", "JumpRequest", function(instance)
	signals[instance] = signals[instance] or signal()
	return signals[instance]
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function()
	return signal()
end)
roblox.implementMethod("Sound", "Play", function() end)
roblox.implementMethod("Sound", "Stop", function() end)
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
roblox.implementMethod("ParticleEmitter", "Clear", function() end)
roblox.implementMethod("GuiService", "IsTenFootInterface", function()
	return false
end)
roblox.implementMethod("ContextActionService", "BindAction", function() end)
roblox.implementMethod("Debris", "AddItem", function() end)
roblox.implementMethod("TweenService", "Create", function(_, instance, _, goal)
	return {
		Play = function()
			for key, value in goal do
				instance[key] = value
			end
		end,
	}
end)
roblox.implementProperty("Humanoid", "FloorMaterial", function(instance)
	return if instance:GetAttribute("Airborne") then roblox.Enum.Material.Air else roblox.Enum.Material.Slate
end)
roblox.implementMethod("Humanoid", "TakeDamage", function(instance, amount)
	instance.Health -= amount
end)
roblox.implementProperty("BasePart", "Position", function(instance)
	return instance.CFrame.Position
end, function(instance, value)
	instance.CFrame = instance.CFrame - instance.CFrame.Position + value
end)
roblox.implementMethod("Model", "GetPivot", function(instance)
	if instance.PrimaryPart then
		return instance.PrimaryPart.CFrame
	end
	if pivots[instance] then
		return pivots[instance]
	end
	local min, max = roblox.Vector3.new(1e9, 1e9, 1e9), roblox.Vector3.new(-1e9, -1e9, -1e9)
	for _, part in instance:GetDescendants() do
		if part:IsA("BasePart") then
			local p = part.CFrame.Position
			min = roblox.Vector3.new(math.min(min.X, p.X), math.min(min.Y, p.Y), math.min(min.Z, p.Z))
			max = roblox.Vector3.new(math.max(max.X, p.X), math.max(max.Y, p.Y), math.max(max.Z, p.Z))
		end
	end
	return roblox.CFrame.new((min + max) / 2)
end)
roblox.implementMethod("Model", "PivotTo", function(instance, cf)
	local delta = cf * instance:GetPivot():Inverse()
	for _, part in instance:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = delta * part.CFrame
		elseif part:IsA("Model") and pivots[part] then
			pivots[part] = delta * pivots[part]
		end
	end
	pivots[instance] = cf
end)
roblox.implementMethod("PhysicsService", "RegisterCollisionGroup", function() end)
roblox.implementMethod("PhysicsService", "CollisionGroupSetCollidable", function() end)
roblox.implementMethod("Player", "LoadCharacterAsync", function(player)
	if player.Character then
		player.Character:Destroy()
	end
	local character = roblox.Instance.new("Model")
	character.Name = player.Name
	local root = roblox.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = character
	local hum = roblox.Instance.new("Humanoid")
	hum.Parent = character
	hum.Health = 100
	character.PrimaryPart = root
	player.Character = character
	character.Parent = player.Parent.Parent:GetService("Workspace")
end)
roblox.implementMethod("Player", "Kick", function(player, reason)
	player:SetAttribute("Kicked", reason)
end)

function Harness.new()
	local self = {
		Game = roblox.deserializePlace(fs.readFile("build/FloatingRealms.rbxlx")),
		Time = 0,
		UnixTime = 1000000,
		Events = {},
		Queue = {},
		Stores = {},
		Failures = 0,
		Persistent = false,
	}
	self.Game = wrap(self.Game)
	local game = self.Game
	game.JobId = "offline-fixture"
	self.Workspace = game:GetService("Workspace")
	-- Roblox provides this singleton automatically; Rojo/Lune's bare XML omits it.
	if not self.Workspace:FindFirstChildOfClass("Terrain") then
		local terrain = roblox.Instance.new("Terrain")
		terrain.Name, terrain.Parent = "Terrain", unwrap(self.Workspace)
	end
	roblox.implementMethod("RunService", "IsStudio", function()
		return not self.Persistent
	end)
	roblox.implementMethod("HttpService", "GenerateGUID", function()
		return "offline-" .. tostring(self.Time)
	end)
	roblox.implementMethod("DataStoreService", "GetDataStore", function(_, name)
		self.Stores[name] = self.Stores[name] or {}
		local store = self.Stores[name]
		return {
			UpdateAsync = function(_, key, callback)
				if self.Failures > 0 then
					self.Failures -= 1
					error("Injected DataStore failure")
				end
				local value = callback(store[key])
				if value ~= nil then
					store[key] = value
				end
				return value
			end,
		}
	end)
	roblox.implementMethod("DataStoreService", "GetOrderedDataStore", function(_, name)
		self.Stores[name] = self.Stores[name] or {}
		local store = self.Stores[name]
		return {
			UpdateAsync = function(_, key, callback)
				store[key] = callback(store[key])
				return store[key]
			end,
			GetSortedAsync = function()
				local list = {}
				for key, value in store do
					table.insert(list, { key = key, value = value })
				end
				table.sort(list, function(a, b)
					return a.value > b.value
				end)
				return {
					GetCurrentPage = function()
						return list
					end,
				}
			end,
		}
	end)
	-- Analytic segment/oriented-box intersections; no physics or contact solver.
	roblox.implementMethod("Workspace", "Raycast", function(_, origin, direction, params)
		local best, bestT
		for _, root in params.FilterDescendantsInstances do
			for _, part in root:GetDescendants() do
				if part:IsA("BasePart") and part.CanQuery and part.CanCollide then
					local o = part.CFrame:PointToObjectSpace(origin)
					local d = part.CFrame:VectorToObjectSpace(direction)
					local near, far = 0, 1
					for _, axis in { "X", "Y", "Z" } do
						local half = part.Size[axis] / 2
						if math.abs(d[axis]) < 1e-8 then
							if math.abs(o[axis]) > half then
								far = -1
								break
							end
						else
							local t0, t1 = (-half - o[axis]) / d[axis], (half - o[axis]) / d[axis]
							near = math.max(near, math.min(t0, t1))
							far = math.min(far, math.max(t0, t1))
						end
					end
					if near <= far and (not bestT or near < bestT) then
						best, bestT = part, near
					end
				end
			end
		end
		return if best then { Instance = best, Position = origin + direction * bestT } else nil
	end)
	local cache, loading = {}, {}
	local environment = table.clone(roblox)
	environment.Instance = {
		new = function(class)
			return wrap(roblox.Instance.new(class))
		end,
	}
	environment.game, environment.workspace = game, self.Workspace
	environment.RaycastParams = {
		new = function()
			return {}
		end,
	}
	environment.TweenInfo = {
		new = function(...)
			return { ... }
		end,
	}
	environment.task = {
		spawn = function(fn, ...)
			fn(...)
			return coroutine.create(function() end)
		end,
		defer = function(fn, ...)
			fn(...)
		end,
		delay = function(seconds, fn)
			table.insert(self.Queue, { At = self.Time + seconds, Fn = fn })
		end,
		wait = function(seconds)
			self.Time += seconds or 0.03
			return seconds or 0.03
		end,
	}
	environment.os = table.clone(os)
	environment.os.clock = function()
		return self.Time
	end
	environment.os.time = function()
		return self.UnixTime + math.floor(self.Time)
	end
	local function load(module)
		assert(module and module:IsA("ModuleScript"), "require target must be ModuleScript")
		if cache[module] then
			return cache[module]
		end
		assert(not loading[module], "Circular require: " .. module:GetFullName())
		loading[module] = true
		local env = table.clone(environment)
		env.script, env.require = module, load
		local chunk = luau.load(module.Source, { debugName = module:GetFullName(), environment = env })
		local result = chunk()
		cache[module], loading[module] = result, nil
		return result
	end
	self.Load = load
	self.Environment = environment
	self.Shared = game:GetService("ReplicatedStorage").Shared
	self.Server = game:GetService("ServerScriptService").Server
	self.Roblox = table.clone(roblox)
	self.Roblox.Instance = environment.Instance
	self.Effects = {
		FireAllClients = function(_, ...)
			table.insert(self.Events, { ... })
		end,
		FireClient = function(_, player, ...)
			table.insert(self.Events, { player, ... })
		end,
	}
	function self:advance(seconds)
		self.Time += seconds
		for i = #self.Queue, 1, -1 do
			if self.Queue[i].At <= self.Time then
				local pending = table.remove(self.Queue, i)
				pending.Fn()
			end
		end
	end
	function self:player(id)
		local p = environment.Instance.new("Player")
		p.Name, p.UserId = "Player" .. id, id
		p.DisplayName = p.Name
		p.Parent = game:GetService("Players")
		return p
	end
	return self
end
return Harness
