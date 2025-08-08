#include %A_SCRIPTDIR%/lib/cmd.ahk
#include %A_SCRIPTDIR%/lib/util.ahk
#include %A_SCRIPTDIR%/lib/window-util.ahk
#include %A_SCRIPTDIR%/lib/icon.ahk

class PlaceWindowCommandParser extends CommandParser {
	static parseConfig(config, screensManager) {
		cmd := Util.getProp(config, "run", "")
		previewIcon := Util.getProp(config, "previewIcon", false)
		if (previewIcon) { ; parse previewIcon (format "[index]file" or just "file")
			previewIcon := regExMatch(previewIcon, '^\[(\d+)\](.+)', &match) ? { index: match[1], file: match[2] } : { file: previewIcon, index: 1 }
		} else if (strlen(cmd) > 0) { ; default previewIcon: 1st word of cmd
			previewIcon := { file: regExReplace(cmd, '\s.*', ''), index: 1 }
		} else {
			previewIcon := { file: "shell32.dll", index: 1 }
		}
		return PlaceWindowCommandParser(screensManager, config.input,
			Util.getProp(config, "name", ""), Util.getProp(config, "criteria"), previewIcon, cmd)
	}

	__new(screensManager, windowInput, name, criteria, defaultPreviewIcon, launchCmdStr := "") {
		this.screensManager := screensManager
		this.windowInput := windowInput
		this.name := name
		this.criteria := criteria
		this.defaultPreviewIcon := defaultPreviewIcon
		this.launchCmdStr := launchCmdStr
	}

	parse(cmdStr, &i, commandParseResults) {
		; TODO Do not accept window input if criteria match no existing window and launchCmdStr is empty
		if (!Util.skip(cmdStr, this.windowInput, &i)) {
			return super.parse(cmdStr, &i, commandParseResults)
		}
		focusCmd := FocusWindowCommand(this.name, this.criteria, this.launchCmdStr, this.screensManager)
		commandParseResults.push(CommandParseResult(this.windowInput, focusCmd))

		tileInput := ""
		t := this.parseTileParameter(cmdStr, this.screensManager, &i, &tileInput)
		if (t) {
			moveCmd := PlaceWindowCommand(t, this.name, this.criteria, this.launchCmdStr, this.defaultPreviewIcon, this.screensManager)
			commandParseResults.push(CommandParseResult(this.windowInput . tileInput, moveCmd))
		}
		return true
	}
}

class FocusWindowCommand extends Command {
	__new(name, criteria, launchCmdStr, screensManager) {
		super.__new()
		this.windowSpec := {
			name: name,
			criteria: criteria,
			launchCommand: launchCmdStr,
		}
		this.screensManager := screensManager
	}

	toString() {
		return format("{}({}, {})", super.toString(), this.windowSpec.name)
	}

	executePreview(screensMgr, errorHandler) {
	}

	static getWindowId_(criteria, screensMgr) {
		if (criteria) {
			windowId := winExist(criteria)
			Util.printDebug('window for {}: {}', criteria, windowId)
			return windowId
		} else { ; MRU mode
			return WindowUtil.getActiveOtherWindow(screensMgr)
		}
	}

	submit(screensMgr, errorHandler) {
		windowId := FocusWindowCommand.getWindowId_(this.windowSpec.criteria, this.screensManager)
		if (!windowId && this.windowSpec.launchCommand) {
			Util.printDebug('run: {}', this.windowSpec.launchCommand)
			run(this.windowSpec.launchCommand)
			Util.printDebug('waiting for window {}', this.windowSpec.criteria)
			windowId := winWait(this.windowSpec.criteria, , 20)
			Util.printDebug('winWait returned {}', windowId)
			if (!windowId) {
				errorHandler(format('WARN: running {} did not yield a window matching {}', this.windowSpec.launchCommand, this.windowSpec.criteria))
				return
			}
		}

		winActivate(windowId)
	}

	undo(screensMgr, errorHandler) {
	}
}

class PlaceWindowCommand extends Command {
	__new(selectedTile, name, criteria, launchCmdStr, defaultPreviewIcon, screensManager) {
		super.__new()
		this.selectedTile := selectedTile
		this.windowSpec := {
			name: name,
			criteria: criteria,
			launchCommand: launchCmdStr,
		}
		this.defaultPreviewIcon := defaultPreviewIcon
		this.screensManager := screensManager

		this.windowId := 0
		this.moveWindowUndoFunc := (*) => {}
	}

	toString() {
		return format("{}({}, {})", super.toString(), this.windowSpec.name, String(this.selectedTile))
	}

	executePreview(screensMgr, errorHandler) {
		this.windowId := FocusWindowCommand.getWindowId_(this.windowSpec.criteria, this.screensManager)
		tw := this.windowId ; selected window does not exist
			? Tile.Window(this.windowId,
				Icon.fromHandle(WindowUtil.getWindowIcon(this.windowId)),
				"window " this.windowId)
			: Tile.Window(0,
				Icon.fromFile(this.defaultPreviewIcon.file, this.defaultPreviewIcon.index),
				this.windowSpec.launchCommand " (pending launch)")
		this.moveWindowUndoFunc := screensMgr.moveWindowToTile(tw, this.selectedTile, errorHandler)
	}

	submit(screensMgr, errorHandler) {
		; window may have been created by FocusWindowCommand in the meantime
		if (!this.windowId) {
			this.undo(screensMgr, errorHandler)
			this.executePreview(screensMgr, errorHandler)
		}
		this.selectedTile.moveLatestWindow(errorHandler)
		this.windowId := 0
	}

	undo(screensMgr, errorHandler) {
		this.moveWindowUndoFunc()
		this.moveWindowUndoFunc := (*) => {}
	}
}