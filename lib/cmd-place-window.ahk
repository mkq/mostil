#include %A_SCRIPTDIR%/lib/cmd.ahk
#include %A_SCRIPTDIR%/lib/util.ahk
#include %A_SCRIPTDIR%/lib/window-util.ahk
#include %A_SCRIPTDIR%/lib/icon.ahk

class PlaceWindowCommandParser extends CommandParser {
	static DEFAULT_ICON {
		get => Icon.fromFile('shell32.dll', 184, Icon.blank())
	}
	static FILE_NOT_FOUND_ICON {
		get => Icon.fromFile('shell32.dll', 240, Icon.blank())
	}

	static parseConfig(config, screensManager) {
		cmd := Util.getProp(config, "run", "")
		previewIcon := Util.getProp(config, "previewIcon", false)
		if (previewIcon) { ; parse previewIcon (format "[index]file" or just "file")
			previewIcon := regExMatch(previewIcon, '^\[(\d+)\](.+)', &match)
				? Icon.fromFile(match[2], match[1], PlaceWindowCommandParser.FILE_NOT_FOUND_ICON)
				: Icon.fromFile(previewIcon, 1, PlaceWindowCommandParser.FILE_NOT_FOUND_ICON)
		} else if (strlen(cmd) > 0) { ; default previewIcon: 1st word of cmd
			previewIcon := Icon.fromFile(regExReplace(cmd, '\s.*', ''), 1, PlaceWindowCommandParser.DEFAULT_ICON)
		} else {
			previewIcon := PlaceWindowCommandParser.DEFAULT_ICON
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

	submit(screensMgr, errorHandler) {
		windowId := FocusWindowCommand.getWindowId_(this.windowSpec.criteria, this.screensManager)
		if (!windowId) {
			if (!this.windowSpec.launchCommand) {
				errorHandler(format('no window matching {} found', this.windowSpec.criteria))
				return
			}
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

	static getWindowId_(criteria, screensMgr) {
		if (criteria) {
			windowId := winExist(criteria)
			Util.printDebug('window for {}: {}', criteria, windowId)
			return windowId
		} else { ; MRU mode
			return WindowUtil.getActiveOtherWindow(screensMgr)
		}
	}
}

class PlaceWindowCommand extends Command {
	__new(selectedTile, name, criteria, launchCmdStr, defaultPreviewIcon, screensMgr) {
		super.__new()
		this.selectedTile := Util.checkType(Tile, selectedTile)
		this.windowSpec := {
			name: Util.checkType(String, name),
			criteria: Util.checkType(String, criteria),
			launchCommand: Util.checkType(String, launchCmdStr),
		}
		this.defaultPreviewIcon := Util.checkType(Icon, defaultPreviewIcon)
		this.screensManager := Util.checkType(ScreensManager, screensMgr)

		this.windowId := 0
		this.moveWindowUndoFunc := (*) => {}
	}

	toString() {
		return format("{}({}, {})", super.toString(), this.windowSpec.name, String(this.selectedTile))
	}

	executePreview(screensMgr, errorHandler) {
		this.windowId := FocusWindowCommand.getWindowId_(this.windowSpec.criteria, this.screensManager)
		text := this.windowId ? ("window " this.windowId) : (this.windowSpec.launchCommand " (pending launch)")
		ico := this.windowId && (hIcon := WindowUtil.getWindowIcon(this.windowId))
			? Icon.fromHandle(hIcon, this.defaultPreviewIcon)
			: this.defaultPreviewIcon
		tw := Tile.Window(this.windowId, ico, text)
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