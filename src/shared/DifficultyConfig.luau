--!strict
local Difficulty = {}
function Difficulty.at(altitude: number)
	local intensity = 1 - math.exp(-math.max(0, altitude) / 1800)
	return {
		Intensity = intensity,
		Speed = 0.65 + intensity * 0.75,
		LandingScale = 1 - intensity * 0.18,
		Combinations = 1 + math.min(2, math.floor(math.max(0, altitude) / 1600)),
	}
end
return table.freeze(Difficulty)
