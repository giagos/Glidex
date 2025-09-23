---@diagnostic disable: undefined-global
local M = {}

function M.beginWindow(id, x, y, w, h, title)
    local lg = love.graphics
    local headerH = 22
    lg.setColor(0.85,0.85,0.85,0.98)
    lg.rectangle('fill', x, y, w, h)
    lg.setColor(0,0,0,1)
    lg.rectangle('line', x, y, w, h)
    -- title bar
    if title and title ~= '' then
        lg.setColor(0.95,0.95,0.95,1)
        lg.rectangle('fill', x + 1, y + 1, w - 2, headerH)
        lg.setColor(0,0,0,1)
        lg.print(title, x + 8, y + 4)
    end
    local cx = x + 1
    local cy = y + headerH + 2
    local cw = w - 2
    local ch = h - headerH - 3
    lg.setScissor(cx, cy, cw, ch)
    return cx, cy, cw, ch, headerH
end

function M.endWindow()
    local lg = love.graphics
    lg.setScissor()
end

return M
