--!nonstrict
-- Designed sound effects built ONLY from audio files that ship inside the Roblox client
-- (content/sounds, verified on the developer machine 2026-10-11). No asset IDs are invented.
-- Each cue shapes a bundled file with playback speed, a time window and SoundEffects
-- (distortion, reverb, EQ, pitch shift, tremolo, chorus) and may stack delayed layers.
-- A permissioned rbxassetid in AudioConfig always overrides the designed cue of the same name.
-- Pure Luau: `make` receives the Instance constructor from the caller (client or server).
local Bank = {}
local F = "rbxasset://sounds/"
Bank.Files = {
	Wind = F .. "action_falling.ogg", -- long rushing-air whoosh
	Steps = F .. "action_footsteps_plastic.mp3",
	GetUp = F .. "action_get_up.mp3",
	Jump = F .. "action_jump.mp3",
	Land = F .. "action_jump_land.mp3", -- soft body thump
	Splash = F .. "action_swim.mp3", -- broadband watery rush (fire/rain/burner bed)
	Boom = F .. "impact_explosion_03.mp3",
	Water = F .. "impact_water.mp3",
	Oof = F .. "oof.ogg",
	Ouch = F .. "ouch.ogg", -- vocal; pitched down it becomes a growl
	Click = F .. "volume_slider.ogg", -- short UI tick; pitched it becomes chimes
}
local W = Bank.Files
-- Recipe fields: Sound, Speed, Volume, Start (TimePosition), Length (cut-off seconds),
-- Range (max hearing distance for positioned one-shots), Looped, Effects, Layers
-- ({ recipe + Delay }). Effects: Distortion, Reverb, Equalizer, PitchShift, Tremolo, Chorus.
local function chime(speeds, volume, gap)
	local layers = {}
	for i, speed in speeds do
		table.insert(layers, {
			Sound = W.Click,
			Speed = speed,
			Volume = volume,
			Delay = (i - 1) * (gap or 0.09),
			Effects = { Reverb = { DecayTime = 0.9, WetLevel = -8 } },
		})
	end
	return { Layers = layers }
