class CommandParser {
	; @param cmdStr command string to parse
	; @param pendingCommandParseResults array of pending CommandParseResults; TODO remove (see PlaceWindowCommandParser)
	; @param i start index; will be incremented to point to the first position which was not understood by this parser
	; @param commandParseResults CommandParseResult[] to which to append
	; @return boolean whether successful
	parse(cmdStr, pendingCommandParseResults, &i, commandParseResults) {
		return false
	}
}

class Command {
	toString() {
		return type(this)
	}

	; Executes this command, but only so far that it can be undone.
	; Other actions are deferred until submit().
	executePreview(errorHandler) {
		throw Error("must be overridden")
	}

	; Called when the input that produced this command is deleted before it has been submitted.
	undo(errorHandler) {
		throw Error("must be overridden")
	}

	submit(errorHandler) {
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
