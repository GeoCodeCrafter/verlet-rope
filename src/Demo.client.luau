local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Rope = require(ReplicatedStorage:WaitForChild("Rope"))

local STEP = 1 / 60
local THICKNESS = 0.3

local rope = Rope.new()
rope:line(Vector3.new(0, 30, -20), Vector3.new(18, 30, -20), 30)

local folder = Instance.new("Folder")
folder.Name = "Ropes"
folder.Parent = workspace

local parts = {}
for i, s in rope.sticks do
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Fabric
	part.Color = Color3.fromRGB(150, 110, 70)
	part.Size = Vector3.new(THICKNESS, THICKNESS, s.len)
	part.Parent = folder
	parts[i] = part
end

-- dragging: grab the point closest to the mouse ray, keep it at the same distance from the camera
local held, heldWasPinned, depth = nil, false, 0

local function mouseRay()
	local m = UserInputService:GetMouseLocation()
	return workspace.CurrentCamera:ViewportPointToRay(m.X, m.Y)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	local ray = mouseRay()
	local best = 3
	for _, p in rope.points do
		local t = (p.pos - ray.Origin):Dot(ray.Direction)
		local d = (p.pos - (ray.Origin + ray.Direction * t)).Magnitude
		if t > 0 and d < best then
			best, held, depth = d, p, t
		end
	end
	if held then
		heldWasPinned = held.pinned
		held.pinned = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and held then
		held.pinned = heldWasPinned
		held = nil
	end
end)

local acc = 0
local cframes = table.create(#parts)

RunService.RenderStepped:Connect(function(dt)
	acc = math.min(acc + dt, 0.1)
	while acc >= STEP do
		if held then
			local ray = mouseRay()
			held.pos = ray.Origin + ray.Direction * depth
		end
		rope:step(STEP)
		acc -= STEP
	end

	for i, s in rope.sticks do
		local a, b = s.a.pos, s.b.pos
		cframes[i] = CFrame.lookAt((a + b) / 2, b)
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)
