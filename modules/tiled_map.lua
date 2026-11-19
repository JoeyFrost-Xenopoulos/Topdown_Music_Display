local TiledMap = {}
TiledMap.__index = TiledMap

local bit = bit or bit32
local FLIP_H = 0x80000000
local FLIP_V = 0x40000000
local FLIP_D = 0x20000000
local FLIP_MASK = bit.bor(FLIP_H, FLIP_V, FLIP_D)

local function resolveImagePath(mapPath, imagePath)
    local mapDir = mapPath:match("^(.*)[/\\][^/\\]*$") or "."
    if imagePath:match("^%a:") or imagePath:match("^/") then
        return imagePath
    end
    return mapDir .. "/" .. imagePath
end

function TiledMap.new(mapPath)
    assert(love.filesystem.getInfo(mapPath), "Map file not found: " .. mapPath)

    local map = love.filesystem.load(mapPath)()
    map.mapPath = mapPath
    map.pixelWidth = map.width * map.tilewidth
    map.pixelHeight = map.height * map.tileheight

    -- Load tileset images
    for _, tileset in ipairs(map.tilesets or {}) do
        if tileset.image then
            tileset.image = love.graphics.newImage(resolveImagePath(mapPath, tileset.image))
            tileset.image:setFilter("nearest", "nearest")
        end
        tileset.columns = tileset.columns or (tileset.imagewidth / tileset.tilewidth)
        tileset.lastgid = tileset.firstgid + (tileset.tilecount or 0) - 1
    end

    -- Pre-process tile layers: build quads and resolve tilesets per tile
    for _, layer in ipairs(map.layers or {}) do
        if layer.type == "tilelayer" then
            layer.quads = {}
            layer.tsets = {}
            layer.flipH = {}
            layer.flipV = {}
            layer.flipD = {}

            for index, rawGid in ipairs(layer.data) do
                if rawGid ~= 0 then
                    local gid = bit.band(rawGid, FLIP_MASK)
                    gid = bit.band(rawGid, bit.bnot(FLIP_MASK))

                    local flipH = bit.band(rawGid, FLIP_H) ~= 0
                    local flipV = bit.band(rawGid, FLIP_V) ~= 0
                    local flipD = bit.band(rawGid, FLIP_D) ~= 0

                    local tileset = map.tilesets[1]
                    for i = #map.tilesets, 1, -1 do
                        if gid >= map.tilesets[i].firstgid then
                            tileset = map.tilesets[i]
                            break
                        end
                    end

                    if tileset.image then
                        local localId = gid - tileset.firstgid
                        local columns = tileset.columns
                        local column = localId % columns
                        local row = math.floor(localId / columns)
                        layer.quads[index] = love.graphics.newQuad(
                            column * tileset.tilewidth,
                            row * tileset.tileheight,
                            tileset.tilewidth,
                            tileset.tileheight,
                            tileset.imagewidth,
                            tileset.imageheight
                        )
                        layer.tsets[index] = tileset
                        layer.flipH[index] = flipH
                        layer.flipV[index] = flipV
                        layer.flipD[index] = flipD
                    end
                end
            end
        end
    end

    -- Parse collision objects from "Wall" layer
    map.walls = {}
    map.records = {}
    for _, layer in ipairs(map.layers or {}) do
        if layer.type == "objectgroup" then
            if layer.name == "Wall" then
                for _, obj in ipairs(layer.objects or {}) do
                    if obj.shape == "rectangle" and obj.visible ~= false then
                        table.insert(map.walls, {
                            x = obj.x,
                            y = obj.y,
                            w = obj.width,
                            h = obj.height
                        })
                    end
                end
            elseif layer.name == "Records" then
                for _, obj in ipairs(layer.objects or {}) do
                    if obj.shape == "rectangle" and obj.visible ~= false then
                        table.insert(map.records, {
                            x = obj.x,
                            y = obj.y,
                            w = obj.width,
                            h = obj.height,
                            id = obj.id,
                            name = obj.name,
                            type = obj.type,
                            properties = obj.properties or {}
                        })
                    end
                end
            elseif layer.name == "Transition" then
                map.transitions = {}
                for _, obj in ipairs(layer.objects or {}) do
                    if obj.shape == "rectangle" and obj.visible ~= false then
                        local props = obj.properties or {}
                        table.insert(map.transitions, {
                            x = obj.x,
                            y = obj.y,
                            w = obj.width,
                            h = obj.height,
                            target_map = props.target_map,
                            target_x = props.target_x,
                            target_y = props.target_y,
                            direction = props.direction,
                            name = obj.name
                        })
                    end
                end
            end
        end
    end

    -- Parse Bookshelf tiles and compute layer center Y for simple y-sorting
    map.bookshelfTiles = {}
    local minY, maxY = math.huge, -math.huge
    for _, layer in ipairs(map.layers or {}) do
        if layer.type == "tilelayer" and layer.name == "Bookshelf" then
            for index, rawGid in ipairs(layer.data) do
                if rawGid ~= 0 then
                    local gid = bit.band(rawGid, bit.bnot(FLIP_MASK))
                    local tileset = map.tilesets[1]
                    for i = #map.tilesets, 1, -1 do
                        if gid >= map.tilesets[i].firstgid then
                            tileset = map.tilesets[i]
                            break
                        end
                    end

                    if tileset.image then
                        local localId = gid - tileset.firstgid
                        local columns = tileset.columns
                        local column = localId % columns
                        local row = math.floor(localId / columns)
                        local quad = love.graphics.newQuad(
                            column * tileset.tilewidth,
                            row * tileset.tileheight,
                            tileset.tilewidth,
                            tileset.tileheight,
                            tileset.imagewidth,
                            tileset.imageheight
                        )
                        local tileX = (index - 1) % map.width
                        local tileY = math.floor((index - 1) / map.width)
                        local worldX = tileX * map.tilewidth
                        local worldY = tileY * map.tileheight
                        table.insert(map.bookshelfTiles, {
                            quad = quad,
                            tileset = tileset,
                            x = worldX,
                            y = worldY,
                        })
                        if worldY < minY then minY = worldY end
                        if worldY > maxY then maxY = worldY end
                    end
                end
            end
        end
    end
    map.bookshelfCenterY = (minY + maxY + map.tileheight) / 2

    return setmetatable(map, TiledMap)
