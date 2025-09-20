---@diagnostic disable: undefined-global
local config = require("codee.config")
local Body = require("codee.maing_body")
local BodyHandler = require("codee.body_handler")
local UI = require("codee.ui")

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
        length_cm = 120,    -- x dimension (cm)
        depth_cm = 30,      -- not drawn in pure side view, kept for physics
        thickness_cm = 5,   -- y dimension (cm)
        mass_g = 2500,
        color = {0.2, 0.6, 1.0},
        origin_x = 60,
        origin_y = 200,
        angle = 0,
    })
    body:setScale(3) -- 1 cm = 3 px

    handler = BodyHandler.new(body)
    handler:add({ name = "m1", mass_g = 200, distance_cm = 20 })
    ui = UI.new(handler, body)
    ui:centerBody()
end

function love.draw()
    love.graphics.setColor(1, 1, 1, 1) -- white
    love.graphics.print(message, 20, 20)
    love.graphics.print(string.format("App: %s | Version: %s", config.appName, config.version), 20, 40)

    -- Draw the body as a filled rectangle with outline
    if body then body:draw() end

    if handler then handler:draw() end
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
