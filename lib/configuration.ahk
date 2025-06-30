#include %A_ScriptDir%/lib/util.ahk
#include %A_ScriptDir%/lib/cmd-comment.ahk
#include %A_ScriptDir%/lib/cmd-place-window.ahk
#include %A_ScriptDir%/lib/cmd-resize-split.ahk

class Configuration extends Object {
	__new(rawConfig) {
		this.debug := getProp(rawConfig, "debug", false)
		this.closeOnFocusLost := getProp(rawConfig, "closeOnFocusLost", true)
		this.hotkey := rawConfig.hotkey
		this.screensManager := Configuration.parseScreensConfig_(getMandatoryProp(rawConfig, 'screens', 'no screens configured'))
		this.commandParsers := Configuration.parseCommandsConfig_(rawConfig.commands)
		printDebug("Configuration ctor end")
	}

	static parseCommandsConfig_(rawCommandsConfigs) {
		parsers := []
		windowNames := []
		for r in rawCommandsConfigs {
			switch r.command {
				case "placeWindow":
					parser := PlaceWindowCommandParser.parseConfig(r)
					if (arrayIndexOf(windowNames, parser.name) > 0) {
						throw ValueError("duplicate window name " parser.name)
					}
					windowNames.push(parser.name)
				case "resizeSplit":
					parser := ResizeSplitCommandParser.parseConfig(r)
				case "comment":
					parser := CommentCommandParser.parseConfig(r)
				default:
					throw ValueError("invalid command: " r.command)
			}
			parsers.push(parser)
		}
		return parsers
	}

	static parseScreensConfig_(rawConfigs) {
		screens := []
		tileInputs := []
		for screenName, screenRawConfig in rawConfigs.ownProps() {
			s := Configuration.parseScreenConfig_(screenName, screenRawConfig)
			screens.push(s)
			for tileInput, t in s.tiles {
				if (arrayIndexOf(tileInputs, tileInput) > 0) {
					throw ValueError("duplicate screen input " tileInput)
				}
				tileInputs.push(tileInput)
			}
		}
		if (screens.length == 0) {
			throw ValueError("no screens configured")
		}
		return ScreensManager(screens)
	}

	static parseScreenConfig_(name, rawConfig) {
		pos := Position(
			requireInteger(rawConfig.x, "screen x"),
			requireInteger(rawConfig.y, "screen y"),
			requireInteger(rawConfig.w, "screen w"),
			requireInteger(rawConfig.h, "screen h"))
		if (type(rawConfig.split) !== "String") {
			throw ValueError("invalid screen split mode type " type(rawConfig.split))
		}
		splitMatcher := ""
		if (!regexMatch(rawConfig.split, "^([hv])(\d+%?)?$", &splitMatcher)) {
			throw ValueError("invalid screen split mode " rawConfig.split)
		}
		horizontal := splitMatcher[1] == "h"
		maxSplitValue := horizontal ? pos.w : pos.h
		defaultSplitValue := parsePercentage(splitMatcher[2] == "" ? "50%" : splitMatcher[2], maxSplitValue,
			"screen split default value")
		splitStepSize := rawConfig.hasProp("grid") ? parsePercentage(rawConfig.grid, maxSplitValue, "screen grid") : 20
		if (defaultSplitValue < 0 || splitStepSize <= 0) {
			throw ValueError("invalid negative value in screen config")
		}

		minMaxSplitValues := getProp(rawConfig, "snap", ["0%", "100%"])
		if !(minMaxSplitValues is Array && minMaxSplitValues.length == 2
			&& (minSplitValue := parsePercentage(minMaxSplitValues[1], maxSplitValue, "snap min")) >= 0
			&& (maxSplitValue := parsePercentage(minMaxSplitValues[2], maxSplitValue, "snap max")) >= 0
			&& minSplitValue + splitStepSize < maxSplitValue) {
			throw ValueError("invalid screen snap (must be an array of two integers betwees 0 and 100, first < second)")
		}

		if (type(rawConfig.inputs) == "Array" && rawConfig.inputs.length == 2
			&& type(rawConfig.inputs[1]) == "String" && type(rawConfig.inputs[2]) == "String") {
			t1input := rawConfig.inputs[1]
			t2input := rawConfig.inputs[2]
			if (t1input == t2input) {
				throw ValueError("duplicate screen key " t1input)
			}
		} else {
			throw ValueError("invalid screen inputs (must be an array of two different strings)")
		}
		tile1 := Tile(1, Configuration.tileNameForInput_(t1input))
		tile2 := Tile(2, Configuration.tileNameForInput_(t2input))

		uiRawConfig := getProp(rawConfig, "ui", { x: pos.x, y: pos.y, scale: "100%", input: false })
		uiConfig := Configuration.parseScreenUiConfig_(uiRawConfig, pos)

		return Screen(name, pos, horizontal, minSplitValue, maxSplitValue, defaultSplitValue, splitStepSize, uiConfig,
			Map(
				t1input, tile1,
				t2input, tile2))
	}

	static parseScreenUiConfig_(rawConfig, screenPos) {
		input := getProp(rawConfig, "input", false)
		if (input != false && input != true) {
			throw ValueError("invalid screen ui input")
		}

		x := requireInteger(rawConfig.x, "screen ui x")
		y := requireInteger(rawConfig.y, "screen ui y")
		percentage := requireInteger(regexReplace(getProp(rawConfig, "scale", "100"), '%$', ''), 'screen ui scale')
		w := computePercentage(screenPos.w, percentage)
		h := computePercentage(screenPos.h, percentage)
		return {
			pos: Position(x, y, w, h),
			hasInput: input
		}
	}

	static tileNameForInput_(tileInput) {
		return format('"{}"', tileInput)
	}
}