#Requires AutoHotkey v2
setTitleMatchMode("RegEx")
#include %A_SCRIPTDIR%/lib/cmd.ahk
#include %A_SCRIPTDIR%/lib/cmd-comment.ahk
#include %A_SCRIPTDIR%/lib/cmd-place-window.ahk
#include %A_SCRIPTDIR%/lib/cmd-resize-split.ahk
#include %A_SCRIPTDIR%/lib/configuration.ahk
#include %A_SCRIPTDIR%/lib/icon.ahk
#include %A_SCRIPTDIR%/lib/screen.ahk
#include %A_SCRIPTDIR%/lib/util.ahk
#include %A_SCRIPTDIR%/lib/window-util.ahk

; TODO
; - allow nesting like a real tiling window manager (a screen can have a parent tile instead of fixed x, y, w, h)
; - allow screen to have an input key ("maximize" shortcut without moving the split to 0% or 100%)
; - for maximizing only: allow a screen without tiles, but with an input key
; - configurable size how many pixels or percent a window should overlap the split
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

class Mostil {
	; Starts the app and returns a function which shows the GUI, intended to be called by a hotkey.
	; Example: hotkey("!f5", Mostil.start({ … }))
	static start(config) {
		app := Mostil(config)
		return (*) => app.screensManager.show(app, msg => app.handleError_(msg))
	}

	__new(config) {
		Util.printDebugF('{}.__new({})', () => [type(this), Util.dump(config)])
		this.name := "Mostil - Mostly tiling window layout manager"
		c := Configuration(config)
		this.commandParsers := c.commandParsers
		this.screensManager := c.screensManager
		this.closeOnFocusLostAllowed := true
		this.defaultInputs := []
		Util.DEBUG_OUTPUT := c.debug
		if (c.closeOnFocusLost) {
			onMessage(0x6, (wp, lp, msg, hwnd) => ; WM_ACTIVATE
				this.closeOnFocusLostAllowed && !wp && this.screensManager.containsWindowId(hwnd)
					? this.cancel('focus lost') : 1)
		}

		this.commandParseResults := []
		this.submittable := true
	}

	; ____________________________________ core logic

	submit() {
		Util.printDebug("submit")
		if (!this.submittable) {
			return
		}

		while this.commandParseResults.length > 0 {
			cpr := this.commandParseResults.removeAt(1)
			Util.printDebug("submit {}", cpr)
			cpr.command.submit(msg => this.handleError_(msg))
		}

		this.screensManager.hide()

		input := this.screensManager.screenWithInput.input
		cmdStr := this.normalizeCommandString(input.value)
		this.defaultInputs := Util.moveToOrInsertAt0(this.defaultInputs, cmdStr)
		input.delete()
		input.add(this.defaultInputs)
	}

	cancel(reasonMessage) {
		Util.printDebug('cancel("{}")', reasonMessage)
		while this.commandParseResults.length > 0 {
			cpr := this.commandParseResults.removeAt(-1)
			Util.printDebug("undo {}", cpr)
			cpr.command.undo(msg => this.handleError_(msg))
		}
		this.screensManager.screenWithInput.input.value := ''
		this.screensManager.hide()
	}

	onValueChange() {
		cmdStr := this.screensManager.screenWithInput.input.text
		Util.printDebug('__________ onValueChange: "{}" __________', cmdStr)
		global closeOnFocusLostAllowed := false
		try {
			this.onValueChange_(cmdStr)
		} finally {
			closeOnFocusLostAllowed := true
		}
	}

	onValueChange_(cmdStr) {
		newCPRs := this.parseCommands(cmdStr)
		diffIndex := Util.findDiffIndex(this.commandParseResults, newCPRs, (a, b) => a.input == b.input)
		Util.printDebug('diffIndex == {}', diffIndex)
		if (diffIndex == 0) {
			return
		}

		; undo commandParseResults which are not in newCPRs:
		loop this.commandParseResults.length - diffIndex + 1 {
			cpr := this.commandParseResults.removeAt(-1)
			Util.printDebug("undo {}", cpr)
			cpr.command.undo(msg => this.handleError_(msg))
		}

		; executePreview and store new commands:
		i := diffIndex
		while (i <= newCPRs.length) {
			cpr := newCPRs[i++]
			this.commandParseResults.push(cpr)
			Util.printDebug("executePreview {}", cpr)
			cpr.command.executePreview(this.screensManager, msg => this.handleError_(msg))
		}
		Util.printDebug('this.commandParseResults:')
		Util.arrayMap(this.commandParseResults, cpr => Util.printDebug("- {}", cpr))
	}

	parseCommands(cmdStr) {
		Util.checkType(String, cmdStr)
		global submittable := true
		this.setStatusBarText_('')
		cprs := []
		i := 1, len := strlen(cmdStr)
		while (i <= len) {
			prevLength := cprs.length
			prevI := i
			for (p in this.commandParsers) {
				if (p.parse(cmdStr, this.commandParseResults, &i, cprs)) { ; p parsed something at i; continue with 1st parser at (already incremented) index
					Util.printDebug("parsed `"{}`" part (next index {} → {}) into {} commands. ⇒ All commands:",
						cmdStr, prevI, i, cprs.length - prevLength)
					Util.arrayMap(cprs, cpr => Util.printDebug("- {}", cpr))
					break
				}
			}
			if (prevI == i) {
				global submittable := false
				msg := format("Invalid or incomplete input starting at index {}: {}", prevI - 1, substr(cmdStr, i))
				Util.printDebug(msg)
				this.handleError_(msg)
				break
			}
		}
		return cprs
	}

	normalizeCommandString(cmdStr) {
		; TODO
		return cmdStr " [" A_NOW "]"
	}

	handleError_(msg) {
		msg := String(msg)
		Util.printDebug('handleError("{}")', msg)
		this.setStatusBarText_(msg)
		Util.showTooltip(msg, 3000, 0, 0)
	}

	setStatusBarText_(text) {
		this.screensManager.screenWithInput.gui.statusBar.setText(text)
	}
}