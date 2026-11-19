local Camera = {}
Camera.__index = Camera

function Camera.new(worldScale)
    local self = setmetatable({}, Camera)
    self.x = 0
    self.y = 0
    self.worldScale = worldScale or 1
    return self
end

function Camera:update(targetX, targetY, targetW, targetH, mapPixelW, mapPixelH, screenW, screenH)
    local screenWScaled = screenW / self.worldScale
    local screenHScaled = screenH / self.worldScale
    local centerX = targetX + targetW / 2
    local centerY = targetY + targetH / 2

    self.x = centerX - screenWScaled / 2
    self.y = centerY - screenHScaled / 2

    if mapPixelW <= screenWScaled then
        self.x = -(screenWScaled - mapPixelW) / 2
    else
        self.x = math.max(0, math.min(self.x, mapPixelW - screenWScaled))
    end

    if mapPixelH <= screenHScaled then
        self.y = -(screenHScaled - mapPixelH) / 2
    else
        self.y = math.max(0, math.min(self.y, mapPixelH - screenHScaled))
    end
end

function Camera:apply()
    love.graphics.translate(-math.floor(self.x), -math.floor(self.y))
end

function Camera:getPosition()
    return self.x, self.y
end

return Camera