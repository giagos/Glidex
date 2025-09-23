---@diagnostic disable: undefined-global
local M = {}

function M.drawCG(ui)
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local margin = 12
    local fh = lg.getFont():getHeight()
    local text = 'CG: N/A'
    if ui.body then
        local pts = (ui.handler and ui.handler.points) or {}
        local VCalc = require('codee.vector_calc')
        local com_left_cm, total_m = VCalc.centerOfMassFromLeft(ui.body, pts)
        if (total_m or 0) > 0 then
            text = string.format('CG: %.1f cm from nose (left)', com_left_cm)
        end
    end
    local textW = lg.getFont():getWidth(text)
    local padX = 6
    local boxW = math.min(w - 2*margin, textW + 4 + padX*2)
    local boxH = fh + 12
    local bx = margin
    local by = h - margin - boxH
    local cx, cy, cw, ch = ui:beginWindow('cghud', bx, by, boxW, boxH, '')
    ui:drawLabel(cx + padX, cy + 4, cw - padX*2, text)
    ui:endWindow()
end

return M
