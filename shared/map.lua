Map = {
	players = {}, -- Array of player IDs, does not contain actual players.
	entities = {}, -- Array of entity IDs.
	map_data = {},
	width = 0,
	height = 0,
	layers = {}
}
function Map:new(map)
	o = {}
	setmetatable(o, Map)
	self.__index = Map

	o.width = map.width
	o.height = map.height
	o.layers = map.layers

	return o
end
function Map:get_tile(x, y, layer)
	layer = layer or 1
	local add = x + self.layers[layer].width * (y - 1)
	if add > #self.layers[layer].data then
		return nil
	end
	return { id = self.layers[layer].data[add] - 1, x = x, y = y }
end
function load_map(state, map)
	state.current_map = map
	state.maps[map] = Map:new(map_list[map])
end
map_list = {
	["sewer"] = require("maps/SewerMap")
}
