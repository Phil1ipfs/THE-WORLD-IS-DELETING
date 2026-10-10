--!strict
-- Reusable keys are collected separately in each region and reset with the round.
return table.freeze({
	Order = table.freeze({ "Sun", "Leaf", "Moon" }),
	Keys = table.freeze({
		Sun = { Shortcut = "1", Color = { 255, 203, 106 } },
		Leaf = { Shortcut = "2", Color = { 139, 218, 143 } },
		Moon = { Shortcut = "3", Color = { 182, 196, 255 } },
	}),
})
