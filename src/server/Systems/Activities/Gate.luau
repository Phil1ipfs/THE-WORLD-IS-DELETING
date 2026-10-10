--!nonstrict
-- Timed vault: a lever opens the vault door for a few seconds. Solo players must sprint or
-- Gust Dash; a partner standing on the lever keeps it open. An inside lever reopens the door.
local Common = require(script.Parent.Common)
local Gate = {}
local C = Color3.fromRGB
Gate.Open = 7
function Gate.build(ctx, act)
	local S, rng = ctx.S, ctx.Rng
	local vault = S:find(rng, 9, { Mainland = true, Outskirts = true }, 50)
	if not vault then
		return false
	end
	local lever
	for _ = 1, 30 do
		local a = rng:range(0, math.pi * 2)
		local d = rng:range(30, 40)
		local x, z = vault.X + math.cos(a) * d, vault.Z + math.sin(a) * d
		if S:fits(x, z, 3, { Mainland = true, Outskirts = true }) then
			lever = { X = x, Z = z }
			S:reserve(x, z, 3)
			break
		end
	end
	if not lever then
		return false
	end
	act.Site, act.Lever = vault, lever
	local yaw = math.atan2(lever.X - vault.X, lever.Z - vault.Z)
	act.Vault = Common.vault(ctx, act, vault.X, vault.Z, yaw, C(110, 100, 96))
	local B = ctx.B
	B.Ground = ctx.Ground(lever.X, lever.Z)
	B.part(
		"GateLeverBase",
		Vector3.new(2.4, 1.4, 2.4),
		CFrame.new(ctx.World(lever.X, lever.Z, 0.7)),
		C(90, 90, 96),
		"Metal",
		{ Collide = true }
	)
	act.Handle = B.part(
		"GateLever",
		Vector3.new(0.4, 3.4, 0.4),
		CFrame.new(ctx.World(lever.X, lever.Z, 2.8)) * CFrame.Angles(0.5, 0, 0),
		C(200, 60, 50),
		"Neon"
	)
	Common.prompt(ctx, act, "Lever", lever.X, lever.Z, 2.2, "Pull lever", 0.2)
	local inside = (act.Vault.LocalBase * CFrame.new(-3.2, 0, -3.5)).Position
	Common.prompt(ctx, act, "Inside", inside.X, inside.Z, 2.2, "Reopen door", 0.2)
	act.OpenUntil = 0
	act.Goal = 1
	act.Hint = "Pull the lever, then reach the vault within "
		.. Gate.Open
		.. "s (Gust Dash helps). A friend on the lever holds it open."
end
function Gate.update(svc, act, _dt, now)
	local region = act.Region
	local lever = region.Center + Vector3.new(act.Lever.X, 3, act.Lever.Z)
	local held = #Common.near(svc, lever, 4.5) > 0 and now < act.OpenUntil + 0.5
	if held then
		act.OpenUntil = math.max(act.OpenUntil, now + 1)
	end
	local open = now < act.OpenUntil
	if open ~= act.WasOpen then
		act.WasOpen = open
		Common.setDoor(act.Vault, open)
		act.Vault.Chest.Prompt.Enabled = open or act.Done
		if act.Handle.Parent then
			act.Handle.Color = if open then C(90, 220, 110) else C(200, 60, 50)
		end
		svc.Effects:FireAllClients("GateState", { Position = act.Vault.Door.Position, Open = open })
	end
	if act.Done then
		act.Vault.Chest.Prompt.Enabled = true
	end
end
function Gate.interact(svc, act, record, spec)
	local now = os.clock()
	if spec.Action == "Lever" or spec.Action == "Inside" then
		-- Crystal Overcharge powers the old mechanism longer.
		local seconds = if now < (record.OverchargeUntil or 0) then Gate.Open + 3 else Gate.Open
		act.OpenUntil = now + seconds
		svc:participate(act, record)
		svc:notice(record, "The vault door is open for " .. seconds .. " seconds. GO!")
		return true
	elseif spec.Action == "Vault" then
		local root = Common.root(record)
		if not root or not Common.inside(act.Vault, root.Position) then
			svc:notice(record, "Get inside the vault first.")
			return false
		end
		svc:participate(act, record)
		local opened = svc:openChest(act, record)
		if opened and not act.Done then
			svc:complete(act, "Vault cracked! Anyone who reaches it can claim a share.")
		end
		return opened
	end
	return false
end
function Gate.status(act)
	return if act.Done then "Cracked" else "Sealed"
end
return Gate
