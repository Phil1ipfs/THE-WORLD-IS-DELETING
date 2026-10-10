--!nonstrict
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r = h.Roblox
local V = r.Vector3
local Items = h.Load(h.Shared.ItemConfig)
local Config = h.Load(h.Shared.GameConfig)
local World = h.Load(h.Server.Systems.WorldManager)
local Players = h.Load(h.Server.Systems.PlayerManager)
local Adventure = h.Load(h.Server.Systems.AdventureService)
local Powers = h.Load(h.Server.Systems.AbilityService)
local passed = 0
local function test(name, fn)
	local ok, err = pcall(fn)
	assert(ok, "FAIL " .. name .. ": " .. tostring(err))
	passed += 1
	print("PASS " .. name)
end
local function setup()
	local w = World.new()
	local p = Players.new(w, h.Effects)
	local a = Adventure.new(w, p, h.Effects)
	w:reset(712)
	local rec = p:add(h:player(800 + passed))
	rec.Ready = true
	p:transition(rec, "Queued")
	p:begin(rec)
	return w, p, a, rec, Powers.new(h.Effects)
end
local function cleanup(w, p, a, rec)
	a:cancel(rec)
	p:remove(rec.Player)
	rec.Player:Destroy()
	for _, region in w.Islands do
		w:dispose(region)
	end
	w.Root:Destroy()
end
local function node(region, kind)
	for _, spec in region.Interactions do
		if spec.Kind == kind then
			return spec
		end
	end
	error("Missing " .. kind)
end
local function near(rec, spec)
	local root = rec.Player.Character.HumanoidRootPart
	root.Position = spec.Part.Position + V.new(0, 1.5, 0)
	rec.LastPosition = root.Position
	h:advance(0.6)
