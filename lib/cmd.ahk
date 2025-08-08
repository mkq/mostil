class CommandParser {
	; @param cmdStr command string to parse
	; @param i start index; will be incremented to point to the first position which was not understood by this parser
	; @param commandParseResults CommandParseResult[] to which to append
	; @return boolean whether successful
	parse(cmdStr, &i, commandParseResults) {
		return false
	}

	parseTileParameter(cmdString, screensMgr, &i, &cmdStrPart) {
		for s in screensMgr.screens {
			for t in s.tiles {
				if (Util.skip(cmdString, t.input, &i)) {
					cmdStrPart := t.input
					return t
				}
			}
		}
		return false
	}
}

class Command {
	static nextId := 1

	__new() {
		this.id := Command.nextId++
	}

	toString() {
		return type(this) '@' this.id
	}

	; Executes this command, but only so far that it can be undone.
	; Other actions are deferred until submit().
	executePreview(screensMgr, errorHandler) {
		throw Error("must be overridden")
	}

	; Called when the input that produced this command is deleted before it has been submitted.
	undo(screensMgr, errorHandler) {
		throw Error("must be overridden")
	}

	submit(screensMgr, errorHandler) {
	}
}

class CommandParseResult {
	__new(input, command) {
		this.input := input
		this.command := command
	}

	toString() {
		return format('["{}" → {}]', this.input, String(this.command))
	}
}