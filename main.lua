local enet = require "enet"
local config = require "client_config"
local nuklear = require "nuklear"

require "time"
require "shared/packet"
require "shared/tiles"
require "shared/map"
require "shared/player"
require "shared/characters"
require "shared/sprite"
require "shared/bounds"
require "shared/math"

textures = {}
sprites = {}
character_sprites = {}
tile_batch = nil

WORLD_TIME = time.get_time()

local ui = nil
local address = { value = "127.0.0.1:5520" }
local running = true
gui_state = {
	visible_windows = {"main_menu"},
	functions = {
		["main_menu"] = function(scale)
			if game_state.is_connected then return false end
			if ui:windowBegin("main_menu", (640 - 100) * scale[1], (360 - 80) * scale[2], 200 * scale[1], 160 * scale[2]) then
				ui:layoutRow("dynamic", 20, 1)
				if not game_state.is_connecting and ui:button("Connect") then
					connect_to_server(address.value)
					address.value = ""
				elseif game_state.is_connecting then
					ui:label("Connecting...")
				end
				ui:edit("field", address)
				if ui:checkbox("VSync", config.VSYNC) then
					love.window.setVSync(config.VSYNC.value)
				end
				running = not ui:button("Quit")
			end
			ui:windowEnd()
		end
	}
}

game_state = {
	is_connected = false,
	is_connecting = false,
	focused_player = 0,
	players = {},
	maps = {},
	current_map = nil,
	next_update = 0,
	connect_timeout = 0
}

local HEIGHT = 720
local WIDTH = 1280

local VIEW_X = WIDTH / 32 + 1
local VIEW_Y = HEIGHT / 32 + 1

local x_cam = 0
local y_cam = 0

keys = {right = "right", left = "left", down = "down", up = "up", z = "jump", x = "run", c = "attack"}
last_frame_keypress = {}
for k, v in pairs(keys) do
	last_frame_keypress[v] = false
end

local host = enet.host_create()
local server = nil

function send_keypress(server, key, value)
	if not game_state.is_connected then
		return false
	end
	if not packet_key_value[keys[key]] then
		return nil
	end
	data = {}
	write_u8_table(data, { packet_types.player_input, packet_key_value[keys[key]], value })
	send_packet(server, { data = data, is_reliable = false })
end

function connect_to_server(address)
	server = host:connect(address, 2)
	game_state.is_connecting = true
	game_state.connect_timeout = time.get_time() + 5000
end

function love.load()
	love.window.setVSync(config.VSYNC.value)
	ui = nuklear.newUI()
	-- Load textures, generate quads.
	for key,char in pairs(characters) do
		local sprite_data = require("sprites/character/" .. key)
		textures[key] = love.graphics.newImage("sprites/character/" .. key .. ".png")
		textures[key]:setFilter("nearest", "nearest")
		character_sprites[key] = {
			frames = {},
			frame_offsets = {},
			states = sprite_data.states,
			width = sprite_data.width,
			height = sprite_data.height
		}
		for k, state in pairs(sprite_data.states) do
			local frame_table = sprite_data.frames[k]
			character_sprites[key].frame_offsets[k] = {}
			character_sprites[key].frames[k] = {}
			for i = 1, #frame_table, 1 do
				local frame = sprite_data.frames[k][i]
				character_sprites[key].frame_offsets[k][i] = { state[i][3], state[i][4] }
				local quad = love.graphics.newQuad(
					(frame[1] - 1) * sprite_data.width, (frame[2] - 1 ) * sprite_data.height,
					sprite_data.width - 1, sprite_data.height - 1, textures[key]:getDimensions()
				)
				character_sprites[key].frames[k][i] = quad
			end
		end
	end
	for k,set in pairs(tilesets) do
		textures[k] = love.graphics.newImage("sprites/" .. set.image)
		textures[k]:setFilter("nearest", "nearest")
		tile_batch = love.graphics.newSpriteBatch(textures[k], 32 * 32)
		for i = 1, #set.tiles, 1 do
			local tile = set.tiles[i]
			local id = tile.id
			local x = 0
			local y = 0
			while id >= set.columns do
				y = y + set.tileheight
				id = id - set.columns
			end
			id = tile.id
			while id % set.columns > 0 do
				id = id - 1
				x = x + set.tilewidth
			end
			sprites[tile.id] = {["texture"] = k, ["quad"] = love.graphics.newQuad(x, y, set.tilewidth, set.tileheight, textures[k]:getDimensions())}
		end
	end
end
function player_init_recv(peer, data)
	local count = read_u8(data, 2)
	for i = 1, count, 1 do
		local jump = (i - 1) * 4
		local id = read_u32(data, 3 + jump)
		if not game_state.players[id] then
			game_state.players[id] = Player:new(id, {x = 0, y = 0})
			game_state.players[id].sprite = Sprite:new(character_sprites["kakashi"], "stand")
			game_state.maps[game_state.current_map].players[id] = game_state.players[id]
		end
	end
end
function player_disc_recv(peer, data)
	local id = read_u32(data, 2)
	game_state.players[id] = nil
end
function sync_player_recv(peer, data)
	local count = read_u8(data, 2)
	for i = 1, count, 1 do
		local jump = (i - 1) * 9
		local id = read_u32(data, 3 + jump)
		local character = read_u8(data, 7 + jump)
		local position = { x = read_u16(data, 8 + jump), y = read_u16(data, 10 + jump) }
		local player = game_state.players[id]
		player:set_position(position)
		if character > 0 then
			player.character = character_keys[character]
			player.sprite:set_atlas(character_sprites[player.character])
		end
	end
