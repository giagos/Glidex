-- Simple 2D vector utilities (screen space)
local V = {}
V.__index = V

function V.new(x, y)
    return { x = x or 0, y = y or 0 }
end

function V.add(a, b)
    return { x = (a.x or 0) + (b.x or 0), y = (a.y or 0) + (b.y or 0) }
end

function V.sub(a, b)
    return { x = (a.x or 0) - (b.x or 0), y = (a.y or 0) - (b.y or 0) }
end

function V.scale(a, s)
    return { x = (a.x or 0) * s, y = (a.y or 0) * s }
end

function V.length(a)
    return math.sqrt((a.x or 0)^2 + (a.y or 0)^2)
end

function V.normalize(a)
    local len = V.length(a)
    if len == 0 then return { x = 0, y = 0 } end
    return { x = a.x / len, y = a.y / len }
end

function V.angle(a)
    return math.deg(math.atan(a.y or 0, a.x or 0))
end

function V.from_polar(magnitude, angle_deg)
    local ang = (angle_deg or 0) * math.pi / 180
    return { x = (magnitude or 0) * math.cos(ang), y = (magnitude or 0) * math.sin(ang) }
end

return V
