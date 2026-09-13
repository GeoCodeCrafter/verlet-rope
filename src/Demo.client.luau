local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Rope = require(ReplicatedStorage:WaitForChild("Rope"))

local STEP = 1 / 60
local THICKNESS = 0.3

local folder = Instance.new("Folder")
folder.Name = "Ropes"
folder.Parent = workspace

local rope, parts
local held, heldWasPinned, depth = nil, false, 0

local function build()
	folder:ClearAllChildren()
	held = nil
	rope = Rope.new()
	rope.tearLength = 2.5
	rope:line(Vector3.new(0, 30, -20), Vector3.new(18, 30, -20), 30)

	parts = {}
	for _, s in rope.sticks do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Fabric
		part.Color = Color3.fromRGB(150, 110, 70)
		part.Size = Vector3.new(THICKNESS, THICKNESS, s.len)
		part.Parent = folder
		parts[s] = part
	end
end
build()

-- dragging: grab the point closest to the mouse ray, keep it at the same distance from the camera
local function mouseRay()
	local m = UserInputService:GetMouseLocation()
	return workspace.CurrentCamera:ViewportPointToRay(m.X, m.Y)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		build()
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
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

RunService.RenderStepped:Connect(function(dt)
	acc = math.min(acc + dt, 0.1)
	while acc >= STEP do
		if held then
			local ray = mouseRay()
			held.pos = ray.Origin + ray.Direction * depth
		end
		for _, s in rope:step(STEP) do
			parts[s]:Destroy()
			parts[s] = nil
		end
		acc -= STEP
	end

	local list, cframes = {}, {}
	for _, s in rope.sticks do
		local a, b = s.a.pos, s.b.pos
		local part = parts[s]
		-- stretch the part to the real length so a pulled rope doesn't turn into a dotted line
		part.Size = Vector3.new(THICKNESS, THICKNESS, (b - a).Magnitude)
		table.insert(list, part)
		table.insert(cframes, CFrame.lookAt((a + b) / 2, b))
	end
	workspace:BulkMoveTo(list, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)
