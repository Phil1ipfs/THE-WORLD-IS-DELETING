--!strict
-- NPC animations. These are Roblox's built-in default R15 character animations (used by every
-- default avatar), not third-party assets. Verify they load in Studio; set UseDefaults = false
-- to use the procedural limb-swing fallback in NpcRig instead.
return table.freeze({
	UseDefaults = true,
	R15 = table.freeze({
		Idle = "rbxassetid://507766666",
		Walk = "rbxassetid://507777826",
		Cheer = "rbxassetid://507770677",
	}),
})
