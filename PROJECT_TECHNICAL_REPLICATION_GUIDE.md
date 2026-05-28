# Glidex: Full Technical Replication Guide

## 1) Purpose and Product Definition

Glidex is a 2D visual mass-balance tool for aircraft fuselage planning, focused on longitudinal center-of-gravity (CG) behavior.

What the program does:
- Lets the user define a fuselage body (length, thickness, angle, mass or g/cm).
- Lets the user add and edit point masses (normal mass, ballast, and CG target markers).
- Calculates and displays center of mass in 1D along fuselage length.
- Draws gravity vectors for each component and a resultant vector at combined CG.
- Provides a retro desktop-style inspector UI and setup/settings modals.

What it does not do:
- It does not solve aerodynamics (no neutral point, static margin, lift, stability derivatives).
- It does not persist project files; only UI settings are persisted.


## 2) Runtime, Stack, and Entry Point

Technology stack:
- Language: Lua
- Runtime/engine: LÖVE (Love2D)
- Main entry point: main.lua

Startup sequence:
1. main.lua sets window title using app name and version.
2. Sets black background.
3. Creates Body object with zeroed dimensions/mass.
4. Sets body scale to 3 px/cm.
5. Creates BodyHandler with the body reference.
6. Creates UI with handler + body.
7. Opens setup modal at startup and centers body.

Main loop behavior:
- love.update(dt): forwards to UI update.
- love.draw():
  - If setup modal is visible, draws UI only and exits early.
  - Otherwise:
    - Runs auto-balance (if target + ballast exist and are visible).
    - Opens drawing canvas region.
    - Centers body in canvas rectangle.
    - Draws body.
    - Draws all point masses and their vectors.
    - Draws resultant gravity vector at global COM.
    - Closes canvas.
    - Draws full UI overlays and HUD.

Input forwarding:
- love.keypressed, love.mousepressed, love.mousemoved, love.resize all forward to UI methods.


## 3) Repository Structure and Responsibilities

