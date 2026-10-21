--!strict
return table.freeze({
	Version = "0.7.2",
	LobbyX = 2400, -- Sanctuary vista sits far from realm airspace (realms span about ±1100).
	RegionRise = 128,
	RegionRadius = 450,
	RegionLifetime = 240, -- 0.5.0: larger realms with sub-areas (outer areas still fall about 70s earlier).
	CorruptionWarning = 14,
	MaxActiveRegions = 9,
	MaxPlayers = 12,
	WalkSpeed = 20,
	JumpPower = 56,
	Gravity = 196.2,
	StartY = 80,
	-- Legacy obstacle-library layout settings; the adventure uses RegionRise/RegionRadius.
	StepRise = 4,
	StepsPerIsland = 8,
	RouteRadius = 26,
	RouteAngle = 0.30,
	PlatformWidth = 7,
	GenerateAhead = 240,
	MaxActiveIslands = 40,
	RebaseAt = 2048,
	RebaseAmount = 1024,
	TickRate = 0.10,
	SnapshotRate = 0.25,
	Intermission = 5, -- Exact queue countdown: 5 → 4 → 3 → 2 → 1 → START.
	OceanY = -32, -- Physical ocean surface (on the 4-stud voxel grid); falling to it is fatal.
	OceanHalfZ = 1536, -- Ocean fill: X from -1536 to LobbyX + 1184, Z within ±OceanHalfZ.
	JoinWindow = 25,
	WaveStart = -40,
	WaveGrace = 60,
	WaveBaseSpeed = 0.45,
	WaveMaxSpeed = 0.9,
	WaveCatchupDistance = 280,
	WaveCatchupSpeed = 5,
	WaveWarningDistance = 55,
	SessionLease = 180,
	AutosaveInterval = 45,
	StudioPersistence = false,
	Seed = 784219,
	Ability = {
		Dash = { Cooldown = 5, Duration = 1.0, Speed = 62, Label = "Gust Dash" },
		DoubleJump = { Cooldown = 6, Duration = 0.25, Lift = 68, Label = "Sky Leap" },
		Shield = { Cooldown = 18, Duration = 8, Health = 60, Label = "Aegis" },
		Glide = { Cooldown = 10, Duration = 6, FallSpeed = 9, Speed = 25, Label = "Wind Sail" },
	},
})
