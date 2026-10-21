--!strict
-- Realm Destroyer rig geometry shared by the server (authoritative hit spheres) and the client
-- (procedural model). Pure numbers in body space: callers transform them by the pose CFrame
-- (the body centre; the dragon faces the pose LookVector, -Z).
-- Body ~34 studs long, ~90 with neck and tail, ~110-stud wingspan (players are ~5 studs tall).
type Point = { X: number, Y: number, Z: number }
type Sphere = { X: number, Y: number, Z: number, R: number }
local Rig = {}
local function p(x: number, y: number, z: number): Point
	return { X = x, Y = y, Z = z }
end
Rig.LandHeight = 14 -- Pose height above the ground while landed or stunned.
Rig.NeckBase = p(0, 4, -16)
Rig.TailBase = p(0, 2, 16)
Rig.WingRoot = p(8, 5, -8) -- Mirrored on X for the left wing.
Rig.Heart = p(0, -4, -10)
-- Head position by action (body space). The client's neck curve ends exactly here.
local heads: { [string]: Point } = {
	Breath = p(0, 2, -35),
	Sweep = p(0, 2, -35),
	Roar = p(0, 9, -32),
	Stunned = p(0, -10, -30),
	Landed = p(0, -2, -33),
	Dive = p(0, 0, -37),
}
local defaultHead = p(0, 7, -36)
function Rig.head(action: string?): Point
	return if action and heads[action] then heads[action] else defaultHead
end
-- Hit spheres (weak points and body) in body space for an action.
function Rig.spheres(action: string?): { [string]: Sphere }
	local head = Rig.head(action)
	local w = Rig.WingRoot
	return {
		Heart = { X = Rig.Heart.X, Y = Rig.Heart.Y, Z = Rig.Heart.Z, R = 6 },
		Head = { X = head.X, Y = head.Y, Z = head.Z, R = 6 },
		WingL = { X = -w.X, Y = w.Y, Z = w.Z, R = 7 },
		WingR = { X = w.X, Y = w.Y, Z = w.Z, R = 7 },
		Body = { X = 0, Y = 0, Z = 0, R = 13 },
		Neck = {
			X = (Rig.NeckBase.X + head.X) / 2,
			Y = (Rig.NeckBase.Y + head.Y) / 2 + 3,
			Z = (Rig.NeckBase.Z + head.Z) / 2,
			R = 6,
		},
		Tail = { X = 0, Y = 1, Z = 28, R = 7 },
	}
end
-- Weak-point groups named by the server's Exposed state.
Rig.WeakGroups = { Heart = { "Heart" }, Head = { "Head" }, Wings = { "WingL", "WingR" } }
-- Mouth (breath origin) in body space.
function Rig.mouth(action: string?): Point
	local head = Rig.head(action)
	return p(head.X, head.Y - 1, head.Z - 8)
end
return table.freeze(Rig)
