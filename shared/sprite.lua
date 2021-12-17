Sprite = {
	atlas = nil,
	current_frame = {},
	frames = {},
	next_frame = {},
}


function Sprite:new(atlas, state)
	sprite = {}
	setmetatable(sprite, self)
	self.__index = self
	sprite.atlas = atlas
	sprite.current_frame = {}
	sprite.frames = {}
	sprite.next_frame = {}
	sprite:set_frame(state or "stand")
	return sprite
end
function Sprite:set_atlas(atlas)
	self.atlas = atlas
end
function Sprite:set_frame(key)
	if not self.current_frame.frames then
		self.current_frame.frames = {}
	end
	if not self.current_frame.frames[key] then
		self.current_frame.frames[key] = 1
	end
	self.current_frame.key = key
end

function Sprite:tick(WORLD_TIME)
	local key = self.current_frame.key
	local state = self.atlas.states[key]
	if not self.next_frame[key] then
		self.next_frame[key] = WORLD_TIME + state[self.current_frame.frames[key]][2]
	end
	if WORLD_TIME >= self.next_frame[key] then
		if state[self.current_frame.frames[key]][1] == #state or WORLD_TIME - self.next_frame[key] >= 1000 then
			self.current_frame.frames[key] = 1
		else
			self.current_frame.frames[key] = self.current_frame.frames[key] + 1
		end
		self.next_frame[key] = WORLD_TIME + state[self.current_frame.frames[key]][2]
	end
end
