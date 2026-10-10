--!nonstrict
-- Sample the avatar footprint: one center ray can hit a trunk/rail or miss a ledge.
local Probe = {}
function Probe.cast(world, root, hum)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world.Root }
	params.RespectCanCollide = true
	local range = math.clamp((hum and hum.HipHeight or 2) + root.Size.Y / 2 + 3, 7, 12)
	for _, offset in
		{
			Vector3.zero,
			Vector3.new(1.4, 0, 0),
			Vector3.new(-1.4, 0, 0),
			Vector3.new(0, 0, 1.4),
			Vector3.new(0, 0, -1.4),
		}
	do
		local hit = workspace:Raycast(root.Position + offset, Vector3.new(0, -range, 0), params)
		if
			hit
			and hit.Instance.CanCollide
			and hit.Instance:GetAttribute("Ground") == true
			and hit.Instance:GetAttribute("Phase") ~= "Breaking"
		then
			return hit
		end
	end
	return nil
end
return Probe
