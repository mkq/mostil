#include %A_SCRIPTDIR%/lib/util.ahk

class CommentCommandParser extends CommandParser {
	static parseConfig(config) {
		chars := config.input
		len := strlen(chars)
		if (!(chars is String) || len < 1 || len > 2) {
			throw ValueError(format('expected string of length 1..2, but got "{}"', chars))
		}
		return CommentCommandParser(Util.charAt(chars, 1), Util.charAt(chars, len))
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
			if (c == this.endCommentChars) {
				depth--
			} else if (c == this.startCommentChar) {
				depth++
			}
			i++
		}
		return true
	}
}
