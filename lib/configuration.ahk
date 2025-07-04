#include %A_ScriptDir%/lib/util.ahk
#include %A_ScriptDir%/lib/cmd-comment.ahk
#include %A_ScriptDir%/lib/cmd-place-window.ahk
#include %A_ScriptDir%/lib/cmd-resize-split.ahk

class Configuration extends Object {
	__new(rawConfig) {
		this.debug := getProp(rawConfig, "debug", false)
		this.closeOnFocusLost := getProp(rawConfig, "closeOnFocusLost", true)
		this.hotkey := rawConfig.hotkey
		this.screensManager := Configuration.parseScreensConfig_(getMandatoryProp(rawConfig, 'screens',
			'no screens configured'))
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

	static parseScreensConfig_(rawConfigs, addInput := false) {
		screens := []
		tileInputs := []
		for screenName, screenRawConfig in rawConfigs.ownProps() {
			if (addInput) {
				addInput := false
				printDebug("choosing input GUI: {}", screenName)
				if (!screenRawConfig.hasProp("ui")) {
					screenRawConfig.ui := {}
				}
				screenRawConfig.ui.input := true
			}
			s := Configuration.parseScreenConfig_(screenName, screenRawConfig)
			screens.push(s)
			for t in s.tiles {
				if (arrayIndexOf(tileInputs, t.input) > 0) {
					throw ValueError("duplicate screen input " t.input)
				}
				tileInputs.push(t.input)
			}
		}
		sm := ScreensManager(screens)
		if (!sm.screenWithInput) {
			return Configuration.parseScreensConfig_(rawConfigs, true)
		}

		return sm
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
		defaultSplitPercentage := Percentage.parse(splitMatcher[2] == "" ? "50%" : splitMatcher[2], maxSplitValue,
			"screen split default value")
		splitStepSize := Percentage.parse(rawConfig.hasProp("grid") ? rawConfig.grid : 20, maxSplitValue, "screen grid")

		minMaxSplitValues := getProp(rawConfig, "snap", ["0%", "100%"])
		if !(minMaxSplitValues is Array && minMaxSplitValues.length == 2) {
			throw ValueError("invalid screen snap (must be an array of two integers betwees 0 and 100, first < second)")
		}
		minSplitValue := Percentage.parse(minMaxSplitValues[1], maxSplitValue, "snap min")
		maxSplitValue := Percentage.parse(minMaxSplitValues[2], maxSplitValue, "snap max")
		if (minSplitValue.value + splitStepSize.value >= maxSplitValue.value) {
			throw ValueError("invalid screen snap (must be an array of two integers betwees 0 and 100, first + grid < second)")
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
		tile1 := Tile(1, Configuration.tileNameForInput_(t1input), t1input)
		tile2 := Tile(2, Configuration.tileNameForInput_(t2input), t2input)

		uiRawConfig := getProp(rawConfig, "ui", { x: pos.x, y: pos.y, scale: "100%", input: false })
		uiConfig := Configuration.parseScreenUiConfig_(uiRawConfig, pos)

		return Screen(name, pos, horizontal, minSplitValue, maxSplitValue, defaultSplitPercentage, splitStepSize, uiConfig,
			[tile1, tile2])
	}

	static parseScreenUiConfig_(rawConfig, screenPos) {
		input := getProp(rawConfig, "input", false)
		if (input != false && input != true) {
			throw ValueError("invalid screen ui input")
		}
		x := requireInteger(getProp(rawConfig, "x", screenPos.x), "screen ui x")
		y := requireInteger(getProp(rawConfig, "y", screenPos.y), "screen ui y")
		p := Percentage(requireNumber(regexReplace(getProp(rawConfig, "scale", "100"), '%$', ''), 'screen ui scale'), 100)
		w := p.applyTo(screenPos.w)
		h := p.applyTo(screenPos.h)
		return {
			pos: Position(x, y, w, h),
			hasInput: input
		}
	}

	static tileNameForInput_(tileInput) {
		return format('[ {} ]', tileInput)
	}
}