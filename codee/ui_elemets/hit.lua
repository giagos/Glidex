local M = {}

function M.insideRect(mx, my, r)
    return r and mx>=r.x and mx<=r.x+r.w and my>=r.y and my<=r.y+r.h
end

function M.insideCircle(mx, my, c)
    if not c or not c.cx then return false end
    local dx = mx - c.cx
    local dy = my - c.cy
    return dx*dx + dy*dy <= (c.r or 0)^2
end

return M
