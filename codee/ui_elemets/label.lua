---@diagnostic disable: undefined-global
local M = {}

local truncate = require('codee.ui_elemets.truncate').truncate

function M.labelClipped(x, y, w, text, font)
    local lg = love.graphics
    if font then lg.setFont(font) end
    local s = truncate(text or '', w, font or (lg and lg.getFont and lg.getFont()))
    lg.print(s, x, y)
end

return M
