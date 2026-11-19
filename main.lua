local Animation = require("modules.animation")
local TiledMap = require("modules.tiled_map")
local Player = require("modules.player")
local Camera = require("modules.camera")
local CoverCollage = require("modules.cover_collage")

local TILE_SIZE = 24
local BEAR_SOURCE_SIZE = 256
local WORLD_SCALE = 2

local map = TiledMap.new("assets/map/map_1.lua")

local player = Player.new(map, TILE_SIZE, BEAR_SOURCE_SIZE)
local camera = Camera.new(WORLD_SCALE)
local coverCollage = CoverCollage.new()

local function loadMap(mapPath)
    map = TiledMap.new(mapPath)
    player.map = map
    player.x = map.pixelWidth / 2 - TILE_SIZE / 2
    player.y = map.pixelHeight / 2 - TILE_SIZE / 2
    player:resolveSpawnCollision()
end

function love.load()
    love.graphics.setBackgroundColor(0.08, 0.08, 0.1)
    love.graphics.setDefaultFilter("nearest", "nearest")
    coverCollage:loadCoverList()
    player:resolveSpawnCollision()
end

function love.keypressed(key)
    if key == "space" and player.state ~= "attack" then
        player.state = "attack"
        player.animations.attack:reset()
    elseif key == "e" then
        if coverCollage.active then
            coverCollage:close()
            player.interactingRecord = nil
        else
            local record = player:tryInteract(map.records)
            if record then
                coverCollage:open(record)
            end
        end
    end
end

function love.update(dt)
    player:update(dt)
    
    -- Check for map transitions
    local hx, hy = player:getHitbox()
    local transition = map:checkTransition(hx, hy, player.hitboxWidth, player.hitboxHeight)
    if transition and transition.target_map then
        local newMapPath = "assets/map/" .. transition.target_map
        loadMap(newMapPath)
        -- Override spawn position with transition target
        player.x = transition.target_x
        player.y = transition.target_y
        player:resolveSpawnCollision()
        coverCollage:close()
    end
    
    camera:update(
        player.x, player.y, player.width, player.height,
        map.pixelWidth, map.pixelHeight,
        love.graphics.getWidth(), love.graphics.getHeight()
    )
end

function love.draw()
    love.graphics.push()
    love.graphics.scale(WORLD_SCALE)
    camera:apply()

    map:draw()
    
    local playerCenterY = player.y + player.height / 2
    
    -- Bookshelf tiles behind player
    map:drawBookshelf(playerCenterY)
    
    player:draw()
    
    -- Bookshelf tiles in front of player
    map:drawBookshelfFront(playerCenterY)

    love.graphics.setColor(1, 0, 0, 0.5)
    for _, wall in ipairs(map.walls) do
        love.graphics.rectangle("line", wall.x, wall.y, wall.w, wall.h)
    end

    love.graphics.setColor(1, 0, 1, 0.5)
    for _, record in ipairs(map.records) do
        love.graphics.rectangle("line", record.x, record.y, record.w, record.h)
    end

    player:drawDebug()

    love.graphics.pop()

    coverCollage:draw()
end