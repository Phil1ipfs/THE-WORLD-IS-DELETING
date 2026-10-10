--!strict
-- Visual phases subdivide the existing 8s warning / 16s damaging event.
-- This module never changes damage, shelter rules or the server event schedule.
local Storm = {
	Warning = 8,
	Active = 16,
	Heavy = 8,
	Recovery = 10,
	CloudHeight = 240,
	RainRate = 80,
	LowRainRate = 24,
	WindRate = 12,
}
function Storm.smooth(value: number): number
	local t = math.clamp(value, 0, 1)
	return t * t * (3 - 2 * t)
end
function Storm.sample(event: string?, phase: string?, remaining: number?): (string, number)
	if event ~= "Storm" then
		return "Clear", 0
	end
	if phase == "Warning" then
		return "Approaching", 0.08 + 0.37 * Storm.smooth(1 - (remaining or Storm.Warning) / Storm.Warning)
	elseif phase == "Active" then
		local elapsed = Storm.Active - math.clamp(remaining or Storm.Active, 0, Storm.Active)
		if elapsed < Storm.Heavy then
			return "Heavy", 0.45 + 0.3 * Storm.smooth(elapsed / Storm.Heavy)
		end
		return "Extreme", 0.75 + 0.25 * Storm.smooth((elapsed - Storm.Heavy) / (Storm.Active - Storm.Heavy))
	end
	return "Clear", 0
end
-- Low frequency gust envelope; shared by weather and the existing camera loop.
function Storm.gust(time: number, intensity: number): number
	return math.max(0, math.sin(time * 0.85) * 0.7 + math.sin(time * 0.31 + 1.4) * 0.3) ^ 3 * intensity
end
return table.freeze(Storm)
