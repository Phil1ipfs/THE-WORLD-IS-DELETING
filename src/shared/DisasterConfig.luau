--!strict
return table.freeze({
	Hurricane = table.freeze({ Height = 280, Orbit = 215, BaseRadius = 9, TopRadius = 66, Segments = 20 }),
	Earthquake = table.freeze({
		CellsPerRegion = 12,
		SurfaceCount = 6,
		TotalCells = 36,
		TotalSurfaces = 18,
		SurfaceLifetime = 24,
	}),
})
