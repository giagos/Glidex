# Glidex

Daedalus Dream Works Glidex is a tiny LÖVE (love2d) app to help free-flight and RC builders calculate center of gravity (CG) from component weights and arms (distance from a chosen datum like the nose).

## What’s included

- `main.lua` – app entry point (draw loop and wiring)
- `codee/maing_body.lua` – main rectangular body (side view) with transforms
- `codee/body_handler.lua` – point-mass manager and CG-style icon drawing
- `codee/ui.lua` – right-side UI: edit body and masses, numeric input
- `codee/config.lua` – basic app config
- `functions/` – reserved (empty)

## Install and run (Windows)

1) Install LÖVE
- Download LÖVE for Windows from https://love2d.org
- Install it (default options are fine)

2) Run this project
- Option A: Drag the project folder `Glidex` onto the LÖVE shortcut
- Option B: Right-click the folder, choose “Open with” -> LÖVE
- Option C (PowerShell):

```powershell
& "C:\Program Files\LOVE\love.exe" "d:\Glidex"
```

If your install path differs, adjust the `love.exe` path accordingly.

## How to use

Units and frames
- Lengths are in centimeters (cm), masses in grams (g), angles in degrees (deg).
- Nose-at-right convention: the nose is the right end; distance increases to the LEFT from the nose.
- The main body is centered on screen; edits keep it centered.

Body (rectangle) controls
- Press keys to select a field, type a number, press Enter to apply:
	- L: Length (cm)
	- T: Thickness (cm)
	- M: Mass (g)
	- A: Angle (deg)

Point masses (CG markers)
- List appears on the right panel. Click a row (or the icon on canvas) to select.
- Edit selected mass:
	- D: distance from nose (cm)
	- M: mass (g)
- Manage masses: `+` to add (100 g at distance=0), `-` to remove selected
- Drag the selected mass horizontally on the canvas; position clamps to [0 .. body length].

Icon style
- Each point mass is drawn as a CG-style circle split by vertical and horizontal lines:
	- Top-right and bottom-left quadrants are black
	- Top-left and bottom-right quadrants are white
- Icon size scales linearly with mass; larger masses draw larger icons.

## Notes

- No file save/load yet.
- Depth (cm) exists for completeness but isn’t shown in pure side view.
- Default scale is 1 cm = 3 px; this only affects drawing, not units.

