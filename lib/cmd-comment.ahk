#include %A_SCRIPTDIR%/lib/util.ahk

class CommentCommandParser extends CommandParser {
	static parseConfig(config) {
		return CommentCommandParser(Util.charAt(Util.requireStrLen(config.input, 2), 1), Util.charAt(config.input, 2))
	}

	__new(startCommentChar, endCommentChar) {
		this.startCommentChar := startCommentChar
		this.endCommentChars := endCommentChar
	}

	parse(cmdStr, pendingCommandParseResults, &i, commandParseResults) {
		if (Util.charAt(cmdStr, i) !== this.startCommentChar) {
			return super.parse(cmdStr, pendingCommandParseResults, &i, commandParseResults)
		}
		i++
		depth := 1, len := strlen(cmdStr)
		while (i <= len && depth > 0) {
			c := Util.charAt(cmdStr, i)
			if (c == this.startCommentChar) {
				depth++
			} else if (c == this.endCommentChars) {
				depth--
			}
			i++
		}
		return true
	}
}
