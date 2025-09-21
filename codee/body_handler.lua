---@diagnostic disable: undefined-global
-- BodyHandler: manage multiple point masses relative to a main body (side view)
-- Units: distance_cm (cm) from the NOSE (right end) along the body; vertical is fixed at 0 (no up/down).
-- Mass in grams. Icon size scales linearly with mass.

local BodyHandler = {}
BodyHandler.__index = BodyHandler
local VDraw = require("codee.vector_draw")
local VCalc = require("codee.vector_calc")

-- Icon scaling
local BASE_RADIUS = 6
local RADIUS_PER_G = 0.03 -- 100g => +3px, 500g => +15px
local MIN_RADIUS = 6
local MAX_RADIUS = 40

local function massToRadius(mg)
    local r = BASE_RADIUS + (mg or 0) * RADIUS_PER_G
    if r < MIN_RADIUS then r = MIN_RADIUS end
    if r > MAX_RADIUS then r = MAX_RADIUS end
    return r
end

function BodyHandler.new(mainBody)
    local h = setmetatable({}, BodyHandler)
    h.body = mainBody
    h.points = {}
    return h
end

-- Add a point mass
-- opts: {id?, name?, mass_g, distance_cm, color}
function BodyHandler:add(opts)
    opts = opts or {}
    local p = {
        id = opts.id or tostring(love.timer.getTime()),
        name = opts.name or ("m" .. tostring(#self.points + 1)),
        mass_g = opts.mass_g or 100,
    distance_cm = opts.distance_cm or 0, -- distance from nose towards tail (cm)
    color = opts.color or {0.9, 0.2, 0.2},
    kind = opts.kind or "mass", -- "mass" | "ballast" | "target"
    }
    table.insert(self.points, p)
    return p
end

function BodyHandler:removeById(id)
    for i, p in ipairs(self.points) do
        if p.id == id then
            table.remove(self.points, i)
            return true
        end
    end
    return false
end

function BodyHandler:updatePosition(id, distance_cm)
    for _, p in ipairs(self.points) do
        if p.id == id then
            p.distance_cm = distance_cm or p.distance_cm
            return true
        end
    end
    return false
end

-- Draw CG-style icon: circle with quadrants: TR and BL black, TL and BR white; with cross lines
local function drawCGIcon(x, y, r)
    local lg = love.graphics
    -- Base: white circle
    lg.setColor(1,1,1,1)
    lg.circle("fill", x, y, r)
    -- Top-right quadrant (black): from -pi/2 (up) to 0 (right)
    lg.setColor(0,0,0,1)
    lg.arc("fill", x, y, r, -math.pi/2, 0)
    -- Bottom-left quadrant (black): from pi/2 (down) to pi (left)
    lg.arc("fill", x, y, r, math.pi/2, math.pi)
    -- Cross lines
    lg.setColor(0,0,0,1)
    lg.setLineWidth(1)
    lg.line(x - r, y, x + r, y)
    lg.line(x, y - r, x, y + r)
    -- Outline
    lg.circle("line", x, y, r)
end

local function drawRing(x, y, r, color)
    local lg = love.graphics
    if not color then return end
    lg.setColor(color[1], color[2], color[3], color[4] or 1)
    lg.setLineWidth(3)
    lg.circle("line", x, y, r + 3)
end

function BodyHandler:draw()
    local body = self.body
    if not body then return end
    -- Adaptive vector scale via calculator
    local gScale = VCalc.adaptiveGravityScale(self.body, self.points)

    for _, p in ipairs(self.points) do
        -- Convert body-local cm to world px using the main body transform
        local x, y = body:localToWorld(p.distance_cm, 0)
        local r = massToRadius(p.mass_g)
        drawCGIcon(x, y, r)
        -- Type highlight ring
        if p.kind == "target" then
            drawRing(x, y, r, {0,1,0,1}) -- green
        elseif p.kind == "ballast" then
            drawRing(x, y, r, {1,1,0,1}) -- yellow
        end
        -- Gravity vector (screen down), magnitude proportional to mass and adaptive scale
        if p.kind ~= "target" then
            local gvx, gvy = 0, (p.mass_g or 0) * gScale
            VDraw.arrowWithLabel(x, y, gvx, gvy, string.format("%.0f g @ 90°", p.mass_g or 0), {1,1,1,1}, r+2)
        end
    end
end

return BodyHandler
