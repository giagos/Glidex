---@diagnostic disable: undefined-global
-- Main rectangular physical body (side view)
-- Inputs and units:
-- - length_cm (number): body length in centimeters (X along fuselage)
-- - depth_cm (number): not rendered in side view; kept for completeness
-- - thickness_cm (number): body thickness in centimeters (Y in side view)
-- - mass_g (number): body mass in grams
-- - color (table): {r,g,b} each in 0..1
-- - scale (number): pixels per centimeter (default 3)
-- - origin_x, origin_y (number): screen pixel position of the NOSE (right end), mid-height
-- - angle (number, radians): body rotation CCW; UI exposes degrees via setAngleDegrees/getAngleDegrees
-- Coordinate frames:
-- - Nose-at-right convention: local u increases to the LEFT from the nose; v increases upward
-- - Screen Y increases downward; transforms account for this
-- Public helpers:
-- - setAngle(rad), setAngleDegrees(deg), getAngleDegrees()
-- - localToWorld(u_cm, v_cm) and worldToLocal(x_px, y_px)
-- - centerAt(cx, cy): centers the geometric center at cx, cy
local Body = {}
Body.__index = Body

-- Default scale: cm to pixels
local DEFAULT_SCALE = 3 -- 1 cm = 3 px (tweak in main if needed)

---Create a new body
---@param opts table {length_cm, depth_cm, thickness_cm, mass_g, color}
---@return table body
function Body.new(opts)
    opts = opts or {}
    local b = setmetatable({}, Body)
    b.length_cm = opts.length_cm or 0
    b.depth_cm = opts.depth_cm or 0
    b.thickness_cm = opts.thickness_cm or 0
    b.mass_g = opts.mass_g or 0
    b.color = opts.color or {1, 0.6, 0.2}
    b.scale = opts.scale or DEFAULT_SCALE
    -- Body origin on screen in pixels at the nose (RIGHT end), mid-height.
    -- We'll draw the body extending to the LEFT from this origin and rotate around it.
    b.origin_x = opts.origin_x or 60
    b.origin_y = opts.origin_y or 150
    -- Angle in radians (counter-clockwise). 0 = along +X axis.
    b.angle = opts.angle or 0
    return b
end

---Set cm→px scale
function Body:setScale(px_per_cm)
    self.scale = px_per_cm or self.scale
end

---Get pixel width/height for side view rectangle
---Side view uses length (x) by thickness (y). Depth is not visible from exact side.
function Body:getPixelSize()
    local w = (self.length_cm or 0) * self.scale
    local h = (self.thickness_cm or 0) * self.scale
    if h < 1 then h = 1 end -- ensure visible line if very thin
    return w, h
end

---Draw the body
-- Convert local cm coords (u along length, v along thickness; origin at NOSE right-mid)
-- to screen pixel coords, applying scale and rotation about origin.
-- Local frame for nose-at-right: u increases to the LEFT, v increases upward.
function Body:localToWorld(u_cm, v_cm)
    -- Positive u means leftwards from nose. Use negative x direction in local screen space.
    local u = (u_cm or 0) * self.scale
    local v = (v_cm or 0) * self.scale
    -- rotate (-u, -v) to account for leftwards u and screen Y down.
    local sx = -u
    local sy = -v
    local ca = math.cos(self.angle)
    local sa = math.sin(self.angle)
    local rx = sx * ca - sy * sa
    local ry = sx * sa + sy * ca
    return self.origin_x + rx, self.origin_y + ry
end

function Body:setAngle(rad)
    self.angle = rad or 0
end

---Set angle in degrees (wrapper for UI convenience)
function Body:setAngleDegrees(deg)
    local rad = (deg or 0) * math.pi / 180
    self.angle = rad
end

---Get angle in degrees
function Body:getAngleDegrees()
    return (self.angle or 0) * 180 / math.pi
end

---Convert world pixel coords to local cm (u,v) with nose-at-right convention
function Body:worldToLocal(x, y)
    local dx = x - self.origin_x
    local dy = y - self.origin_y
    local ca = math.cos(self.angle)
    local sa = math.sin(self.angle)
    -- rotate by -angle
    local lx = dx * ca + dy * sa
    local ly = -dx * sa + dy * ca
    -- local x increases to the right; u increases to the LEFT => u = -lx
    local u_px = -lx
    local v_px = -ly
    return (u_px / self.scale), (v_px / self.scale)
end

---Center the body visually in the screen (nose-at-right). cx, cy are the desired screen center in px.
function Body:centerAt(cx, cy)
    local w_px, h_px = self:getPixelSize()
    -- For nose-at-right, the center of the rectangle is at origin shifted left by half width in local space.
    -- When angle != 0, a perfect bounding box center is more complex; we center by placing the geometric center at (cx, cy).
    -- The geometric center in local rotated space is at (-w_px/2, 0) relative to origin.
    local ca = math.cos(self.angle)
    local sa = math.sin(self.angle)
    local gx = (-w_px/2) * ca - (0) * sa
    local gy = (-w_px/2) * sa + (0) * ca
    self.origin_x = cx - gx
    self.origin_y = cy - gy
end

function Body:draw()
    local lg = love.graphics
    local r,g,b = self.color[1], self.color[2], self.color[3]
    lg.setColor(r, g, b, 1)
    local w_px, h_px = self:getPixelSize()
    local half_h = h_px * 0.5

    -- We draw a rectangle with its RIGHT-midpoint at origin, rotated by angle.
    lg.push()
    lg.translate(self.origin_x, self.origin_y)
    lg.rotate(self.angle)
    -- In local rotated space, extend to the LEFT: draw from (-w_px,-half_h) to (0, +half_h)
    lg.rectangle("fill", -w_px, -half_h, w_px, h_px)
    -- Outline for visibility
    lg.setColor(0, 0, 0, 1)
    lg.setLineWidth(1)
    lg.rectangle("line", -w_px, -half_h, w_px, h_px)
    lg.pop()
end

return Body
