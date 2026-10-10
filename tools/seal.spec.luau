--!nonstrict
-- Real production modules under fixture services; no native input or rendering simulation.
local Harness = require("./OfflineHarness")
local h = Harness.new()
local r, V = h.Roblox, h.Roblox.Vector3
local World = h.Load(h.Server.Systems.WorldManager)
local Players = h.Load(h.Server.Systems.PlayerManager)
local Adventure = h.Load(h.Server.Systems.AdventureService)
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
	local rec = p:add(h:player(2400 + passed))
	rec.Ready = true
	p:transition(rec, "Queued")
	p:begin(rec)
	return w, p, a, rec
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
local function node(region, kind, glyph)
	for _, spec in region.Interactions do
		if spec.Kind == kind and (not glyph or spec.Extra == glyph) then
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
local function collectAll(a, rec, region)
	for _, glyph in { "Sun", "Leaf", "Moon" } do
		local spec = node(region, "Glyph", glyph)
		near(rec, spec)
		assert(a:request(rec, spec.Id))
	end
end
test("Sun, Leaf and Moon collect once through native and fallback paths without auto-solving", function()
	local w, p, a, rec = setup()
	local region = w.Islands[0]
	for _, glyph in { "Sun", "Leaf", "Moon" } do
		local spec = node(region, "Glyph", glyph)
		assert(spec.Part:GetAttribute("Collectible") and spec.Prompt.HoldDuration == 0)
		assert(spec.Prompt.ActionText == "Collect " .. glyph .. " key")
		near(rec, spec)
		if glyph == "Sun" then
			spec.Prompt.Triggered:Fire(rec.Player)
		else
			assert(a:request(rec, spec.Id))
		end
		assert(rec.Glyphs[0][glyph] and spec.Claims[rec.Player.UserId])
		h:advance(0.6)
		assert(not a:request(rec, spec.Id), "Duplicate key collected")
	end
	assert(region.Glyph == 0 and not region.Model:GetAttribute("PortalOpen"))
	local status = a:sealStatus(rec)
	assert(status.Sun and status.Leaf and status.Moon)
	cleanup(w, p, a, rec)
end)
test("Altar requires collected keys, supports E/X next-key use, and wrong order is recoverable", function()
	local w, p, a, rec = setup()
	local region, altar = w.Islands[0], w.Islands[0].Seal
	near(rec, altar)
	assert(not a:useGlyph(rec, "Sun") and region.Glyph == 0)
	collectAll(a, rec, region)
	near(rec, altar)
	assert(a:request(rec, altar.Id) and region.Glyph == 1)
	assert(not a:useGlyph(rec, "Leaf"), "Shared interaction debounce bypassed")
	h:advance(0.6)
	assert(a:useGlyph(rec, "Moon") and region.Glyph == 0)
	assert(rec.Glyphs[0].Sun and rec.Glyphs[0].Moon, "Wrong order destroyed reusable keys")
	for i = 1, 3 do
		h:advance(0.6)
		assert(a:request(rec, altar.Id) and region.Glyph == i)
	end
	assert(region.Model:GetAttribute("PortalOpen") and a:sealStatus(rec).Open)
	h:advance(0.6)
	assert(not a:useGlyph(rec, "Moon") and region.Glyph == 3)
	cleanup(w, p, a, rec)
end)
test("Seal keys and progress are shared safely between players with independent collection", function()
	local w, p, a, rec = setup()
	local other = p:add(h:player(2900))
	other.Ready = true
	p:transition(other, "Queued")
	p:begin(other)
	local region = w.Islands[0]
	collectAll(a, rec, region)
	collectAll(a, other, region)
	near(rec, region.Seal)
	assert(a:useGlyph(rec, "Sun"))
	near(other, region.Seal)
	assert(a:useGlyph(other, "Leaf") and region.Glyph == 2)
	h:advance(0.6)
	assert(a:useGlyph(other, "Moon") and region.Model:GetAttribute("PortalOpen"))
	assert(a:sealStatus(rec).Progress == 3)
	p:remove(other.Player)
	other.Player:Destroy()
	cleanup(w, p, a, rec)
end)
test("Key use rejects forged, distant, displaced, dead, unready, airborne and transit requests", function()
	local w, p, a, rec = setup()
	local region = w.Islands[0]
	collectAll(a, rec, region)
	assert(not a:useGlyph(rec, {}) and not a:useGlyph(rec, string.rep("Sun", 1000)))
	local root, hum = rec.Player.Character.HumanoidRootPart, rec.Player.Character.Humanoid
	root.Position = w:point(0) + V.new(0, 4, 0)
	rec.LastPosition = root.Position
	h:advance(0.6)
	assert(not a:useGlyph(rec, "Sun"), "Distant key use accepted")
	near(rec, region.Seal)
	rec.LastPosition -= V.new(40, 0, 0)
	assert(not a:useGlyph(rec, "Sun"))
	rec.LastPosition = root.Position
	rec.Transit = true
	assert(not a:useGlyph(rec, "Sun"))
	rec.Transit, rec.Ready = nil, false
	assert(not a:useGlyph(rec, "Sun"))
	rec.Ready, hum.Health = true, 0
	assert(not a:useGlyph(rec, "Sun"))
	hum.Health = 100
	root.Position += V.new(0, 8, 0)
	rec.LastPosition = root.Position
	assert(not a:useGlyph(rec, "Sun"), "Unsupported altar use accepted")
	assert(region.Glyph == 0)
	cleanup(w, p, a, rec)
end)
test("Keys cannot unlock other realms, clear on a new round, and are pruned with retired regions", function()
	local w, p, a, rec = setup()
	collectAll(a, rec, w.Islands[0])
	near(rec, w.Islands[1].Seal)
	assert(not a:useGlyph(rec, "Sun") and not a:sealStatus(rec).Sun)
	w:dispose(w.Islands[0])
	assert(rec.Glyphs[0] == nil, "Retired region key pouch leaked")
	rec.Glyphs[1] = { Sun = true }
	p:eliminate(rec, "test")
	p:transition(rec, "Queued")
	assert(p:begin(rec) and next(rec.Glyphs) == nil)
	cleanup(w, p, a, rec)
end)
test("Collected key tablet and its label hide locally while other players keep their copy", function()
	local w, p, a, rec = setup()
	h.Game:GetService("Players").LocalPlayer = rec.Player
	local client = h.Game:GetService("StarterPlayer").StarterPlayerScripts.Client
	local interaction = h.Load(client.Controllers.InteractionController)
		.new({}, { Data = { RoundNumber = 1 } })
	local spec = node(w.Islands[0], "Glyph", "Leaf")
	local untouched = spec.Part:Clone()
	untouched.Parent = w.Islands[0].Model
	near(rec, spec)
	assert(a:request(rec, spec.Id))
	local payload
	for _, event in h.Events do
		if event[1] == rec.Player and event[2] == "Collected" and event[3].Id == spec.Id then
			payload = event[3]
		end
	end
	assert(payload and payload.Kind == "Leaf")
	interaction:collect(payload)
	assert(spec.Part.LocalTransparencyModifier == 1 and not spec.Prompt.Enabled)
	assert(not spec.Part.Sign.BillboardGui.Enabled, "Key label remained after pickup")
	assert(untouched.ProximityPrompt.Enabled, "Another player's collectible was disabled")
	untouched:Destroy()
	cleanup(w, p, a, rec)
end)
print(string.format("%d seal-key regressions passed (offline; Studio input/replication pending)", passed))
