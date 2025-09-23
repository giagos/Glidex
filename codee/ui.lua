---@diagnostic disable: undefined-global
-- UI module: handles drawing and input for body and point masses
local UI = {}
local utf8 = require("utf8")
UI.__index = UI

function UI.new(handler, body)
    local ui = setmetatable({}, UI)
    ui.handler = handler
    ui.body = body
    ui.selected = nil -- index in handler.points
    ui.editField = nil -- "distance" or "mass" or body fields
    ui.inputText = ""
    ui.showSetup = false
    ui.setupEditField = nil -- "setup.length" | "setup.thickness" | "setup.mass" | "setup.angle" | "setup.g_per_cm"
    ui.setupBtn = {x=16, y=60, w=160, h=28}
    ui.hit = { body = {}, comp = { mass = {}, dist = {} }, setup = {} }
    -- Command-console feature was removed for simplicity.
    -- Preferences and layout
    ui.settings = { panelWidthFrac = 0.22, fontSize = 14, uiScalePerc = 100, fullscreen = false, windowW = nil, windowH = nil, resIndex = 1 }
    ui.menu = { open = false, bounds = {x=0,y=0,w=0,h=0}, items = { {id="settings", label="Settings..."} } }
    ui.showSettings = false
    ui.settingsEditField = nil -- "settings.panelWidthFrac" | "settings.fontSize"
    ui.canvasFullscreen = true
    -- Inspector panel collapse/expand state
    ui.panelCollapsed = ui.panelCollapsed or false
    ui.panelCollapsedW = ui.panelCollapsedW or 24
    ui._panelAnim = (ui.panelCollapsed and 1) or 0 -- 0 expanded, 1 collapsed
    ui._panelAnimTarget = ui._panelAnim
    -- load persisted settings if present
    if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("settings.ini") then
        local data = love.filesystem.read("settings.ini")
        if data then
            for line in tostring(data):gmatch("[^\n]+") do
                local k, v = line:match("^%s*([%w_]+)%s*=%s*([%-%d%.]+)%s*$")
                if k and v then
                    if k == "panelWidthFrac" then ui.settings.panelWidthFrac = math.max(0.10, math.min(0.40, tonumber(v) or ui.settings.panelWidthFrac)) end
                    if k == "fontSize" then ui.settings.fontSize = math.max(10, math.min(28, math.floor(tonumber(v) or ui.settings.fontSize))) end
                    if k == "uiScalePerc" then ui.settings.uiScalePerc = math.max(50, math.min(200, math.floor(tonumber(v) or 100))) end
                    if k == "fullscreen" then ui.settings.fullscreen = tonumber(v) == 1 end
                    if k == "windowW" then ui.settings.windowW = tonumber(v) end
                    if k == "windowH" then ui.settings.windowH = tonumber(v) end
                    if k == "resIndex" then ui.settings.resIndex = math.max(1, math.floor(tonumber(v) or 1)) end
                end
            end
        end
    end
    -- init font
    ui:refreshFont()
    -- Initialize resolution choices and apply saved mode if available
    ui:_initResolutionList()
    if love and love.window and (ui.settings.windowW and ui.settings.windowH and ui.settings.windowW > 0 and ui.settings.windowH > 0) then
        pcall(function() love.window.setMode(ui.settings.windowW, ui.settings.windowH, {fullscreen = ui.settings.fullscreen}) end)
    end
    return ui
end
-- Helpers: text truncation and clipped label/button
function UI:_truncate(text, maxW)
    local lg = love.graphics
    local t = tostring(text or "")
    local font = lg.getFont()
    if font:getWidth(t) <= maxW then return t end
    local ell = "..." -- ASCII ellipsis to avoid multi-byte issues
    while #t > 0 and font:getWidth(t .. ell) > maxW do
        local byteoffset = utf8.offset(t, -1)
        if not byteoffset then t = ""; break end
        t = t:sub(1, byteoffset - 1)
    end
    return t .. ell
end

function UI:_labelClipped(x, y, w, text)
    local lg = love.graphics
    local t = self:_truncate(text, w)
    lg.print(t, x, y)
end

function UI:_button(x, y, w, h, label)
    local lg = love.graphics
    lg.rectangle("line", x, y, w, h)
    local pad = 6
    self:_labelClipped(x + pad, y + math.floor((h - lg.getFont():getHeight())/2), w - pad*2, label)
    return {x=x,y=y,w=w,h=h}
end


-- save settings helper
function UI:saveSettings()
    if not (love and love.filesystem and love.filesystem.write) then return end
    local s = string.format(
        "panelWidthFrac=%.3f\nfontSize=%d\nuiScalePerc=%d\nfullscreen=%d\nwindowW=%d\nwindowH=%d\nresIndex=%d\n",
        self.settings.panelWidthFrac,
        self.settings.fontSize,
        self.settings.uiScalePerc or 100,
        self.settings.fullscreen and 1 or 0,
        self.settings.windowW or 0,
        self.settings.windowH or 0,
        self.settings.resIndex or 1
    )
    love.filesystem.write("settings.ini", s)
end

function UI:refreshFont()
    if love and love.graphics and love.graphics.newFont then
        local base = self.settings.fontSize or 14
        local scale = (self.settings.uiScalePerc or 100) / 100
        local sz = math.max(8, math.floor(base * scale + 0.5))
        self.font = love.graphics.newFont(sz)
    end
end

-- Minimal retro windowing system with clipping and helpers
-- beginWindow draws a lined frame and optional title bar, then applies a scissor for content
-- Returns content rect (cx, cy, cw, ch) and header height so callers can layout safely
function UI:beginWindow(id, x, y, w, h, title)
    local lg = love.graphics
    -- frame
    lg.setColor(1,1,1,1)
    lg.rectangle("line", x, y, w, h)
    -- optional title bar
    local headerH = 0
    if title and title ~= "" then
        headerH = math.max(0, lg.getFont():getHeight() + 6)
        lg.setColor(0.85,0.85,0.85,1)
        lg.rectangle("fill", x+1, y+1, w-2, headerH)
        lg.setColor(0,0,0,1)
        lg.print(title, x + 8, y + math.floor((headerH - lg.getFont():getHeight())/2))
        lg.setColor(1,1,1,1)
    end
    -- clip content
    local cx, cy, cw, ch = x + 2, y + 2 + headerH, w - 4, h - 4 - headerH
    lg.setScissor(cx, cy, cw, ch)
    return cx, cy, cw, ch, headerH
end
-- Basic contrast utilities
function UI:_relativeLuminance(r,g,b)
    -- simple perceived luminance approximation
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

function UI:contrastColorFor(bgR, bgG, bgB)
    local L = self:_relativeLuminance(bgR or 0, bgG or 0, bgB or 0)
    if L > 0.6 then return 0,0,0 else return 1,1,1 end
end

function UI:maybeInvertColor(fr, fg, fb, br, bg, bb, threshold)
    threshold = threshold or 0.25
    local Lf = self:_relativeLuminance(fr, fg, fb)
    local Lb = self:_relativeLuminance(br, bg, bb)
    if math.abs(Lf - Lb) < threshold then
        return 1-fr, 1-fg, 1-fb
    end
    return fr, fg, fb
end


function UI:endWindow()
    love.graphics.setScissor()
