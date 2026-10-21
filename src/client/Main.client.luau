--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local net = ReplicatedStorage:WaitForChild("Network")
local request, snapshot, effects =
	net:WaitForChild("Request"), net:WaitForChild("Snapshot"), net:WaitForChild("Effects")
local settings = { Music = true, SFX = true, Camera = true, Detail = true }
local ui = require(script.Parent.UI.Interface).new(request, settings)
local camera = require(script.Parent.Controllers.CameraController).new(settings, request)
local audio = require(script.Parent.Controllers.AudioController).new(settings)
local environment = require(script.Parent.Controllers.EnvironmentController).new(settings)
local interaction = require(script.Parent.Controllers.InteractionController).new(request, ui)
local power = require(script.Parent.Controllers.PowerController).new()
local fx = require(script.Parent.Controllers.PowerEffects).new(settings)
environment.Effects = fx
local dragon = require(script.Parent.Controllers.DragonController).new(settings, fx)
-- Crossbow intent: the camera's aim direction only; the server validates and resolves the hit.
ui.OnFire = function()
	if ui.State == "Alive" and not ui.Panel.Visible and workspace.CurrentCamera then
		request:FireServer("Fire", workspace.CurrentCamera.CFrame.LookVector)
	end
end
ui.OnThrow = function()
	if ui.State == "Alive" and not ui.Panel.Visible and workspace.CurrentCamera then
		request:FireServer("Throw", workspace.CurrentCamera.CFrame.LookVector)
	end
end
dragon.Audio = audio
local shotCue = {
	Crossbow = "DragonbaneShot",
	Harpoon = "HarpoonThrow",
	Ballista = "BallistaFire",
	Cannon = "CannonFire",
	Dash = "Hit",
}
local lastHurtCue = 0
ui.OnInteract = function()
	interaction:activate()
end
interaction.OnCollected = function(node, payload)
	fx:pickup(node, payload.Position or node.Position, payload.Kind)
end
ui.OnCountdown = function(n)
	audio:play(if n == 0 then "Start" else "Tick")
end
fx.OnShieldBreak = function()
	audio:play("ShieldBreak")
	ui:feed("Aegis shattered", Color3.fromRGB(130, 220, 255))
end
require(script.Parent.Controllers.InputController).start(request, ui)
require(script.Parent.Controllers.MovementController).start(request, ui)
local data
snapshot.OnClientEvent:Connect(function(value)
	data = value
	ui:update(value)
end)
ui.OnNextSpectator = function()
	if data then
		camera:next(data.Roster)
	end
