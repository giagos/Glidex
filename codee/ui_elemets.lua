---@diagnostic disable: undefined-global
-- Shared UI element utilities: text truncation, basic widgets, windows, contrast helpers
local UIE = {}

local utf8 = require("utf8")

-- Truncate a string to fit maxW using current or provided font; appends ASCII ellipsis
function UIE.truncate(text, maxW, font)
    local lg = love.graphics
    local f = font or lg.getFont()
    local t = tostring(text or "")
    if f:getWidth(t) <= maxW then return t end
    local ell = "..."
    while #t > 0 and f:getWidth(t .. ell) > maxW do
        local byteoffset = utf8.offset(t, -1)
        if not byteoffset then t = ""; break end
        t = t:sub(1, byteoffset - 1)
    end
    return t .. ell
end

function UIE.labelClipped(x, y, w, text, font)
    local lg = love.graphics
    local f = font or lg.getFont()
    local t = UIE.truncate(text, w, f)
    lg.print(t, x, y)
end

function UIE.button(x, y, w, h, label, font)
    local lg = love.graphics
    lg.rectangle("line", x, y, w, h)
    local pad = 6
    local f = font or lg.getFont()
    local ty = y + math.floor((h - f:getHeight())/2)
    UIE.labelClipped(x + pad, ty, w - pad*2, label, f)
    return {x=x,y=y,w=w,h=h}
end

-- Simple retro window frame with optional title and scissored content region
function UIE.beginWindow(id, x, y, w, h, title)
    local lg = love.graphics
    lg.setColor(1,1,1,1)
    lg.rectangle("line", x, y, w, h)
    local headerH = 0
    if title and title ~= "" then
        local fh = lg.getFont():getHeight()
        headerH = math.max(0, fh + 6)
        lg.setColor(0.85,0.85,0.85,1)
        lg.rectangle("fill", x+1, y+1, w-2, headerH)
        lg.setColor(0,0,0,1)
        lg.print(title, x + 8, y + math.floor((headerH - fh)/2))
        lg.setColor(1,1,1,1)
    end
    local cx, cy, cw, ch = x + 2, y + 2 + headerH, w - 4, h - 4 - headerH
    lg.setScissor(cx, cy, cw, ch)
    return cx, cy, cw, ch, headerH
end

function UIE.endWindow()
    love.graphics.setScissor()
end

-- Contrast helpers
function UIE.relativeLuminance(r,g,b)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

function UIE.contrastColorFor(bgR, bgG, bgB)
    local L = UIE.relativeLuminance(bgR or 0, bgG or 0, bgB or 0)
    if L > 0.6 then return 0,0,0 else return 1,1,1 end
end

function UIE.maybeInvertColor(fr, fg, fb, br, bg, bb, threshold)
    threshold = threshold or 0.25
    local Lf = UIE.relativeLuminance(fr, fg, fb)
    local Lb = UIE.relativeLuminance(br, bg, bb)
    if math.abs(Lf - Lb) < threshold then
        return 1-fr, 1-fg, 1-fb
    end
    return fr, fg, fb
end

-- Generic filled highlight bar
function UIE.drawFillBar(x, y, w, h, alpha)
    local lg = love.graphics
    lg.setColor(0,0,0, alpha or 0.35)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(1,1,1,1)
end

-- Expose optional helpers for callers
UIE.hit = require('codee.ui_elemets.hit')
UIE.layout = (function()
    local ok, mod = pcall(require, 'codee.ui_elemets.layout')
    if ok then return mod end
    return nil
end)()

return UIE
