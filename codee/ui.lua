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
    lg.print("Edit: [L] length, [T] thickness, [M] mass, [A] angle → type number → Enter", panelX + 10, y); y = y + 22

    -- Point masses
    lg.print("Point Masses (distance from nose, cm)", panelX + 10, y); y = y + 20
    for i, p in ipairs(self.handler.points) do
        local line = string.format("%d) %s  mass=%.0fg  distance=%.1f cm", i, p.name or ("m"..i), p.mass_g, p.distance_cm)
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
    lg.print("Mass edit: [D] distance (cm), [M] mass (g)", panelX + 10, y); y = y + 18
    lg.print("Mass manage: [+] add, [-] remove", panelX + 10, y); y = y + 18
    if self.editField then
        lg.print("Editing " .. self.editField .. ": " .. self.inputText, panelX + 10, y)
    end
end

function UI:keypressed(key)
    if key == "+" or key == "=" then
    self.handler:add({ mass_g = 100, distance_cm = 0 })
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
    if key == "m" and (not self.selected) then self.editField = "body.mass"; self.inputText = ""; return end
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
            if self.editField == "mass" and self.selected then self.handler.points[self.selected].mass_g = math.max(1, val) end
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
