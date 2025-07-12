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

class Mostil {
	; ____________________________________ init
	static SHORT_PROGRAM_NAME := "Mostil"
	static LONG_PROGRAM_NAME := Mostil.SHORT_PROGRAM_NAME " - Mostly tiling window layout manager"
	static PAD_X := 5
	static PAD_Y := 5

	; Starts the app and returns a function which shows the GUI, intended to be called by a hotkey.
	; Example: hotkey("!f5", Mostil.start({ … }))
	static start(config) {
		app := Mostil(config)
		return (*) => app.screensManager.show(app)
	}

	__new(config) {
		Util.printDebugF('{}.__new({})', () => [type(this), Util.dump(config)])
		c := Configuration(config)
		this.commandParsers := c.commandParsers
		this.screensManager := c.screensManager
		this.closeOnFocusLostAllowed := true
		this.defaultInputs := []
		Util.DEBUG_OUTPUT := c.debug
		onMessage(0x6, (wp, lp, msg, hwnd) => ; WM_ACTIVATE
			(c.closeOnFocusLost && this.closeOnFocusLostAllowed && !wp && this.screensManager.containsWindowId(hwnd))
				? this.cancel('focus lost') : 1)
		this.errorHandler := msg => this.screensManager.screenWithInput.gui.statusBar.setText(msg)

		this.pendingCommandParseResults := []
		this.submittable := true
	}

	; ____________________________________ core logic

	submit() {
		Util.printDebug("submit")
		if (!this.submittable) {
			return
		}
		this.screensManager.hide()

		while this.pendingCommandParseResults.length > 0 {
			cpr := this.pendingCommandParseResults.removeAt(1)
			Util.printDebug("submit {}", cpr)
			cpr.command.submit(this.errorHandler)
		}

		input := this.screensManager.screenWithInput.gui.input
		cmdStr := this.normalizeCommandString(input.value)
		this.defaultInputs := Util.moveToOrInsertAt0(this.defaultInputs, cmdStr)
		input.delete()
		input.add(this.defaultInputs)
	}

	cancel(reasonMessage) {
		Util.printDebug('cancel("{}")', reasonMessage)
		while this.pendingCommandParseResults.length > 0 {
			cpr := this.pendingCommandParseResults.removeAt(-1)
			Util.printDebug("undo {}", cpr)
			cpr.command.undo(this.errorHandler)
		}
		this.screensManager.screenWithInput.gui.input.value := ""
		this.screensManager.hide()
	}

	onValueChange() {
		cmdStr := this.screensManager.screenWithInput.gui.input.text
		Util.printDebug('__________ onValueChange("{}") __________', cmdStr)
		newCommandPRs := this.parseCommands(cmdStr)
		try {
			this.handleCommandChange(newCommandPRs)
		} finally {
			this.pendingCommandParseResults := newCommandPRs
		}
	}

	; TODO (Bug) Do not replace uncommitted Command instances with new ones, because it breaks undo.
	; Example:
	; - input: "-t" ⇒ instance 1, executePreview 1
	; - input: "t" ⇒ "-tt" ⇒ instances [2, 3], executePreview 3
	; - input: Backspace ⇒ "-t" ⇒ instance 4, undoes 3
	; - input: Backspace ⇒ "-" ⇒ creates none, unparsed input "-", undoes 4
	; So, 1 and 3 store undo data, but 3 and 4 are undone.
	handleCommandChange(commandParseResults) {
		Util.printDebug("handleCommandChange")
		diffIndex := Util.findDiffIndex(this.pendingCommandParseResults, commandParseResults, (a, b) => a.input == b.input)
		if (diffIndex == 0) {
			return
		}

		global closeOnFocusLostAllowed := false
		try {
			; undo pendingCommandParseResults which are not in commandParseResults:
			loop this.pendingCommandParseResults.length - diffIndex + 1 {
				cpr := this.pendingCommandParseResults.removeAt(-1)
				Util.printDebug("undo {}", cpr)
				cpr.command.undo(this.errorHandler)
			}

			; execute new commands:
			i := diffIndex
			while (i <= commandParseResults.length) {
				cpr := commandParseResults[i++]
				Util.printDebug("executePreview {}", cpr)
				cpr.command.executePreview(this.errorHandler)
			}
		} finally {
			closeOnFocusLostAllowed := true
		}
	}

	parseCommands(cmdStr) {
		global submittable := true
		this.screensManager.screenWithInput.gui.statusBar.setText("")
		cprs := []
		i := 1, len := strlen(cmdStr)
		while (i <= len) {
			prevLength := cprs.length
			prevI := i
			for (p in this.commandParsers) {
				if (p.parse(cmdStr, this.pendingCommandParseResults, &i, cprs)) { ; p parsed something at i; continue with 1st parser at (already incremented) index
					Util.printDebug("parsed `"{}`" (next index {} → {}) into {} commands. ⇒ All commands:",
						cmdStr, prevI, i, cprs.length - prevLength)
					Util.arrayMap(cprs, cpr => Util.printDebug("- {}", cpr))
					break
				}
			}
			if (prevI == i) {
				global submittable := false
				msg := format("Invalid or incomplete input starting at index {}: {}", prevI - 1, substr(cmdStr, i))
				Util.printDebug(msg)
				this.screensManager.screenWithInput.gui.statusBar.setText(msg)
				break
			}
		}
		return cprs
	}

	normalizeCommandString(cmdStr) {
		; TODO
		return cmdStr " [" A_NOW "]"
	}
}
