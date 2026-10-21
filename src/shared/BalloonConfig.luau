--!strict
-- Sky Balloon transport (replaces the 0.6 sky elevator). Server-owned boarding, a shared
-- departure countdown, guided flight to the next region and a turnaround before it docks again.
return table.freeze({
	Countdown = 5, -- Seconds between the first boarding and departure; later riders join the same flight.
	Capacity = 8, -- Riders per flight; the rest wait for the next balloon.
	Flight = 14, -- Seconds from lift-off to arrival.
	ExpressFlight = 8, -- With the realm's machinery repaired (ExpressLift).
	Turnaround = 8, -- Seconds after arrival before a fresh balloon docks at the station.
	Climb = 46, -- Extra arc height above the straight path at mid-flight.
	-- Gondola seat offsets (studs) from the deck centre; riders stand at deck height + 3.
	Seats = {
		{ -1.8, -1.8 },
		{ 1.8, 1.8 },
		{ 1.8, -1.8 },
		{ -1.8, 1.8 },
		{ 0, -2.4 },
		{ 0, 2.4 },
		{ -2.4, 0 },
		{ 2.4, 0 },
	},
	-- Fabric variants (RGB). Navy & cream is the primary; red & cream alternates by region.
	Variants = {
		Navy = { Envelope = { 34, 48, 96 }, Stripe = { 238, 228, 204 }, Trim = { 214, 172, 74 } },
		Crimson = { Envelope = { 150, 34, 38 }, Stripe = { 240, 230, 210 }, Trim = { 214, 172, 74 } },
	},
})
