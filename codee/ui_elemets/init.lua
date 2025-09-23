local M = {}

-- Forward load submodules
M.truncate = require('codee.ui_elemets.truncate').truncate
M.labelClipped = require('codee.ui_elemets.label').labelClipped
M.button = require('codee.ui_elemets.button').button
M.beginWindow = require('codee.ui_elemets.window').beginWindow
M.endWindow = require('codee.ui_elemets.window').endWindow
M.relativeLuminance = require('codee.ui_elemets.colors').relativeLuminance
M.contrastColorFor = require('codee.ui_elemets.colors').contrastColorFor
M.maybeInvertColor = require('codee.ui_elemets.colors').maybeInvertColor
M.drawFillBar = require('codee.ui_elemets.fillbar').drawFillBar
M.layout = require('codee.ui_elemets.layout')
M.hit = require('codee.ui_elemets.hit')

return M
