tilesets = {}
tile_data = {}

tile_search = {"tiles"}

for i = 1, #tile_search, 1 do
	local tileset = require("sprites/" .. tile_search[i])
	tilesets[tileset.name] = tileset
	for i = 1, #tileset.tiles, 1 do
		local tile = tileset.tiles[i]
		tile_data[tile.id] = tile.properties
	end
end
