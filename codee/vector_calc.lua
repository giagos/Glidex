---@diagnostic disable: undefined-global
-- Vector/physics calculator: sums, center of mass, and resultant gravity vector
-- Domain: 1D rod (body) with point masses along the length; gravity vectors are parallel (downward)

local VCalc = {}

---Sum a list of vectors { {vx,vy}, ... }
---@param vecs table
---@return number sx, number sy
function VCalc.sumVectors(vecs)
    local sx, sy = 0, 0
    if not vecs then return sx, sy end
    for _, v in ipairs(vecs) do
        sx = sx + (v[1] or 0)
        sy = sy + (v[2] or 0)
    end
    return sx, sy
end

---Compute center of mass along the rod (nose-at-right). Returns distance_cm from the nose and total mass_g.
---@param body table Body with length_cm, mass_g
---@param points table list of {mass_g, distance_cm}
---@return number com_distance_cm, number total_mass_g
function VCalc.centerOfMass(body, points)
    local total_m = 0
    local moment = 0
    -- include point masses
    if points then
        for _, p in ipairs(points) do
            local m = p.mass_g or 0
            local d = p.distance_cm or 0
            total_m = total_m + m
            moment = moment + m * d
        end
    end
    -- include body mass at its geometric center (length/2)
    if body and (body.mass_g or 0) > 0 then
        local m = body.mass_g or 0
        local d = (body.length_cm or 0) * 0.5
        total_m = total_m + m
        moment = moment + m * d
    end
    if total_m <= 0 then return 0, 0 end
    return (moment / total_m), total_m
end

---Center of mass measured from the left end (treat left as the nose)
---@param body table Body with length_cm, mass_g
---@param points table list of {mass_g, distance_cm}
---@return number com_from_left_cm, number total_mass_g
function VCalc.centerOfMassFromLeft(body, points)
    local com_from_right, total_m = VCalc.centerOfMass(body, points)
    local L = (body and body.length_cm) or 0
    return (L - (com_from_right or 0)), total_m or 0
end

---Adaptive gravity scale: makes the largest visible mass vector reach a target pixel length
---@param body table
---@param points table
---@return number gScale
function VCalc.adaptiveGravityScale(body, points)
    local w, h = love.graphics.getDimensions()
    local visibleMaxMass = 0
    local anyVisible = false
    local function consider(mass_g, u_cm)
        if not body then return end
        local x, y = body:localToWorld(u_cm or 0, 0)
        if x >= 0 and x <= w and y >= 0 and y <= h then
            anyVisible = true
            if mass_g and mass_g > visibleMaxMass then visibleMaxMass = mass_g end
        end
    end
    -- consider point masses (only these are drawn); exclude main body mass entirely
    if points then
        for _, p in ipairs(points) do
            consider(p.mass_g or 0, p.distance_cm or 0)
        end
    end
    if not anyVisible then
        -- fallback to overall max
        if points then
            for _, p in ipairs(points) do
                if p.mass_g and p.mass_g > visibleMaxMass then visibleMaxMass = p.mass_g end
            end
        end
    end
    local minDim = math.min(w, h)
    local targetMaxPx = math.max(100, math.min(minDim * 0.25, 220))
    if visibleMaxMass > 0 then
        return targetMaxPx / visibleMaxMass
    end
    return 0.12 -- default fallback
end

---Return the target pixel length used for the largest vector on screen
---@return number targetMaxPx
function VCalc.targetVectorLength()
    local w, h = love.graphics.getDimensions()
    local minDim = math.min(w, h)
    return math.max(100, math.min(minDim * 0.25, 220))
end

---Compute resultant gravity vector and where to draw it (at COM).
---@param body table
---@param points table
---@return number|nil x, number|nil y, number|nil vx, number|nil vy, number total_m_g, number gScale
function VCalc.resultantGravityVector(body, points)
    local com_cm, total_m = VCalc.centerOfMass(body, points)
    if not body or total_m <= 0 then return nil, nil, nil, nil, 0, 0.12 end
    local x, y = body:localToWorld(com_cm, 0)
    local gScale = VCalc.adaptiveGravityScale(body, points)
    -- Resultant length: match the largest displayed vector, not proportional to total mass
    local targetLen = VCalc.targetVectorLength()
    local vx, vy = 0, targetLen
    return x, y, vx, vy, total_m, gScale
end

return VCalc
