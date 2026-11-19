local Animation = require("animation")
local TiledMap = require("tiled_map")

local TILE_SIZE = 24
local BEAR_SOURCE_SIZE = 256
local WORLD_SCALE = 2

local map = TiledMap.new("assets/map/map_1.lua")

local player = {
    x = map.pixelWidth / 2 - TILE_SIZE / 2,
    y = map.pixelHeight / 2 - TILE_SIZE / 2,
    width = TILE_SIZE * 5,
    height = TILE_SIZE * 5,
    hitboxWidth = 32,
    hitboxHeight = 32,
    speed = 120,
    state = "idle",
    facingRight = true,
    animations = {},
    interactingRecord = nil,
}

local coverCollage = {
    active = false,
    covers = {},
    coverSize = 160,
    padding = 8,
    cols = 3,
    rows = 3,
}

local camera = { x = 0, y = 0 }

local function loadAnimations()
    player.animations.idle = Animation.new("assets/Bear/Bear_Idle.png", 256, 256, 0.1)
    player.animations.run = Animation.new("assets/Bear/Bear_Run.png", 256, 256, 0.08)
    player.animations.attack = Animation.new("assets/Bear/Bear_Attack.png", 256, 256, 0.06, false)
end

local function updateCamera()
    local screenW = love.graphics.getWidth() / WORLD_SCALE
    local screenH = love.graphics.getHeight() / WORLD_SCALE
    local targetX = player.x + player.width / 2
    local targetY = player.y + player.height / 2

    camera.x = targetX - screenW / 2
    camera.y = targetY - screenH / 2

    if map.pixelWidth <= screenW then
        camera.x = -(screenW - map.pixelWidth) / 2
    else
        camera.x = math.max(0, math.min(camera.x, map.pixelWidth - screenW))
    end

    if map.pixelHeight <= screenH then
        camera.y = -(screenH - map.pixelHeight) / 2
    else
        camera.y = math.max(0, math.min(camera.y, map.pixelHeight - screenH))
    end
end

