local M = {}

-- Row/label metric helpers centralizing font math
function M.rowStep(font)
    local fh = font:getHeight()
    return fh + 6
end

function M.rowRect(font, y)
    local fh = font:getHeight()
    return y, fh
end

function M.textPad(font)
    return math.floor(font:getWidth(' ') * 0.5 + 0.5), math.floor(font:getHeight() * 0.15 + 0.5)
end

return M
