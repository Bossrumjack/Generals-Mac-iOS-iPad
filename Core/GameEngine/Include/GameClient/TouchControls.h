/*
**	Touch control overlay for the iOS port.
**
**	Two on-screen affordances a keyboard-less device needs:
**	  - a visible camera joystick pad (lower-left), and
**	  - a "select all units on screen" button (top-left).
**
**	Geometry lives in TheDisplay's game-internal pixel space, so the overlay is
**	drawn INSIDE the pillarbox/safe-area blit automatically (clear of the notch /
**	Dynamic Island / rounded corners). The SDL3 touch handler converts each touch
**	into that same game space before hit-testing, so what you see and what you
**	press always line up. Everything no-ops on non-touch builds.
*/

#pragma once

#include "Lib/BaseType.h"

/// Draw the joystick pad and the select-all button. Call once per frame from the
/// in-game UI render pass.
void TouchOverlay_Draw(void);

/// Hit-test a point given in GAME-INTERNAL pixel coords.
/// Returns 0 = joystick pad, 1 = select-all button, -1 = neither.
Int TouchOverlay_HitTest(Int gameX, Int gameY);

/// Update the joystick thumb indicator (game-internal coords) for drawing.
void TouchOverlay_SetThumb(Bool active, Int gameX, Int gameY);

/// Select every unit currently on screen (as the keyboard select-all would).
void TouchOverlay_SelectAll(void);
