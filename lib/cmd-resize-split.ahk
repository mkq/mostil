#include %A_SCRIPTDIR%/lib/util.ahk

class ResizeSplitCommandParser extends CommandParser {
	static parseConfig(config, screensMgr) {
		return ResizeSplitCommandParser(config.input, screensMgr)
	}

	__new(input, screensMgr) {
		this.input := input
		this.screensManager := screensMgr
	}

	parse(cmdStr, pendingCommandParseResults, &i, commandParseResults) {
		origI := i
		if (!skip(cmdStr, this.input, &i)) {
			return super.parse(cmdStr, pendingCommandParseResults, &i, commandParseResults)
		}
		resetChar := substr(this.input, -1)

		; 1st arg is mandatory; reset index if missing
		cpr := this.parseArg_(cmdStr, &i, resetChar, this.input)
		if (cpr == false) {
			i := origI
			return false
		}
		commandParseResults.push(cpr)

		; more optional args
		while (cpr := this.parseArg_(cmdStr, &i, resetChar, "")) != false {
			commandParseResults.push(cpr)
		}
		return true
	}

	; We create a new Command for each arg in order to get proper undo() e.g. on each press of backspace key
	parseArg_(cmdStr, &i, resetChar, inputPrefix) {
		len := strlen(cmdStr)
		if (skip(cmdStr, resetChar, &i)) {
			return CommandParseResult(inputPrefix . resetChar, ResizeSplitCommand(this.screensManager))
		}
		input := ""
		t := parseTileParameter(cmdStr, this.screensManager, &i, &input)
		return t == false ? false : CommandParseResult(inputPrefix . input, ResizeSplitCommand(this.screensManager, t))
	}
}

class ResizeSplitCommand extends Command {
	__new(screensMgr, selectedTile := false) {
		this.screensManager := screensMgr
		this.selectedTile := selectedTile
	}

	toString() {
		return format("{}({})", type(this), this.selectedTile is Tile ? this.selectedTile.toString() : "")
	}

	executePreview() {
		if (this.selectedTile is Tile) {
			this.selectedTile.moveSplit()
		} else {
			this.screensManager.forEachScreen(s => s.resetSplit())
		}

		; TODO resize all windows in the tile and its sibling tile
	}

	submit() {
		; nothing to do
	}

	undo() {
		if (this.selectedTile is Tile) {
			this.selectedTile.screen.updateWindowPositions()
		} else {
			this.screensManager.forEachScreen(s => s.updateWindowPositions())
		}
	}
}
