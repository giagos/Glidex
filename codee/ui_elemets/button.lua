---@diagnostic disable: undefined-global
local M = {}

local labelClipped = require('codee.ui_elemets.label').labelClipped

function M.button(x, y, w, h, label, font)
    local lg = love.graphics
    lg.setColor(0.9,0.9,0.9,1)
    lg.rectangle('fill', x, y, w, h)
    lg.setColor(0,0,0,1)
    lg.rectangle('line', x, y, w, h)
    local fh = (font or lg.getFont()):getHeight()
    local ty = y + math.floor((h - fh)/2)
    labelClipped(x + 6, ty, w - 12, label or '', font)
    lg.setColor(1,1,1,1)
end

return M