end
local abilityCue = { Dash = "Dash", DoubleJump = "Leap", Shield = "Shield", Glide = "Glide" }
local itemCue = { Herb = "Heal", Crystal = "Overcharge", Timber = "Brace" }
effects.OnClientEvent:Connect(function(action, payload)
	if action == "Eliminated" then
		ui.Result = payload
		ui:open("Elimination")
	elseif action == "Notice" then
		ui:notice(payload)
	elseif action == "Bonus" then
		ui:notice("Challenge cleared • +" .. payload .. " coins")
	elseif action == "Leaderboard" then
		ui.GlobalBoard = payload
		if ui.Page == "Leaderboard" then
			ui:open("Leaderboard")
		end
	elseif action == "Rebase" then
		if data and (data.State == "Alive" or data.State == "Spectating") then
			camera:rebase(payload)
		end
	elseif action == "Collapse" then
		audio:play("Collapse", payload)
	elseif action == "Discovery" or action == "GateState" then
		audio:play("Discovery", payload.Position)
	elseif action == "Collected" then
		interaction:collect(payload)
		if not payload.Node or not payload.Node.Parent then
			fx:pickup(nil, payload.Position, payload.Kind)
		end
		audio:play("Pickup", payload.Position)
		ui:event(action, payload)
	elseif action == "ItemUsed" then
		fx:item(payload)
		if payload.UserId == Players.LocalPlayer.UserId then
			audio:play(itemCue[payload.Kind] or "Ability")
		end
	elseif action == "WorldEvent" then
		if payload.Phase == "Warning" then
			ui:notice(
				if payload.Name == "Earthquake"
					then "Earthquake approaching. Leave fractured ground; keep the sky causeway in sight."
					else payload.Name .. " approaching. Find shelter and keep escape routes in sight."
			)
		end
		if payload.Phase == "Active" and payload.Name ~= "Storm" then
			audio:play(
				if payload.Name == "DeletionSurge"
					then "Deletion"
					elseif payload.Name == "StructureCollapse" then "Collapse"
					else payload.Name
			)
		end
	elseif action == "OceanDeath" then
		fx:splash(payload.Position)
		audio:play("Splash", payload.Position)
		if payload.UserId == Players.LocalPlayer.UserId then
			ui:flash(Color3.fromRGB(40, 140, 170), 0.45)
			ui:notice("You fell into the ocean. The sea below the realms is fatal.")
		end
	elseif action == "Dragon" then
		dragon:event(payload, environment.StormState)
		ui:event(action, payload)
		if payload.Kind == "Roar" or payload.Kind == "Meteors" then
			-- Played at the listener: roars carry across the whole sky.
			audio:play("DragonRoar")
		elseif payload.Kind == "Impact" or payload.Kind == "Slam" or payload.Kind == "Strike" then
			audio:play("DragonImpact", payload.Position)
		elseif payload.Kind == "Gust" then
			audio:play("DragonGust", payload.Position)
		elseif payload.Kind == "Interrupted" then
			audio:play("DragonHurt", payload.Position)
		elseif payload.Kind == "Raze" then
			audio:play("Earthquake")
		elseif payload.Kind == "Repelled" then
			audio:play("DragonRoar")
			audio:play("Complete")
		elseif payload.Kind == "Crossbow" or payload.Kind == "Harpoons" or payload.Kind == "Crafted" then
			audio:play("ForgeCraft")
		end
	elseif action == "DragonShot" then
		dragon:shot(payload)
		audio:play(shotCue[payload.Weapon] or "DragonbaneShot", payload.From)
		if (payload.Damage or 0) > 0 then
			audio:play("WeakPointHit") -- Hit confirmation at the listener.
			if os.clock() - lastHurtCue > 1.5 then
				lastHurtCue = os.clock()
				audio:play("DragonHurt", payload.To)
			end
		end
	elseif action == "Shop" then
		ui:event(action, payload)
		audio:play(if payload.Kind == "Bought" then "Chest" else "Tick")
	elseif action == "DragonTrophy" or action == "Bestiary" then
		ui:event(action, payload)
		audio:play("Complete")
	elseif action == "Knockback" then
		power:knockback(payload)
	elseif action == "Balloon" then
		if payload.Phase == "Boarded" then
			audio:play("Tick")
		elseif payload.Phase == "Depart" then
			audio:play("BalloonDepart")
			audio:play("BalloonBurner")
		elseif payload.Phase == "Arrive" then
			audio:play("BalloonArrive")
		end
	elseif action == "Dialogue" then
		ui:dialogue(payload)
	elseif action == "Bleat" then
		audio:play("SheepBleat", payload.Position)
	elseif action == "Emote" then
		environment:emote(payload)
	elseif action == "Ability" then
		power:activate(payload)
		fx:ability(payload)
		if payload.UserId == Players.LocalPlayer.UserId then
			audio:play(abilityCue[payload.Name] or "Ability")
			if payload.Name == "Dash" then
				camera.DashUntil = os.clock() + payload.Duration
			end
		end
	elseif action == "Updraft" then
		power:updraft(payload)
		fx:updraft(payload)
		audio:play("Glide")
	elseif action == "CreatureHit" then
		fx:creatureHit(payload)
		audio:play(if payload.Defeated then "Complete" else "Hit", payload.Position)
	elseif action == "CreatureAttack" then
		fx:creatureAttack(payload)
		audio:play("Hit", payload.Position)
	elseif action == "ChestOpened" then
		if payload.Position then
			fx:chest(payload.Position)
		end
		if payload.UserId == Players.LocalPlayer.UserId then
			audio:play("Chest")
		end
	elseif action == "Mined" then
		fx:burst(payload.Position, Color3.fromRGB(150, 220, 255), 12)
		audio:play("Hit", payload.Position)
	elseif
		action == "Objective"
		or action == "Reward"
		or action == "Perk"
		or action == "Achievement"
		or action == "Hurt"
	then
		ui:event(action, payload)
		if
			(action == "Objective" and payload.Kind == "Complete")
			or action == "Achievement"
			or action == "Perk"
		then
			audio:play("Complete")
		end
	end
end)
RunService:BindToRenderStep("RealmCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not data then
		return
	end
	local name = camera:update(math.min(dt, 0.1), data, environment.StormState)
	power:update(data)
	fx:update(dt, data)
	dragon:update(math.min(dt, 0.1))
	ui:animate(dt)
	if name then
		ui.SpectatorName.Text = "Spectating • " .. name
	end
end)
local accum = 0
RunService.Heartbeat:Connect(function(dt)
	if not data then
		return
	end
	accum += dt
	if accum < 1 / 20 then
		return
	end
	local step = math.min(accum, 0.2)
	accum = 0
	interaction:update(step)
	environment:update(step, data)
	audio:update(step, data, environment.StormState)
	ui:updateStorm(data, environment.StormState)
end)
