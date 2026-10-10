--!nonstrict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Movement = {}
-- Input buffering requests a normal Humanoid jump after landing; coyote time is
-- validated against the server's last grounded observation and downward velocity.
function Movement.start(request, ui)
	local player = Players.LocalPlayer
	local hum, root, stateConnection
	local pendingUntil, lastGrounded = 0, -100
	local function bind(character)
		if stateConnection then
			stateConnection:Disconnect()
		end
		hum = character:WaitForChild("Humanoid", 10)
		root = character:WaitForChild("HumanoidRootPart", 10)
		pendingUntil, lastGrounded = 0, -100
		if not hum or not root then
			return
		end
		stateConnection = hum.StateChanged:Connect(function(_, state)
			if state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running then
				lastGrounded = os.clock()
				if os.clock() <= pendingUntil and ui.State == "Alive" then
					pendingUntil = 0
					task.defer(function()
						if hum and hum.Parent then
							hum.Jump = true
						end
					end)
				end
			elseif state == Enum.HumanoidStateType.Freefall then
				-- Freefall entered directly from the ground is a ledge departure.
				if root.AssemblyLinearVelocity.Y <= 1 then
					lastGrounded = os.clock()
				end
			end
		end)
	end
	player.CharacterAdded:Connect(bind)
	if player.Character then
		task.spawn(bind, player.Character)
	end
	UserInputService.JumpRequest:Connect(function()
		if ui.State ~= "Alive" or ui.Panel.Visible or not hum or not root then
			return
		end
		pendingUntil = os.clock() + 0.12
		if
			hum:GetState() == Enum.HumanoidStateType.Freefall
			and os.clock() - lastGrounded < 0.12
			and root.AssemblyLinearVelocity.Y <= 1
		then
			request:FireServer("CoyoteJump")
			lastGrounded = -100
		elseif hum:GetState() == Enum.HumanoidStateType.Freefall and os.clock() - lastGrounded > 0.2 then
			request:FireServer("Ability", "DoubleJump")
		end
	end)
end
return Movement
