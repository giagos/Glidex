---@diagnostic disable: undefined-global
local M = {}

function M.drawFillBar(x, y, w, h, alpha)
    local lg = love.graphics
    lg.setColor(0, 0, 0, alpha or 0.35)
    lg.rectangle('fill', x, y, w, h)
    lg.setColor(1,1,1,1)
end

return M
