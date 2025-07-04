#include %A_ScriptDir%/lib/util.ahk
#include %A_ScriptDir%/lib/core.ahk

class PlaceWindowCommandParser extends CommandParser {
	static parseConfig(config) {
		cmd := getProp(config, "run", "")
		previewIcon := getProp(config, "previewIcon", false)
		if (previewIcon) { ; parse previewIcon (format "[index]file" or just "file")
			previewIcon := regExMatch(previewIcon, '^\[(\d+)\](.+)', &match) ? { index: match[1], file: match[2] } : { file: previewIcon, index: 1 }
		} else if (strlen(cmd) > 0) { ; default previewIcon: 1st word of cmd
			previewIcon := { file: regExReplace(cmd, '\s.*', ''), index: 1 }
		} else {
			previewIcon := { file: "shell32.dll", index: 1 }
		}
		return PlaceWindowCommandParser(config.input, getProp(config, "name", ""), getProp(config, "criteria"), previewIcon, cmd)
	}

	__new(windowInput, name, criteria, defaultPreviewIcon, launchCmdStr := "") {
		this.windowInput := windowInput
		this.name := name
		this.criteria := criteria
		this.defaultPreviewIcon := defaultPreviewIcon
		this.launchCmdStr := launchCmdStr
	}

	parse(cmdStr, &i, commandParseResults) {
		if (!skip(cmdStr, this.windowInput, &i)) {
			return super.parse(cmdStr, &i, commandParseResults)
		}
		tileInput := ""
		t := parseTileParameter(cmdStr, &i, &tileInput)
		cmd := PlaceWindowCommand(t, this.name, this.criteria, this.launchCmdStr, this.defaultPreviewIcon)
		; A PlaceWindowCommand with selected tile should replace one for the same window.
		; This happens all the time when the user types the window name followed by the tile.
		; TODO Is the condition sufficient or must all preceding commands in pendingCommandParseResults and
		; commandParseResults be equal?
		; TODO Make this less hacky. Maybe handle it in parseCommands: Save command start indexes instead of
		; inputs & detect replacement with them? E.g. with a window called "e" and a tile "t" and command "e"
		; having the same index in pendingCommandParseResults as "et" in commands, we know that the former became the
		; latter and should be replaced.
		if (t && gl.pendingCommandParseResults.length > 0) {
			replacedCommandParseResult := gl.pendingCommandParseResults[-1]
			if (replacedCommandParseResult.command is PlaceWindowCommand
				&& replacedCommandParseResult.command.windowSpec.name == this.name) {
				printDebug('replacing command "{}"', replacedCommandParseResult.input)
				gl.pendingCommandParseResults.removeAt(-1)
			}
		}
		commandParseResults.push(CommandParseResult(this.windowInput . tileInput, cmd))
		return true
	}
}

class PlaceWindowCommand extends Command {
	__new(selectedTile, name, criteria, launchCmdStr, defaultPreviewIcon) {
		this.selectedTile := selectedTile
		this.windowSpec := {
			name: name,
			criteria: criteria,
			launchCommand: launchCmdStr
		}
		this.defaultPreviewIcon := defaultPreviewIcon
		this.windowId := 0
		this.oldTileText := selectedTile ? selectedTile.text : false
		this.oldTileIcon := selectedTile ? selectedTile.icon.internalFormat : false
	}

	toString() {
		return format("{}({}, {})", type(this), this.windowSpec.name, String(this.selectedTile))
	}

	executePreview() {
		if (this.windowSpec.criteria) {
			this.windowId := winExist(this.windowSpec.criteria)
			printDebug('window for {}: {}', this.windowSpec.criteria, this.windowId)
		} else { ; MRU mode
			myWindowIds := arrayMap(gl.screensManager.screens, s => s.gui.gui.hwnd)
			this.windowId := 0
			for wid in getNormalWindowIds() {
				if (arrayIndexOf(myWindowIds, wid) == 0) {
					this.windowId := wid
					break
				}
			}
			printDebug('MRU window: {}', this.windowId)
		}

		if (!this.windowId) { ; selected window does not exist
			if (!this.selectedTile) { ; no tile, i.e. focus-only mode, but selected window does not exist: do nothing
				return
			}
			if (!this.windowSpec.launchCommand) {
				return
			}
			this.oldTileText := this.selectedTile.text := this.windowSpec.launchCommand " (pending launch)"
			this.oldTileIcon := this.selectedTile.icon.setToFile(this.defaultPreviewIcon.file, this.defaultPreviewIcon.index)
		} else if (this.selectedTile) {
			this.oldTileText := this.selectedTile.text := "window " this.windowId
			this.oldTileIcon := this.selectedTile.icon.setToHandle(getWindowIcon(this.windowId))
		}
	}

	submit() {
		if (this.selectedTile) {
			this.selectedTile.text := this.oldTileText
			this.selectedTile.icon.internalFormat := this.oldTileIcon
		}

		if (!this.windowId) {
			printDebug('run: {}', this.windowSpec.launchCommand)
			run(this.windowSpec.launchCommand)
			printDebug('waiting for window {}', this.windowSpec.criteria)
			this.windowId := winWait(this.windowSpec.criteria, , 20)
			printDebug('winWait returned {}', this.windowId)

			if (!this.windowId) {
				gl.screensManager.screenWithInput.gui.statusBar.setText(format('WARN: running {} did not yield a window matching {}',
					this.windowSpec.launchCommand, this.windowSpec.criteria))
				return
			}
		}

		winActivate(this.windowId)
		if (this.selectedTile) {
			this.selectedTile.grabWindow(this.windowId)
		}
	}

	undo() {
		if (this.selectedTile) {
			this.selectedTile.text := this.oldTileText
			this.selectedTile.icon.internalFormat := this.oldTileIcon
		}
	}
}
