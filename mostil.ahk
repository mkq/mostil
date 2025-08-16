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
; - implement normalizeCommandString for a clean command history in ComboBox drop-down.
;   For example, replace ResizeSplitCommands [left, right, right, right] with [right, right], but only if
;   that would not change the outcome. (I.e. the left one was not affected by the snap margin.)
; - allow nesting like a real tiling window manager (a screen can have a parent tile instead of fixed x, y, w, h)
; - allow screen to have an input key ("maximize" shortcut without moving the split to 0% or 100%)
; - for maximizing only: allow a screen without tiles, but with an input key
; - configurable size how many pixels or percent a window should overlap the split
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
		return (*) => app.show()
	}

	; private constructor
	; @see static start method
	__new(config) {
		Util.printDebugF('{}.__new({})', () => [type(this), Util.dump(config)])
		this.name := "Mostil - Mostly tiling window layout manager"
		c := Configuration(config)
		this.commandParsers := c.commandParsers
		this.screensManager := c.screensManager
		this.closeOnFocusLostAllowed := true
		this.defaultInputs := []
		Util.DEBUG_OUTPUT := c.debug

		this.commandParseResults := []
		this.submittable := true
		; 0x6: WM_ACTIVATE; wp: 0 = deactivated, 1 = activated, 2 = activated by mouse
		onMessage(0x6, (wp, lp, msg, windowId) => this.handleWmActivateMessage(wp, windowId, c.closeOnFocusLost))
	}

	show() {
		this.doWithCloseOnFocusLostDisallowed(() => this.screensManager.show(this, this.handleError_))
	}

	submit() {
		this.doWithCloseOnFocusLostDisallowed(() => this.submit_())
	}
	submit_() {
		Util.printDebug("submit")
		if (!this.submittable) {
			return
		}

		while this.commandParseResults.length > 0 {
			cpr := this.commandParseResults.removeAt(1)
			Util.printDebug("submit {}", cpr)
			cpr.command.submit(this.screensManager, msg => this.handleError_(msg))
		}

		input := this.screensManager.screenWithInput.input
		cmdStr := this.normalizeCommandString(input.text)
		this.defaultInputs := Util.moveToOrInsertAt0(this.defaultInputs, cmdStr)
		input.delete()
		input.add(this.defaultInputs)

		this.screensManager.hide()
	}

	cancel(reasonMessage) {
		Util.printDebug('cancel("{}")', reasonMessage)
		while this.commandParseResults.length > 0 {
			cpr := this.commandParseResults.removeAt(-1)
			Util.printDebug("undo {}", cpr)
			cpr.command.undo(this.screensManager, msg => this.handleError_(msg))
		}
		this.screensManager.screenWithInput.input.text := ''
		this.screensManager.hide()
	}

	handleWmActivateMessage(activated, windowId, closeOnFocusLost) {
		Util.printDebug('handleWmActivateMessage({}, {}, {})', activated, windowId, closeOnFocusLost)
		inputGui := this.screensManager.screenWithInput.gui.gui
		if (!inputGui) {
			return 1
		}

		; If any of our windows is activated, activate the one with input instead.
		if (activated && this.screensManager.containsWindowId(windowId) && windowId != inputGui.hwnd) {
			Util.printDebug('switching focus from {} to {}', windowId, inputGui.hwnd)
			winActivate(inputGui)
			return 0
		}

		if (closeOnFocusLost) {
			activeWindowId := winExist('A')
			isOtherWindow := !this.screensManager.containsWindowId(activeWindowId)
			Util.printDebug('checking focus lost: allowed: {}, deactivated: {}, activeWindowId: {}, isOtherWindow: {}',
				this.closeOnFocusLostAllowed, !activated, activeWindowId, isOtherWindow)
			if (this.closeOnFocusLostAllowed && !activated && isOtherWindow) {
				this.cancel('focus lost')
				return 0
			}
		}

		Util.printDebug('handleWmActivateMessage: not handled')
		return 1
	}

	onValueChange() {
		this.closeOnFocusLostAllowed := false
		try {
			this.onValueChange_()
		} finally {
			this.closeOnFocusLostAllowed := true
		}
	}

	onValueChange_() {
		cmdStr := this.screensManager.screenWithInput.input.text
		Util.printDebug('__________ onValueChange_: "{}" __________', cmdStr)
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
			cpr.command.undo(this.screensManager, msg => this.handleError_(msg))
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
		this.submittable := true
		this.setStatusBarText_('')
		cprs := []
		i := 1, len := strlen(cmdStr)
		while (i <= len) {
			prevLength := cprs.length
			prevI := i
			for (p in this.commandParsers) {
				if (p.parse(cmdStr, &i, cprs)) { ; p parsed something at i; continue with 1st parser at (already incremented) index
					Util.printDebug("parsed `"{}`" part (next index {} → {}) into {} commands. ⇒ All commands:",
						cmdStr, prevI, i, cprs.length - prevLength)
					Util.arrayMap(cprs, cpr => Util.printDebug("- {}", cpr))
					break
				}
			}
			if (prevI == i) {
				this.submittable := false
				msg := format("Invalid or incomplete input starting at index {}: {}", prevI - 1, substr(cmdStr, i))
				Util.printDebug(msg)
				this.handleError_(msg)
				break
			}
		}
		return cprs
	}

	normalizeCommandString(cmdStr) {
		return cmdStr
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

	doWithCloseOnFocusLostDisallowed(f) {
		oldValue := this.closeOnFocusLostAllowed
		this.closeOnFocusLostAllowed := false
		try {
			f()
		} finally {
			this.closeOnFocusLostAllowed := oldValue
		}
	}

}