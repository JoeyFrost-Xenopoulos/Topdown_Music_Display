local Animation = {}
Animation.__index = Animation

function Animation.new(imagePath, frameWidth, frameHeight, frameDuration, loop)
    local self = setmetatable({}, Animation)
    self.image = love.graphics.newImage(imagePath)
    self.frameWidth = frameWidth
    self.frameHeight = frameHeight
    self.frameDuration = frameDuration or 0.1
    self.loop = loop ~= false
    self.frameCount = math.floor(self.image:getWidth() / frameWidth)
    self.duration = self.frameCount * self.frameDuration
    self.elapsed = 0
    self.finished = false
    return self
end

function Animation:update(dt)
    if self.finished then return end
    self.elapsed = self.elapsed + dt
    if self.elapsed >= self.duration then
        if self.loop then
            self.elapsed = self.elapsed % self.duration
        else
            self.elapsed = self.duration
            self.finished = true
        end
    end
end

function Animation:draw(x, y, scaleX, scaleY)
    local frame
    if self.finished then
        frame = self.frameCount - 1
    else
        frame = math.floor(self.elapsed / self.frameDuration) % self.frameCount
    end
    local sx = frame * self.frameWidth
    local quad = love.graphics.newQuad(sx, 0, self.frameWidth, self.frameHeight, self.image:getDimensions())
    love.graphics.draw(self.image, quad, x, y, 0, scaleX or 1, scaleY or 1)
end

function Animation:reset()
    self.elapsed = 0
    self.finished = false
end

return Animation