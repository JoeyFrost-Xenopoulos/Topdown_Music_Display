local Animation = require("animation")

local Player = {}
Player.__index = Player

function Player.new(map, tileSize, bearSourceSize)
    local self = setmetatable({}, Player)
    self.map = map
    self.tileSize = tileSize
    self.bearSourceSize = bearSourceSize
    
    self.x = map.pixelWidth / 2 - tileSize / 2
    self.y = map.pixelHeight / 2 - tileSize / 2
    self.width = tileSize * 5
    self.height = tileSize * 5
    self.hitboxWidth = 32
    self.hitboxHeight = 32
    self.speed = 120
    self.state = "idle"
    self.facingRight = true
    self.animations = {}
    self.interactingRecord = nil
    
    self:loadAnimations()
    return self
end

function Player:loadAnimations()
    self.animations.idle = Animation.new("assets/Bear/Bear_Idle.png", 256, 256, 0.1)
    self.animations.run = Animation.new("assets/Bear/Bear_Run.png", 256, 256, 0.08)
    self.animations.attack = Animation.new("assets/Bear/Bear_Attack.png", 256, 256, 0.06, false)
end

function Player:getHitbox()
    local hx = self.x + (self.width - self.hitboxWidth) / 2
    local hy = self.y + (self.height - self.hitboxHeight) / 2
    return hx, hy
end

function Player:resolveSpawnCollision()
    local hx, hy = self:getHitbox()
    
    if self.map:checkCollision(hx, hy, self.hitboxWidth, self.hitboxHeight) then
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
                if not self.map:checkCollision(testX, testY, self.hitboxWidth, self.hitboxHeight) then
                    self.x = testX - (self.width - self.hitboxWidth) / 2
                    self.y = testY - (self.height - self.hitboxHeight) / 2
                    return true
                end
            end
        end
        for y = 0, self.map.pixelHeight, 24 do
            for x = 0, self.map.pixelWidth, 24 do
                if not self.map:checkCollision(x, y, self.hitboxWidth, self.hitboxHeight) then
                    self.x = x - (self.width - self.hitboxWidth) / 2
                    self.y = y - (self.height - self.hitboxHeight) / 2
                    return true
                end
            end
        end
    end
    return false
end

function Player:update(dt)
    local dx, dy = 0, 0

    if love.keyboard.isDown("a", "left") then dx = dx - 1 end
    if love.keyboard.isDown("d", "right") then dx = dx + 1 end
    if love.keyboard.isDown("w", "up") then dy = dy - 1 end
    if love.keyboard.isDown("s", "down") then dy = dy + 1 end

    if dx ~= 0 or dy ~= 0 then
        if dx < 0 then
            self.facingRight = false
        elseif dx > 0 then
            self.facingRight = true
        end

        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length
        dy = dy / length

        local newX = self.x + dx * self.speed * dt
        local newY = self.y + dy * self.speed * dt

        local hx, hy = self:getHitbox()
        local nhx = hx + dx * self.speed * dt
        local nhy = hy + dy * self.speed * dt

        if not self.map:checkCollision(nhx, hy, self.hitboxWidth, self.hitboxHeight) then
            self.x = newX
        end
        if not self.map:checkCollision(hx, nhy, self.hitboxWidth, self.hitboxHeight) then
            self.y = newY
        end

        if self.state ~= "attack" then
            self.state = "run"
        end
    elseif self.state ~= "attack" then
        self.state = "idle"
    end

    if self.state == "attack" and self.animations.attack.finished then
        self.state = "idle"
    end

    local hx, hy = self:getHitbox()
    hx = math.max(0, math.min(self.map.pixelWidth - self.hitboxWidth, hx))
    hy = math.max(0, math.min(self.map.pixelHeight - self.hitboxHeight, hy))
    self.x = hx - (self.width - self.hitboxWidth) / 2
    self.y = hy - (self.height - self.hitboxHeight) / 2

    self.animations[self.state]:update(dt)
end

function Player:tryInteract(records)
    local hx, hy = self:getHitbox()
    for _, record in ipairs(records) do
        if hx < record.x + record.w and hx + self.hitboxWidth > record.x and
           hy < record.y + record.h and hy + self.hitboxHeight > record.y then
            self.interactingRecord = record
            return record
        end
    end
    return nil
end

function Player:draw()
    local bearScale = (self.width / self.bearSourceSize)
    local anim = self.animations[self.state]
    if self.facingRight then
        anim:draw(self.x, self.y, bearScale, bearScale)
    else
        love.graphics.push()
        love.graphics.translate(self.x + self.width, self.y)
        love.graphics.scale(-bearScale, bearScale)
        anim:draw(0, 0)
        love.graphics.pop()
    end
end

function Player:drawDebug()
    local hx, hy = self:getHitbox()
    love.graphics.setColor(0, 1, 0, 0.7)
    love.graphics.rectangle("line", hx, hy, self.hitboxWidth, self.hitboxHeight)
    
    if self.interactingRecord then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Record ID: " .. self.interactingRecord.id, self.x, self.y - 30)
    else
        for _, record in ipairs(self.map.records) do
            if hx < record.x + record.w and hx + self.hitboxWidth > record.x and
               hy < record.y + record.h and hy + self.hitboxHeight > record.y then
                love.graphics.setColor(1, 1, 0, 1)
                love.graphics.print("[E] Interact", self.x, self.y - 30)
                break
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Player