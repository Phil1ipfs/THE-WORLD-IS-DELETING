--!strict
local Route = {}
type Config = {
	RouteAngle: number,
	RouteRadius: number,
	StartY: number,
	StepRise: number,
	JumpPower: number,
	Gravity: number,
	WalkSpeed: number,
}
type Point = { X: number, Y: number, Z: number, Step: number }
-- Coordinates depend on step, never on client-reported position or generation order.
function Route.point(step: number, config: Config): Point
	local angle = step * config.RouteAngle
	local radius = config.RouteRadius * (0.92 + math.sin(step * 0.07) * 0.055)
	return {
		X = math.sin(angle) * radius,
		Y = config.StartY + step * config.StepRise,
		Z = math.cos(angle) * radius,
		Step = step,
	}
end
function Route.reachable(a: Point, b: Point, config: Config): boolean
	local rise = b.Y - a.Y
	local discriminant = config.JumpPower ^ 2 - 2 * config.Gravity * rise
	if discriminant <= 0 then
		return false
	end
	local airtime = (config.JumpPower + math.sqrt(discriminant)) / config.Gravity
	local distance = math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
	-- Require center-to-center travel with 15% speed reserve AND time to rise clear
	-- of the next tread before moving forward. This is stronger than edge-to-edge.
	return distance <= math.min(airtime * 0.85, airtime - 0.1) * config.WalkSpeed
end
function Route.validate(first: number, last: number, config: Config): boolean
	for step = first, last - 1 do
		if not Route.reachable(Route.point(step, config), Route.point(step + 1, config), config) then
			return false
		end
	end
	return true
end
return table.freeze(Route)
