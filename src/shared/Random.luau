--!strict
-- Park-Miller PRNG: identical in Studio and the standalone Luau tests.
local Random = {}
Random.__index = Random
function Random.new(seed: number)
	local state = math.floor(math.abs(seed)) % 2147483646 + 1
	-- Scramble adjacent stage seeds before the first selection; the first raw Park-Miller
	-- output from linearly increasing seeds is correlated and biases early obstacles.
	for _ = 1, 4 do
		state = (state * 16807) % 2147483647
	end
	return setmetatable({ state = state }, Random)
end
function Random.next(self: { state: number }): number
	self.state = (self.state * 16807) % 2147483647
	return self.state / 2147483647
end
function Random.range(self: any, low: number, high: number): number
	return low + (high - low) * self:next()
end
function Random.integer(self: any, low: number, high: number): number
	return math.floor(self:range(low, high + 1))
end
return Random
