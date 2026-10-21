--!strict
local Rules = {}
-- Persisted achievement identifiers; ObjectiveConfig supplies display names.
Rules.AchievementIds = {
	"Rescuer",
	"Puzzler",
	"Hunter",
	"Bossbane",
	"Treasure",
	"Keeper",
	"Daredevil",
	"Engineer",
	"Completionist",
	"Dragonbane",
}
local transitions: { [string]: { [string]: boolean } } = {
	Lobby = { Queued = true },
	Queued = { Alive = true, Lobby = true },
	Alive = { Eliminated = true },
	Eliminated = { Spectating = true, Lobby = true, Queued = true },
	Spectating = { Lobby = true, Queued = true },
}
function Rules.canTransition(from: string, to: string): boolean
	return transitions[from] ~= nil and transitions[from][to] == true
end
function Rules.reward(altitude: number, seconds: number)
	local height = math.max(0, math.floor(altitude))
	local time = math.max(0, math.floor(seconds))
	return {
		Coins = math.floor(height / 12) + math.floor(time / 20),
		XP = math.floor(height / 4) + math.floor(time / 5),
	}
end
function Rules.level(xp: number): number
	return 1 + math.floor(math.sqrt(math.max(0, xp) / 80))
end
function Rules.wave(
	height: number,
	dt: number,
	elapsed: number,
	config: {
		WaveGrace: number,
		WaveBaseSpeed: number,
		WaveMaxSpeed: number,
		WaveCatchupDistance: number?,
		WaveCatchupSpeed: number?,
	},
	leaderY: number?
): number
	if elapsed <= config.WaveGrace then
		return height
	end
	local speed = config.WaveBaseSpeed
		+ (config.WaveMaxSpeed - config.WaveBaseSpeed) * (1 - math.exp(-math.max(0, height) / 1600))
	if leaderY and config.WaveCatchupDistance and config.WaveCatchupSpeed then
		local catchup = math.max(0, leaderY - height - config.WaveCatchupDistance) * 0.04
		speed = math.max(speed, math.min(config.WaveCatchupSpeed, catchup))
	end
	return height + speed * math.max(0, dt)
end
function Rules.profile(raw: any)
	local function safe(value: any): number
		return if type(value) == "number"
				and value == value
				and value < math.huge
			then math.clamp(math.floor(value), 0, 1e12)
			else 0
	end
	raw = if type(raw) == "table" then raw else {}
	local owned: { [string]: boolean } = { none = true }
	if type(raw.Owned) == "table" then
		for _, id in
			{
				"azure",
				"sunrise",
				"ember",
				"frostfire",
				"aura",
				"sparks",
				"voidshimmer",
				"wave",
				"royal",
				"golden",
				"galewings",
				"halo",
				"stormtrail",
				"mantle",
				"dragonwing",
			}
		do
			if raw.Owned[id] == true then
				owned[id] = true
			end
		end
	end
	local achievements: { [string]: boolean } = {}
	if type(raw.Achievements) == "table" then
		for _, id in Rules.AchievementIds do
			if raw.Achievements[id] == true then
				achievements[id] = true
			end
		end
	end
	-- Bestiary discovery: creature id -> stage (1-4); bounded so a tampered table cannot grow.
	local bestiary: { [string]: number } = {}
	if type(raw.Bestiary) == "table" then
		local count = 0
		for id, stage in raw.Bestiary do
			if
				count < 64
				and type(id) == "string"
				and #id <= 32
				and string.match(id, "^%u%a*$") ~= nil
				and type(stage) == "number"
				and stage == stage
			then
				local value = math.clamp(math.floor(stage), 0, 4)
				if value > 0 then
					bestiary[id] = value
					count += 1
				end
			end
		end
	end
	return {
		Schema = 1,
		Best = safe(raw.Best),
		Survival = safe(raw.Survival),
		Attempts = safe(raw.Attempts),
		Coins = safe(raw.Coins),
		XP = safe(raw.XP),
		Owned = owned,
		Achievements = achievements,
		Relics = safe(raw.Relics),
		Rescues = safe(raw.Rescues),
		DragonScales = safe(raw.DragonScales),
		Emberhearts = safe(raw.Emberhearts),
		DragonKills = safe(raw.DragonKills),
		DragonAt = safe(raw.DragonAt),
		DragonRolls = safe(raw.DragonRolls),
		Bestiary = bestiary,
		Equipped = if type(raw.Equipped) == "string" and owned[raw.Equipped] then raw.Equipped else "none",
	}
end
function Rules.canLease(lock: any, owner: string, now: number): boolean
	return type(lock) ~= "table"
		or lock.Owner == owner
		or type(lock.Expires) ~= "number"
		or lock.Expires <= now
end
return table.freeze(Rules)
