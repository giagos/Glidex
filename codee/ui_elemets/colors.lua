local M = {}

-- Simple WCAG-ish luminance and contrast helpers
function M.relativeLuminance(r, g, b)
    local function srgb_to_lin(c)
        if c <= 0.03928 then return c/12.92 else return ((c+0.055)/1.055)^2.4 end
    end
    local R = srgb_to_lin(r)
    local G = srgb_to_lin(g)
    local B = srgb_to_lin(b)
    return 0.2126*R + 0.7152*G + 0.0722*B
end

function M.contrastColorFor(r, g, b)
    local L = M.relativeLuminance(r, g, b)
    -- Return black for light bg, white for dark bg
    return (L > 0.5) and 0 or 1, (L > 0.5) and 0 or 1, (L > 0.5) and 0 or 1
end

function M.maybeInvertColor(r, g, b)
    local cr, cg, cb = M.contrastColorFor(r, g, b)
    return cr, cg, cb
end

return M