end

function TiledMap:draw()
    for _, layer in ipairs(self.layers or {}) do
        if layer.type == "tilelayer" and layer.visible ~= false and layer.quads then
            for index, rawGid in ipairs(layer.data) do
                local quad = layer.quads[index]
                if rawGid ~= 0 and quad then
                    local tileset = layer.tsets[index]
                    if tileset and tileset.image then
                        local column = (index - 1) % self.width
                        local row = math.floor((index - 1) / self.width)
                        local destX = column * self.tilewidth + (layer.offsetx or 0)
                        local destY = row * self.tileheight + (layer.offsety or 0)

                        local flipH = layer.flipH[index]
                        local flipV = layer.flipV[index]
                        local flipD = layer.flipD[index]

                        local sx, sy = 1, 1
                        local ox, oy = 0, 0
                        local rot = 0

                        if flipD then
                            -- Diagonal flip (transpose)
                            rot = math.pi / 2
                            ox, oy = self.tilewidth, 0
                        end
                        if flipH then
                            sx = -sx
                            ox = ox + self.tilewidth
                        end
                        if flipV then
                            sy = -sy
                            oy = oy + self.tileheight
                        end

                        love.graphics.draw(
                            tileset.image,
                            quad,
                            destX + ox,
                            destY + oy,
                            rot,
                            sx,
                            sy
                        )
                    end
                end
            end
        end
    end
end

function TiledMap:checkCollision(x, y, w, h)
    for _, wall in ipairs(self.walls) do
        if x < wall.x + wall.w and x + w > wall.x and
           y < wall.y + wall.h and y + h > wall.y then
            return true
        end
    end
    return false
end

function TiledMap:checkTransition(x, y, w, h)
    for _, t in ipairs(self.transitions or {}) do
        if x < t.x + t.w and x + w > t.x and
           y < t.y + t.h and y + h > t.y then
            return t
        end
    end
    return nil
end

function TiledMap:drawBookshelf(playerCenterY)
    if not self.bookshelfTiles then return end
    
    if self.bookshelfCenterY <= playerCenterY then
        -- Shelf above player: draw behind
        for _, tile in ipairs(self.bookshelfTiles) do
            love.graphics.draw(tile.tileset.image, tile.quad, tile.x, tile.y)
        end
    end
end

function TiledMap:drawBookshelfFront(playerCenterY)
    if not self.bookshelfTiles then return end
    
    if self.bookshelfCenterY > playerCenterY then
        -- Shelf below player: draw in front
        for _, tile in ipairs(self.bookshelfTiles) do
            love.graphics.draw(tile.tileset.image, tile.quad, tile.x, tile.y)
        end
    end
end

return TiledMap