end

-- Alias requested naming style
UI.CreateWindow = UI.beginWindow

-- Lightweight z-order queue (optional use)
function UI:beginFrame()
    self._layers = {}
end

function UI:pushLayer(z, fn)
    table.insert(self._layers, {z=z or 0, fn=fn})
end

function UI:flushLayers()
    table.sort(self._layers, function(a,b) return a.z < b.z end)
    for _, it in ipairs(self._layers) do it.fn() end
    self._layers = {}
end

function UI:drawLabel(x, y, w, text)
    self:_labelClipped(x, y, w, text)
end

function UI:drawButton(x, y, w, h, label)
    return self:_button(x, y, w, h, label)
end

-- layout helper
function UI:getLayout()
    local w, h = love.graphics.getDimensions()
    local topBarH = 32
    local frac = self.settings.panelWidthFrac or 0.22
    local expandedW = math.max(280, math.min(math.floor(w * frac), 420))
    local collapsedW = self.panelCollapsedW or 24
    local t = math.max(0, math.min(1, self._panelAnim or 0))
    local panelW = math.floor(expandedW * (1 - t) + collapsedW * t + 0.5)
    local panelX = w - panelW - 20
    local startY = topBarH + 8
    return panelX, panelW, startY, topBarH
end

-- Resolution utilities
function UI:_initResolutionList()
    local lw, lh = love.graphics.getDimensions()
    if love and love.window and love.window.getDesktopDimensions then
        local dw, dh = love.window.getDesktopDimensions(1)
        if dw and dh then lw, lh = dw, dh end
    end
    -- Curated list + Native; remove duplicates by WxH
    local list = {
        {label = string.format("Native (%dx%d)", lw, lh), w = lw, h = lh},
        {label = "800x600 (SVGA)", w = 800, h = 600},
        {label = "1024x768 (XGA)", w = 1024, h = 768},
        {label = "1280x720 (HD 720p)", w = 1280, h = 720},
        {label = "1366x768 (WXGA)", w = 1366, h = 768},
        {label = "1600x900 (HD+)", w = 1600, h = 900},
        {label = "1920x1080 (FHD)", w = 1920, h = 1080},
        {label = "2560x1440 (QHD)", w = 2560, h = 1440},
        {label = "3840x2160 (4K UHD)", w = 3840, h = 2160},
    }
    local seen = {}
    self.resolutions = {}
    for _, r in ipairs(list) do
        local k = string.format("%dx%d", r.w, r.h)
        if not seen[k] then
            table.insert(self.resolutions, r)
            seen[k] = true
        end
    end
    if not self.settings.resIndex or self.settings.resIndex < 1 or self.settings.resIndex > #self.resolutions then
        self.settings.resIndex = 1
    end
end

function UI:applyResolution(index)
    if not (love and love.window) then return end
    if not (self.resolutions and self.resolutions[index]) then return end
    local r = self.resolutions[index]
    self.settings.resIndex = index
    self.settings.windowW, self.settings.windowH = r.w, r.h
    pcall(function() love.window.setMode(r.w, r.h, {fullscreen = self.settings.fullscreen}) end)
    self:saveSettings()
end

function UI:toggleFullscreen()
    if not (love and love.window) then return end
    self.settings.fullscreen = not self.settings.fullscreen
    local w = self.settings.windowW or select(1, love.graphics.getDimensions())
    local h = self.settings.windowH or select(2, love.graphics.getDimensions())
    pcall(function() love.window.setMode(w, h, {fullscreen = self.settings.fullscreen}) end)
    self:saveSettings()
end

-- Graphics canvas frame (where body/vectors render). Left area, below ribbon, left of panel.
function UI:getCanvasFrame()
    local w, h = love.graphics.getDimensions()
    local panelX, panelW, startY, topBarH = self:getLayout()
    local margin = 12
    local x = margin
    local y = topBarH + margin
    local cw = math.max(100, panelX - x - margin)
    local ch = math.max(80, h - y - margin)
    return x, y, cw, ch
end

function UI:applyCanvasClip()
    local x, y, w, h = self:getCanvasFrame()
    love.graphics.setScissor(x, y, w, h)
    return x, y, w, h
end

-- Helpers to compute canvas rectangles for windowed vs fullscreen-canvas modes
function UI:_computeCanvasRect()
    local w, h = love.graphics.getDimensions()
    local panelX, panelW, _, topBarH = self:getLayout()
    local margin = self.canvasFullscreen and 0 or 12
    local x = margin
    local y = topBarH + margin
    local cw = math.max(100, panelX - x - margin)
    local ch = math.max(80, h - y - margin)
    return x, y, cw, ch
end

-- Draw the graphics canvas with toggleable window frame; return content rect
function UI:beginCanvas()
    local x, y, w, h = self:_computeCanvasRect()
    local cx, cy, cw, ch
    local lg = love.graphics
    if self.canvasFullscreen then
        -- Borderless canvas: clip to full area
        lg.setScissor(x, y, w, h)
        cx, cy, cw, ch = x, y, w, h
    -- Old Windows-style "Restore" icon (two overlapping squares) at top-right edge with dark backdrop
    local size = 14
    local pad = 6
    local bx = x + w - (size + pad)
    local by = y + pad
    local mx, my = love.mouse.getPosition()
    local hx, hy, hw, hh = bx-6, by-4, size+10, size+10
    local hovered = (mx>=hx and mx<=hx+hw and my>=hy and my<=hy+hh)
    -- backdrop for contrast (stronger on hover)
    lg.setColor(0,0,0, hovered and 0.65 or 0.45)
    lg.rectangle("fill", hx, hy, hw, hh)
    -- thicker icon lines in white for visibility
    local oldLW = lg.getLineWidth and lg.getLineWidth() or 1
    if lg.setLineWidth then lg.setLineWidth(2) end
    lg.setColor(1,1,1,1)
    lg.rectangle("line", bx-3, by+3, size, size) -- back square
    lg.rectangle("line", bx, by, size, size)     -- front square
    if lg.setLineWidth then lg.setLineWidth(oldLW) end
    self.hit.canvasToggle = {x=hx, y=hy, w=hw, h=hh}
    else
        -- Windowed canvas: draw a framed window and place a Win95-style maximize icon in the title bar
        local cx2, cy2, cw2, ch2, headerH = self:beginWindow("canvas", x, y, w, h, "Canvas")
        cx, cy, cw, ch = cx2, cy2, cw2, ch2
        -- Temporarily clear scissor to draw in title bar area (above content)
        love.graphics.setScissor()
        local size = 14
        local pad = 6
        local ibx = x + w - (size + pad)
        local iby = y + math.max(1, math.floor((headerH - size)/2))
        local oldLW = lg.getLineWidth and lg.getLineWidth() or 1
        if lg.setLineWidth then lg.setLineWidth(2) end
        -- Title bar is light; use solid black icon for clarity
        lg.setColor(0,0,0,1)
        lg.rectangle("line", ibx, iby, size, size)
        if lg.setLineWidth then lg.setLineWidth(oldLW) end
        self.hit.canvasToggle = {x=ibx, y=iby, w=size, h=size}
        -- Restore scissor to content area
        love.graphics.setScissor(cx, cy, cw, ch)
    end
    return cx, cy, cw, ch
