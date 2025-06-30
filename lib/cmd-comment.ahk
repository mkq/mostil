#include %A_ScriptDir%/lib/core.ahk

class CommentCommandParser extends CommandParser {
	static parseConfig(config) {
		return CommentCommandParser(charAt(requireStrLen(config.input, 2), 1), charAt(config.input, 2))
	}

	__new(startCommentChar, endCommentChar) {
		this.startCommentChar := startCommentChar
		this.endCommentChars := endCommentChar
	}

	parse(cmdStr, &i, commandParseResults) {
		if (charAt(cmdStr, i) !== this.startCommentChar) {
			return super.parse(cmdStr, &i, commandParseResults)
		}
		depth := 1, len := strlen(cmdStr)
		while (i <= len && depth > 0) {
			c := charAt(cmdStr, i)
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