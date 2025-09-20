---@diagnostic disable: undefined-global
-- Drawing utilities for vectors (arrows with labels)
local VDraw = {}

local function drawArrow(x, y, vx, vy, color)
    local lg = love.graphics
    local len = math.sqrt(vx*vx + vy*vy)
    if len < 1 then return end
    local nx, ny = vx/len, vy/len
    local head = math.min(14, len * 0.3)
    local backx, backy = x, y
    local tipx, tipy = x + vx, y + vy
    lg.setColor(color[1], color[2], color[3], color[4] or 1)
    lg.setLineWidth(3)
    lg.line(backx, backy, tipx, tipy)
    -- Arrow head (two short lines at 30°)
    local leftx = tipx - nx*head + (-ny)*head*0.6
    local lefty = tipy - ny*head + ( nx)*head*0.6
    local rightx = tipx - nx*head - (-ny)*head*0.6
    local righty = tipy - ny*head - ( nx)*head*0.6
    lg.line(tipx, tipy, leftx, lefty)
    lg.line(tipx, tipy, rightx, righty)
end

function VDraw.arrowWithLabel(x, y, vx, vy, label, color, startOffset)
    -- Offset start so the arrow begins at the icon edge (if provided)
    if startOffset and startOffset > 0 then
        local len = math.sqrt(vx*vx + vy*vy)
        if len > 0 then
            local ox = vx/len * startOffset
            local oy = vy/len * startOffset
            x = x + ox; y = y + oy
            vx = vx - ox; vy = vy - oy
        end
    end
    drawArrow(x, y, vx, vy, color or {1,1,1,1})
    local lg = love.graphics
    lg.setColor(1,1,1,1)
    lg.print(label or "", x + vx + 8, y + vy)
end

return VDraw
