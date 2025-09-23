---@diagnostic disable: undefined-global
local UIE = require('codee.ui_elemets')
local M = {}

-- Draw Fuselage Setup modal. Returns true if it handled drawing and the caller should return early.
function M.draw(ui)
    if not ui.showSetup then return false end
    local lg = love.graphics
    local w, h = lg.getDimensions()
    -- ensure hit tables exist
    ui.hit = ui.hit or {}
    ui.hit.setup = ui.hit.setup or {}
    -- dim background
    lg.setColor(0.8,0.8,0.8,0.12)
    lg.rectangle('fill', 0, 0, w, h)

    -- Auto-size modal to content
    local fh = lg.getFont():getHeight()
    local lines = {}
    table.insert(lines, 'Fuselage Setup (cm, g, deg)')
    do
        local gpc = ui.body.g_per_cm
        local L1 = string.format('Length [L]: %.1f cm', ui.body.length_cm)
        local L2 = string.format('Thickness [T]: %.1f cm', ui.body.thickness_cm)
        local L3
        if gpc and gpc > 0 then
            L3 = string.format('Mass [W]: %.0f g (computed)', ui.body.mass_g)
        else
            L3 = string.format('Mass [W]: %.0f g', ui.body.mass_g)
        end
        local L4 = string.format('Angle [A]: %.1f deg', ui.body:getAngleDegrees())
        local L5 = string.format('g/cm [G]: %s', gpc and string.format('%.3f', gpc) or '(none)')
        local L6 = 'Use Up/Down or Tab to change field. Type to edit. Enter to apply. Esc to close.'
        table.insert(lines, L1)
        table.insert(lines, L2)
        table.insert(lines, L3)
        table.insert(lines, L4)
        table.insert(lines, L5)
        table.insert(lines, L6)
        if ui.setupEditField then
            table.insert(lines, 'Editing ' .. ui.setupEditField .. ': ' .. ui.inputText)
        end
    end

    local maxW = 0
    for _, t in ipairs(lines) do maxW = math.max(maxW, lg.getFont():getWidth(t)) end
    local padX, padY = 12, 12
    local mw = math.min(w - 40, math.max(260, maxW + 4 + padX*2))
    local titleH = fh + 10
    local bodyLines = #lines - 1
    local lineH = fh + 6
    local mh = math.min(h - 40, padY + titleH + bodyLines * lineH + padY)
    local mx, my = math.floor((w - mw)/2), math.floor((h - mh)/2)
    lg.setColor(0.85,0.85,0.85,0.95)
    lg.rectangle('fill', mx, my, mw, mh)
    lg.setColor(0,0,0,1)
    lg.rectangle('line', mx, my, mw, mh)
    local yy = my + 12
    ui:drawLabel(mx + padX, yy, mw - padX*2, 'Fuselage Setup (cm, g, deg)'); yy = yy + 22

    local gpc = ui.body.g_per_cm
    if gpc and gpc > 0 then ui.body.mass_g = (ui.body.length_cm or 0) * gpc end
    if not ui.setupEditField then ui.setupEditField = 'setup.length' end

    love.graphics.setScissor(mx+1, my+1, mw-2, mh-2)
    ui:drawLabel(mx + padX, yy, mw - padX*2, string.format('Length [L]: %.1f cm', ui.body.length_cm)); ui.hit.setup.length = {x=mx+padX-2,y=yy-4,w=mw-(padX*2-4),h=lg.getFont():getHeight()+6}; yy = yy + (lg.getFont():getHeight()+6)
    ui:drawLabel(mx + padX, yy, mw - padX*2, string.format('Thickness [T]: %.1f cm', ui.body.thickness_cm)); ui.hit.setup.thickness = {x=mx+padX-2,y=yy-4,w=mw-(padX*2-4),h=lg.getFont():getHeight()+6}; yy = yy + (lg.getFont():getHeight()+6)
    if gpc and gpc > 0 then
        ui:drawLabel(mx + padX, yy, mw - padX*2, string.format('Mass [W]: %.0f g (computed)', ui.body.mass_g))
    else
        ui:drawLabel(mx + padX, yy, mw - padX*2, string.format('Mass [W]: %.0f g', ui.body.mass_g)); ui.hit.setup.mass = {x=mx+padX-2,y=yy-4,w=mw-(padX*2-4),h=lg.getFont():getHeight()+6}
    end
    yy = yy + (lg.getFont():getHeight()+6)
    ui:drawLabel(mx + padX, yy, mw - padX*2, string.format('Angle [A]: %.1f deg', ui.body:getAngleDegrees())); ui.hit.setup.angle = {x=mx+padX-2,y=yy-4,w=mw-(padX*2-4),h=lg.getFont():getHeight()+6}; yy = yy + (lg.getFont():getHeight()+6)
    ui:drawLabel(mx + padX, yy, mw - padX*2, string.format('g/cm [G]: %s', gpc and string.format('%.3f', gpc) or '(none)')); ui.hit.setup.gpc = {x=mx+padX-2,y=yy-4,w=mw-(padX*2-4),h=lg.getFont():getHeight()+6}; yy = yy + (lg.getFont():getHeight()+10)
    ui:drawLabel(mx + padX, yy, mw - padX*2, 'Use Up/Down or Tab to change field. Type to edit. Enter to apply. Esc to close.'); yy = yy + (lg.getFont():getHeight()+2)
    if ui.setupEditField then ui:drawLabel(mx + padX, yy, mw - padX*2, 'Editing ' .. ui.setupEditField .. ': ' .. ui.inputText) end

    -- focus fill behind current field
    local function fillFocus(r)
        if not r then return end
        UIE.drawFillBar(r.x, r.y, r.w, r.h, 0.35)
    end
    if ui.setupEditField == 'setup.length' then fillFocus(ui.hit.setup.length) end
    if ui.setupEditField == 'setup.thickness' then fillFocus(ui.hit.setup.thickness) end
    if ui.setupEditField == 'setup.mass' then fillFocus(ui.hit.setup.mass) end
    if ui.setupEditField == 'setup.angle' then fillFocus(ui.hit.setup.angle) end
    if ui.setupEditField == 'setup.g_per_cm' then fillFocus(ui.hit.setup.gpc) end

    love.graphics.setScissor()
    return true
end

return M
