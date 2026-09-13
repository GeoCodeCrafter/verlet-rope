local Rope = {}
Rope.__index = Rope

function Rope.new()
	local self = setmetatable({}, Rope)
	self.points = {}
	self.sticks = {}
	self.gravity = Vector3.new(0, -workspace.Gravity, 0)
	self.damping = 0.99
	self.iterations = 12
	self.tearLength = nil -- e.g. 2.5 = a stick snaps at 2.5x its rest length
	return self
end

function Rope:point(pos, pinned)
	local p = { pos = pos, old = pos, pinned = pinned or false }
	table.insert(self.points, p)
	return p
end

function Rope:stick(a, b)
	local s = { a = a, b = b, len = (a.pos - b.pos).Magnitude }
	table.insert(self.sticks, s)
	return s
end

-- rope from `from` to `to`, first point pinned
function Rope:line(from, to, segments)
	local first = self:point(from, true)
	local prev = first
	for i = 1, segments do
		local p = self:point(from:Lerp(to, i / segments))
		self:stick(prev, p)
		prev = p
	end
	return first, prev
end

-- cloth: cols x rows points hanging down from `origin` along `right`, every `pinEvery`th top point pinned
function Rope:grid(origin, right, cols, rows, gap, pinEvery)
	local grid = {}
	for y = 0, rows - 1 do
		grid[y] = {}
		for x = 0, cols - 1 do
			local pinned = y == 0 and x % (pinEvery or 1) == 0
			local p = self:point(origin + right * (x * gap) - Vector3.yAxis * (y * gap), pinned)
			grid[y][x] = p
			if x > 0 then
				self:stick(grid[y][x - 1], p)
			end
			if y > 0 then
				self:stick(grid[y - 1][x], p)
			end
		end
	end
	return grid
end

function Rope:step(dt)
	local g = self.gravity * dt * dt
	for _, p in self.points do
		if not p.pinned then
			local v = (p.pos - p.old) * self.damping
			p.old = p.pos
			p.pos += v + g
		end
	end

	for _ = 1, self.iterations do
		for _, s in self.sticks do
			local a, b = s.a, s.b
			local wa = if a.pinned then 0 else 1
			local wb = if b.pinned then 0 else 1
			if wa + wb > 0 then
				local delta = b.pos - a.pos
				local d = delta.Magnitude
				if d > 1e-4 then
					-- pull both ends back to rest length, pinned ends stay put
					local k = (d - s.len) / d / (wa + wb)
					a.pos += delta * (k * wa)
					b.pos -= delta * (k * wb)
				end
			end
		end
	end

	-- returns the sticks that snapped this step so whatever draws them can clean up
	local torn = {}
	if self.tearLength then
		for i = #self.sticks, 1, -1 do
			local s = self.sticks[i]
			if (s.b.pos - s.a.pos).Magnitude > s.len * self.tearLength then
				table.remove(self.sticks, i)
				table.insert(torn, s)
			end
		end
	end
	return torn
end

return Rope
