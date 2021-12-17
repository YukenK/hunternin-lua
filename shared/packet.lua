local TYPE_SIZE = 1 -- u8.
packet_types = {
	player_input = 0,
	sync_player = 1,
	position_update = 2,
	map_update = 3,
	set_focus = 4,
	select_character = 5,
	player_disc = 6,
	player_init = 7
}
map_keys = {sewer = 0}
packet_key_value = {right = 0, left = 1, down = 2, up = 3, jump = 4, attack = 5, jump = 6, run = 7} -- Key to value.
packet_value_key = {}
character_keys = {
	kakashi = 1
}
for k,v in pairs(packet_types) do
	packet_types[v] = k
end
for k,v in pairs(map_keys) do
	map_keys[v] = k
end
for k,v in pairs(packet_key_value) do
	packet_value_key[v] = k
end
for k,v in pairs(character_keys) do
	character_keys[v] = k
end

function write_u8(data, n)
	data[#data + 1] = n
end

function write_u8_table(data, n)
	for i = 1, #n, 1 do
		write_u8(data, n[i])
	end
end

function read_u8(data, pos)
	return string.byte(data, pos)
end

function write_u16(data, n)
	data[#data + 1] = bit.band(bit.rshift(n, 8), 0xFF)
	data[#data + 1] = bit.band(n, 0xFF)
end

function write_u16_table(data, n)
	for i = 1, #n, 1 do
		write_u16(data, n[i])
	end
end

function read_u16(data, pos)
	return bit.bor(bit.band(0xFFFF, bit.lshift(string.byte(data, pos), 8)), string.byte(data, pos + 1))
end

function write_u32(data, n)
	local bits = 24
	for i = 1, 4, 1 do
		data[#data + 1] = bit.band(bit.rshift(n, bits), 0xFF)
		bits = bits - 8
	end
end
function read_u32(data, pos)
	local u32_hex = 0xFFFFFFFF
	print(bit)
	return bit.bor(bit.band(u32_hex, bit.lshift(string.byte(data, pos), 24)), bit.band(u32_hex, bit.lshift(string.byte(data, pos + 1), 16)), bit.band(u32_hex, bit.lshift(string.byte(data, pos + 2), 8)), string.byte(data, pos + 3))
end
function send_packet(peer, packet, host)
	if peer ~= "broadcast" then
		if packet.is_reliable then
			peer:send(string.char(unpack(packet.data)), 0, "reliable")
		else
			peer:send(string.char(unpack(packet.data)), 1, "unsequenced")
		end
	else
		if packet.is_reliable then
			host:broadcast(string.char(unpack(packet.data)), 0, "reliable")
		else
			host:broadcast(string.char(unpack(packet.data)), 1, "unsequenced")
		end
	end
end
