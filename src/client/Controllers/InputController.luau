--!nonstrict
local ContextActionService = game:GetService("ContextActionService")
local Input = {}
function Input.start(request, ui)
	ContextActionService:BindAction("RealmInteract", function(_, state)
		if state == Enum.UserInputState.Begin and ui.OnInteract then
			ui.OnInteract()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	for _, entry in
		{ { "Sun", Enum.KeyCode.One }, { "Leaf", Enum.KeyCode.Two }, { "Moon", Enum.KeyCode.Three } }
	do
		local glyph = entry[1]
		ContextActionService:BindAction("Use" .. glyph .. "Key", function(_, state)
			if state == Enum.UserInputState.Begin and ui.State == "Alive" and not ui.Panel.Visible then
				request:FireServer("UseGlyph", glyph)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, entry[2])
	end
	for _, entry in
		{
			{ "Herb", Enum.KeyCode.H, Enum.KeyCode.DPadUp },
			{ "Crystal", Enum.KeyCode.C, Enum.KeyCode.DPadRight },
			{ "Timber", Enum.KeyCode.V, Enum.KeyCode.DPadLeft },
		}
	do
		local kind = entry[1]
		ContextActionService:BindAction("Use" .. kind, function(_, state)
			if state == Enum.UserInputState.Begin and ui.State == "Alive" and not ui.Panel.Visible then
				request:FireServer("UseItem", kind)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, entry[2], entry[3])
	end
	local bindings = {
		Dash = { Enum.KeyCode.Q, Enum.KeyCode.ButtonR2 },
		DoubleJump = { Enum.KeyCode.Z, Enum.KeyCode.ButtonY },
		Shield = { Enum.KeyCode.R, Enum.KeyCode.ButtonB },
		Glide = { Enum.KeyCode.F, Enum.KeyCode.ButtonL1 },
	}
	for name, keys in bindings do
		ContextActionService:BindAction("Realm" .. name, function(_, state)
			if state == Enum.UserInputState.Begin and ui.State == "Alive" and not ui.Panel.Visible then
				request:FireServer("Ability", name)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, table.unpack(keys))
	end
	ContextActionService:BindAction("RealmMenu", function(_, state)
		if state == Enum.UserInputState.Begin then
			ui:open(if ui.Panel.Visible then "Menu" else "Settings")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonSelect)
end
return Input
