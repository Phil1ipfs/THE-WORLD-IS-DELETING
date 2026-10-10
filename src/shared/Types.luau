--!strict
export type PlayerState = "Lobby" | "Queued" | "Alive" | "Eliminated" | "Spectating"
export type Profile = {
	Schema: number,
	Best: number,
	Survival: number,
	Attempts: number,
	Coins: number,
	XP: number,
	Owned: { [string]: boolean },
	Equipped: string,
}
export type Difficulty = { Intensity: number, Speed: number, LandingScale: number, Combinations: number }
export type RoutePoint = { X: number, Y: number, Z: number, Step: number }
return {}
