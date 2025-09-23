---@diagnostic disable: undefined-global
local config = require("codee.config")
local Body = require("codee.maing_body")
local BodyHandler = require("codee.body_handler")
local UI = require("codee.ui")
local VCalc = require("codee.vector_calc")
local VDraw = require("codee.vector_draw")
local AutoBalance = require("codee.autobalance")

local message = "Welcome to Daedalus Dream Works Glidex"

local body
local handler
local ui

function love.load()
    -- Set the window title using config
    if love.window and love.window.setTitle then
        love.window.setTitle(string.format("%s %s", config.appName, config.version))
    end
    if config.debug then
        print(string.format("[%s %s] Debug mode enabled", config.appName, config.version))
    end
    -- Black background for high contrast with white arrows
    if love.graphics.setBackgroundColor then
        love.graphics.setBackgroundColor(0, 0, 0)
    end

    -- Create a rectangle body (side view)
    body = Body.new({
        length_cm = 0,
        depth_cm = 0,
        thickness_cm = 0,
        mass_g = 0,
        color = {0.2, 0.6, 1.0},
        origin_x = 60,
        origin_y = 200,
        angle = 0,
    })
    body:setScale(3) -- 1 cm = 3 px

    handler = BodyHandler.new(body)
    ui = UI.new(handler, body)
    -- Open setup modal on first screen
    ui.showSetup = true
    ui:centerBody()
end

function love.update(dt)
    if ui and ui.update then ui:update(dt) end
end

function love.draw()
    -- If setup modal is open, draw only the modal and nothing behind
    if ui and ui.showSetup then
        if ui then ui:draw() end
        return
    end

    -- All non-graphics text is drawn by the UI system

    -- Auto-adjust ballast to meet CG target when both visible
    if body and handler then
        AutoBalance.apply(body, handler)
    end

    -- Draw graphics inside a canvas (windowed or fullscreen) and keep centered
    local cx, cy, cw, ch = ui:beginCanvas()
    -- Keep graphics centered in the canvas window
    ui:centerBodyInRect(cx, cy, cw, ch)
    if body then body:draw() end
    if handler then handler:draw() end
    -- Resultant gravity vector in green at the overall center of mass
    if body and handler then
        local rx, ry, rvx, rvy, total_m, _ = VCalc.resultantGravityVector(body, handler.points)
        if rx and rvx then
            love.graphics.setColor(0, 1, 0, 1) -- green
            VDraw.arrowWithLabel(rx, ry, rvx, rvy, string.format("%.0f g total", total_m), {0,1,0,1}, 0)
        end
    end
    ui:endCanvas() -- end canvas and clear clip

    -- CG HUD is drawn by the UI
    if ui then ui:draw() end
end

function love.keypressed(key)
    if ui then ui:keypressed(key) end
end

function love.mousepressed(mx, my, button)
    if ui then ui:mousepressed(mx, my, button) end
end

function love.mousemoved(mx, my, dx, dy)
    if ui then ui:mousemoved(mx, my, dx, dy) end
end

function love.resize()
    if ui then ui:resize() end
end
