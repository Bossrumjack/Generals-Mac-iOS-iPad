/*
**	Touch control overlays for the iOS port.
**
**	The team (control-group) bar: a row of numbered buttons drawn along the top
**	of the screen so a keyboard-less device can create and recall hotkey squads.
**	Tap a button to select that team; long-press to assign the current selection
**	to it — the same MSG_SELECT_TEAMn / MSG_CREATE_TEAMn the number keys emit.
**
**	Drawing lives in InGameUI::postDraw (render pass); hit-testing is called from
**	the SDL3 touch handler (input pass). Both share the geometry below. Every
**	function is a no-op on non-touch builds, so desktop behaviour is unchanged.
*/

#pragma once

#include "Lib/BaseType.h"

/// Draw the team bar. Call once per frame from the in-game UI render pass.
void TouchTeamBar_Draw(void);

/// Return the team button (0..9) under a touch point given in NORMALIZED window
/// coordinates (0..1, i.e. SDL's tfinger.x/y), or -1 if the point is not on the
/// bar. Normalized input keeps the test resolution-independent: it is converted
/// against the same TheDisplay basis the bar is drawn in, so window-vs-internal
/// scaling never desyncs the buttons from the touches.
Int TouchTeamBar_HitTest(Real normX, Real normY);

/// Recall a hotkey squad (as pressing the number key would).
void TouchTeamBar_Select(Int team);

/// Assign the current selection to a hotkey squad (as CTRL+number would).
void TouchTeamBar_Assign(Int team);
