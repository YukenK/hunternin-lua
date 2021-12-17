-- This is a terrible utility designed to just let me figure out offsets and framerates without
-- a full, proper spriting utility. Don't use this unless you really have to; hopefully
-- I can replace this with something better in the future(TM).

require "libs.time"
require "libs.writer"
local keys = { left = "left", right = "right", up = "up", down = "down", x = "next_frame", z = "prev_frame", space = "pause", c = "prev", v = "next", f = "flip" }

local table = {}
function write_table(table, data)
	table[#table + 1] = "{"
	for key, value in pairs(data) do
		if type(value) == "table" then
			table[#table + 1] = key .. "="
			write_table(table, value)
		elseif type(value) == "string" then
			table[#table + 1] = key .. "=\"" .. tostring(value) .. "\","
		else
			table[#table + 1] = key .. "=" .. value .. ","
		end
	end
	table[#table + 1] = "},"
end
local last_keys = {}
for k, v in pairs(keys) do
	last_keys[v] = false
end

local sprite = "kakashi"
local texture = nil
local atlas = {}

local state_index = 1
local max_states = 0
local current_state = "stand"
local current_frame = 1
local paused = false
local frame_offsets = {}
local flipped = false

function love.load()
	local sprite_data = require(sprite)
	write_table(table, sprite_data)
	writer.write_string("test.lua", #table, table)
	texture = love.graphics.newImage(sprite .. ".png")
	local image_data = love.image.newImageData(sprite .. ".png")
	atlas = {
		frames = {},
		states = sprite_data.states
	}
	for k, state in pairs(sprite_data.states) do
		atlas.frames[k] = {}
		frame_offsets[k] = {}
		max_states = max_states + 1
		for i = 1, #state, 1 do
			local frame = sprite_data.frames[k][state[i][1]]
			frame_offsets[k][i] = { state[i][3], state[i][4] }
			for w = (frame[1] - 1) * sprite_data.width + (sprite_data.width - 1), (frame[1] - 1) * sprite_data.width, -1 do
				local finished = false
				local least_width = 0
				for h = (frame[2] - 1) * sprite_data.height + (sprite_data.height - 1), (frame[2] - 1) * sprite_data.height, -1 do
					local r, g, b = image_data:getPixel(w, h)
					if r + g + b ~= 0 then
						local width = (w + 1) - (frame[1] - 1) * sprite_data.width
						if least_width == 0 or width < least_width then
							least_width = width
						end
						frame_offsets[k][i][3] = (w + 1) - (frame[1] - 1) * sprite_data.width
						finished = true
						break
					end
				end
				frame_offsets[k].least_width = least_width
				if finished then
					break
				end
			end
			atlas.frames[k][i] = love.graphics.newQuad((frame[1] - 1) * sprite_data.width, (frame[2] - 1) * sprite_data.height, sprite_data.width - 1, sprite_data.height - 1, texture:getDimensions())
		end
		current_state = k
		state_index = max_states
	end
end

local next_frame_time = time.get_time()
function next_state()
	if state_index == max_states then
		state_index = 1
		for k, v in pairs(atlas.states) do
			current_state = k
			break
		end
	else
		state_index = state_index + 1
		local n = 0
		for k, v in pairs(atlas.states) do
			n = n + 1
			if n == state_index then
				current_state = k
				break
			end
		end
	end
	current_frame = 1
end
function prev_state()

end
function next_frame()
	if current_frame >= #atlas.frames[current_state] then
		current_frame = 1
	else
		current_frame = current_frame + 1
	end
end
function prev_frame()
	if current_frame == 1 then
		current_frame = #atlas.frames[current_state]
	else
		current_frame = current_frame - 1
	end
end
function handle_key(key, value)
	if key == "right" and value then
		frame_offsets[current_state][current_frame][1] = frame_offsets[current_state][current_frame][1] + 1
	elseif key == "left" and value then
		frame_offsets[current_state][current_frame][1] = frame_offsets[current_state][current_frame][1] - 1
	elseif key == "up" and value then
		frame_offsets[current_state][current_frame][2] = frame_offsets[current_state][current_frame][2] - 1
	elseif key == "down" and value then
		frame_offsets[current_state][current_frame][2] = frame_offsets[current_state][current_frame][2] + 1
	elseif key == "next" and value then
		next_state()
	elseif key == "prev" and value then
		prev_state()
	elseif key == "next_frame" and value then
		next_frame()
	elseif key == "prev_frame" and value then
		prev_frame()
	elseif key == "pause" and value then
		paused = not paused
	elseif key == "flip" and value then
		flipped = not flipped
	end
end


function love.update()
	if not paused and time.get_time() >= next_frame_time then
		next_frame()
		next_frame_time = (atlas.states[current_state][current_frame][2]) + time.get_time()
	end
	for k, v in pairs(keys) do
		if love.keyboard.isDown(k) and not last_keys[v] then
			last_keys[v] = true
			handle_key(v, true)
		elseif last_keys[v] and not love.keyboard.isDown(k) then
			last_keys[v] = false
			handle_key(v, false)
		end
	end
end

function love.draw()
	love.graphics.print("X: " .. frame_offsets[current_state][current_frame][1], 12, 12)
	love.graphics.print("Y: " .. frame_offsets[current_state][current_frame][2], 12, 24)
	love.graphics.print("Frame: " .. current_frame, 12, 36)
	local scale_x = 1
	local offset_x = 0
	local offset_y = 0
	if flipped then
		scale_x = -1
--		print(frame_offsets[current_state][current_frame][3])
		--offset_x = -frame_offsets[current_state][current_frame][1]
		offset_x = frame_offsets[current_state].least_width - frame_offsets[current_state][current_frame][1]
	else
		scale_x = 1
		offset_x = frame_offsets[current_state][current_frame][1]
	end
	love.graphics.draw(texture, atlas.frames[current_state][current_frame], 120 + offset_x, 120 + frame_offsets[current_state][current_frame][2], 0, scale_x, 1)
end
