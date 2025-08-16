#include %A_SCRIPTDIR%/lib/cmd.ahk
#include %A_SCRIPTDIR%/lib/util.ahk

class NopCommandParser extends CommandParser {
	static parseConfig(config) {
		chars := config.input
		if (!(chars is String) || strlen(chars) == 0) {
			throw ValueError(format('expected non-empty string, but got "{}"', chars))
		}
		return NopCommandParser(chars)
	}

	__new(chars) {
		this.chars := chars
	}

	parse(cmdStr, &i, commandParseResults) {
		found := false
		len := strlen(cmdStr)
		while (i <= len) {
			if (inStr(this.chars, Util.charAt(cmdStr, i), true)) {
				found := true
				i++
			} else {
				break
			}
		}
		return found
	}
}