end
Bank.Cues = {
	-- Movement and powers.
	Jump = { Sound = W.Jump, Speed = 1, Volume = 0.28 },
	Land = { Sound = W.Land, Speed = 1, Volume = 0.32 },
	Dash = { Sound = W.Wind, Speed = 1.8, Volume = 0.36, Start = 0.25, Length = 0.55 },
	Leap = {
		Layers = {
			{ Sound = W.Jump, Speed = 0.85, Volume = 0.45 },
			{ Sound = W.Wind, Speed = 1.5, Volume = 0.25, Start = 0.3, Length = 0.45 },
		},
	},
	Glide = { Sound = W.Wind, Speed = 1.05, Volume = 0.3, Start = 0.2, Length = 1.1 },
	Shield = {
		Layers = {
			{
				Sound = W.Click,
				Speed = 0.55,
				Volume = 0.45,
				Effects = { Chorus = { Depth = 0.4, Mix = 0.6 }, Reverb = { DecayTime = 1.4 } },
			},
			{
				Sound = W.Click,
				Speed = 0.82,
				Volume = 0.3,
				Delay = 0.06,
				Effects = { Reverb = { DecayTime = 1.4 } },
			},
		},
	},
	ShieldBreak = {
		Sound = W.Boom,
		Speed = 2.1,
		Volume = 0.32,
		Length = 0.45,
		Effects = { Equalizer = { LowGain = -12, MidGain = 0, HighGain = 4 } },
	},
	Ability = { Sound = W.Click, Speed = 0.9, Volume = 0.35 },
	-- Supplies.
	Pickup = chime({ 1.3, 1.65 }, 0.35, 0.06),
	Heal = chime({ 1.2, 1.5, 1.8 }, 0.3),
	Overcharge = {
		Layers = {
			{ Sound = W.Click, Speed = 0.6, Volume = 0.45, Effects = { Distortion = { Level = 0.35 } } },
			{ Sound = W.Click, Speed = 1.2, Volume = 0.35, Delay = 0.08 },
			{ Sound = W.Click, Speed = 1.8, Volume = 0.3, Delay = 0.16 },
		},
	},
	Brace = {
		Layers = {
			{ Sound = W.Land, Speed = 0.6, Volume = 0.55 },
			{ Sound = W.Steps, Speed = 0.8, Volume = 0.35, Length = 0.3, Delay = 0.05 },
		},
	},
	Hit = { Sound = W.Land, Speed = 1.35, Volume = 0.5, Effects = { Distortion = { Level = 0.2 } } },
	Chest = chime({ 1.1, 1.4, 1.75 }, 0.4, 0.11),
	Complete = chime({ 1.0, 1.26, 1.5, 2.0 }, 0.4, 0.1),
	Discovery = chime({ 1.2, 1.6 }, 0.35, 0.12),
	Tick = { Sound = W.Click, Speed = 1, Volume = 0.42 },
	Start = chime({ 1.5, 2.0 }, 0.5, 0.07),
	Splash = { Sound = W.Water, Speed = 1, Volume = 0.6 },
	SheepBleat = {
		Sound = W.Oof,
		Speed = 1.9,
		Volume = 0.35,
		Range = 60,
		Effects = { Tremolo = { Depth = 0.7, Frequency = 16 } },
	},
	-- World and disasters.
	Collapse = {
		Sound = W.Boom,
		Speed = 0.7,
		Volume = 0.5,
		Effects = { Equalizer = { LowGain = 6, MidGain = 0, HighGain = -8 } },
	},
	Deletion = {
		Sound = W.Wind,
		Speed = 0.4,
		Volume = 0.45,
		Length = 2.2,
		Effects = { Distortion = { Level = 0.5 } },
	},
	Earthquake = {
		Layers = {
			{
				Sound = W.Boom,
				Speed = 0.32,
				Volume = 0.7,
				Effects = { Distortion = { Level = 0.35 }, Reverb = { DecayTime = 2.5 } },
			},
			{ Sound = W.Wind, Speed = 0.3, Volume = 0.4, Length = 2.5, Delay = 0.1 },
		},
	},
	Storm = {
		Sound = W.Boom,
		Speed = 0.45,
		Volume = 0.5,
		Effects = { Reverb = { DecayTime = 3.5, WetLevel = -2 } },
	},
	Thunder = {
		Sound = W.Boom,
		Speed = 0.42,
		Volume = 0.55,
		Range = 4000,
		Effects = {
			Reverb = { DecayTime = 4, WetLevel = 0 },
			Equalizer = { LowGain = 6, MidGain = 0, HighGain = -4 },
		},
	},
	DistantThunder = {
		Sound = W.Boom,
		Speed = 0.3,
		Volume = 0.3,
		Range = 4000,
		Effects = {
			Reverb = { DecayTime = 5, WetLevel = 0 },
			Equalizer = { LowGain = 4, MidGain = -6, HighGain = -20 },
		},
	},
	-- Realm Destroyer.
	DragonRoar = {
		Range = 4000,
		Layers = {
			{
				Sound = W.Ouch,
				Speed = 0.33,
				Volume = 0.9,
				Effects = { Distortion = { Level = 0.6 }, Reverb = { DecayTime = 2.8, WetLevel = -3 } },
			},
			{
				Sound = W.Wind,
				Speed = 0.3,
				Volume = 0.55,
				Length = 2.6,
				Effects = {
					Distortion = { Level = 0.45 },
					Equalizer = { LowGain = 8, MidGain = 0, HighGain = -12 },
				},
			},
			{
				Sound = W.Boom,
				Speed = 0.26,
				Volume = 0.45,
				Delay = 0.15,
				Effects = { Equalizer = { LowGain = 10, MidGain = -4, HighGain = -18 } },
			},
		},
	},
	DragonFire = {
		Sound = W.Splash,
		Speed = 0.55,
		Volume = 0.75,
		Looped = true,
		Effects = { Distortion = { Level = 0.55 }, Equalizer = { LowGain = 4, MidGain = 2, HighGain = -6 } },
	},
	DragonWings = {
		Layers = {
			{
				Sound = W.Land,
				Speed = 0.33,
				Volume = 0.6,
				Effects = { Equalizer = { LowGain = 8, MidGain = 0, HighGain = -10 } },
			},
			{ Sound = W.Wind, Speed = 0.55, Volume = 0.35, Start = 0.4, Length = 0.45 },
		},
	},
	DragonGust = {
		Sound = W.Wind,
		Speed = 0.85,
		Volume = 0.75,
		Start = 0.1,
		Length = 1.3,
		Range = 300,
		Effects = { Equalizer = { LowGain = 6, MidGain = 0, HighGain = -2 } },
	},
	DragonImpact = {
		Sound = W.Boom,
		Speed = 0.55,
		Volume = 0.85,
		Range = 400,
		Effects = {
			Reverb = { DecayTime = 2.2, WetLevel = -4 },
			Equalizer = { LowGain = 8, MidGain = 0, HighGain = -4 },
		},
	},
	DragonHurt = {
		Sound = W.Ouch,
		Speed = 0.5,
		Volume = 0.6,
		Range = 600,
		Effects = { Distortion = { Level = 0.45 } },
	},
	-- Dragonbane weapons.
	DragonbaneShot = {
		Layers = {
			{ Sound = W.Jump, Speed = 2.2, Volume = 0.45, Length = 0.25 },
			{ Sound = W.Click, Speed = 2.4, Volume = 0.35 },
		},
	},
	HarpoonThrow = {
		Layers = {
			{ Sound = W.Wind, Speed = 2.1, Volume = 0.45, Start = 0.2, Length = 0.45 },
			{ Sound = W.Jump, Speed = 0.75, Volume = 0.4 },
		},
	},
	BallistaFire = {
		Range = 200,
		Layers = {
			{ Sound = W.Land, Speed = 0.5, Volume = 0.7 },
			{ Sound = W.Wind, Speed = 1.6, Volume = 0.45, Start = 0.3, Length = 0.4, Delay = 0.03 },
			{ Sound = W.Click, Speed = 0.5, Volume = 0.4 },
		},
	},
	CannonFire = {
		Range = 260,
		Layers = {
			{ Sound = W.Boom, Speed = 1.25, Volume = 0.7 },
			{
				Sound = W.Click,
				Speed = 0.7,
				Volume = 0.45,
				Effects = { Chorus = { Depth = 0.5, Mix = 0.7 }, Reverb = { DecayTime = 1.8 } },
			},
		},
	},
	WeakPointHit = chime({ 2.0, 2.6 }, 0.45, 0.05),
	ForgeCraft = {
		Layers = {
			{
				Sound = W.Land,
				Speed = 1.7,
				Volume = 0.55,
				Effects = { Equalizer = { LowGain = -6, MidGain = 4, HighGain = 6 } },
			},
			{ Sound = W.Click, Speed = 0.8, Volume = 0.4, Delay = 0.04 },
			{ Sound = W.Land, Speed = 1.9, Volume = 0.45, Delay = 0.28 },
		},
	},
	-- Sky Balloon.
	BalloonBurner = {
		Sound = W.Wind,
		Speed = 0.7,
		Volume = 0.5,
		Start = 0.2,
		Length = 1.4,
		Effects = { Equalizer = { LowGain = 5, MidGain = 0, HighGain = -6 } },
	},
	BalloonDepart = {
		Layers = {
			{ Sound = W.Wind, Speed = 0.55, Volume = 0.5, Length = 2.4 },
			{ Sound = W.Click, Speed = 1.0, Volume = 0.35, Delay = 0.1 },
		},
	},
	BalloonArrive = chime({ 1.0, 1.33, 1.6 }, 0.35, 0.12),
}
-- Looping beds (AudioController ambience and storm layers).
Bank.Beds = {
	StormWind = {
		Sound = W.Wind,
		Speed = 0.55,
		Looped = true,
		Effects = { Equalizer = { LowGain = 4, MidGain = 0, HighGain = -4 } },
	},
	StormRain = {
		Sound = W.Splash,
		Speed = 1.35,
		Looped = true,
		Effects = { Equalizer = { LowGain = -10, MidGain = 0, HighGain = 2 } },
	},
	Danger = {
		Sound = W.Wind,
		Speed = 0.25,
		Looped = true,
		Effects = { Distortion = { Level = 0.25 }, Tremolo = { Depth = 0.4, Frequency = 1.2 } },
	},
	Biome = {
		Sound = W.Wind,
		Speed = 0.38,
		Looped = true,
		Effects = { Equalizer = { LowGain = 0, MidGain = -6, HighGain = -14 } },
	},
}
-- World-object loops (server-created, 3D): balloon burner, forge fire, dragon breath.
Bank.Loops = {
	BalloonBurner = {
		Sound = W.Splash,
		Speed = 0.4,
		Volume = 0.32,
		Looped = true,
		Range = 70,
		Effects = { Equalizer = { LowGain = 6, MidGain = -2, HighGain = -10 } },
	},
	ForgeFire = {
		Sound = W.Splash,
		Speed = 0.8,
		Volume = 0.22,
		Looped = true,
		Range = 40,
		Effects = { Distortion = { Level = 0.4 }, Equalizer = { LowGain = -4, MidGain = 0, HighGain = 0 } },
	},
}
local effectClass = {
	Distortion = "DistortionSoundEffect",
	Reverb = "ReverbSoundEffect",
	Equalizer = "EqualizerSoundEffect",
	PitchShift = "PitchShiftSoundEffect",
	Tremolo = "TremoloSoundEffect",
	Chorus = "ChorusSoundEffect",
}
-- Every file a recipe references (tests assert they are all in Bank.Files).
function Bank.paths()
	local seen = {}
	local function visit(recipe)
		if recipe.Sound then
			seen[recipe.Sound] = true
		end
		for _, layer in recipe.Layers or {} do
			visit(layer)
		end
	end
	for _, group in { Bank.Cues, Bank.Beds, Bank.Loops } do
		for _, recipe in group do
			visit(recipe)
		end
	end
	return seen
end
-- Replaces a Sound's effects with a recipe's (new = Instance.new from the caller).
function Bank.effects(new, recipe, sound)
	for _, child in sound:GetChildren() do
		if child:GetAttribute("BankEffect") then
			child:Destroy()
		end
	end
	for name, props in recipe.Effects or {} do
		local effect = new(effectClass[name])
		for key, value in props do
			effect[key] = value
		end
		effect:SetAttribute("BankEffect", true)
		effect.Parent = sound
	end
end
-- Builds a configured Sound under parent for a single-file recipe (layers use the first).
function Bank.make(new, recipe, parent, name)
	local base = recipe.Sound and recipe or (recipe.Layers and recipe.Layers[1]) or recipe
	local sound = new("Sound")
	sound.Name = name or "BankSound"
	sound.SoundId = base.Sound or ""
	sound.PlaybackSpeed = base.Speed or 1
	sound.Volume = base.Volume or 0.5
	sound.Looped = recipe.Looped == true
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = recipe.Range or 120
	Bank.effects(new, base, sound)
	sound.Parent = parent
	return sound
end
return Bank
