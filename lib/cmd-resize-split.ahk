#include %A_SCRIPTDIR%/lib/util.ahk
#include %A_SCRIPTDIR%/lib/cmd.ahk

class ResizeSplitCommandParser extends CommandParser {
	static parseConfig(config, screensMgr) {
		return ResizeSplitCommandParser(config.input, screensMgr)
	}

	__new(input, screensMgr) {
		this.input := input
		this.screensManager := screensMgr
	}

	parse(cmdStr, &i, commandParseResults) {
		origI := i
		if (!Util.skip(cmdStr, this.input, &i)) {
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
		if (Util.skip(cmdStr, resetChar, &i)) {
			return CommandParseResult(inputPrefix . resetChar, ResetSplitCommand(this.screensManager))
		}
		input := ""
		t := this.parseTileParameter(cmdStr, this.screensManager, &i, &input)
		return t == false ? false : CommandParseResult(inputPrefix . input, ResizeSplitCommand(this.screensManager, t))
	}
}

class ResizeSplitCommand extends Command {
	__new(screensMgr, selectedTile) {
		super.__new()
		this.screensManager := screensMgr
		this.selectedTile := selectedTile
		this.oldSplitPercentage := false
	}

	toString() {
		return format("{}({})", super.toString(), this.selectedTile.toString())
	}

	executePreview(screensMgr, errorHandler) {
		this.oldSplitPercentage := Util.checkType(Percentage, this.selectedTile.moveSplit(this.screensManager))
		Util.printDebugF('oldSplitPercentage == {}', () => [this.oldSplitPercentage])
	}

	submit(screensMgr, errorHandler) {
		this.selectedTile.screen.updateWindowPositions(errorHandler)
	}

	undo(screensMgr, errorHandler) {
		Util.printDebugF('oldSplitPercentage == {}', () => [this.oldSplitPercentage])
		this.selectedTile.screen.setSplitToPercentage(this.oldSplitPercentage, this.screensManager)
	}
}

class ResetSplitCommand extends Command {
	__new(screensMgr) {
		this.screensManager := screensMgr
	}

	toString() {
		return type(this)
	}

	executePreview(screensMgr, errorHandler) {
		this.oldSplitPercentages := Util.checkType(Percentage, this.screensManager.forEachScreen(s => s.resetSplit()))
	}

	submit(screensMgr, errorHandler) {
		this.screensManager.forEachScreen(s => s.updateWindowPositions(errorHandler))
	}

	undo(screensMgr, errorHandler) {
		i := 0
		this.screensManager.forEachScreen(s => s.setSplitToPercentage(this.oldSplitPercentages[++i]))
	}
}