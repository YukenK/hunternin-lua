require "enet"
require "time"
local config = require "server_config"

require "shared/tiles"
require "shared/map"
require "shared/packet"
require "shared/player"
require "shared/bounds"
require "shared/math"

local ffi = require "ffi"
local host = enet.host_create("*:5520", 32, 2)

game_state = {
	players = { -- Keyed, ID to the Player object.

	},
	peers = {

	},
	maps = { -- Keyed, ID to Map object.

	},
	current_map = nil
}



if ffi.os == "Windows" then
	ffi.cdef "void Sleep(int ms);"
	function sleep(s)
		ffi.C.Sleep(s)
	end
else
	ffi.cdef "int poll(struct pollfd *fds, unsigned long nfds, int timeout);"
	function sleep(s)
		ffi.C.poll(nil, 0, s)
	end
end

function sync_player_data(data, player)
	write_u32(data, player.id)
	if not character_keys[player.character] then
		write_u8(data, 0)
	else
		write_u8(data, character_keys[player.character])
	end
	write_u16_table(data, { player.position.x, player.position.y })
end
function sync_all_players_send(peer)
	local data = {}
	local count = 0
	for _, _ in pairs(game_state.players) do
		count = count + 1
	end
	write_u8_table(data, { packet_types.sync_player, count })
	for key, player in pairs(game_state.players) do
		if player.id then
			sync_player_data(data, player)
		end
	end
	send_packet(peer, { data = data, is_reliable = true })
end
function sync_player_send(peer, player)
	local data = {}
	write_u8(data, packet_types.sync_player)
	write_u8(data, 1)
	sync_player_data(data, player)
	send_packet(peer, { data = data, is_reliable = true })
end
function position_update_send(peer, entity)
	local data = {}
	write_u8(data, packet_types.position_update)
	write_u16_table(data, { entity.id, entity.position.x, entity.position.y })
	send_packet(peer, { data = data, is_reliable = false })
end
function position_update_multiple_send(peer, entity_table)
	local data = {}
	write_u8_table(data, { packet_types.position_update, #entity_table })
	for i = 1, #entity_table, 1 do
		entity = entity_table[i]
		write_u32(data, entity.id)
		write_u16_table(data, { entity.position.x, entity.position.y })
	end
	send_packet(peer, { data = data, is_reliable = false }, host)
end

function set_focus_send(peer, id)
	local data = {}
	write_u8(data, packet_types.set_focus)
	write_u32(data, id)
	send_packet(peer, { data = data, is_reliable = true })
end

function select_character_recv(peer, data)

end

function select_character_send(peer, data)

end

function player_input_recv(peer, data)
	local key = packet_value_key[read_u8(data, 2)]
	local value = read_u8(data, 3)
	if key then
		game_state.players[game_state.peers[peer:connect_id()].control].inputs[key] = value
	end
end

function player_init_all_send(peer)
	local count = 0
	for _, _ in pairs(game_state.players) do
		count = count + 1		
	end
	local data = {}
	write_u8_table(data, { packet_types.player_init, count })
	for key, player in pairs(game_state.players) do
		write_u32(data, player.id)
	end
	send_packet(peer, { data = data, is_reliable = true } )
end
function player_init_send(player)
	local data = {}
	count = 1
	write_u8_table(data, { packet_types.player_init, count })
	write_u32(data, player.id)
	send_packet("broadcast", { data = data, is_reliable = true }, host)
end

function initialize_player(peer)
	local id = time.get_time()
	game_state.peers[peer:connect_id()] = { peer = peer, original_id = id, control = id, focus = id }
	game_state.players[id] = Player:new(id, {x = 64, y = 160})

	local data = {}
	write_u8_table(data, { packet_types.map_update, map_keys[game_state.current_map] })
	send_packet(peer, { data = data, is_reliable = true })

	player_init_send(game_state.players[id])
	player_init_all_send(peer)
	sync_all_players_send(peer)
	set_focus_send(peer, id)
end
function remove_player(peer)
	local player = nil
	for key, peer in pairs(game_state.peers) do
		if peer.peer:state() == "disconnected" then
			player = game_state.players[peer.original_id]
			game_state.peers[key] = nil
		end
	end
	if player == nil then
		return false
	end
	local data = {}
	write_u8(data, packet_types.player_disc)
	write_u32(data, player.id)
	game_state.players[player.id] = nil
	send_packet("broadcast", { data = data, is_reliable = true }, host)
end

function handle_packet(peer, data)
	local type = packet_types[read_u8(data, 1)]
	if type then
		if type == "player_input" then
			player_input_recv(peer, data)
		elseif type == "select_character" then
			select_character_recv(peer, data)
		end
	end
end

local last_time = time.get_time()
local max_dt = 50

load_map(game_state, "sewer")

while true do
	local current_time = time.get_time()
	local dt = math.min(current_time - last_time, max_dt) / 1000

	local event = host:service()
	if event then
		if event.type == "receive" then
			handle_packet(event.peer, event.data)
		elseif event.type == "connect" then
			print("Connect.")
			initialize_player(event.peer)
		elseif event.type == "disconnect" then
			print("Disconnect.")
			remove_player(event.peer)
		end
	end
	local position_updates = {}
	for id, player in pairs(game_state.players) do
		player:check_grounded(game_state.maps[game_state.current_map])
		player:tick(dt, game_state.maps[game_state.current_map])
		if player.has_moved_since_tick then
			position_updates[#position_updates + 1] = player
		end
	end
	if #position_updates > 0 then
		position_update_multiple_send("broadcast", position_updates)
	end
	host:flush()

	sleep(config.TICK_MS)
	last_time = current_time
end
