local Rope = {}
Rope.__index = Rope

function Rope.new()
	local self = setmetatable({}, Rope)
	self.points = {}
	self.sticks = {}
	self.balls = {}
	self.gravity = Vector3.new(0, -workspace.Gravity, 0)
	self.damping = 0.99
	self.iterations = 12
	self.tearLength = nil -- e.g. 2.5 = a stick snaps at 2.5x its rest length
	return self
end

local function weight(p)
	return if p.pinned then 0 else 1 / (p.mass or 1)
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

-- bridge: pinned at both ends, slack > 1 makes it sag. its sticks are `width` wide planks things land on
function Rope:bridge(from, to, segments, slack, width)
	local first, last = self:line(from, to, segments)
	last.pinned = true
	local sticks = {}
	for i = #self.sticks - segments + 1, #self.sticks do
		local s = self.sticks[i]
		s.len *= slack or 1
		s.width = width or 2
		table.insert(sticks, s)
	end
	return sticks
end

-- a point with a radius that lands on planks
function Rope:ball(pos, radius, mass)
	local p = self:point(pos)
	p.radius = radius
	p.mass = mass
	table.insert(self.balls, p)
	return p
end

-- a crate: 4 corners kept square by its edges and both diagonals. it's the corners that land,
-- so it sits flat and tips over on a slope instead of sinking in like one big ball did
function Rope:box(center, size, mass)
	local h = size / 2
	local c = {}
	for i, o in { Vector3.new(-h, -h, 0), Vector3.new(h, -h, 0), Vector3.new(h, h, 0), Vector3.new(-h, h, 0) } do
		c[i] = self:ball(center + o, 0.25, mass / 4)
	end
	for _, pair in { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, { 1, 3 }, { 2, 4 } } do
		self:stick(c[pair[1]], c[pair[2]]).tearLength = math.huge
	end
	return c
end

local function collide(ball, s)
	local a, b = s.a.pos, s.b.pos
	local ab = b - a
	local len = ab.Magnitude
	if len < 1e-4 then
		return
	end
	local dir = ab / len
	local t = (ball.pos - a):Dot(dir) / len
	if t < -0.05 or t > 1.05 then
		return
	end
	local c = a + ab * math.clamp(t, 0, 1)
	local up = Vector3.yAxis - dir * dir.Y
	up = up / up.Magnitude
	local h = (ball.pos - c):Dot(up)
	if h >= ball.radius or math.abs((ball.pos - c):Dot(dir:Cross(up))) > s.width / 2 then
		return
	end
	-- planks only have a top. if it was above the plank last step it goes back on top, even if one of
	-- them moved right past the other this step. has to be where the plank WAS, not where it is now,
	-- or a bridge springing back up passes the crate and it counts as already underneath
	local oldC = s.a.old:Lerp(s.b.old, math.clamp(t, 0, 1))
	if (ball.old - oldC):Dot(up) < 0 then
		return
	end

	local n = up * (ball.radius - h)
	local w0, wa, wb = weight(ball), weight(s.a) * (1 - t), weight(s.b) * t
	local total = w0 + wa + wb
	if total <= 0 then
		return
	end
	ball.pos += n * (w0 / total)
	s.a.pos -= n * (wa / total)
	s.b.pos -= n * (wb / total)
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
			local wa, wb = weight(a), weight(b)
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
		for _, ball in self.balls do
			for _, s in self.sticks do
				if s.width then
					collide(ball, s)
				end
			end
		end
	end

	-- returns the sticks that snapped this step so whatever draws them can clean up
	local torn = {}
	for i = #self.sticks, 1, -1 do
		local s = self.sticks[i]
		local limit = s.tearLength or self.tearLength
		if limit and (s.b.pos - s.a.pos).Magnitude > s.len * limit then
			table.remove(self.sticks, i)
			table.insert(torn, s)
		end
	end
	return torn
end

return Rope