end

function UI:endCanvas()
    if self.canvasFullscreen then
        love.graphics.setScissor()
    else
        self:endWindow()
    end
end

-- Center the body within a given content rectangle (no bias)
function UI:centerBodyInRect(cx, cy, cw, ch)
    if not self.body then return end
    local bx = cx + cw * 0.5
    local by = cy + ch * 0.5
    self.body:centerAt(bx, by)
end

function UI:centerBody()
    local w, h = love.graphics.getDimensions()
    if self.body then
        self.body:centerAt(w * 0.5 - 100, h * 0.5) -- shift a bit left to leave space for the panel
    end
end

function UI:draw()
    local lg = love.graphics
    local w, h = lg.getDimensions()
    local panelX, panelW, y, topBarH = self:getLayout()
    self:beginFrame()
    -- always start with no scissor to avoid clipping overlays
    love.graphics.setScissor()
    -- If Setup modal is open, draw ONLY the modal (full-screen overlay) and return
    if self.showSetup then
        -- dim background
        lg.setColor(0.8,0.8,0.8,0.12)
        lg.rectangle("fill", 0, 0, w, h)
        -- Auto-size modal to content
        local fh = lg.getFont():getHeight()
        local lines = {}
        table.insert(lines, "Fuselage Setup (cm, g, deg)")
        do
            local gpc = self.body.g_per_cm
            local L1 = string.format("Length [L]: %.1f cm", self.body.length_cm)
            local L2 = string.format("Thickness [T]: %.1f cm", self.body.thickness_cm)
            local L3
            if gpc and gpc > 0 then
                L3 = string.format("Mass [W]: %.0f g (computed)", self.body.mass_g)
            else
                L3 = string.format("Mass [W]: %.0f g", self.body.mass_g)
            end
            local L4 = string.format("Angle [A]: %.1f deg", self.body:getAngleDegrees())
            local L5 = string.format("g/cm [G]: %s", gpc and string.format("%.3f", gpc) or "(none)")
            local L6 = "Use Up/Down or Tab to change field. Type to edit. Enter to apply. Esc to close."
            table.insert(lines, L1)
            table.insert(lines, L2)
            table.insert(lines, L3)
            table.insert(lines, L4)
            table.insert(lines, L5)
            table.insert(lines, L6)
            if self.setupEditField then
                table.insert(lines, "Editing " .. self.setupEditField .. ": " .. self.inputText)
            end
        end
    local maxW = 0
    for _, t in ipairs(lines) do maxW = math.max(maxW, lg.getFont():getWidth(t)) end
    -- Symmetric padding: beginWindow content has 2px border; add padX both sides
    local padX, padY = 12, 12
    local mw = math.min(w - 40, math.max(260, maxW + 4 + padX*2))
    -- Height: padY + (title line) + (#other lines * lineH) + padY
    local titleH = fh + 10
    local bodyLines = #lines - 1
    local lineH = fh + 6
    local mh = math.min(h - 40, padY + titleH + bodyLines * lineH + padY)
        local mx, my = math.floor((w - mw)/2), math.floor((h - mh)/2)
        lg.setColor(0.85,0.85,0.85,0.95)
        lg.rectangle("fill", mx, my, mw, mh)
        lg.setColor(0,0,0,1)
        lg.rectangle("line", mx, my, mw, mh)
        local yy = my + 12
    self:drawLabel(mx + padX, yy, mw - padX*2, "Fuselage Setup (cm, g, deg)"); yy = yy + 22
        local gpc = self.body.g_per_cm
        if gpc and gpc > 0 then self.body.mass_g = (self.body.length_cm or 0) * gpc end
        -- ensure a default focused field
        if not self.setupEditField then self.setupEditField = "setup.length" end
        -- Clip content to window
        love.graphics.setScissor(mx+1, my+1, mw-2, mh-2)
        -- draw fields and compute hit boxes
    self:drawLabel(mx + padX, yy, mw - padX*2, string.format("Length [L]: %.1f cm", self.body.length_cm)); self.hit.setup.length = {x=mx+padX-2,y=yy-4,w=mw-(padX*2-4),h=lg.getFont():getHeight()+6}; yy = yy + (lg.getFont():getHeight()+6)
    self:drawLabel(mx + padX, yy, mw - padX*2, string.format("Thickness [T]: %.1f cm", self.body.thickness_cm)); self.hit.setup.thickness = {x=mx+padX-2,y=yy-4,w=mw-(padX*2-4),h=lg.getFont():getHeight()+6}; yy = yy + (lg.getFont():getHeight()+6)
        if gpc and gpc > 0 then
            self:drawLabel(mx + padX, yy, mw - padX*2, string.format("Mass [W]: %.0f g (computed)", self.body.mass_g))
        else
            self:drawLabel(mx + padX, yy, mw - padX*2, string.format("Mass [W]: %.0f g", self.body.mass_g)); self.hit.setup.mass = {x=mx+padX-2,y=yy-4,w=mw-(padX*2-4),h=lg.getFont():getHeight()+6}
        end
        yy = yy + (lg.getFont():getHeight()+6)
        self:drawLabel(mx + padX, yy, mw - padX*2, string.format("Angle [A]: %.1f deg", self.body:getAngleDegrees())); self.hit.setup.angle = {x=mx+padX-2,y=yy-4,w=mw-(padX*2-4),h=lg.getFont():getHeight()+6}; yy = yy + (lg.getFont():getHeight()+6)
        self:drawLabel(mx + padX, yy, mw - padX*2, string.format("g/cm [G]: %s", gpc and string.format("%.3f", gpc) or "(none)")); self.hit.setup.gpc = {x=mx+padX-2,y=yy-4,w=mw-(padX*2-4),h=lg.getFont():getHeight()+6}; yy = yy + (lg.getFont():getHeight()+10)
        self:drawLabel(mx + padX, yy, mw - padX*2, "Use Up/Down or Tab to change field. Type to edit. Enter to apply. Esc to close."); yy = yy + (lg.getFont():getHeight()+2)
        if self.setupEditField then self:drawLabel(mx + padX, yy, mw - padX*2, "Editing " .. self.setupEditField .. ": " .. self.inputText) end
        -- Black rectangular indicator behind current field
        local function fillFocus(r)
            if not r then return end
            love.graphics.setColor(0,0,0,0.35)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
            love.graphics.setColor(1,1,1,1)
        end
        if self.setupEditField == "setup.length" then fillFocus(self.hit.setup.length) end
        if self.setupEditField == "setup.thickness" then fillFocus(self.hit.setup.thickness) end
        if self.setupEditField == "setup.mass" then fillFocus(self.hit.setup.mass) end
        if self.setupEditField == "setup.angle" then fillFocus(self.hit.setup.angle) end
        if self.setupEditField == "setup.g_per_cm" then fillFocus(self.hit.setup.gpc) end
        love.graphics.setScissor()
        return
    end
    -- apply consistent font
    local oldFont = lg.getFont()
    if self.font then lg.setFont(self.font) end

    -- top gray ribbon / menu bar
    do
        lg.setColor(0.2,0.2,0.2,1)
        lg.rectangle("fill", 0, 0, w, topBarH)
        lg.setColor(0.7,0.7,0.7,1)
        lg.rectangle("line", 0, 0, w, topBarH)
    local label = "Preferences"
    local tx = 12
    local ty = math.max(0, math.floor(topBarH/2 - (lg.getFont():getHeight()/2)))
    love.graphics.setScissor(0, 0, w, topBarH)
    lg.setColor(1,1,1,1)
    self:drawLabel(tx, ty, w - 20, label)
    local tw = lg.getFont():getWidth(label)
        self.menu.bounds = {x=tx-4, y=math.max(0, ty-2), w=tw+8, h=lg.getFont():getHeight()+4}
    love.graphics.setScissor()
        if self.menu.open then
            local mx, my = self.menu.bounds.x, topBarH
            local mw, mh = 160, #self.menu.items * 24 + 6
            lg.setColor(0.2,0.2,0.2,0.98)
            lg.rectangle("fill", mx, my, mw, mh)
            lg.setColor(0.7,0.7,0.7,1)
            lg.rectangle("line", mx, my, mw, mh)
            local yy = my + 6
            for i, item in ipairs(self.menu.items) do
        lg.setColor(1,1,1,1)
        self:drawLabel(mx + 10, yy, mw - 20, item.label)
                item._bounds = {x=mx, y=yy-2, w=mw, h=20}
                yy = yy + 24
            end
        end
    end

    -- Left-side button: Fuselage Setup
    do
    local b = self.setupBtn
    -- anchor below menu bar
    b.x = 16
    local extraY = 0
    if self.menu.open then
        extraY = (#self.menu.items * 24 + 6) + 8 -- dropdown height + margin
    end
    b.y = topBarH + 12 + extraY
    -- auto-size button to its label to avoid extra empty space
    local label = "Fuselage Setup"
    local pad = 6
    local fh = lg.getFont():getHeight()
    local fw = lg.getFont():getWidth(label)
    b.w = math.floor(fw + pad*2 + 4)
    b.h = math.floor(fh + 8)
    lg.setColor(1,1,1,1)
    self:drawButton(b.x, b.y, b.w, b.h, label)
    end

    -- Clear hit maps (will be rebuilt this frame)
    self.hit.body = {}
    self.hit.comp.mass = {}
    self.hit.comp.dist = {}
        self.hit.comp.icon = {}
    self.hit.setup = {}
    self.hit.settings = {}
    self.hit.selection = {}

    -- Inspector arrow button attached to panel left edge; stays at same Y, moves with X
    local panelH = math.max(120, h - y - 24)
    local btnW, btnH = 18, 36
    local btnX = panelX - btnW
    local btnY = y + math.floor(panelH/2 - btnH/2)
    -- Button background
    lg.setColor(0.25,0.25,0.25,0.95)
    lg.rectangle("fill", btnX, btnY, btnW, btnH)
    lg.setColor(1,1,1,1)
    lg.rectangle("line", btnX, btnY, btnW, btnH)
    -- Arrow icon
    local dir = (self._panelAnimTarget == 1) and 1 or (self._panelAnimTarget == 0 and -1 or (self.panelCollapsed and 1 or -1))
    local ax = btnX + btnW/2
    local ay = btnY + btnH/2
    local tri = {
        ax + dir*5, ay,
        ax - dir*5, ay - 6,
        ax - dir*5, ay + 6,
    }
    lg.polygon("fill", tri)
    self.hit.panelToggle = {x=btnX, y=btnY, w=btnW, h=btnH}

    -- Panel (windowed with clipping) when not fully collapsed; vertical title when collapsed
    lg.setColor(1,1,1,1)
    if (self._panelAnim or 0) < 0.99 then
        local cx, cy, cw, ch = self:beginWindow("panel", panelX, y, panelW, panelH, "Inspector")
        local left = cx + 8
        local y = cy + 8

        -- Selection section (top): current component with editable parameters
        self:drawLabel(left, y, cw - 16, "Selection"); y = y + 20
        local font = lg.getFont()
        local lineH = font:getHeight() + 2
        if self.selected and self.handler.points[self.selected] then
            local p = self.handler.points[self.selected]
            local name = p.name or (p.kind or "mass")
            self:drawLabel(left, y, cw - 16, string.format("%d) [%s] %s", self.selected, p.kind or "mass", name)); y = y + lineH
            -- Mass (click to edit)
            local massLabel = "Mass (g): "
            local massVal = string.format("%.0f", p.mass_g)
            local x0 = left
            local xMass = x0 + font:getWidth(massLabel)
            local wMass = font:getWidth(massVal)
            self:drawLabel(left, y, cw - 16, massLabel .. massVal)
            -- hit for selection mass edit
            local ascent = font:getAscent()
            local descent = font:getDescent()
            local rectY = y - ascent
            local rectH = (ascent - descent)
            local pad = 2
            self.hit.selection.mass = {x=xMass - pad, y=rectY - pad, w=wMass + pad*2, h=rectH + pad*2}
            y = y + lineH
            -- Distance (click to edit)
            local distLabel = "Distance (cm): "
            local distVal = string.format("%.1f", p.distance_cm)
            local xDist = x0 + font:getWidth(distLabel)
            local wDist = font:getWidth(distVal)
            self:drawLabel(left, y, cw - 16, distLabel .. distVal)
            self.hit.selection.dist = {x=xDist - pad, y=y - ascent - pad, w=wDist + pad*2, h=rectH + pad*2}
            y = y + lineH + 6
        else
            self:drawLabel(left, y, cw - 16, "No component selected. Click a row."); y = y + lineH + 6
        end

    -- Point masses list
    self:drawLabel(left, y, cw - 16, "Components (distance from nose, cm)"); y = y + 20
    -- reuse current font
    local rowStep = font:getHeight() + 6
    -- expose list metrics for precise hit testing
    self.listStartY = y
    self.rowStep = rowStep
    self.listPanelX = panelX
    self.listPanelW = panelW
    for i, p in ipairs(self.handler.points) do
        local kind = p.kind or "mass"
        local name = p.name or ("m"..i)
        local base = string.format("%d) [%s] %s  ", i, kind, name)
        local massLabel = "mass="
        local massVal = string.format("%.0fg", p.mass_g)
        local sep = "  "
        local distLabel = "distance="
        local distVal = string.format("%.1f cm", p.distance_cm)
        local line = base .. massLabel .. massVal .. sep .. distLabel .. distVal
        local ascent = font:getAscent()
        local descent = font:getDescent()
        local rowRectY = y - ascent
        local rowRectH = (ascent - descent)
        if self.selected == i then
            lg.setColor(0, 1, 0, 0.25)
            lg.rectangle("fill", panelX + 6, rowRectY - 2, panelW - 12, rowRectH + 4)
            lg.setColor(0, 1, 0, 0.9)
            lg.rectangle("line", panelX + 6, rowRectY - 2, panelW - 12, rowRectH + 4)
            lg.setColor(1,1,1,1)
        end
    self:drawLabel(panelX + 10, y, cw - 20, line)
        -- clickable regions for mass value and distance value
    -- pixel-perfect icon hit area near the drawn point mass icon
        local ix, iy = self.body:localToWorld(p.distance_cm, 0)
        self.hit.comp.icon[i] = {cx=ix, cy=iy, r=7, x=ix-7, y=iy-7, w=14, h=14}
        local x0 = panelX + 10
        local xMass = x0 + font:getWidth(base .. massLabel)
        local wMass = font:getWidth(massVal)
        local xDist = x0 + font:getWidth(base .. massLabel .. massVal .. sep .. distLabel)
        local wDist = font:getWidth(distVal)
        -- Align hitboxes to text using ascent/descent and add a little padding
        local rectY = y - ascent
        local rectH = (ascent - descent)
        local pad = 2
        self.hit.comp.mass[i] = {x=xMass - pad, y=rectY - pad, w=wMass + pad*2, h=rectH + pad*2}
        self.hit.comp.dist[i] = {x=xDist - pad, y=rectY - pad, w=wDist + pad*2, h=rectH + pad*2}
    y = y + rowStep
    end

    y = y + 10
    self:drawLabel(left, y, cw - 16, "Click a row to select."); y = y + 18
    self:drawLabel(left, y, cw - 16, "Edit selected: [D] distance (cm), [M] mass (g)"); y = y + 18
    self:drawLabel(left, y, cw - 16, "Add: [+] mass, [B] ballast (±g), [G] CG target"); y = y + 18
    self:drawLabel(left, y, cw - 16, "Remove: [-] selected"); y = y + 18

    -- Overall aircraft info (bottom section)
    do
        local VCalc = require("codee.vector_calc")
        local com_left_cm, total_m = VCalc.centerOfMassFromLeft(self.body, self.handler.points)
        local compCount = 0
        for _, p in ipairs(self.handler.points) do if p.kind ~= "target" then compCount = compCount + 1 end end
        self:drawLabel(left, y, cw - 16, "Aircraft Info"); y = y + 20
        self:drawLabel(left, y, cw - 16, string.format("Total mass: %.0f g", total_m or 0)); y = y + 18
        self:drawLabel(left, y, cw - 16, string.format("CG from nose (left): %.1f cm", com_left_cm or 0)); y = y + 18
        self:drawLabel(left, y, cw - 16, string.format("Components: %d", compCount)); y = y + 6
    end
    if self.editField then
        self:drawLabel(left, y, cw - 16, "Editing " .. self.editField .. ": " .. self.inputText)
    end
        -- end panel window clipping before drawing other UI
        self:endWindow()
    else
        -- Collapsed: draw vertical "Inspector" label inside the collapsed bar area
        local bx, by, bw, bh = panelX, y, (self.panelCollapsedW or 24), panelH
        -- border to match windows
        lg.setColor(1,1,1,1)
        lg.rectangle("line", bx, by, bw, bh)
        local label = "Inspector"
        -- rotate and center
        lg.push()
        lg.translate(bx + bw/2, by + bh/2)
        lg.rotate(-math.pi/2)
        local tw = lg.getFont():getWidth(label)
        local th = lg.getFont():getHeight()
        lg.setColor(1,1,1,1)
        lg.print(label, -tw/2, -th/2)
        lg.pop()
    end

    -- (removed duplicate setup modal block; modal is drawn exclusively earlier)

    -- Settings modal (classic WX-style dialog)
    if self.showSettings then
        -- Safety: if mouse not down, stop dragging slider
        if self._dragScale and (not love.mouse.isDown(1)) then self._dragScale = false end
        love.graphics.setScissor() -- ensure not clipped by panel
        lg.setColor(0.1,0.1,0.1,0.55)
        lg.rectangle("fill", 0, 0, w, h)

        -- Compute dynamic modal size
        local mw = math.min(560, w - 80)
        local baseTop = 12 + 22 + 22 -- top pad + title + resolution row
        local listH = 0
        if self._resOpen and self.resolutions then
            listH = #self.resolutions * 20 + 6 + 8 -- dropdown + margin below
        end
        local tail = 28 + 18 + 12 + 16 + 22 + 22 + 18 + (self.settingsEditField and 18 or 0)
        local desired = baseTop + listH + tail + 12 -- bottom pad
        local maxH = h - 80
        local mh = math.min(math.max(260, desired), maxH)
        local mx, my = math.floor((w - mw)/2), math.floor((h - mh)/2)

        lg.setColor(0.85,0.85,0.85,0.98)
        lg.rectangle("fill", mx, my, mw, mh)
        lg.setColor(0,0,0,1)
        lg.rectangle("line", mx, my, mw, mh)
        local yy = my + 12
        lg.print("Settings", mx + 12, yy); yy = yy + 22
        -- Resolution dropdown row
        local r = self.resolutions and self.resolutions[self.settings.resIndex or 1]
        local fRes = string.format("Resolution: %s", r and r.label or "(unknown)")
        lg.print(fRes, mx + 12, yy); self.hit.settings.res = {x=mx+12,y=yy-2,w=mw-24,h=18}; yy = yy + 22
        if self._resOpen and self.resolutions then
            local fullListH = #self.resolutions * 20 + 6
            local lx, ly, lw2 = mx + 12, yy, math.min(mw-24, 360)
            -- clamp dropdown height to fit inside modal
            local remaining = (my + mh) - ly - 12 - (28 + 18 + 12 + 16 + 22 + 22 + 18) -- leave space for rest of controls + bottom pad
            local lh2 = math.max(40, math.min(fullListH, remaining))
            lg.setColor(0.2,0.2,0.2,0.98)
            lg.rectangle("fill", lx, ly, lw2, lh2)
            lg.setColor(1,1,1,1)
            lg.rectangle("line", lx, ly, lw2, lh2)
            -- clip list content to box
            love.graphics.setScissor(lx, ly, lw2, lh2)
            local yy2 = ly + 4
            for i, it in ipairs(self.resolutions) do
                lg.print(it.label, lx + 8, yy2)
                it._bounds = {x=lx, y=yy2-2, w=lw2, h=18, idx=i}
                yy2 = yy2 + 20
            end
            love.graphics.setScissor()
            yy = ly + lh2 + 8
        end
        -- Fullscreen toggle button
        local fsLabel = string.format("Fullscreen: %s", self.settings.fullscreen and "On" or "Off")
        self.hit.settings.fullscreenBtn = {x=mx+12, y=yy-2, w=160, h=22}
        self:drawButton(self.hit.settings.fullscreenBtn.x, self.hit.settings.fullscreenBtn.y, self.hit.settings.fullscreenBtn.w, self.hit.settings.fullscreenBtn.h, fsLabel)
        yy = yy + 28
        -- UI scale slider
        local sLabel = string.format("UI scale: %d%%", self.settings.uiScalePerc or 100)
        lg.print(sLabel, mx + 12, yy); yy = yy + 18
        local barX, barY, barW, barH = mx + 12, yy, mw - 24, 12
        self.hit.settings.scaleBar = {x=barX, y=barY, w=barW, h=barH}
        lg.setColor(0.2,0.2,0.2,1); lg.rectangle("fill", barX, barY + barH/2 - 2, barW, 4)
        lg.setColor(1,1,1,1); lg.rectangle("line", barX, barY + barH/2 - 2, barW, 4)
        local perc = math.max(50, math.min(200, self.settings.uiScalePerc or 100))
        local knobX = barX + (perc - 50) / 150 * barW
        lg.setColor(1,1,1,1); lg.rectangle("fill", knobX-4, barY, 8, barH)
        yy = yy + barH + 16
        -- Existing text options
        local f1 = string.format("Panel width (%% of screen): %.0f%%", (self.settings.panelWidthFrac or 0.22)*100)
        lg.print(f1, mx + 12, yy); self.hit.settings.panel = {x=mx+12,y=yy-2,w=mw-24,h=18}; yy = yy + 22
        local f3 = string.format("Base font size (px): %d", self.settings.fontSize or 14)
        lg.print(f3, mx + 12, yy); self.hit.settings.font = {x=mx+12,y=yy-2,w=mw-24,h=18}; yy = yy + 22
        lg.print("Tab to switch. Enter to apply. Esc to close.", mx + 12, yy); yy = yy + 18
        if self.settingsEditField then
            lg.print("Editing " .. self.settingsEditField .. ": " .. self.inputText, mx + 12, yy)
        end
    end

    -- CG HUD (bottom-left), UI-managed
    do
        local margin = 12
        local fh = lg.getFont():getHeight()
        local text = "CG: N/A"
        if self.body then
            local pts = (self.handler and self.handler.points) or {}
            local VCalc = require("codee.vector_calc")
            local com_left_cm, total_m = VCalc.centerOfMassFromLeft(self.body, pts)
            if (total_m or 0) > 0 then
                text = string.format("CG: %.1f cm from nose (left)", com_left_cm)
            end
        end
    -- Auto-size CG HUD to content exactly with symmetric padding
    local textW = lg.getFont():getWidth(text)
    local padX = 6 -- horizontal content padding
    local boxW = math.min(w - 2*margin, textW + 4 + padX*2) -- beginWindow contributes 2px each side within frame
        local boxH = fh + 12
        local bx = margin
        local by = h - margin - boxH
    local cx, cy, cw, ch = self:beginWindow("cghud", bx, by, boxW, boxH, "")
    self:drawLabel(cx + padX, cy + 4, cw - padX*2, text)
        self:endWindow()
    end
    -- flush any queued layers (currently unused for most sections)
    self:flushLayers()

    -- Edit focus indicator: highlight the active field/number while typing
    do
        local function outline(r)
            if not r then return end
            lg.setColor(1, 1, 0, 0.7)
            lg.rectangle("line", r.x - 2, r.y - 2, r.w + 4, r.h + 4)
            lg.setColor(1,1,1,1)
        end
        -- setup modal fields
        if self.showSetup and self.setupEditField then
            if self.setupEditField == "setup.length" then outline(self.hit.setup.length) end
            if self.setupEditField == "setup.thickness" then outline(self.hit.setup.thickness) end
            if self.setupEditField == "setup.mass" then outline(self.hit.setup.mass) end
            if self.setupEditField == "setup.angle" then outline(self.hit.setup.angle) end
            if self.setupEditField == "setup.g_per_cm" then outline(self.hit.setup.gpc) end
        end
        -- main panel fields
        if self.editField then
            if self.editField == "body.length" then outline(self.hit.body.length) end
            if self.editField == "body.thickness" then outline(self.hit.body.thickness) end
            if self.editField == "body.mass" then outline(self.hit.body.mass) end
            if self.editField == "body.angle" then outline(self.hit.body.angle) end
            if self.editField == "mass" and self.selected then outline(self.hit.selection.mass or self.hit.comp.mass[self.selected]) end
            if self.editField == "distance" and self.selected then outline(self.hit.selection.dist or self.hit.comp.dist[self.selected]) end
        end
    end
end

function UI:keypressed(key)
    -- Modal handler first
    if self.showSetup then
        if key == "tab" or key == "down" then
            self:cycleSetupField(1)
            return
        end
        if key == "up" then
            self:cycleSetupField(-1)
            return
        end
        if key == "escape" then
            self.showSetup = false
            self.setupEditField = nil
            self.inputText = ""
            return
        end
        if key == "l" then self.setupEditField = "setup.length"; self.inputText = ""; return end
        if key == "t" then self.setupEditField = "setup.thickness"; self.inputText = ""; return end
        if key == "a" then self.setupEditField = "setup.angle"; self.inputText = tostring(math.floor(self.body:getAngleDegrees()+0.5)); return end
        if key == "g" then self.setupEditField = "setup.g_per_cm"; self.inputText = ""; return end
        if key == "w" then
            -- only allow manual mass if g/cm is not set
            if not (self.body.g_per_cm and self.body.g_per_cm > 0) then
                self.setupEditField = "setup.mass"; self.inputText = ""
            end
            return
        end
        if key == "return" or key == "kpenter" then
            local val = tonumber(self.inputText)
            if val then
                if self.setupEditField == "setup.length" then
                    self.body.length_cm = math.max(1, val)
                elseif self.setupEditField == "setup.thickness" then
                    self.body.thickness_cm = math.max(0.1, val)
                elseif self.setupEditField == "setup.mass" then
                    self.body.g_per_cm = nil
                    self.body.mass_g = math.max(1, val)
                elseif self.setupEditField == "setup.angle" then
                    self.body:setAngleDegrees(val)
                elseif self.setupEditField == "setup.g_per_cm" then
                    if val and val > 0 then
                        self.body.g_per_cm = val
                        self.body.mass_g = self.body.length_cm * val
                    else
                        self.body.g_per_cm = nil
                    end
                end
                -- Re-center after changes
                self:centerBody()
            end
            self.setupEditField = nil
            self.inputText = ""
            return
        end
    if self.setupEditField then
            if key == "backspace" then
                self.inputText = self.inputText:sub(1, -2)
            elseif key:match("^[%d%.%-]$") then
                self.inputText = self.inputText .. key
            end
            -- live apply while typing (if numeric)
            local val = tonumber(self.inputText)
            if val then
                if self.setupEditField == "setup.length" then
                    self.body.length_cm = math.max(1, val)
                    self:centerBody()
                elseif self.setupEditField == "setup.thickness" then
                    self.body.thickness_cm = math.max(0.1, val)
                elseif self.setupEditField == "setup.mass" then
                    self.body.g_per_cm = nil
                    self.body.mass_g = math.max(1, val)
                elseif self.setupEditField == "setup.angle" then
                    self.body:setAngleDegrees(val)
                elseif self.setupEditField == "setup.g_per_cm" then
                    if val > 0 then
                        self.body.g_per_cm = val
                        self.body.mass_g = self.body.length_cm * val
                    else
                        self.body.g_per_cm = nil
                    end
                end
            end
            return
        end
        -- in modal but no edit: ignore other keys
        return
    end

    -- Settings modal handler
    if self.showSettings then
        if key == "tab" then
            self:cycleSettingsField(1)
            self.inputText = ""
            return
        end
        if key == "down" then
            self:cycleSettingsField(1)
            self.inputText = ""
            return
        end
        if key == "up" then
            self:cycleSettingsField(-1)
            self.inputText = ""
            return
        end
        if key == "escape" then
            self.showSettings = false
            self.settingsEditField = nil
            self.inputText = ""
            self:saveSettings()
            return
        end
    if key == "return" or key == "kpenter" then
            local val = tonumber(self.inputText)
            if val then
                if self.settingsEditField == "settings.panelWidthFrac" then
                    self.settings.panelWidthFrac = math.max(0.10, math.min(0.40, (val >= 1 and val/100 or val)))
                elseif self.settingsEditField == "settings.fontSize" then
                    self.settings.fontSize = math.max(10, math.min(28, math.floor(val)))
                    self:refreshFont()
                end
            end
            self.settingsEditField = nil
            self.inputText = ""
            self:saveSettings()
            return
        end
        if key == "backspace" then
            self.inputText = self.inputText:sub(1, -2)
            return
        end
    if key:match("^[%d%.]$") then
            self.inputText = self.inputText .. key
            -- live apply preview
            local val = tonumber(self.inputText)
            if val then
                if self.settingsEditField == "settings.panelWidthFrac" then
                    local f = (val >= 1 and val/100 or val)
                    self.settings.panelWidthFrac = math.max(0.10, math.min(0.40, f))
                elseif self.settingsEditField == "settings.fontSize" then
                    self.settings.fontSize = math.max(10, math.min(28, math.floor(val)))
                    self:refreshFont()
                end
            end
            return
        end
        return
    end

    -- No console: no additional key routing here

    -- Global Tab: select next component
    if key == "tab" then
        if self.editField == "mass" or self.editField == "distance" then
            self.editField = nil
            self.inputText = ""
        end
        self:selectNextComponent()
        return
    end
    if key == "down" then self:selectNextComponent(); return end
    if key == "up" then self:selectPrevComponent(); return end

    -- Quick-select component by number keys (1-9)
    if not self.editField then
        local idx = tonumber(key)
        if idx and idx >= 1 and idx <= 9 then
            if self.handler.points[idx] then
                self.selected = idx
            end
            return
        end
    end

    if key == "+" or key == "=" then
        self.handler:add({ mass_g = 100, distance_cm = 0, kind = "mass" })
        self.selected = #self.handler.points
        return
    end
    if key == "b" then
        self.handler:add({ mass_g = 0, distance_cm = 0, kind = "ballast", name = "ballast" })
        self.selected = #self.handler.points
        return
    end
    if key == "g" then
        self.handler:add({ mass_g = 0, distance_cm = (self.body.length_cm or 0) * 0.5, kind = "target", name = "target" })
        self.selected = #self.handler.points
        local d = (self.body.length_cm or 0) * 0.5
        return
    end
    if key == "-" then
        if self.selected and self.handler.points[self.selected] then
            local p = self.handler.points[self.selected]
            table.remove(self.handler.points, self.selected)
            if self.selected > #self.handler.points then self.selected = #self.handler.points end
            if #self.handler.points == 0 then self.selected = nil end
        end
        return
    end

    -- Body property editing disabled outside Setup modal

    -- Selected point editing
    if key == "d" and self.selected then self.editField = "distance"; self.inputText = ""; return end
    if key == "m" and self.selected then self.editField = "mass"; self.inputText = ""; return end

    if key == "return" or key == "kpenter" then
        local val = tonumber(self.inputText)
        if val then
            -- body.* fields disabled outside modal
            if self.editField == "body.length" or self.editField == "body.thickness" or self.editField == "body.mass" or self.editField == "body.angle" then
                -- ignore
            end
            if self.editField == "distance" and self.selected then self.handler.points[self.selected].distance_cm = math.max(0, math.min(val, self.body.length_cm)) end
            if self.editField == "mass" and self.selected then
                local k = self.handler.points[self.selected].kind or "mass"
                if k == "ballast" then
                    self.handler.points[self.selected].mass_g = val -- allow negative for ballast
                else
                    self.handler.points[self.selected].mass_g = math.max(1, val)
                end
            end
            -- No command logging
        end
        self.editField = nil
        self.inputText = ""
        -- Recenter after body property changes
        self:centerBody()
        return
    end

    if self.editField then
        if key == "backspace" then
            self.inputText = self.inputText:sub(1, -2)
        elseif key:match("^[%d%.%-]$") then
            self.inputText = self.inputText .. key
        end
        -- live apply while typing (if numeric)
        local val = tonumber(self.inputText)
        if val then
            if self.editField == "distance" and self.selected then
                self.handler.points[self.selected].distance_cm = math.max(0, math.min(val, self.body.length_cm))
            elseif self.editField == "mass" and self.selected then
                local k = self.handler.points[self.selected].kind or "mass"
                if k == "ballast" then
                    self.handler.points[self.selected].mass_g = val
                else
                    self.handler.points[self.selected].mass_g = math.max(1, val)
                end
            end
        end
    end
end

function UI:mousepressed(mx, my, button)
    if button ~= 1 then return end
    -- No console click focus
    -- settings modal clicks
    if self.showSettings then
        local s = self.hit.settings
        local function inside(r) return r and mx>=r.x and mx<=r.x+r.w and my>=r.y and my<=r.y+r.h end
        -- Resolution dropdown label toggles list
        if inside(s.res) then
            self._resOpen = not self._resOpen
            return
        end
        -- If dropdown open, check list selection
        if self._resOpen and self.resolutions then
            for _, it in ipairs(self.resolutions) do
                if it._bounds and inside(it._bounds) then
                    self:applyResolution(it._bounds.idx)
                    self._resOpen = false
                    return
                end
            end
        end
        -- Fullscreen toggle button
        if inside(s.fullscreenBtn) then
            self:toggleFullscreen()
            return
        end
        -- UI scale slider drag start
        if inside(s.scaleBar) then
            self._dragScale = true
            self:_updateScaleWithMouse(mx)
            return
        end
        -- Numeric fields
        if inside(s.panel) then self.settingsEditField = "settings.panelWidthFrac"; self.inputText = ""; return end
        if inside(s.font) then self.settingsEditField = "settings.fontSize"; self.inputText = ""; return end
        return
    end
    -- Toggle Inspector panel via side handle
    if self.hit and self.hit.panelToggle then
        local r = self.hit.panelToggle
        if mx>=r.x and mx<=r.x+r.w and my>=r.y and my<=r.y+r.h then
            -- animate: 0 expanded -> 1 collapsed
            if (self._panelAnim or 0) < 0.5 then
                self._panelAnimTarget = 1; self.panelCollapsed = true
            else
                self._panelAnimTarget = 0; self.panelCollapsed = false
            end
            return
        end
    end
    -- Canvas toggle (both modes)
    if self.hit and self.hit.canvasToggle then
        local r = self.hit.canvasToggle
        if mx>=r.x and mx<=r.x+r.w and my>=r.y and my<=r.y+r.h then
            self.canvasFullscreen = not self.canvasFullscreen
            return
        end
    end
    -- Check setup button click
    do
        local b = self.setupBtn
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            self.showSetup = true
            self.setupEditField = nil
            self.inputText = ""
            return
        end
    end
    -- If modal open, allow clicking lines to edit
    if self.showSetup then
        local s = self.hit.setup
        local function inside(r) return r and mx>=r.x and mx<=r.x+r.w and my>=r.y and my<=r.y+r.h end
        if inside(s.length) then self.setupEditField="setup.length"; self.inputText=""; return end
        if inside(s.thickness) then self.setupEditField="setup.thickness"; self.inputText=""; return end
        if inside(s.mass) then self.setupEditField="setup.mass"; self.inputText=""; return end
        if inside(s.angle) then self.setupEditField="setup.angle"; self.inputText=tostring(math.floor(self.body:getAngleDegrees()+0.5)); return end
        if inside(s.gpc) then self.setupEditField="setup.g_per_cm"; self.inputText=""; return end
        return
    end
    -- Menu interactions (top bar)
    do
        local b = self.menu.bounds or {x=0,y=0,w=0,h=0}
        local _, _, _, topBarH = self:getLayout()
        if my <= topBarH and mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            self.menu.open = not self.menu.open
            return
        end
        if self.menu.open then
            for _, item in ipairs(self.menu.items) do
                local r = item._bounds
                if r and mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
                    if item.id == "settings" then self.showSettings = true end
                    self.menu.open = false
                    return
                end
            end
            -- click outside closes dropdown
            self.menu.open = false
        end
    end
    -- Click body fields to edit (disabled outside setup)
    do
        local b = self.hit.body
        local function inside(r) return r and mx>=r.x and mx<=r.x+r.w and my>=r.y and my<=r.y+r.h end
        -- no-op: must use Setup modal
    end
    -- Click rows
    local w, h = love.graphics.getDimensions()
    -- use metrics captured during draw
    local panelX = self.listPanelX or (w - 300)
    local panelW = self.listPanelW or 280
    local listStartY = self.listStartY or 20
    local rowStep = self.rowStep or (love.graphics.getFont():getHeight() + 6)
    local font = love.graphics.getFont()
    local ascent = font:getAscent()
    local descent = font:getDescent()
    local rowH = (ascent - descent) + 4
    for i, _ in ipairs(self.handler.points) do
        local rowY = listStartY + (i - 1) * rowStep
        local rectY = rowY - ascent - 2
        if mx >= panelX + 6 and mx <= panelX + panelW - 6 and my >= rectY and my <= rectY + rowH then
            self.selected = i
            -- If clicked directly on a numeric value, start editing
            local function inside(r) return r and mx>=r.x and mx<=r.x+r.w and my>=r.y and my<=r.y+r.h end
            if inside(self.hit.comp.mass[i]) then self.editField="mass"; self.inputText=""; return end
            if inside(self.hit.comp.dist[i]) then self.editField="distance"; self.inputText=""; return end
                if inside(self.hit.comp.icon[i]) then self.editField="icon"; self.inputText=""; return end
            return
        end
    end
    -- Pixel-perfect icon drag: start only if clicking inside the icon circle of selected item
    if self.selected and self.hit and self.hit.comp and self.hit.comp.icon and self.hit.comp.icon[self.selected] then
        local r = self.hit.comp.icon[self.selected]
        local dx = mx - r.cx
        local dy = my - r.cy
        if dx*dx + dy*dy <= (r.r*r.r) then
            self.draggingIndex = self.selected
            return
        end
    end
    -- Clicking in selection section mass/distance enables editing
    if self.hit and self.hit.selection then
        local s = self.hit.selection
        local function inside(rr) return rr and mx>=rr.x and mx<=rr.x+rr.w and my>=rr.y and my<=rr.y+rr.h end
        if inside(s.mass) and self.selected then self.editField = "mass"; self.inputText = ""; return end
        if inside(s.dist) and self.selected then self.editField = "distance"; self.inputText = ""; return end
    end
end

function UI:mousemoved(mx, my, dx, dy)
    -- Update UI scale slider while dragging
    if self.showSettings and self._dragScale then
        self:_updateScaleWithMouse(mx)
        return
    end
    if not self.draggingIndex then return end
    if love.mouse.isDown(1) == false then self.draggingIndex = nil; return end
    local i = self.draggingIndex
    if not self.body or not self.handler or not self.handler.points or not self.handler.points[i] then return end
    local distance_cm = select(1, self.body:worldToLocal(mx, my))
    local maxLen = self.body.length_cm or 0
    self.handler.points[i].distance_cm = math.max(0, math.min(distance_cm or 0, maxLen))
end

function UI:mousereleased(mx, my, button)
    if button ~= 1 then return end
    self._dragScale = false
        self.draggingIndex = nil
end

function UI:resize()
    -- Recenter within current canvas content on window resize
    local x, y, w, h = self:_computeCanvasRect()
    self:centerBodyInRect(x, y, w, h)
end

-- Update per-frame timers (placeholder)
function UI:update(dt)
    -- caret blink, etc. Ensure slider drag ends if button not held
    if self._dragScale and (not love.mouse.isDown(1)) then self._dragScale = false end
    -- slide animation for Inspector panel
    if self._panelAnimTarget ~= nil then
        local speed = 6 -- units per second
        local t = self._panelAnim or 0
        local target = self._panelAnimTarget
        if math.abs(t - target) > 0.001 then
            local dir = (t < target) and 1 or -1
            t = t + dir * speed * (dt or 0)
            if (dir == 1 and t > target) or (dir == -1 and t < target) then t = target end
            self._panelAnim = math.max(0, math.min(1, t))
        end
    end
end

-- Cycle through setup fields for Tab navigation in the modal
function UI:cycleSetupField(dir)
    dir = dir or 1
    local order = {"setup.length", "setup.thickness", "setup.mass", "setup.angle", "setup.g_per_cm"}
    if not self.setupEditField then
        self.setupEditField = order[1]
        self.inputText = ""
        return
    end
    local idx = 1
    for i, v in ipairs(order) do if v == self.setupEditField then idx = i break end end
    idx = ((idx - 1 + dir) % #order) + 1
    -- skip mass if g_per_cm is set (mass locked by g/cm)
    if order[idx] == "setup.mass" and self.body.g_per_cm and self.body.g_per_cm > 0 then
        idx = ((idx - 1 + dir) % #order) + 1
    end
    self.setupEditField = order[idx]
    self.inputText = ""
    if self.setupEditField == "setup.angle" then
        self.inputText = tostring(math.floor(self.body:getAngleDegrees()+0.5))
    end
end

-- Select next component (wrap-around)
function UI:selectNextComponent()
    local n = #self.handler.points
    if n == 0 then return end
    if not self.selected then
        self.selected = 1
    else
        self.selected = (self.selected % n) + 1
    end
end

-- Select previous component (wrap-around)
function UI:selectPrevComponent()
    local n = #self.handler.points
    if n == 0 then return end
    if not self.selected then
        self.selected = n
    else
        self.selected = ((self.selected - 2) % n) + 1
    end
end

-- Cycle settings fields
function UI:cycleSettingsField(dir)
    dir = dir or 1
    local order = {"settings.panelWidthFrac", "settings.fontSize"}
    if not self.settingsEditField then
        self.settingsEditField = order[1]
        return
    end
    local idx = 1
    for i, v in ipairs(order) do if v == self.settingsEditField then idx = i break end end
    idx = ((idx - 1 + dir) % #order) + 1
    self.settingsEditField = order[idx]
end

function UI:_updateScaleWithMouse(mx)
    local s = self.hit and self.hit.settings
    if not s or not s.scaleBar then return end
    local bar = s.scaleBar
    local rel = math.max(0, math.min(1, (mx - bar.x) / bar.w))
    local perc = math.floor(50 + rel * 150 + 0.5)
    if perc ~= self.settings.uiScalePerc then
        self.settings.uiScalePerc = perc
        self:refreshFont()
        self:saveSettings()
    end
end

return UI
