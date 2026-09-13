local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Rope = require(ReplicatedStorage:WaitForChild("Rope"))

local STEP = 1 / 60
local THICKNESS = 0.3
local BRIDGE_FROM = Vector3.new(-12, 12, -45)
local BRIDGE_TO = Vector3.new(18, 12, -45)

local folder = Instance.new("Folder")
folder.Name = "Ropes"
folder.Parent = workspace

local rope, parts, crates
local held, heldWasPinned, depth = nil, false, 0

local function newPart(size, color, material)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanQuery = false
	part.CanTouch = false
	part.Material = material
	part.Color = color
	part.Size = size
	part.Parent = folder
	return part
end

local function addParts(from, width, height, color, material)
	for i = from, #rope.sticks do
		local s = rope.sticks[i]
		local part = newPart(Vector3.new(width, height, s.len), color, material)
		part.CanCollide = s.width ~= nil
		parts[s] = part
	end
end

local function build()
	folder:ClearAllChildren()
	held = nil
	parts, crates = {}, {}
	rope = Rope.new()
	rope.tearLength = 2.5

	rope:line(Vector3.new(0, 30, -20), Vector3.new(18, 30, -20), 30)
	addParts(1, THICKNESS, THICKNESS, Color3.fromRGB(150, 110, 70), Enum.Material.Fabric)

	local n = #rope.sticks
	rope:grid(Vector3.new(-24, 30, -20), Vector3.xAxis, 16, 12, 1, 3)
	addParts(n + 1, 0.15, 0.15, Color3.fromRGB(200, 60, 60), Enum.Material.Fabric)

	n = #rope.sticks
	for _, s in rope:bridge(BRIDGE_FROM, BRIDGE_TO, 20, 1.08, 4) do
		s.tearLength = 1.5
	end
	addParts(n + 1, 4, 0.4, Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks)

	for _, top in { BRIDGE_FROM, BRIDGE_TO } do
		local post = newPart(Vector3.new(2, top.Y, 6), Color3.fromRGB(90, 90, 95), Enum.Material.Slate)
		post.Position = Vector3.new(top.X, top.Y / 2 - 0.2, top.Z)
	end
end
build()

local function dropCrate()
	local x = math.random() * (BRIDGE_TO.X - BRIDGE_FROM.X - 8) + BRIDGE_FROM.X + 4
	local box = rope:box(Vector3.new(x, BRIDGE_FROM.Y + 15, BRIDGE_FROM.Z), 3, 8)
	local part = newPart(Vector3.new(3, 3, 3), Color3.fromRGB(160, 120, 70), Enum.Material.Wood)
	part.CanCollide = false
	crates[box] = part
end

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
	if input.KeyCode == Enum.KeyCode.B then
		dropCrate()
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
			if parts[s] then
				parts[s]:Destroy()
				parts[s] = nil
			end
		end
		acc -= STEP
	end

	local list, cframes = {}, {}
	for _, s in rope.sticks do
		local part = parts[s]
		if part then
			local a, b = s.a.pos, s.b.pos
			-- stretch the part to the real length so a pulled rope doesn't turn into a dotted line
			part.Size = Vector3.new(part.Size.X, part.Size.Y, (b - a).Magnitude)
			table.insert(list, part)
			table.insert(cframes, CFrame.lookAt((a + b) / 2, b))
		end
	end
	-- crates are drawn from their 4 corners so they tilt with the bridge
	for box, part in crates do
		local c1, c2, c3, c4 = box[1].pos, box[2].pos, box[3].pos, box[4].pos
		local right = (c2 - c1 + c3 - c4).Unit
		local up = (c4 - c1 + c3 - c2).Unit
		table.insert(list, part)
		table.insert(cframes, CFrame.fromMatrix((c1 + c2 + c3 + c4) / 4, right, up))
	end
	workspace:BulkMoveTo(list, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)
