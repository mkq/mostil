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

	parse(cmdStr, pendingCommandParseResults, &i, commandParseResults) {
		if (!Util.skip(cmdStr, this.windowInput, &i)) {
			return super.parse(cmdStr, pendingCommandParseResults, &i, commandParseResults)
		}
		tileInput := ""
		t := Util.parseTileParameter(cmdStr, this.screensManager, &i, &tileInput)
		cmd := PlaceWindowCommand(t, this.name, this.criteria, this.launchCmdStr, this.defaultPreviewIcon, this.screensManager)
		; A PlaceWindowCommand with selected tile should replace one for the same window.
		; This happens all the time when the user types the window name followed by the tile.
		; TODO Is the condition sufficient or must all preceding commands in pendingCommandParseResults and
		; commandParseResults be equal?
		; TODO Make this less hacky. Maybe handle it in parseCommands: Save command start indexes instead of
		; inputs & detect replacement with them? E.g. with a window called "e" and a tile "t" and command "e"
		; having the same index in pendingCommandParseResults as "et" in commands, we know that the former became the
		; latter and should be replaced.
		if (t && pendingCommandParseResults.length > 0) {
			replacedCommandParseResult := pendingCommandParseResults[-1]
			if (replacedCommandParseResult.command is PlaceWindowCommand
				&& replacedCommandParseResult.command.windowSpec.name == this.name) {
				Util.printDebug('replacing command "{}"', replacedCommandParseResult.input)
				pendingCommandParseResults.removeAt(-1)
			}
		}
		commandParseResults.push(CommandParseResult(this.windowInput . tileInput, cmd))
		return true
	}
}

class PlaceWindowCommand extends Command {
	__new(selectedTile, name, criteria, launchCmdStr, defaultPreviewIcon, screensManager) {
		super.__new()
		this.selectedTile := selectedTile
		this.windowSpec := {
			name: name,
			criteria: criteria,
			launchCommand: launchCmdStr
		}
		this.defaultPreviewIcon := defaultPreviewIcon
		this.screensManager := screensManager

		this.windowId := 0
		this.moveWindowUndoFunc := () => {}
	}

	toString() {
		return format("{}({}, {})", super.toString(), this.windowSpec.name, String(this.selectedTile))
	}

	executePreview(screensMgr, errorHandler) {
		if (this.windowSpec.criteria) {
			this.windowId := winExist(this.windowSpec.criteria)
			Util.printDebug('window for {}: {}', this.windowSpec.criteria, this.windowId)
		} else { ; MRU mode
			myWindowIds := Util.arrayMap(this.screensManager.screens, s => s.gui.gui.hwnd)
			Util.printDebugF('my window ids: {}', () => [Util.dump(myWindowIds)])
			this.windowId := 0
			for wid in WindowUtil.getNormalWindowIds() {
				if (Util.arrayIndexOf(myWindowIds, wid) == 0) {
					this.windowId := wid
					break
				}
			}
			Util.printDebug('MRU window: {}', this.windowId)
		}

		if (!this.windowId) { ; selected window does not exist
			if (!this.selectedTile) { ; no tile, i.e. focus-only mode, but selected window does not exist: do nothing
				Util.printDebug('focus non-existing window => do nothing')
				return
			}
			if (!this.windowSpec.launchCommand) {
				; TODO If selected window does not exist and has no run command configured, the parser should already
				; treat the input as invalid.
				Util.printDebug('non-existing, no launch command => do nothing')
				return
			}
			tw := Tile.Window(0,
				Icon.fromFile(this.defaultPreviewIcon.file, this.defaultPreviewIcon.index),
				this.windowSpec.launchCommand " (pending launch)")
			this.moveWindowUndoFunc := screensMgr.moveWindowToTile(tw, this.selectedTile, errorHandler)
		} else if (this.selectedTile) {
			tw := Tile.Window(this.windowId,
				Icon.fromHandle(WindowUtil.getWindowIcon(this.windowId)),
				"window " this.windowId)
			this.moveWindowUndoFunc := screensMgr.moveWindowToTile(tw, this.selectedTile, errorHandler)
		}
	}

	submit(errorHandler) {
		if (!this.windowId) {
			Util.printDebug('run: {}', this.windowSpec.launchCommand)
			run(this.windowSpec.launchCommand)
			Util.printDebug('waiting for window {}', this.windowSpec.criteria)
			this.windowId := winWait(this.windowSpec.criteria, , 20)
			Util.printDebug('winWait returned {}', this.windowId)
			if (!this.windowId) {
				errorHandler(format('WARN: running {} did not yield a window matching {}', this.windowSpec.launchCommand, this.windowSpec.criteria))
				return
			}
			if (this.selectedTile) {
				this.selectedTile.windows[-1].id := this.windowId
			}
		}

		if (this.selectedTile) {
			this.selectedTile.moveLatestWindow(errorHandler)
		}
		winActivate(this.windowId)
	}

	undo(errorHandler) {
		this.moveWindowUndoFunc()
		this.moveWindowUndoFunc := () => {}
	}
}