local function loadCoverList()
    -- Get list of cover files
    coverCollage.allCovers = {}
    local files = love.filesystem.getDirectoryItems("assets/covers")
    for _, file in ipairs(files) do
        if file:match("%.png$") then
            table.insert(coverCollage.allCovers, "assets/covers/" .. file)
        end
    end
    print("Found " .. #coverCollage.allCovers .. " album covers")
end

local function loadCollageCovers(record)
    coverCollage.covers = {}
    coverCollage.coverPaths = {}
    coverCollage.recordId = record.id
    
    -- Use record ID as seed for consistent but different results per record
    local seed = record.id * 12345
    local rng = love.math.newRandomGenerator(seed)
    
    -- Different behavior based on record
    local numCovers = 9
    local coverSize = 160
    if record.id == 30 then
        -- First record: standard 3x3
        coverCollage.cols = 3
        coverCollage.rows = 3
        coverCollage.coverSize = 160
    elseif record.id == 31 then
        -- Second record: 2x4 layout, smaller covers
        coverCollage.cols = 4
        coverCollage.rows = 2
        coverCollage.coverSize = 140
        numCovers = 8
    else
        coverCollage.cols = 3
        coverCollage.rows = 3
        coverCollage.coverSize = 160
    end
    
    -- Pick random unique indices from the full cover list
    local totalCovers = #coverCollage.allCovers
    local usedIndices = {}
    local selectedIndices = {}
    
    for i = 1, math.min(numCovers, totalCovers) do
        local idx = rng:random(1, totalCovers)
        -- Ensure unique
        while usedIndices[idx] do
            idx = rng:random(1, totalCovers)
        end
        usedIndices[idx] = true
        table.insert(selectedIndices, idx)
    end
    
    for _, idx in ipairs(selectedIndices) do
        local path = coverCollage.allCovers[idx]
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("linear", "linear")
            table.insert(coverCollage.covers, img)
            table.insert(coverCollage.coverPaths, path)
        end
    end
end

local function drawCoverCollage()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local c = coverCollage
    local gridW = c.cols * c.coverSize + (c.cols - 1) * c.padding
    local gridH = c.rows * c.coverSize + (c.rows - 1) * c.padding
    local startX = (screenW - gridW) / 2
    local startY = (screenH - gridH) / 2

    -- Dark overlay background
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Grid background
    love.graphics.setColor(0.1, 0.1, 0.15, 1)
    love.graphics.rectangle("fill", startX - 16, startY - 16, gridW + 32, gridH + 32, 8, 8)

    -- Draw covers in grid
    for i, img in ipairs(c.covers) do
        local col = (i - 1) % c.cols
        local row = math.floor((i - 1) / c.cols)
        local x = startX + col * (c.coverSize + c.padding)
        local y = startY + row * (c.coverSize + c.padding)

        -- Scale image to fit coverSize
        local scale = c.coverSize / math.max(img:getWidth(), img:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x, y, 0, scale, scale)

        -- Subtle border
        love.graphics.setColor(0.3, 0.3, 0.4, 1)
        love.graphics.rectangle("line", x, y, c.coverSize, c.coverSize)
    end

    -- Draw 4th column: album/artist info stacked by row
    local textX = startX + c.cols * (c.coverSize + c.padding) + 24
    local textWidth = 320
    local rowHeight = c.coverSize + c.padding
    
    for row = 0, c.rows - 1 do
        local baseY = startY + row * rowHeight
        -- Stack 3 entries per row (left, middle, right covers)
        for col = 0, c.cols - 1 do
            local idx = row * c.cols + col + 1
            if idx <= #c.covers then
                local path = c.coverPaths[idx]
                if path then
                    local filename = path:match("([^/\\]+)%.png$") or ""
                    local artist, album = filename:match("^(.+) %- (.+)$")
                    if not artist then
                        artist = "Unknown Artist"
                        album = filename
                    end
                    
                    local entryY = baseY + col * (c.coverSize / 3)
                    
                    love.graphics.setColor(0.9, 0.9, 0.95, 1)
                    love.graphics.setFont(love.graphics.newFont(14))
                    love.graphics.printf(album, textX, entryY + 4, textWidth, "left")
                    love.graphics.setColor(0.7, 0.7, 0.8, 1)
                    love.graphics.setFont(love.graphics.newFont(11))
                    love.graphics.printf(artist, textX, entryY + 22, textWidth, "left")
                end
            end
        end
    end
    love.graphics.setFont(love.graphics.newFont(12))

    -- Close hint
    love.graphics.setColor(0.7, 0.7, 0.8, 1)
    love.graphics.printf("Press [E] to close", 0, startY + gridH + 24, screenW, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

local function resolveSpawnCollision()
    local hx = player.x + (player.width - player.hitboxWidth) / 2
    local hy = player.y + (player.height - player.hitboxHeight) / 2
    
    if map:checkCollision(hx, hy, player.hitboxWidth, player.hitboxHeight) then
        -- Try pushing out in 8 directions
        local directions = {
            {0, -1}, {0, 1}, {-1, 0}, {1, 0},
            {-1, -1}, {1, -1}, {-1, 1}, {1, 1}
        }
        local step = 16
        local maxSteps = 50
        
        for _, dir in ipairs(directions) do
            local testX, testY = hx, hy
            for i = 1, maxSteps do
                testX = testX + dir[1] * step
                testY = testY + dir[2] * step
                if not map:checkCollision(testX, testY, player.hitboxWidth, player.hitboxHeight) then
                    player.x = testX - (player.width - player.hitboxWidth) / 2
                    player.y = testY - (player.height - player.hitboxHeight) / 2
                    return true
                end
            end
        end
        -- Fallback: find any valid position by scanning
        for y = 0, map.pixelHeight, 24 do
            for x = 0, map.pixelWidth, 24 do
                if not map:checkCollision(x, y, player.hitboxWidth, player.hitboxHeight) then
                    player.x = x - (player.width - player.hitboxWidth) / 2
                    player.y = y - (player.height - player.hitboxHeight) / 2
                    return true
                end
            end
        end
    end
    return false
end

function love.load()
    love.graphics.setBackgroundColor(0.08, 0.08, 0.1)
    love.graphics.setDefaultFilter("nearest", "nearest")
    loadAnimations()
    loadCoverList()
    resolveSpawnCollision()
end

function love.keypressed(key)
    if key == "space" and player.state ~= "attack" then
        player.state = "attack"
        player.animations.attack:reset()
    elseif key == "e" then
        if coverCollage.active then
            coverCollage.active = false
            player.interactingRecord = nil
        else
            local hx = player.x + (player.width - player.hitboxWidth) / 2
            local hy = player.y + (player.height - player.hitboxHeight) / 2
            for _, record in ipairs(map.records) do
                if hx < record.x + record.w and hx + player.hitboxWidth > record.x and
                   hy < record.y + record.h and hy + player.hitboxHeight > record.y then
                    player.interactingRecord = record
                    coverCollage.active = true
                    loadCollageCovers(record)
                    break
                end
            end
        end
    end
end

function love.update(dt)
    local dx, dy = 0, 0

    if love.keyboard.isDown("a", "left") then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end
    if love.keyboard.isDown("w", "up") then dy = dy - 1 end
    if love.keyboard.isDown("s", "down") then dy = dy + 1 end

    if dx ~= 0 or dy ~= 0 then
        if dx < 0 then
            player.facingRight = false
        elseif dx > 0 then
            player.facingRight = true
        end

        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length
        dy = dy / length

        local newX = player.x + dx * player.speed * dt
        local newY = player.y + dy * player.speed * dt

        local hx = player.x + (player.width - player.hitboxWidth) / 2
        local hy = player.y + (player.height - player.hitboxHeight) / 2
        local nhx = hx + dx * player.speed * dt
        local nhy = hy + dy * player.speed * dt

        if not map:checkCollision(nhx, hy, player.hitboxWidth, player.hitboxHeight) then
            player.x = newX
        end
        if not map:checkCollision(hx, nhy, player.hitboxWidth, player.hitboxHeight) then
            player.y = newY
        end

        if player.state ~= "attack" then
            player.state = "run"
        end
    elseif player.state ~= "attack" then
        player.state = "idle"
    end

    if player.state == "attack" and player.animations.attack.finished then
        player.state = "idle"
    end

    local hx = player.x + (player.width - player.hitboxWidth) / 2
    local hy = player.y + (player.height - player.hitboxHeight) / 2
    hx = math.max(0, math.min(map.pixelWidth - player.hitboxWidth, hx))
    hy = math.max(0, math.min(map.pixelHeight - player.hitboxHeight, hy))
    player.x = hx - (player.width - player.hitboxWidth) / 2
    player.y = hy - (player.height - player.hitboxHeight) / 2

    player.animations[player.state]:update(dt)
    updateCamera()
end

function love.draw()
    love.graphics.push()
    love.graphics.scale(WORLD_SCALE)
    love.graphics.translate(-math.floor(camera.x), -math.floor(camera.y))

    map:draw()

    local bearScale = (player.width / BEAR_SOURCE_SIZE)
    local anim = player.animations[player.state]
    if player.facingRight then
        anim:draw(player.x, player.y, bearScale, bearScale)
    else
        love.graphics.push()
        love.graphics.translate(player.x + player.width, player.y)
        love.graphics.scale(-bearScale, bearScale)
        anim:draw(0, 0)
        love.graphics.pop()
    end

    -- Debug: draw wall outlines
    love.graphics.setColor(1, 0, 0, 0.5)
    for _, wall in ipairs(map.walls) do
        love.graphics.rectangle("line", wall.x, wall.y, wall.w, wall.h)
    end

    -- Debug: draw player hitbox
    local hx = player.x + (player.width - player.hitboxWidth) / 2
    local hy = player.y + (player.height - player.hitboxHeight) / 2
    love.graphics.setColor(0, 1, 0, 0.7)
    love.graphics.rectangle("line", hx, hy, player.hitboxWidth, player.hitboxHeight)

    -- Debug: draw record objects
    love.graphics.setColor(1, 0, 1, 0.5)
    for _, record in ipairs(map.records) do
        love.graphics.rectangle("line", record.x, record.y, record.w, record.h)
    end

    -- Interaction prompt
    if player.interactingRecord then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Record ID: " .. player.interactingRecord.id, player.x, player.y - 30)
    else
        -- Show prompt when hitbox actually overlaps record (same as interaction check)
        for _, record in ipairs(map.records) do
            if hx < record.x + record.w and hx + player.hitboxWidth > record.x and
               hy < record.y + record.h and hy + player.hitboxHeight > record.y then
                love.graphics.setColor(1, 1, 0, 1)
                love.graphics.print("[E] Interact", player.x, player.y - 30)
                break
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.pop()

    -- Draw cover collage overlay
    if coverCollage.active and #coverCollage.covers > 0 then
        drawCoverCollage()
    end
end