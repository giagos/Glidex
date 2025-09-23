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

    love.graphics.setColor(1, 1, 1, 1) -- white
    love.graphics.print(message, 20, 20)
    love.graphics.print(string.format("App: %s | Version: %s", config.appName, config.version), 20, 40)

    -- Auto-adjust ballast to meet CG target when both visible
    if body and handler then
        AutoBalance.apply(body, handler)
    end

    -- Draw the body as a filled rectangle with outline
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

    -- Bottom-left CG readout (in cm from the nose)
    do
        local w, h = love.graphics.getDimensions()
        love.graphics.setColor(1, 1, 1, 1)
        local text = "CG: N/A"
        if body then
            local pts = (handler and handler.points) or {}
            local com_left_cm, total_m = VCalc.centerOfMassFromLeft(body, pts)
            if (total_m or 0) > 0 then
                text = string.format("CG: %.1f cm from nose (left)", com_left_cm)
            end
        end
        love.graphics.print(text, 16, h - 24)
    end
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
