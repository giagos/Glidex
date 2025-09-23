---@diagnostic disable: undefined-global
-- UI module: handles drawing and input for body and point masses
local UI = {}
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
    -- lightweight console/history and interactive command console
    ui.history = {}
    ui.maxHistory = 50
    ui.consoleFocus = false
    ui.consoleInput = ""
    ui.consoleBox = {x=0,y=0,w=0,h=0}
    return ui
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
    local panelX = w - 300
    local panelW = 280
    local y = 20

    -- Left-side button: Fuselage Setup
    do
        local b = self.setupBtn
        lg.setColor(1,1,1,1)
        lg.rectangle("line", b.x, b.y, b.w, b.h)
        lg.print("Fuselage Setup", b.x + 8, b.y + 6)
    end

    -- Clear hit maps (will be rebuilt this frame)
    self.hit.body = {}
    self.hit.comp.mass = {}
    self.hit.comp.dist = {}
    self.hit.setup = {}

    -- Panel
    lg.setColor(1,1,1,1)
    lg.rectangle("line", panelX, y, panelW, h - 40)
    y = y + 10

    -- Body controls
    lg.print("Main Body (units: cm, g, deg)", panelX + 10, y); y = y + 20
    local lineH = 18
    local bx = panelX + 10
    lg.print(string.format("Length (cm): %.1f", self.body.length_cm), bx, y)
    self.hit.body.length = {x=bx, y=y-2, w=panelW-20, h=lineH}
    y = y + lineH
    lg.print(string.format("Thickness (cm): %.1f", self.body.thickness_cm), bx, y)
    self.hit.body.thickness = {x=bx, y=y-2, w=panelW-20, h=lineH}
    y = y + lineH
    lg.print(string.format("Mass (g): %.0f", self.body.mass_g), bx, y)
    self.hit.body.mass = {x=bx, y=y-2, w=panelW-20, h=lineH}
    y = y + lineH
    lg.print(string.format("Angle (deg): %.1f", self.body:getAngleDegrees()), bx, y)
    self.hit.body.angle = {x=bx, y=y-2, w=panelW-20, h=lineH}
    y = y + lineH + 4
    lg.print("Edit: [L] length, [T] thickness, [W] mass, [A] angle → type number → Enter", panelX + 10, y); y = y + 22

    -- Point masses
    lg.print("Components (distance from nose, cm)", panelX + 10, y); y = y + 20
    local font = lg.getFont()
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
        if self.selected == i then
            lg.setColor(0, 1, 0, 0.25)
            lg.rectangle("fill", panelX + 6, y - 2, panelW - 12, 18)
            lg.setColor(0, 1, 0, 0.9)
            lg.rectangle("line", panelX + 6, y - 2, panelW - 12, 18)
            lg.setColor(1,1,1,1)
        end
        lg.print(line, panelX + 10, y)
        -- clickable regions for mass value and distance value
        local x0 = panelX + 10
        local xMass = x0 + font:getWidth(base .. massLabel)
        local wMass = font:getWidth(massVal)
        local xDist = x0 + font:getWidth(base .. massLabel .. massVal .. sep .. distLabel)
        local wDist = font:getWidth(distVal)
        self.hit.comp.mass[i] = {x=xMass, y=y-2, w=wMass, h=18}
        self.hit.comp.dist[i] = {x=xDist, y=y-2, w=wDist, h=18}
        y = y + 20
    end

    y = y + 10
    lg.print("Click a row to select.", panelX + 10, y); y = y + 18
    lg.print("Edit selected: [D] distance (cm), [M] mass (g)", panelX + 10, y); y = y + 18
    lg.print("Add: [+] mass, [B] ballast (±g), [G] CG target", panelX + 10, y); y = y + 18
    lg.print("Remove: [-] selected", panelX + 10, y); y = y + 18
    if self.editField then
        lg.print("Editing " .. self.editField .. ": " .. self.inputText, panelX + 10, y)
    end

    -- Setup modal
    if self.showSetup then
        -- dim background lightly
        lg.setColor(0.8,0.8,0.8,0.12)
        lg.rectangle("fill", 0, 0, w, h)
        local mw, mh = math.min(420, w-80), 240
        local mx, my = 40, 100
        lg.setColor(0.85,0.85,0.85,0.85) -- light translucent gray
        lg.rectangle("fill", mx, my, mw, mh)
        lg.setColor(0,0,0,1)
        lg.rectangle("line", mx, my, mw, mh)
        local yy = my + 12
        lg.print("Fuselage Setup (cm, g, deg)", mx + 12, yy); yy = yy + 22
        -- show current values; if g_per_cm set, mass is computed
        local gpc = self.body.g_per_cm
        if gpc and gpc > 0 then
            local computed = (self.body.length_cm or 0) * gpc
            self.body.mass_g = computed
        end
        lg.print(string.format("Length [L]: %.1f cm", self.body.length_cm), mx + 12, yy); self.hit.setup.length = {x=mx+12,y=yy-2,w=mw-24,h=18}; yy = yy + 18
        lg.print(string.format("Thickness [T]: %.1f cm", self.body.thickness_cm), mx + 12, yy); self.hit.setup.thickness = {x=mx+12,y=yy-2,w=mw-24,h=18}; yy = yy + 18
        if gpc and gpc > 0 then
            lg.print(string.format("Mass [W]: %.0f g (computed)", self.body.mass_g), mx + 12, yy)
        else
            lg.print(string.format("Mass [W]: %.0f g", self.body.mass_g), mx + 12, yy); self.hit.setup.mass = {x=mx+12,y=yy-2,w=mw-24,h=18}
        end
        yy = yy + 18
        lg.print(string.format("Angle [A]: %.1f deg", self.body:getAngleDegrees()), mx + 12, yy); self.hit.setup.angle = {x=mx+12,y=yy-2,w=mw-24,h=18}; yy = yy + 18
        lg.print(string.format("g/cm [G]: %s", gpc and string.format("%.3f", gpc) or "(none)"), mx + 12, yy); self.hit.setup.gpc = {x=mx+12,y=yy-2,w=mw-24,h=18}; yy = yy + 24
        lg.print("Enter value after key (L/T/W/A/G). Esc to close.", mx + 12, yy); yy = yy + 18
        if self.setupEditField then
            lg.print("Editing " .. self.setupEditField .. ": " .. self.inputText, mx + 12, yy)
        end
    end

    -- Draw console (collapsible) at bottom-left: collapsed shows prompt only; expanded shows executed commands
    do
        local margin = 12
        local boxW = math.min(520, w - 2*margin)
        local collapsedH = 34
        local expandedH = 140
        local boxH = self.consoleFocus and expandedH or collapsedH
        local bx, by = margin, h - boxH - margin
        self.consoleBox = {x=bx, y=by, w=boxW, h=boxH}
        lg.setColor(0,0,0,0.5)
        lg.rectangle("fill", bx, by, boxW, boxH)
        lg.setColor(1,1,1,1)
        lg.rectangle("line", bx, by, boxW, boxH)
        local yy = by + 8
        -- input prompt
        local prompt = "> " .. self.consoleInput
        -- simple caret blink based on time
        if self.consoleFocus and (love.timer.getTime() % 1.0) < 0.5 then
            prompt = prompt .. "_"
        end
        lg.setColor(self.consoleFocus and 0.9 or 1, self.consoleFocus and 0.9 or 1, self.consoleFocus and 0.2 or 1, 1)
        lg.print(prompt, bx + 8, yy)
        yy = yy + 22
        -- if expanded, show recent executed commands (history)
        if self.consoleFocus then
            lg.setColor(1,1,1,0.3)
            lg.line(bx + 8, yy, bx + boxW - 8, yy)
            lg.setColor(1,1,1,1)
            yy = yy + 8
            local linesToShow = 5
            local start = math.max(1, #self.history - linesToShow + 1)
            for i = start, #self.history do
                lg.print(self.history[i], bx + 10, yy)
                yy = yy + 18
            end
        end
    end

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
            if self.editField == "mass" and self.selected then outline(self.hit.comp.mass[self.selected]) end
            if self.editField == "distance" and self.selected then outline(self.hit.comp.dist[self.selected]) end
        end
    end
end

function UI:keypressed(key)
    -- Modal handler first
    if self.showSetup then
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

    -- Console focus shortcut
    if key == "/" then
        self.consoleFocus = true
        return
    end
    if self.consoleFocus then
        if key == "escape" then
            self.consoleFocus = false
            return
        end
        if key == "return" or key == "kpenter" then
            local line = self.consoleInput
            if line ~= "" then
                self:log("> " .. line)
                self:execCommand(line)
            end
            self.consoleInput = ""
            return
        end
        if key == "backspace" then
            self.consoleInput = self.consoleInput:sub(1, -2)
            return
        end
        if key:match("^[%w%p%space]$") then
            -- basic ASCII capture
            self.consoleInput = self.consoleInput .. key
            return
        end
        return
    end

    if key == "+" or key == "=" then
        self.handler:add({ mass_g = 100, distance_cm = 0, kind = "mass" })
        self.selected = #self.handler.points
        self:log("> add mass 100 0")
        return
    end
    if key == "b" then
        self.handler:add({ mass_g = 0, distance_cm = 0, kind = "ballast", name = "ballast" })
        self.selected = #self.handler.points
        self:log("> add ballast 0")
        return
    end
    if key == "g" then
        self.handler:add({ mass_g = 0, distance_cm = (self.body.length_cm or 0) * 0.5, kind = "target", name = "target" })
        self.selected = #self.handler.points
        local d = (self.body.length_cm or 0) * 0.5
        self:log("> add target " .. tostring(math.floor(d*10+0.5)/10))
        return
    end
    if key == "-" then
        if self.selected and self.handler.points[self.selected] then
            local p = self.handler.points[self.selected]
            table.remove(self.handler.points, self.selected)
            if self.selected > #self.handler.points then self.selected = #self.handler.points end
            if #self.handler.points == 0 then self.selected = nil end
            self:log("> remove selected")
        end
        return
    end

    -- Body property editing
    if key == "l" then self.editField = "body.length"; self.inputText = ""; return end
    if key == "t" then self.editField = "body.thickness"; self.inputText = ""; return end
    if key == "w" then self.body.g_per_cm = nil; self.editField = "body.mass"; self.inputText = ""; return end
    if key == "a" then self.editField = "body.angle"; self.inputText = tostring(math.floor(self.body:getAngleDegrees()+0.5)); return end

    -- Selected point editing
    if key == "d" and self.selected then self.editField = "distance"; self.inputText = ""; return end
    if key == "m" and self.selected then self.editField = "mass"; self.inputText = ""; return end

    if key == "return" or key == "kpenter" then
        local val = tonumber(self.inputText)
        if val then
            if self.editField == "body.length" then self.body.length_cm = math.max(1, val) end
            if self.editField == "body.thickness" then self.body.thickness_cm = math.max(0.1, val) end
            if self.editField == "body.mass" then self.body.mass_g = math.max(1, val) end
            if self.editField == "body.angle" then self.body:setAngleDegrees(val) end
            if self.editField == "distance" and self.selected then self.handler.points[self.selected].distance_cm = math.max(0, math.min(val, self.body.length_cm)) end
            if self.editField == "mass" and self.selected then
                local k = self.handler.points[self.selected].kind or "mass"
                if k == "ballast" then
                    self.handler.points[self.selected].mass_g = val -- allow negative for ballast
                else
                    self.handler.points[self.selected].mass_g = math.max(1, val)
                end
            end
            -- log canonical command for the change
            if self.editField == "body.length" then self:log("> set body length " .. tostring(val)) end
            if self.editField == "body.thickness" then self:log("> set body thickness " .. tostring(val)) end
            if self.editField == "body.mass" then self:log("> set body mass " .. tostring(val)) end
            if self.editField == "body.angle" then self:log("> set body angle " .. tostring(val)) end
            if self.editField == "distance" and self.selected then self:log("> set selected distance " .. tostring(val)) end
            if self.editField == "mass" and self.selected then self:log("> set selected mass " .. tostring(val)) end
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
            if self.editField == "body.length" then
                self.body.length_cm = math.max(1, val)
                self:centerBody()
            elseif self.editField == "body.thickness" then
                self.body.thickness_cm = math.max(0.1, val)
            elseif self.editField == "body.mass" then
                self.body.mass_g = math.max(1, val)
            elseif self.editField == "body.angle" then
                self.body:setAngleDegrees(val)
            elseif self.editField == "distance" and self.selected then
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
    -- focus console on click inside console box
    local cb = self.consoleBox or {x=0,y=0,w=0,h=0}
    if mx >= cb.x and mx <= cb.x + cb.w and my >= cb.y and my <= cb.y + cb.h then
        self.consoleFocus = true
        return
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
    -- Click body fields to edit
    do
        local b = self.hit.body
        local function inside(r) return r and mx>=r.x and mx<=r.x+r.w and my>=r.y and my<=r.y+r.h end
        if inside(b.length) then self.editField="body.length"; self.inputText=""; return end
        if inside(b.thickness) then self.editField="body.thickness"; self.inputText=""; return end
        if inside(b.mass) then self.body.g_per_cm=nil; self.editField="body.mass"; self.inputText=""; return end
        if inside(b.angle) then self.editField="body.angle"; self.inputText=tostring(math.floor(self.body:getAngleDegrees()+0.5)); return end
    end
    -- Click rows
    local w, h = love.graphics.getDimensions()
    local panelX = w - 300
    local panelW = 280
    local y = 20 + 10 + 20 + 18 + 18 + 22 + 20 -- body header + body lines + helper text start
    local listStartY = y
    for i, _ in ipairs(self.handler.points) do
        local rowY = listStartY + (i - 1) * 20
        if mx >= panelX + 6 and mx <= panelX + panelW - 6 and my >= rowY - 2 and my <= rowY + 16 then
            self.selected = i
            -- If clicked directly on a numeric value, start editing
            local function inside(r) return r and mx>=r.x and mx<=r.x+r.w and my>=r.y and my<=r.y+r.h end
            if inside(self.hit.comp.mass[i]) then self.editField="mass"; self.inputText=""; return end
            if inside(self.hit.comp.dist[i]) then self.editField="distance"; self.inputText=""; return end
            return
        end
    end
    -- Click near icon selects nearest
    local bestI, bestD = nil, 1e9
    for i, p in ipairs(self.handler.points) do
        local x, y = self.body:localToWorld(p.distance_cm, 0)
        local d2 = (mx - x) * (mx - x) + (my - y) * (my - y)
        if d2 < bestD then bestD = d2; bestI = i end
    end
    if bestI then self.selected = bestI end
end

function UI:mousemoved(mx, my, dx, dy)
    if love.mouse.isDown(1) == false then return end
    if not self.selected then return end
    if not self.body or not self.handler or not self.handler.points or not self.handler.points[self.selected] then return end
    local distance_cm = select(1, self.body:worldToLocal(mx, my))
    local maxLen = self.body.length_cm or 0
    self.handler.points[self.selected].distance_cm = math.max(0, math.min(distance_cm or 0, maxLen))
end

function UI:resize()
    self:centerBody()
end

-- Append a message to history (keeps last maxHistory entries)
function UI:log(msg)
    if not msg or msg == "" then return end
    table.insert(self.history, tostring(msg))
    if #self.history > self.maxHistory then
        table.remove(self.history, 1)
    end
end

-- Update per-frame timers (e.g., click indicator)
function UI:update(dt)
    -- currently used for caret blink timing only (via love.timer.getTime in draw)
end

-- Execute a console command line
function UI:execCommand(line)
    local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
    line = trim(line or "")
    if line == "" then return end
    local args = {}
    for w in line:gmatch("%S+") do table.insert(args, w) end
    local cmd = args[1] and args[1]:lower()
    local function ok(msg) self:log("ok: " .. msg) end
    local function err(msg) self:log("err: " .. msg) end

    if cmd == "help" then
        ok("commands: add [mass|ballast|target] [mass] [dist]; remove [index|selected]; select [index]; set body [length|thickness|mass|angle] val; set [index|selected] [mass|distance] val; list; setup [open|close]; center; gpc val")
        return
    elseif cmd == "add" then
        local kind = (args[2] or "mass"):lower()
        if kind == "mass" then
            local m = tonumber(args[3] or "100") or 100
            local d = tonumber(args[4] or "0") or 0
            self.handler:add({ mass_g = m, distance_cm = d, kind = "mass" })
            self.selected = #self.handler.points
            ok("added mass " .. m .. " @ " .. d)
            return
        elseif kind == "ballast" then
            local d = tonumber(args[3] or "0") or 0
            self.handler:add({ mass_g = 0, distance_cm = d, kind = "ballast", name = "ballast" })
            self.selected = #self.handler.points
            ok("added ballast @ " .. d)
            return
        elseif kind == "target" then
            local d = tonumber(args[3] or tostring((self.body.length_cm or 0) * 0.5)) or (self.body.length_cm or 0) * 0.5
            self.handler:add({ mass_g = 0, distance_cm = d, kind = "target", name = "target" })
            self.selected = #self.handler.points
            ok("added target @ " .. d)
            return
        else
            return err("unknown add kind")
        end
    elseif cmd == "remove" then
        local idx = args[2]
        if not idx or idx == "selected" then
            if self.selected and self.handler.points[self.selected] then
                table.remove(self.handler.points, self.selected)
                if self.selected > #self.handler.points then self.selected = #self.handler.points end
                if #self.handler.points == 0 then self.selected = nil end
                return ok("removed selected")
            else
                return err("nothing selected")
            end
        else
            local i = tonumber(idx)
            if i and self.handler.points[i] then
                table.remove(self.handler.points, i)
                if self.selected and self.selected >= i then self.selected = math.max(1, self.selected - 1) end
                if #self.handler.points == 0 then self.selected = nil end
                return ok("removed #" .. i)
            end
            return err("invalid index")
        end
    elseif cmd == "select" then
        local i = tonumber(args[2] or "")
        if i and self.handler.points[i] then self.selected = i; return ok("selected #" .. i) end
        return err("invalid index")
    elseif cmd == "set" then
        local target = (args[2] or ""):lower()
        if target == "body" then
            local field = (args[3] or ""):lower()
            local val = tonumber(args[4] or "")
            if not val then return err("missing value") end
            if field == "length" then self.body.length_cm = math.max(1, val); self:centerBody(); return ok("body length=" .. val) end
            if field == "thickness" then self.body.thickness_cm = math.max(0.1, val); return ok("body thickness=" .. val) end
            if field == "mass" then self.body.g_per_cm = nil; self.body.mass_g = math.max(1, val); return ok("body mass=" .. val) end
            if field == "angle" then self.body:setAngleDegrees(val); return ok("body angle=" .. val) end
            return err("unknown body field")
        else
            local idx = target == "selected" and self.selected or tonumber(target)
            if not (idx and self.handler.points[idx]) then return err("invalid index") end
            local field = (args[3] or ""):lower()
            local val = tonumber(args[4] or "")
            if not val then return err("missing value") end
            if field == "mass" then
                local k = self.handler.points[idx].kind or "mass"
                if k == "ballast" then self.handler.points[idx].mass_g = val else self.handler.points[idx].mass_g = math.max(1, val) end
                return ok("set #"..idx.." mass="..val)
            elseif field == "distance" or field == "dist" then
                self.handler.points[idx].distance_cm = math.max(0, math.min(val, self.body.length_cm))
                return ok("set #"..idx.." distance="..val)
            end
            return err("unknown field")
        end
    elseif cmd == "list" then
        ok("components: " .. tostring(#self.handler.points))
        for i, p in ipairs(self.handler.points) do
            self:log(string.format("  #%d [%s] m=%g g, d=%.1f cm", i, p.kind or "mass", p.mass_g or 0, p.distance_cm or 0))
        end
        return
    elseif cmd == "setup" then
        local sub = (args[2] or ""):lower()
        if sub == "open" then self.showSetup = true; return ok("setup opened") end
        if sub == "close" then self.showSetup = false; return ok("setup closed") end
        return err("use: setup open|close")
    elseif cmd == "center" then
        self:centerBody(); return ok("centered body")
    elseif cmd == "gpc" then
        local v = tonumber(args[2] or "")
        if not v then return err("missing value") end
        if v > 0 then self.body.g_per_cm = v; self.body.mass_g = self.body.length_cm * v; return ok("g/cm=" .. v) end
        self.body.g_per_cm = nil; return ok("g/cm cleared")
    else
        return err("unknown command; try 'help'")
    end
end

return UI
