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

    -- Panel
    lg.setColor(1,1,1,1)
    lg.rectangle("line", panelX, y, panelW, h - 40)
    y = y + 10

    -- Body controls
    lg.print("Main Body (units: cm, g, deg)", panelX + 10, y); y = y + 20
    lg.print(string.format("Length (cm): %.1f", self.body.length_cm), panelX + 10, y); y = y + 18
    lg.print(string.format("Thickness (cm): %.1f", self.body.thickness_cm), panelX + 10, y); y = y + 18
    lg.print(string.format("Mass (g): %.0f", self.body.mass_g), panelX + 10, y); y = y + 18
    lg.print(string.format("Angle (deg): %.1f", self.body:getAngleDegrees()), panelX + 10, y); y = y + 22
    lg.print("Edit: [L] length, [T] thickness, [W] mass, [A] angle → type number → Enter", panelX + 10, y); y = y + 22

    -- Point masses
    lg.print("Components (distance from nose, cm)", panelX + 10, y); y = y + 20
    for i, p in ipairs(self.handler.points) do
        local kind = p.kind or "mass"
        local line = string.format("%d) [%s] %s  mass=%.0fg  distance=%.1f cm", i, kind, p.name or ("m"..i), p.mass_g, p.distance_cm)
        if self.selected == i then
            lg.setColor(0.9, 0.9, 0.9, 0.4)
            lg.rectangle("fill", panelX + 6, y - 2, panelW - 12, 18)
            lg.setColor(1,1,1,1)
        end
        lg.print(line, panelX + 10, y)
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
        lg.print(string.format("Length [L]: %.1f cm", self.body.length_cm), mx + 12, yy); yy = yy + 18
        lg.print(string.format("Thickness [T]: %.1f cm", self.body.thickness_cm), mx + 12, yy); yy = yy + 18
        if gpc and gpc > 0 then
            lg.print(string.format("Mass [W]: %.0f g (computed)", self.body.mass_g), mx + 12, yy)
        else
            lg.print(string.format("Mass [W]: %.0f g", self.body.mass_g), mx + 12, yy)
        end
        yy = yy + 18
        lg.print(string.format("Angle [A]: %.1f deg", self.body:getAngleDegrees()), mx + 12, yy); yy = yy + 18
        lg.print(string.format("g/cm [G]: %s", gpc and string.format("%.3f", gpc) or "(none)"), mx + 12, yy); yy = yy + 24
        lg.print("Enter value after key (L/T/W/A/G). Esc to close.", mx + 12, yy); yy = yy + 18
        if self.setupEditField then
            lg.print("Editing " .. self.setupEditField .. ": " .. self.inputText, mx + 12, yy)
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
            return
        end
        -- in modal but no edit: ignore other keys
        return
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
        return
    end
    if key == "-" then
        if self.selected and self.handler.points[self.selected] then
            table.remove(self.handler.points, self.selected)
            if self.selected > #self.handler.points then self.selected = #self.handler.points end
            if #self.handler.points == 0 then self.selected = nil end
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
    end
end

function UI:mousepressed(mx, my, button)
    if button ~= 1 then return end
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

return UI