end
test(
	"Native and fallback interactions share once-only collection and retain separate player stock",
	function()
		local w, p, a, rec = setup()
		local spec = node(w.Islands[0], "Timber")
		assert(spec.Prompt.Enabled and spec.Prompt.HoldDuration == 0 and spec.Part.CanQuery)
		near(rec, spec)
		spec.Prompt.Triggered:Fire(rec.Player)
		assert(rec.Bag.Timber == 1 and spec.Claims[rec.Player.UserId])
		h:advance(0.6)
		assert(not a:request(rec, spec.Id) and rec.Bag.Timber == 1)
		local other = p:add(h:player(1900))
		other.Ready = true
		p:transition(other, "Queued")
		p:begin(other)
		near(other, spec)
		assert(a:request(other, spec.Id) and other.Bag.Timber == 1)
		assert(spec.Stock == 10)
		assert(not a:request(rec, "forged-id"))
		p:remove(other.Player)
		other.Player:Destroy()
		cleanup(w, p, a, rec)
	end
)
test("Footprint support permits pickups next to rails and rejects supply over deleted ground", function()
	local w, p, a, rec = setup()
	local spec = node(w.Islands[0], "Herb")
	near(rec, spec)
	local root = rec.Player.Character.HumanoidRootPart
	local obstacle = r.Instance.new("Part")
	obstacle.Size, obstacle.CFrame, obstacle.Anchored =
		V.new(0.6, 1, 0.6), r.CFrame.new(root.Position - V.new(0, 1, 0)), true
	obstacle.Parent = w.Root
	assert(a:request(rec, spec.Id), "A small decorative obstruction blocked every footprint ray")
	obstacle:Destroy()
	local nextSpec
	for _, s in w.Islands[0].Interactions do
		if s.Kind == "Herb" and s ~= spec then
			nextSpec = s
			break
		end
	end
	near(rec, nextSpec)
	for _, region in w.Islands do
		for _, c in region.Cells do
			c.Part.CanCollide, c.Part.CanQuery = false, false
		end
	end
	assert(not a:request(rec, nextSpec.Id), "Supply in empty air was collected")
	cleanup(w, p, a, rec)
end)
test(
	"Portable healing preserves herbs at full health, heals anywhere, and enforces cooldown and costs",
	function()
		local w, p, a, rec = setup()
		rec.Bag.Herb = 2
		assert(not a:use(rec, "Herb") and rec.Bag.Herb == 2)
		local hum = rec.Player.Character.Humanoid
		hum.Health = 30
		assert(a:use(rec, "Herb") and hum.Health == 70 and rec.Bag.Herb == 1)
		assert(not a:use(rec, "Herb") and hum.Health == 70)
		h:advance(5.1)
		assert(a:use(rec, "Herb") and hum.Health == 100 and rec.Bag.Herb == 0)
		assert(not a:use(rec, "unknown") and not a:use(rec, "Timber"))
		cleanup(w, p, a, rec)
	end
)
test("Timber braces delay local destruction without protecting against the deletion wave", function()
	local w, p, a, rec = setup()
	rec.Bag.Timber = 2
	assert(a:use(rec, "Timber") and rec.Bag.Timber == 0)
	local guarded
	for _, c in w.Islands[0].Cells do
		if c.BracedUntil and not c.Late then
			guarded = c
			break
		end
	end
	assert(guarded)
	w.Islands[0].Activated = h.Time - Config.RegionLifetime + guarded.Edge * 75 - 1
	w:consume(-100)
	assert(guarded.State == "Stable")
	h:advance(18.1)
	w:consume(-100)
	assert(guarded.State == "Cracking")
	p:update(rec.Player.Character.HumanoidRootPart.Position.Y + w.Origin + 1)
	assert(rec.State == "Eliminated", "Timber incorrectly shielded the wave")
	cleanup(w, p, a, rec)
end)
test("Crystal overcharge reduces cooldown and strengthens authorized powers without stacking", function()
	local w, p, a, rec, power = setup()
	rec.Bag.Crystal = 2
	rec.Cooldowns.Dash = h.Time + 6
	assert(a:use(rec, "Crystal") and rec.Bag.Crystal == 1)
	assert(math.abs(rec.Cooldowns.Dash - h.Time - 3) < 0.01)
	assert(not a:use(rec, "Crystal") and rec.Bag.Crystal == 1)
	h:advance(3.1)
	assert(power:request(rec, "Dash"))
	assert(rec.DashSpeed > Config.Ability.Dash.Speed)
	assert(power:request(rec, "Shield") and rec.ShieldHealth > 60)
	cleanup(w, p, a, rec)
end)
test("Gust dash persists, Sky Leap exceeds a normal jump, and air leap cannot repeat", function()
	local w, p, a, rec, power = setup()
	local root, hum = rec.Player.Character.HumanoidRootPart, rec.Player.Character.Humanoid
	assert(power:request(rec, "Dash"))
	local movementUntil = rec.MovementUntil
	hum:SetAttribute("Airborne", true)
	rec.LastGrounded = h.Time
	root.AssemblyLinearVelocity = V.zero
	power:coyote(rec)
	assert(
		rec.CoyoteUsed and rec.MovementUntil >= movementUntil,
		"Coyote jump shortened the running dash allowance"
	)
	hum:SetAttribute("Airborne", false)
	root.AssemblyLinearVelocity = V.zero
	h:advance(0.75)
	power:update(p)
	assert(V.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 60)
	assert(rec.DashUntil > h.Time and rec.MovementUntil >= rec.DashUntil, "Dash did not last a full second")
	assert(math.abs(rec.Cooldowns.Dash - h.Time - 4.25) < 0.01, "Dash cooldown changed")
	assert(not power:request(rec, "Dash"))
	assert(not power:request(rec, "DoubleJump"))
	hum:SetAttribute("Airborne", true)
	assert(power:request(rec, "DoubleJump") and root.AssemblyLinearVelocity.Y > Config.JumpPower)
	assert(rec.MovementUntil >= rec.DashUntil, "Air leap shortened the dash movement allowance")
	h:advance(0.3)
	root.AssemblyLinearVelocity = V.zero
	power:update(p)
	assert(root.AssemblyLinearVelocity == V.zero, "Expired dash still applied velocity")
	h:advance(7)
	assert(not power:request(rec, "DoubleJump"), "Air leap repeated without landing")
	cleanup(w, p, a, rec)
end)
test("Aegis absorbs its budget then passes excess damage through", function()
	local w, p, a, rec, power = setup()
	assert(power:request(rec, "Shield"))
	p:damage(rec, 40)
	assert(rec.Player.Character.Humanoid.Health == 100 and rec.ShieldHealth == 20)
	p:damage(rec, 35)
	assert(rec.Player.Character.Humanoid.Health == 85 and rec.ShieldHealth == 0)
	cleanup(w, p, a, rec)
end)
test("Wind Sail slows falling, lasts longer, folds on request and rejects ground activation", function()
	local w, p, a, rec, power = setup()
	assert(not power:request(rec, "Glide"))
	local root, hum = rec.Player.Character.HumanoidRootPart, rec.Player.Character.Humanoid
	hum:SetAttribute("Airborne", true)
	root.AssemblyLinearVelocity = V.new(12, -80, 0)
	assert(power:request(rec, "Glide"))
	assert(rec.GlideUntil - h.Time >= 6 and root.AssemblyLinearVelocity.Y == -9)
	root.AssemblyLinearVelocity = V.new(90, -60, 0)
	power:update(p)
	assert(root.AssemblyLinearVelocity.X <= 25 and root.AssemblyLinearVelocity.Y == -9)
	assert(power:request(rec, "Dash"))
	root.AssemblyLinearVelocity = V.new(0, -60, 0)
	power:update(p)
	assert(
		V.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 60,
		"Glide cancelled an authorized dash"
	)
	assert(root.AssemblyLinearVelocity.Y == -9)
	assert(power:request(rec, "Glide") and rec.GlideUntil == 0)
	rec.Transit = true
	assert(not power:request(rec, "Shield"))
	cleanup(w, p, a, rec)
end)
test("Collected item vanishes locally and fallback interaction sends only a known node ID", function()
	local w, p, a, rec = setup()
	h.Game:GetService("Players").LocalPlayer = rec.Player
	local client = h.Game:GetService("StarterPlayer").StarterPlayerScripts.Client
	local requests = {}
	local ui = { State = "Alive", Panel = { Visible = false }, Interact = {}, Data = { RoundNumber = 1 } }
	local interaction = h.Load(client.Controllers.InteractionController).new({
		FireServer = function(_, ...)
			table.insert(requests, { ... })
		end,
	}, ui)
	local spec = node(w.Islands[0], "Herb")
	near(rec, spec)
	interaction:update(0.3)
	assert(interaction.Target and ui.Interact.Visible)
	interaction:activate()
	assert(requests[1][1] == "Interact" and a.Specs[requests[1][2]])
	interaction:collect({ Node = spec.Part })
	assert(spec.Part.LocalTransparencyModifier == 1 and not spec.Prompt.Enabled)
	local streamed = spec.Part:Clone()
	streamed.LocalTransparencyModifier, streamed.ProximityPrompt.Enabled = 0, true
	streamed.Parent = w.Islands[0].Model
	spec.Part.Parent = nil
	interaction:update(0.3)
	assert(
		streamed.LocalTransparencyModifier == 1 and not streamed.ProximityPrompt.Enabled,
		"Collected supply reappeared after streaming"
	)
	ui.Data.RoundNumber = 2
	interaction:update(0.3)
	assert(not interaction.ClaimedIds[spec.Id], "Supply claims survived into a new round")
	spec.Part:Destroy()
	cleanup(w, p, a, rec)
end)
print(string.format("%d item/power regressions passed (offline; avatar physics pending Studio)", passed))
