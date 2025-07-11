#include %A_SCRIPTDIR%/lib/cmd.ahk
#include %A_SCRIPTDIR%/lib/util.ahk
#include %A_SCRIPTDIR%/lib/window-util.ahk

class PlaceWindowCommandParser extends Mostil.CommandParser {
	static parseConfig(config, screensManager) {
		cmd := Mostil.Util.getProp(config, "run", "")
		previewIcon := Mostil.Util.getProp(config, "previewIcon", false)
		if (previewIcon) { ; parse previewIcon (format "[index]file" or just "file")
			previewIcon := regExMatch(previewIcon, '^\[(\d+)\](.+)', &match) ? { index: match[1], file: match[2] } : { file: previewIcon, index: 1 }
		} else if (strlen(cmd) > 0) { ; default previewIcon: 1st word of cmd
			previewIcon := { file: regExReplace(cmd, '\s.*', ''), index: 1 }
		} else {
			previewIcon := { file: "shell32.dll", index: 1 }
		}
		return Mostil.PlaceWindowCommandParser(screensManager, config.input,
			Mostil.Util.getProp(config, "name", ""), Mostil.Util.getProp(config, "criteria"), previewIcon, cmd)
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
		if (!Mostil.Util.skip(cmdStr, this.windowInput, &i)) {
			return super.parse(cmdStr, pendingCommandParseResults, &i, commandParseResults)
		}
		tileInput := ""
		t := Mostil.Util.parseTileParameter(cmdStr, this.screensManager, &i, &tileInput)
		cmd := Mostil.PlaceWindowCommand(t, this.name, this.criteria, this.launchCmdStr, this.defaultPreviewIcon, this.screensManager)
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
			if (replacedCommandParseResult.command is Mostil.PlaceWindowCommand
				&& replacedCommandParseResult.command.windowSpec.name == this.name) {
				Mostil.Util.printDebug('replacing command "{}"', replacedCommandParseResult.input)
				pendingCommandParseResults.removeAt(-1)
			}
		}
		commandParseResults.push(Mostil.CommandParseResult(this.windowInput . tileInput, cmd))
		return true
	}
}

class PlaceWindowCommand extends Mostil.Command {
	__new(selectedTile, name, criteria, launchCmdStr, defaultPreviewIcon, screensManager) {
		this.selectedTile := selectedTile
		this.windowSpec := {
			name: name,
			criteria: criteria,
			launchCommand: launchCmdStr
		}
		this.defaultPreviewIcon := defaultPreviewIcon
		this.screensManager := screensManager

		this.windowId := 0
		this.oldTileText := selectedTile ? selectedTile.text : false
		this.oldTileIcon := selectedTile ? selectedTile.icon.internalFormat : false
	}

	toString() {
		return format("{}({}, {})", type(this), this.windowSpec.name, String(this.selectedTile))
	}

	executePreview(errorHandler) {
		if (this.windowSpec.criteria) {
			this.windowId := winExist(this.windowSpec.criteria)
			Mostil.Util.printDebug('window for {}: {}', this.windowSpec.criteria, this.windowId)
		} else { ; MRU mode
			myWindowIds := Mostil.Util.arrayMap(this.screensManager.screens, s => s.gui.gui.hwnd)
			Mostil.Util.printDebugF('my window ids: {}', () => [Mostil.Util.dump(myWindowIds)])
			this.windowId := 0
			for wid in WindowUtil.getNormalWindowIds() {
				if (Mostil.Util.arrayIndexOf(myWindowIds, wid) == 0) {
					this.windowId := wid
					break
				}
			}
			Mostil.Util.printDebug('MRU window: {}', this.windowId)
		}

		if (!this.windowId) { ; selected window does not exist
			if (!this.selectedTile) { ; no tile, i.e. focus-only mode, but selected window does not exist: do nothing
				Mostil.Util.printDebug('focus non-existing window => do nothing')
				return
			}
			if (!this.windowSpec.launchCommand) {
				; TODO If selected window does not exist and has no run command configured, the parser should already
				; treat the input as invalid.
				Mostil.Util.printDebug('non-existing, no launch command => do nothing')
				return
			}
			this.oldTileText := this.selectedTile.text := this.windowSpec.launchCommand " (pending launch)"
			this.oldTileIcon := this.selectedTile.icon.setToFile(this.defaultPreviewIcon.file, this.defaultPreviewIcon.index)
		} else if (this.selectedTile) {
			this.oldTileText := this.selectedTile.text := "window " this.windowId
			this.oldTileIcon := this.selectedTile.icon.setToHandle(Mostil.WindowUtil.getWindowIcon(this.windowId))
		}
	}

	submit(errorHandler) {
		if (this.selectedTile) {
			this.selectedTile.text := this.oldTileText
			this.selectedTile.icon.internalFormat := this.oldTileIcon
		}

		if (!this.windowId) {
			Mostil.Util.printDebug('run: {}', this.windowSpec.launchCommand)
			run(this.windowSpec.launchCommand)
			Mostil.Util.printDebug('waiting for window {}', this.windowSpec.criteria)
			this.windowId := winWait(this.windowSpec.criteria, , 20)
			Mostil.Util.printDebug('winWait returned {}', this.windowId)

			if (!this.windowId) {
				this.screensManager.screenWithInput.gui.statusBar.setText(format('WARN: running {} did not yield a window matching {}',
					this.windowSpec.launchCommand, this.windowSpec.criteria))
				return
			}
		}

		if (this.selectedTile) {
			this.selectedTile.addWindow(this.windowId, this.screensManager, errorHandler)
		}
		winActivate(this.windowId)
	}

	undo(errorHandler) {
		if (this.selectedTile) {
			this.selectedTile.text := this.oldTileText
			this.selectedTile.icon.internalFormat := this.oldTileIcon
		}
	}
}
