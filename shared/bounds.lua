BoundingBox = {
	position = { x = 0, y = 0 },
	bounds = { x = 0, y = 0 }
}
function BoundingBox:new(position, bounds)
	box = {}
	setmetatable(box, BoundingBox)
	self.__index = BoundingBox
	box.position = position or { x = 0, y = 0 }
	box.bounds = bounds or { x = 32, y = 32 }
	return box
end
function BoundingBox:set_position(position)
	assert(position.x, position.y, "Invalid position X/Y.")
	self.position = position
end
function BoundingBox:set_bounds(bounds)
	assert(bounds.x, bounds.y, "Invalid bounds X/Y.")
	self.bounds = bounds
end
function BoundingBox:does_collide(box)
	return self.position.x < box.position.x + box.bounds.x and self.position.x + self.bounds.x > box.position.x and self.position.y < box.position.y + box.bounds.y and self.position.y + self.bounds.y > box.position.y
end
function BoundingBox:would_collide(box, position)
	local pos = self.position
	self.position = position
	local collides = self:does_collide(box)
	self.position = pos
	return collides
end
