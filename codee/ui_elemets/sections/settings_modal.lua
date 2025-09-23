---@diagnostic disable: undefined-global
local UIE = require('codee.ui_elemets')
local M = {}

function M.draw(ui)
    local lg = love.graphics
    local w, h = lg.getDimensions()
    if ui._dragScale and (not love.mouse.isDown(1)) then ui._dragScale = false end

    -- dim background behind modal
    love.graphics.setScissor()
    lg.setColor(0.1,0.1,0.1,0.55)
    lg.rectangle('fill', 0, 0, w, h)

    local mw = math.min(560, w - 80)
    local baseTop = 12 + 22 + 22
    local listH = 0
    if ui._resOpen and ui.resolutions then
        listH = #ui.resolutions * 20 + 6 + 8
    end
    local tail = 28 + 18 + 12 + 16 + 22 + 22 + 18 + (ui.settingsEditField and 18 or 0)
    local desired = baseTop + listH + tail + 12
    local maxH = h - 80
    local mh = math.min(math.max(260, desired), maxH)
    local mx, my = math.floor((w - mw)/2), math.floor((h - mh)/2)

    lg.setColor(0.85,0.85,0.85,0.98)
    lg.rectangle('fill', mx, my, mw, mh)
    lg.setColor(0,0,0,1)
    lg.rectangle('line', mx, my, mw, mh)
    local yy = my + 12
    lg.print('Settings', mx + 12, yy); yy = yy + 22

    -- ensure hit tables exist
    ui.hit = ui.hit or {}
    ui.hit.settings = ui.hit.settings or {}

    local r = ui.resolutions and ui.resolutions[ui.settings.resIndex or 1]
    local fRes = string.format('Resolution: %s', r and r.label or '(unknown)')
    lg.print(fRes, mx + 12, yy); ui.hit.settings.res = {x=mx+12,y=yy-2,w=mw-24,h=18}; yy = yy + 22
    if ui._resOpen and ui.resolutions then
        local fullListH = #ui.resolutions * 20 + 6
        local lx, ly, lw2 = mx + 12, yy, math.min(mw-24, 360)
        local remaining = (my + mh) - ly - 12 - (28 + 18 + 12 + 16 + 22 + 22 + 18)
        local lh2 = math.max(40, math.min(fullListH, remaining))
        lg.setColor(0.2,0.2,0.2,0.98)
        lg.rectangle('fill', lx, ly, lw2, lh2)
        lg.setColor(1,1,1,1)
        lg.rectangle('line', lx, ly, lw2, lh2)
        love.graphics.setScissor(lx, ly, lw2, lh2)
        local yy2 = ly + 4
        for i, it in ipairs(ui.resolutions) do
            lg.print(it.label, lx + 8, yy2)
            it._bounds = {x=lx, y=yy2-2, w=lw2, h=18, idx=i}
            yy2 = yy2 + 20
        end
        love.graphics.setScissor()
        yy = ly + lh2 + 8
    end

    local fsLabel = string.format('Fullscreen: %s', ui.settings.fullscreen and 'On' or 'Off')
    ui.hit.settings.fullscreenBtn = {x=mx+12, y=yy-2, w=160, h=22}
    ui:drawButton(ui.hit.settings.fullscreenBtn.x, ui.hit.settings.fullscreenBtn.y, ui.hit.settings.fullscreenBtn.w, ui.hit.settings.fullscreenBtn.h, fsLabel)
    yy = yy + 28

    local sLabel = string.format('UI scale: %d%%', ui.settings.uiScalePerc or 100)
    lg.print(sLabel, mx + 12, yy); yy = yy + 18
    local barX, barY, barW, barH = mx + 12, yy, mw - 24, 12
    ui.hit.settings.scaleBar = {x=barX, y=barY, w=barW, h=barH}
    lg.setColor(0.2,0.2,0.2,1); lg.rectangle('fill', barX, barY + barH/2 - 2, barW, 4)
    lg.setColor(1,1,1,1); lg.rectangle('line', barX, barY + barH/2 - 2, barW, 4)
    local perc = math.max(50, math.min(200, ui.settings.uiScalePerc or 100))
    local knobX = barX + (perc - 50) / 150 * barW
    lg.setColor(1,1,1,1); lg.rectangle('fill', knobX-4, barY, 8, barH)
    yy = yy + barH + 16

    local f1 = string.format('Panel width (%% of screen): %.0f%%', (ui.settings.panelWidthFrac or 0.22)*100)
    lg.print(f1, mx + 12, yy); ui.hit.settings.panel = {x=mx+12,y=yy-2,w=mw-24,h=18}; yy = yy + 22
    local f3 = string.format('Base font size (px): %d', ui.settings.fontSize or 14)
    lg.print(f3, mx + 12, yy); ui.hit.settings.font = {x=mx+12,y=yy-2,w=mw-24,h=18}; yy = yy + 22
    lg.print('Tab to switch. Enter to apply. Esc to close.', mx + 12, yy); yy = yy + 18
    if ui.settingsEditField then
        lg.print('Editing ' .. ui.settingsEditField .. ': ' .. ui.inputText, mx + 12, yy)
    end
end

return M
