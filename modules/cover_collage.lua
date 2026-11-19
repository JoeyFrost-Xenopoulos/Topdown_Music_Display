local CoverCollage = {}
CoverCollage.__index = CoverCollage

local albumData = require("data.album_data")

function CoverCollage.new()
    local self = setmetatable({}, CoverCollage)
    self.active = false
    self.covers = {}
    self.coverPaths = {}
    self.coverMeta = {}
    self.coverSize = 160
    self.padding = 8
    self.cols = 3
    self.rows = 3
    self.allCovers = {}
    self.recordId = nil
    return self
end

function CoverCollage:loadCoverList()
    self.allCovers = {}
    local files = love.filesystem.getDirectoryItems("assets/covers_thumb")
    for _, file in ipairs(files) do
        if file:match("%.png$") then
            table.insert(self.allCovers, "assets/covers_thumb/" .. file)
        end
    end
    print("Found " .. #self.allCovers .. " album cover thumbnails")
end

function CoverCollage:lookupMeta(path)
    local filename = path:match("([^/\\]+)%.png$") or ""
    local meta = albumData[filename] or albumData[filename:lower()]
    if meta then
        return meta.album, meta.artist, meta.year
    end
    -- Fallback: parse "Artist - Album" from filename
    local artist, album = filename:match("^(.+) %- (.+)$")
    if not artist then
        artist = "Unknown Artist"
        album = filename
    end
    return album, artist, nil
end

function CoverCollage:loadCollageCovers(record)
    self.covers = {}
    self.coverPaths = {}
    self.coverMeta = {}
    self.recordId = record.id
    
    local seed = record.id * 12345
    local rng = love.math.newRandomGenerator(seed)
    
    local numCovers = 9
    if record.id == 30 then
        self.cols = 3
        self.rows = 3
        self.coverSize = 160
    elseif record.id == 31 then
        self.cols = 4
        self.rows = 2
        self.coverSize = 140
        numCovers = 8
    else
        self.cols = 3
        self.rows = 3
        self.coverSize = 160
    end
    
    local totalCovers = #self.allCovers
    local usedIndices = {}
    local selectedIndices = {}
    
    for i = 1, math.min(numCovers, totalCovers) do
        local idx = rng:random(1, totalCovers)
        while usedIndices[idx] do
            idx = rng:random(1, totalCovers)
        end
        usedIndices[idx] = true
        table.insert(selectedIndices, idx)
    end
    
    for _, idx in ipairs(selectedIndices) do
        local path = self.allCovers[idx]
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("linear", "linear")
            table.insert(self.covers, img)
            table.insert(self.coverPaths, path)
            local album, artist, year = self:lookupMeta(path)
            table.insert(self.coverMeta, { album = album, artist = artist, year = year })
        end
    end
end

function CoverCollage:open(record)
    self.active = true
    self:loadCollageCovers(record)
end

function CoverCollage:close()
    self.active = false
    self.covers = {}
    self.coverPaths = {}
    self.coverMeta = {}
    self.recordId = nil
end

function CoverCollage:draw()
    if not self.active or #self.covers == 0 then return end
    
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local gridW = self.cols * self.coverSize + (self.cols - 1) * self.padding
    local gridH = self.rows * self.coverSize + (self.rows - 1) * self.padding
    local startX = (screenW - gridW) / 2
    local startY = (screenH - gridH) / 2

    local textX = startX + self.cols * (self.coverSize + self.padding) + 24
    local textWidth = 320
    local totalW = (textX + textWidth) - (startX - 16) + 16

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setColor(0.1, 0.1, 0.15, 1)
    love.graphics.rectangle("fill", startX - 16, startY - 16, totalW, gridH + 32, 8, 8)

    for i, img in ipairs(self.covers) do
        local col = (i - 1) % self.cols
        local row = math.floor((i - 1) / self.cols)
        local x = startX + col * (self.coverSize + self.padding)
        local y = startY + row * (self.coverSize + self.padding)

        local scale = self.coverSize / math.max(img:getWidth(), img:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x, y, 0, scale, scale)

        love.graphics.setColor(0.3, 0.3, 0.4, 1)
        love.graphics.rectangle("line", x, y, self.coverSize, self.coverSize)
    end

    local rowHeight = self.coverSize + self.padding
    
    for row = 0, self.rows - 1 do
        local baseY = startY + row * rowHeight
        for col = 0, self.cols - 1 do
            local idx = row * self.cols + col + 1
            if idx <= #self.covers then
                local meta = self.coverMeta[idx]
                if meta then
                    local album = meta.album
                    local artist = meta.artist
                    local year = meta.year
                    
                    local entryY = baseY + col * (self.coverSize / 3)
                    
                    love.graphics.setColor(0.9, 0.9, 0.95, 1)
                    love.graphics.setFont(love.graphics.newFont(14))
                    love.graphics.printf(album, textX, entryY + 4, textWidth, "left")
                    love.graphics.setColor(0.7, 0.7, 0.8, 1)
                    love.graphics.setFont(love.graphics.newFont(11))
                    local artistLine = artist
                    if year then
                        artistLine = artistLine .. " (" .. year .. ")"
                    end
                    love.graphics.printf(artistLine, textX, entryY + 22, textWidth, "left")
                end
            end
        end
    end
    love.graphics.setFont(love.graphics.newFont(12))

    love.graphics.setColor(0.7, 0.7, 0.8, 1)
    love.graphics.printf("Press [E] to close", 0, startY + gridH + 24, screenW, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

return CoverCollage