end
function position_update_recv(peer, data)
	local count = read_u8(data, 2)
	for i = 1, count, 1 do 
		local jump = (i - 1) * 8
		local id = read_u32(data, 3 + jump)
		local position = { x = read_u16(data, 7 + jump), y = read_u16(data, 9 + jump) }
		game_state.players[id]:set_position(position)
		if id == game_state.focused_player then
			x_cam = position.x + 32
			y_cam = position.y - 32
		end
	end
end
function map_update_recv(peer, data)
	local map = map_keys[read_u8(data, 2)]
	load_map(game_state, map)
end
function set_focus_recv(peer, data)
	local id = read_u32(data, 2)
	game_state.focused_player = id
end
local xc = 0
function select_character_send()

end

function select_character_recv()

end

function handle_packet(peer, data)
	local type = packet_types[read_u8(data, 1)]
	if type then
		if type == "player_input" then -- LuaJIT doesn't like anonymous functions as much as it likes if-else.
			player_input_recv(peer, data)
		elseif type == "position_update" then
			position_update_recv(peer, data)
		elseif type == "sync_player" then
			sync_player_recv(peer, data)
		elseif type == "map_update" then
			map_update_recv(peer, data)
		elseif type == "set_focus" then
			set_focus_recv(peer, data)
		elseif type == "select_character" then
			select_character_recv(peer, data)
		elseif type == "player_disc" then
			player_disc_recv(peer, data)
		elseif type == "player_init" then
			player_init_recv(peer, data)
		end
	end
end

function love.keypressed(key, scancode, isrepeat)
	ui:keypressed(key, scancode, isrepeat)
	if not isrepeat then
		send_keypress(server, key, 1)
	end
end
function love.keyreleased(key, scancode)
	ui:keyreleased(key, scancode)
	if not isrepeat then
		send_keypress(server, key, 0)
	end
end
function love.mousepressed(x, y, button, istouch, presses)
	ui:mousepressed(x, y, button, istouch, presses)
end
function love.mousereleased(x, y, button, istouch, presses)
	ui:mousereleased(x, y, button, istouch, presses)
end
function love.mousemoved(x, y, dx, dy, istouch)
	ui:mousemoved(x, y, dx, dy, istouch)
end
function love.textinput(text)
	ui:textinput(text)
end
function love.wheelmoved(x, y)
	ui:wheelmoved(x, y)
end
function love.update(dt)
	if not running then
		love.event.quit(0)
	end
	WORLD_TIME = time.get_time()
	-- Don't check for packets until a single game tick has passed (default 15ms~).
	if game_state.is_connecting then
		if WORLD_TIME > game_state.connect_timeout then
			print("Could not connect to server.")
			game_state.is_connecting = false
		else
			local event = host:service()
			if event and event.type == "connect" then
				print("Connected to server.")
				game_state.is_connected = true
				game_state.is_connecting = false
			end
		end
	end
	if game_state.is_connected then
		game_state.next_update = WORLD_TIME + config.TICK_MS
		local event = host:service()
		if event then
			if event.type == "receive" then
				handle_packet(event.peer, event.data)
			end
			if event.type == "disconnect" then
				game_state.is_connected = false
			end
		end
		host:flush()
		for _, map in pairs(game_state.maps) do
			for id, player in pairs(map.players) do
				player:check_grounded(map)
				player:sprite_tick()
			end
		end
	end
	draw_gui()
end
function draw_map()
	local map = game_state.maps[game_state.current_map]
	tile_batch:clear()
	local a = 0
	local b = 0
	for i = 1, #map.layers, 1 do
		local layer = map.layers[i]
		for x = math.max(1, math.floor(x_cam) / 32 - VIEW_X), math.min(layer.width, math.floor(x_cam) / 32 + VIEW_X), 1 do
			for y = math.max(1, math.floor(y_cam) / 32 - VIEW_Y), math.min(layer.height, math.floor(y_cam) / 32 + VIEW_Y), 1 do
				local id = map:get_tile(x, y, i).id
				if sprites[id] then
					tile_batch:add(sprites[id]["quad"], ((x - 1) * 32) - x_cam + WIDTH / 2, (y - 1) * 32 - y_cam + HEIGHT / 2)
				else
					print("Missing sprite ID: " .. tostring(id))
				end
			end
		end
	end
	tile_batch:flush()
	love.graphics.draw(tile_batch)
end

function draw_character()
	for id, player in pairs(game_state.players) do
		player.is_loaded = true
		player.character = "kakashi"
		if player.is_loaded then
			player.sprite:tick(WORLD_TIME)
			local texture = textures[player.character]
			local atlas = player.sprite.atlas
			local scale_x = 1
			if player.dir == "left" then
				scale_x = -1
			end
			local key = player.sprite.current_frame.key
			love.graphics.draw(
				texture, atlas.frames[key][player.sprite.current_frame.frames[key]], 
				player.position.x + atlas.frame_offsets[key][player.sprite.current_frame.frames[key]][1] - x_cam + WIDTH / 2,
				player.position.y + atlas.frame_offsets[key][player.sprite.current_frame.frames[key]][2] - atlas.height - y_cam + HEIGHT / 2, 0, scale_x, 1)
		end
	end
end

function draw_gui()
	local w, h = love.graphics.getDimensions()
	local scale = { w / WIDTH, h / HEIGHT }
	ui:frameBegin()
	for i = 1, #gui_state.visible_windows, 1 do
		gui_state.functions[gui_state.visible_windows[i]](scale)
	end
	ui:frameEnd()
end

function love.draw()
	local w, h = love.graphics.getDimensions()
	love.graphics.scale(w / WIDTH, h / HEIGHT)
	if game_state.maps[game_state.current_map] then
		draw_map()
	end
	draw_character()
	love.graphics.scale(WIDTH / w, HEIGHT / h)
	love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 10)
	ui:draw()
end

