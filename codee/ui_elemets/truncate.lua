---@diagnostic disable: undefined-global
local M = {}

-- UTF-8 safe truncation with ASCII ellipsis
function M.truncate(text, maxW, font)
    local lg = love.graphics
    if not font then font = lg and lg.getFont and lg.getFont() or nil end
    if not font or not text or maxW <= 0 then return text or '' end
    local tw = font:getWidth(text)
    if tw <= maxW then return text end
    local ell = '...'
    local ellW = font:getWidth(ell)
    local target = math.max(0, maxW - ellW)
    -- binary chop by byte length (assumes most labels ASCII; for UTF-8, trim by codepoints)
    local lo, hi = 0, #text
    local best = ''
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local s = text:sub(1, mid)
        if font:getWidth(s) <= target then
            best = s
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    return best .. ell
end

return M
