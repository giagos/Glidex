---@diagnostic disable: undefined-global
-- Auto-balance: when a target and a ballast are visible, set ballast mass so CG hits the target

local VCalc = require("codee.vector_calc")

local Auto = {}

local function isVisible(body, u_cm)
    if not body then return false end
    local x, y = body:localToWorld(u_cm or 0, 0)
    local w, h = love.graphics.getDimensions()
    return x >= 0 and x <= w and y >= 0 and y <= h
end

---Apply auto-balance if both a target and a ballast exist and are on-screen.
---@param body table
---@param handler table
---@return boolean changed, number? newMass
function Auto.apply(body, handler)
    if not (body and handler and handler.points) then return false end
    local target, ballast
    for _, p in ipairs(handler.points) do
        if p.kind == "target" and not target then target = p end
        if p.kind == "ballast" and not ballast then ballast = p end
        if target and ballast then break end
    end
    if not (target and ballast) then return false end
    if not (isVisible(body, target.distance_cm) and isVisible(body, ballast.distance_cm)) then
        return false
    end
    -- Solve for ballast mass so COM equals target position
    local L = body.length_cm or 0
    local u_t = target.distance_cm or 0 -- distance from right-nose increasing left
    local u_b = ballast.distance_cm or 0
    -- Build sums excluding the adjustable ballast and excluding targets
    local M0 = 0
    local S0 = 0
    -- include body mass at center
    if (body.mass_g or 0) ~= 0 then
        local m = body.mass_g or 0
        local u = L * 0.5
        M0 = M0 + m
        S0 = S0 + m * u
    end
    for _, p in ipairs(handler.points) do
        if p ~= ballast and p.kind ~= "target" then
            local m = p.mass_g or 0
            local u = p.distance_cm or 0
            M0 = M0 + m
            S0 = S0 + m * u
        end
    end
    local denom = (u_b - u_t)
    if math.abs(denom) < 1e-6 then
        -- If current non-adjustable moment already matches target, do nothing; else cannot solve
        if math.abs(u_t * M0 - S0) < 1e-3 then
            return false
        else
            return false
        end
    end
    local m_b = (u_t * M0 - S0) / denom
    if ballast.mass_g ~= m_b then
        ballast.mass_g = m_b
        return true, m_b
    end
    return false
end

return Auto
