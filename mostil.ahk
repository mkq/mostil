#Requires AutoHotkey v2
#ErrorStdOut UTF-8
#Warn All, StdOut
#SingleInstance force
traySetIcon("shell32.dll", 251)
setTitleMatchMode("RegEx")
#include %A_ScriptDir%/lib/util.ahk
#include %A_ScriptDir%/lib/configuration.ahk
#include %A_ScriptDir%/lib/cmd-comment.ahk
#include %A_ScriptDir%/lib/cmd-place-window.ahk
#include %A_ScriptDir%/lib/cmd-resize-split.ahk
#include %A_ScriptDir%/mostil.ahk.conf

; TODO
; - allow nesting like a real tiling window manager (a screen can have a parent tile instead of fixed x, y, w, h)
; - allow screen to have an input key ("maximize" shortcut without moving the split to 0% or 100%)
; - for maximizing only: allow a screen without tiles, but with an input key
; - refactor main script into a function and make the config script the main script?
; - configurable size how many pixels or percent a window should overlap the split
; - configurable max. number of windows to activate when undoing FocusWindowCommand
; - Add configurable command separator char? That would e.g. enable multiple focus commands even if a placeWindow input starts
;   with a char equal to a tile.
; - If any own window is activated, activate the one with input instead.
; - ResizeSplitCommand: Update a tile's window position only if it is still roughly (configurable) at tile position.
; - new command to close a window
; - new command to activate previously active window; example command strings if this is bound to "^":
;   - "en^" => select window "e", move it to tile "n", focus back.
;   - "e^" => select window "e", focus back. => Can be used to bring window "e" to z-order 2.
; - new sleep command (e.g. bound to "^^") with optional number of seconds.
;   Example combination with activate previously active window command:
;   - "e^3^" => select window "e", wait 3s, focus back. => Can be used to briefly check a window.

DEBUG_OUTPUT := true ; later overwritten with configured value

; ____________________________________ init
gl := {} ; instead of most global variables; TODO completely avoid globals
SHORT_PROGRAM_NAME := "Mostil"
LONG_PROGRAM_NAME := SHORT_PROGRAM_NAME " - Mostly tiling window layout manager"
PAD_X := 5
PAD_Y := 5

init() {
	printDebug("init")
	c := Configuration(config)
	gl.commandParsers := c.commandParsers
	gl.screensManager := c.screensManager
	gl.closeOnFocusLostAllowed := true
	gl.defaultInputs := []
	global DEBUG_OUTPUT := c.debug
	onMessage(0x6, (wp, lp, msg, hwnd) => ; WM_ACTIVATE
		(c.closeOnFocusLost && gl.closeOnFocusLostAllowed && !wp && gl.screensManager.containsWindowId(hwnd))
			? cancel('focus lost') : 1)

	hotkey(c.hotkey, hk => gl.screensManager.show())
	gl.pendingCommandParseResults := []
	gl.submittable := true
}
init()

; ____________________________________ core logic

submit() {
	printDebug("submit")
	if (!gl.submittable) {
		return
	}
	gl.screensManager.hide()

	while gl.pendingCommandParseResults.length > 0 {
		cpr := gl.pendingCommandParseResults.removeAt(1)
		printDebug("submit {}", cpr)
		cpr.command.submit()
	}

	input := gl.screensManager.screenWithInput.gui.input
	cmdStr := normalizeCommandString(input.value)
	gl.defaultInputs := moveToOrInsertAt0(gl.defaultInputs, cmdStr)
	input.delete()
	input.add(gl.defaultInputs)
}

cancel(reasonMessage) {
	printDebug('cancel("{}")', reasonMessage)
	while gl.pendingCommandParseResults.length > 0 {
		cpr := gl.pendingCommandParseResults.removeAt(-1)
		printDebug("undo {}", cpr)
		cpr.command.undo()
	}
	gl.screensManager.screenWithInput.gui.input.value := ""
	gl.screensManager.hide()
}

onValueChange(srcControl, *) {
	cmdStr := gl.screensManager.screenWithInput.gui.input.text
	printDebug('__________ onValueChange("{}") __________', cmdStr)
	newCommandPRs := parseCommands(cmdStr)
	try {
		handleCommandChange(newCommandPRs)
	} finally {
		gl.pendingCommandParseResults := newCommandPRs
	}
}

handleCommandChange(commandParseResults) {
	printDebug("handleCommandChange")
	diffIndex := findDiffIndex(gl.pendingCommandParseResults, commandParseResults, (a, b) => a.input == b.input)
	if (diffIndex == 0) {
		return
	}

	global closeOnFocusLostAllowed := false
	try {
		; undo pendingCommandParseResults which are not in commandParseResults:
		loop gl.pendingCommandParseResults.length - diffIndex + 1 {
			cpr := gl.pendingCommandParseResults.removeAt(-1)
			printDebug("undo {}", cpr)
			cpr.command.undo()
		}

		; execute new commands:
		i := diffIndex
		while (i <= commandParseResults.length) {
			cpr := commandParseResults[i++]
			printDebug("executePreview {}", cpr)
			cpr.command.executePreview()
		}
	} finally {
		closeOnFocusLostAllowed := true
	}
}

parseCommands(cmdStr) {
	global submittable := true
	gl.screensManager.screenWithInput.gui.statusBar.setText("")
	cprs := []
	i := 1, len := strlen(cmdStr)
	while (i <= len) {
		prevLength := cprs.length
		prevI := i
		for (p in gl.commandParsers) {
			if (p.parse(cmdStr, &i, cprs)) { ; p parsed something at i; continue with 1st parser at (already incremented) index
				printDebug("parsed `"{}`" (next index {} → {}) into {} commands. ⇒ All commands:",
					cmdStr, prevI, i, cprs.length - prevLength)
				arrayMap(cprs, cpr => printDebug("- {}", cpr))
				break
			}
		}
		if (prevLength == cprs.length) {
			global submittable := false
			gl.screensManager.screenWithInput.gui.statusBar.setText(format("Invalid or incomplete input starting at index {}: {}", prevI - 1, substr(cmdStr, i)))
			break
		}
	}
	return cprs
}

normalizeCommandString(cmdStr) {
	; TODO
	return cmdStr " [" A_NOW "]"
}
