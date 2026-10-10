--!strict
-- Shared menu-scene geometry: the sanctuary center (from GameConfig.LobbyX), the radius
-- containing every sanctuary object, and the cinematic orbit for the client menu camera.
-- Pure numbers so standalone Luau tests validate it; clients convert points into a CFrame.
type Point = { X: number, Y: number, Z: number }
local Scene = {}
Scene.Height = 80
Scene.Clearance = 92
Scene.MinRadius, Scene.MaxRadius, Scene.MinHeight = 118, 138, 38
function Scene.center(lobbyX: number): Point
	return { X = lobbyX, Y = Scene.Height, Z = 0 }
end
-- Camera position and focus point at time t (seconds).
function Scene.camera(t: number, lobbyX: number): (Point, Point)
	local c = Scene.center(lobbyX)
	local angle = t * 0.045
	local radius = 128 + math.sin(t * 0.07) * 10
	local height = 46 + math.sin(t * 0.11) * 8
	local position =
		{ X = c.X + math.cos(angle) * radius, Y = c.Y + height, Z = c.Z + math.sin(angle) * radius }
	local focus = { X = c.X + math.cos(angle + 2.2) * 40, Y = c.Y + 6, Z = c.Z + math.sin(angle + 2.2) * 40 }
	return position, focus
end
return table.freeze(Scene)