Core files:
- main.lua: application bootstrap + frame orchestration.
- codee/config.lua: app metadata and debug flag.
- codee/maing_body.lua: fuselage geometry, transform math, rendering.
- codee/body_handler.lua: point-mass collection management + per-point render.
- codee/vector_calc.lua: COM and vector math.
- codee/vector_draw.lua: arrow drawing utility.
- codee/autobalance.lua: solver that adjusts ballast mass to hit target CG.
- codee/ui.lua: main UI controller, interaction state, rendering, hit maps.
- codee/ui_elemets/*: reusable UI primitives and section renderers.

UI section files:
- codee/ui_elemets/sections/setup_modal.lua: fuselage setup dialog.
- codee/ui_elemets/sections/settings_modal.lua: preferences dialog.
- codee/ui_elemets/sections/hud.lua: bottom-left CG readout.

Utilities:
- codee/vector.lua: general-purpose 2D vector utility library.
- codee/ui_elemets.lua and codee/ui_elemets/init.lua: module aggregation APIs.


## 4) Data Model and Units

Global coordinate convention:
- Nose is on the right side of body.
- Positive fuselage distance increases leftward from nose.
- Distances are in cm.
- Masses are in g.
- Angles are in degrees in UI, stored in radians inside body object.

Body object fields:
- length_cm, depth_cm, thickness_cm, mass_g
- color
- scale (px per cm)
- origin_x, origin_y (nose position in world pixels)
- angle (radians)
- optional g_per_cm (derived-mode mass density)

Point mass fields:
- id
- name
- mass_g
- distance_cm
- color
- kind: mass, ballast, or target

Important semantic rules:
- target points are markers and are excluded from mass/COM calculations.
- ballast may be negative when user edits mass directly.
- body mass contributes at geometric center length_cm/2.


## 5) Math and Algorithms

### 5.1 Center of Mass

The implementation computes COM along one axis (fuselage axis):

CG_from_nose = sum(m_i * d_i) / sum(m_i)

Where:
- m_i includes non-target point masses and body mass.
- d_i is distance from nose, in cm.
- body contributes as m_body at d = length_cm * 0.5.

A converted value is also reported as "from left" by:

CG_from_left = body_length - CG_from_nose

### 5.2 Adaptive Vector Scale

The code chooses a scale so the largest visible mass vector has readable length:
- Finds max visible mass magnitude among non-target points.
- Chooses target pixel length based on viewport min dimension, clamped roughly to 100..220 px.
- scale = targetMaxPx / visibleMaxMass
- If nothing visible, fallback to overall max mass; final fallback constant around 0.12.

### 5.3 Resultant Gravity Vector

Resultant is drawn at global COM position, but vector length is fixed to target max length for readability, not proportional to total mass. Label still reports total mass.

### 5.4 Auto-balance Solver

When both a target and a ballast are present and both icons are on-screen:
- Solve ballast mass m_b such that global COM equals target location u_t.
- Let ballast location be u_b.
- Let M0 and S0 be total mass and moment of all non-adjustable non-target masses (including body).

From
u_t = (S0 + m_b * u_b) / (M0 + m_b)

the solver computes
m_b = (u_t * M0 - S0) / (u_b - u_t)

Edge case:
- If u_b equals u_t, denominator is near zero, so solver does nothing.


## 6) Transform and Rendering Model

Body local frame:
- Local u axis increases leftward from nose.
- Local v axis increases upward.

World transform:
- localToWorld(u, v):
  - convert cm to px
  - map to screen basis with inverted directions to match convention
  - apply rotation by body angle
  - offset by body origin

Inverse transform:
- worldToLocal(x, y):
  - subtract origin
  - rotate by negative body angle
  - invert x/y signs according to convention
  - divide by scale

Body drawing:
- Rectangle drawn from nose-origin toward left by width = length_cm * scale.
- Height = thickness_cm * scale (min 1 px).
- Draws filled body + 1 px outline.

Point drawing:
- Each point drawn as CG-style circular icon (quadrant pattern + cross).
- Radius scales with mass, clamped between min and max.
- Ballast gets yellow ring, target gets green ring.
- Non-target points receive downward gravity arrow + text label.


## 7) UI Architecture and Interaction Style

Visual style:
- Retro desktop aesthetic.
- Light gray window panels with hard outlines.
- Monochrome high-contrast text, black background canvas.
- Functional and technical, not decorative.

UI composition:
- Top ribbon with Preferences menu.
- Fuselage Setup button below ribbon on left.
- Canvas area on left/middle (borderless or windowed mode with toggle icon).
- Inspector panel on right (expand/collapse with animated side tab).
- Modal dialogs for Setup and Settings.
- Persistent CG HUD at bottom-left.

Hit-map design:
- Hit boxes are rebuilt every frame in ui.hit tables.
- Separate maps for setup fields, settings controls, selection fields, and component rows.
- Circular hit test used for icon drag start.

Modal priority rules:
- Setup modal captures keyboard interaction first.
- Settings modal captures keyboard/mouse while open.
- Escape closes active modal and clears edit context.

Selection and editing model:
- Single selected component index.
- Editing modes: mass, distance, setup fields, settings fields.
- Numeric input uses typed buffer string and live-apply behavior.
- Enter commits and exits current edit mode.

Keyboard controls:
- Tab/up/down cycles selected component or modal field.
- D edits selected distance.
- M edits selected mass.
- + adds standard mass point.
- B adds ballast point.
- G adds target point.
- - removes selected point.
- Setup modal shortcuts: L, T, W, A, G.

Mouse controls:
- Click component row to select.
- Click numeric subregions to start direct field editing.
- Drag selected icon horizontally to change distance.
- Click side arrow to collapse/expand inspector panel.
- Click top Preferences label to open dropdown.


## 8) State Persistence

The app writes only UI settings to settings.ini in LÖVE writable storage.

Persisted keys:
- panelWidthFrac
- fontSize
- uiScalePerc
- fullscreen
- windowW
- windowH
- resIndex

Loaded on UI init, then applied by window mode and font refresh.

No project data persistence exists for bodies/components.


## 9) Replication Blueprint (Build from Scratch)

### 9.1 Engine Setup

1. Install LÖVE.
2. Create a project root with main.lua.
3. Set main callbacks: load, update, draw, keypressed, mousepressed, mousemoved, resize.

### 9.2 Core Domain Layer

Implement modules in this order:
1. Body module
  - fields and constructor
  - setScale, setAngleDegrees/getAngleDegrees
  - localToWorld/worldToLocal
  - centerAt and draw
2. Vector calculation module
  - centerOfMass
  - centerOfMassFromLeft
  - adaptiveGravityScale
  - resultantGravityVector
3. Vector drawing utility
  - arrow + label
4. BodyHandler
  - points list management
  - icon rendering and per-point vectors
5. AutoBalance
  - ballast solve and apply function

Validation checkpoint:
- Render body and one mass point.
- Confirm drag changes distance and COM output moves correctly.

### 9.3 UI Framework Layer

Implement shared primitives:
- truncate
- labelClipped
- button
- beginWindow/endWindow
- hit helpers
- layout helper
- fillbar helper

Then implement UI controller:
- Internal state for selected index, edit mode, modal toggles, settings.
- Dynamic layout calculations for top bar/canvas/panel.
- Full draw pipeline:
  - ribbon/menu
  - setup button
  - panel + rows + selection section
  - modal sections
  - HUD
- Mouse and keyboard input routing with modal-first precedence.
- Frame-by-frame hit map rebuild.

Validation checkpoint:
- Can select rows, edit values, and drag icons.
- Panel collapse animation works.
- Menu and settings modal open/close correctly.

### 9.4 Modal Sections

Setup modal:
- Dim backdrop, center dialog.
- Show length/thickness/mass/angle/g per cm.
- If g_per_cm set, mass line is computed and non-editable.
- Live apply values while typing.

Settings modal:
- Resolution selector.
- Fullscreen toggle.
- UI scale slider.
- Panel width and font-size fields.
- Save on changes.

HUD section:
- Bottom-left compact window showing CG from nose-left wording.

### 9.5 Main Integration

In main draw:
- If setup modal open: draw UI only and return.
- Otherwise:
  - auto-balance
  - begin canvas
  - center body in canvas
  - draw body and points
  - draw resultant vector
  - end canvas
  - draw UI overlays

Validation checkpoint:
- Target + ballast causes automatic ballast mass solve when visible.
- Resultant vector appears at COM and scales as expected.


## 10) Functional Specification Summary

Minimum behavior for equivalent clone:
- Body setup with cm/g/deg inputs.
- Multiple component points with kinds.
- Real-time COM calculations excluding target points.
- Drag-and-edit workflow for component distances.
- Inspector list with per-row editable mass and distance.
- Visual vectors per component and global resultant vector.
- Auto-balancing ballast solver toward target marker.
- Settings persistence and configurable display/layout.


## 11) Known Technical Characteristics and Tradeoffs

- COM model is intentionally 1D; vertical and lateral CG are not modeled.
- Resultant vector length is readability-normalized, not physically scaled by total force.
- Auto-balance executes every frame when target and ballast are both visible.
- Project-state save/load is not present, so scenarios must be recreated manually each run.


## 12) Run and Packaging

Run locally:
- Launch project folder with LÖVE executable.

Expected runtime files:
- main.lua
- codee folder modules
- optional README images for documentation only

Packaging path for distribution:
- Standard LÖVE packaging methods can be used once code is stable.


## 13) Suggested Next Replication Improvements

If you want a stronger second-generation clone:
- Add JSON project save/load for body + points.
- Add units profile system and validation constraints.
- Add deterministic scenario tests for COM and ballast solver.
- Add static margin helper inputs (NP and MAC) as optional overlay.
- Add profile presets for typical RC/UAV fuselage classes.


## 14) File Map for Fast Navigation

- main.lua: runtime lifecycle and draw orchestration.
- codee/maing_body.lua: body geometry and transforms.
- codee/body_handler.lua: point model and icon/vector rendering.
- codee/vector_calc.lua: COM and vector scaling math.
- codee/autobalance.lua: target ballast equation solve.
- codee/ui.lua: complete UI state machine and interaction routing.
- codee/ui_elemets/sections/setup_modal.lua: setup modal renderer.
- codee/ui_elemets/sections/settings_modal.lua: settings modal renderer.
- codee/ui_elemets/sections/hud.lua: CG HUD renderer.

This guide contains enough implementation detail to reproduce the program architecture and behavior with the same runtime model and interaction style.