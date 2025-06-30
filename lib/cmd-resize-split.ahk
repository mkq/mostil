#include %A_ScriptDir%/lib/util.ahk
#include %A_ScriptDir%/lib/core.ahk

class ResizeSplitCommandParser extends CommandParser {
	static parseConfig(config) {
		return ResizeSplitCommandParser(config.input)
	}

	__new(input) {
		this.input := input
	}

	parse(cmdStr, &i, commandParseResults) {
		origI := i
		if (!skip(cmdStr, this.input, &i)) {
			return super.parse(cmdStr, &i, commandParseResults)
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
			return ResizeSplitCommand()
		}
		input := ""
		t := parseTileParameter(cmdStr, &i, &input)
		return t == false ? false : CommandParseResult(inputPrefix . input, ResizeSplitCommand(t))
	}
}

class ResizeSplitCommand extends Command {
	__new(selectedTile := false) {
		this.selectedTile := selectedTile
	}

	toString() {
		return format("{}({})", type(this), this.selectedTile is Tile ? this.selectedTile.toString() : "")
	}

	executePreview() {
		if (this.selectedTile is Tile) {
			this.selectedTile.moveSplit()
		} else {
			gl.screensManager.forEachScreen(s => s.resetSplit())
		}
		; TODO resize all windows in the tile and its sibling tile
		return this
	}

	submit() {
		;TODO
	}

	undo() {
		;TODO
	}
}