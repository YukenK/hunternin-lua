Player = {
	id = nil,
	position = { x = 0, y = 0 },
	last_position = { x = 0, y = 0 },
	velocity = { x = 0, y = 0 },
	bounding_box = nil,
	inputs = {},
	last_inputs = {},
	character = nil,
	sprite = nil,
	dir = "east",
	is_loaded = false,
	is_grounded = false,

	move_speed = 64,
	run_speed = 192,
	run_cost = 5,
	gravity_rate = 2048,
	gravity_max = 1024,
	move_x = 0,
	is_run = false,
	has_moved_since_tick = false,

	stats = {},

	binds = {}
}
function Player:new(id, position, box)
	p = {}
	setmetatable(p, self)
	self.__index = self
	
	p.id = id
	p.position = position or { x = 0, y = 0 }
	p.bounding_box = box or BoundingBox:new(p.position)
	p.velocity = { x = 0, y = 0 }
	p.inputs = {}
	p.last_inputs = {}
	for key, _ in pairs(packet_key_value) do
		p.inputs[key] = 0
		p.last_inputs[key] = 0
	end
	return p
end
function Player:tick(dt, map)
	if self.sprite then
		self:sprite_tick()
	end
	self:handle_input()
	self:move(dt, map)
end
function Player:handle_input()
	if self.inputs.left ~= 0 and self.inputs.right ~= 0 then
		self.move_x = 0
	elseif self.inputs.left == 1 then
		self.move_x = -1
	elseif self.inputs.right == 1 then
		self.move_x = 1
	else
		self.move_x = 0
	end
	self.is_run = self.inputs.run == 1
	for key, value in pairs(self.inputs) do
		self.last_inputs[key] = value
	end

end
function Player:set_position(position)
	self.last_position.x = self.position.x
	self.last_position.y = self.position.y
	self.position.x = position.x
	self.position.y = position.y
	if self.position.x ~= self.last_position.x or self.position.y ~= self.last_position.y then
		self.has_moved_since_tick = true
	end
	self.bounding_box.position = { x = position.x, y = position.y - self.bounding_box.bounds.y}
end
function Player:gravity(dt)
	if self.is_grounded then
		self.velocity.y = 0
	elseif self.velocity.y > self.gravity_max then
		self.velocity.y = math.clamp(self.velocity.y - self.gravity_rate * dt, self.gravity_max, self.velocity.y)
	elseif self.velocity.y < self.gravity_max then
		self.velocity.y = math.clamp(self.velocity.y + self.gravity_rate * dt, self.velocity.y, self.gravity_max)
	end
end
function Player:move(dt, map)
	self:gravity(dt)
	if self.is_run then
		self.velocity.x = self.run_speed * self.move_x
	else
		self.velocity.x = self.move_speed * self.move_x
	end
	if self.velocity.x == 0 and self.velocity.y == 0 then
		return nil
	end
	local bounds = {}
	for x = -1, 1, 1 do -- Get all tiles around us to collision check.
		for y = -1, 1, 1 do
			local tile = map:get_tile(math.ceil(self.bounding_box.position.x / 32) + x, math.ceil(self.bounding_box.position.y / 32) + y + math.round_up(self.bounding_box.bounds.y, 32) / 32)
			if tile and tile_data[tile.id].dense then
				bounds[#bounds + 1] = BoundingBox:new({x = (tile.x - 1) * 32, y = (tile.y - 1) * 32}, {x = 32, y = 32})
			end
		end
	end
	local new_position = { }
	local has_moved = false
	if self.velocity.x ~= 0 then -- We check X and Y separately, to prevent "sticking".
		local should_move_x = true
		local new_bounds = { x = self.bounding_box.position.x + self.velocity.x * dt, y = math.ceil(self.bounding_box.position.y) }
		for i = 1, #bounds, 1 do
			if self.bounding_box:would_collide(bounds[i], new_bounds) then
				should_move_x = false
				break
			end
		end
		if should_move_x then
			has_moved = true
			new_position.x = self.position.x + self.velocity.x * dt
		end
	end
	if self.velocity.y ~= 0 then
		local should_move_y = true
		local new_bounds = { x = math.ceil(self.bounding_box.position.x), y = math.ceil(self.bounding_box.position.y + self.velocity.y * dt) }
		for i = 1, #bounds, 1 do
			if self.bounding_box:would_collide(bounds[i], new_bounds) then
				should_move_y = false
				break
			end
		end
		if should_move_y then
			has_moved = true
			new_position.y = self.position.y + self.velocity.y * dt
		elseif self.position.y % 32 ~= 0 then -- If we have downward velocity, our next movement would make us merge with the ground but we still haven't touched the ground, set us to the ground.
			new_position.y = math.round_up(self.position.y, 32)
			has_moved = true
		end
	end
	if has_moved then self:set_position({ x = new_position.x or self.position.x, y = new_position.y or self.position.y }) end
end
function Player:check_grounded(map)
	self.is_grounded = false
	for i = -1, 1, 1 do
		local x = math.ceil(self.bounding_box.position.x / 32) + i
		local y = math.ceil(self.bounding_box.position.y / 32) + math.round_up(self.bounding_box.bounds.x, 32) / 32 + 1
		if x > 0 and y > 0 then
			local tile = map:get_tile(x, y)
			if tile then
				local bounds = BoundingBox:new({x = (tile.x - 1) * 32, y = (tile.y - 1) * 32}, {x = 32, y = 32})
				self.is_grounded = tile_data[tile.id].dense and self.bounding_box:would_collide(bounds, {x = self.bounding_box.position.x, y = self.bounding_box.position.y + 2})
				if self.is_grounded then break end
			end
		end
	end
end
function Player:can_move()
	for _, _ in pairs(self.binds) do
		return false
	end
	return self.is_loaded
end
function Player:can_turn()
	for _, bind in pairs(self.binds) do
		if not bind.can_turn then
			return false
		end
	end
	return self.is_loaded
end
function Player:can_run()
	return self.stats.stamina >= self.run_cost
end
function Player:sprite_tick()
	if not self.is_grounded then
		self.sprite:set_frame("jump")
	elseif self.move_x ~= 0 then
		if self.is_run then
			self.sprite:set_frame("run")
		else
			self.sprite:set_frame("walk")
		end
	else
		self.sprite:set_frame("stand")
	end
end
