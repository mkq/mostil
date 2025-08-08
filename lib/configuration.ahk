#include %A_SCRIPTDIR%/lib/cmd-comment.ahk
#include %A_SCRIPTDIR%/lib/cmd-place-window.ahk
#include %A_SCRIPTDIR%/lib/cmd-resize-split.ahk
#include %A_SCRIPTDIR%/lib/configuration.ahk
#include %A_SCRIPTDIR%/lib/screen.ahk
#include %A_SCRIPTDIR%/lib/screens.ahk
#include %A_SCRIPTDIR%/lib/util.ahk

class Configuration {
	__new(rawConfig) {
		this.debug := Util.getProp(rawConfig, "debug", false)
		this.closeOnFocusLost := Util.getProp(rawConfig, "closeOnFocusLost", true)
		screensRawConfig := Util.getMandatoryProp(rawConfig, 'screens', 'no screens configured')
		guiConfig := Configuration.parseGuiConfig_(Util.getProp(rawConfig, 'gui', {}))
		this.screensManager := Configuration.parseScreensConfig_(screensRawConfig, guiConfig)
		this.commandParsers := Configuration.parseCommandsConfig_(rawConfig.commands, this.screensManager)
		Util.printDebug("Configuration ctor end")
	}

	static parseGuiConfig_(rawConfig) {
		return {
			iconScale: Percentage.parse(Util.getProp(rawConfig, 'iconScale', '10%'), 100, 'iconScale'),
			maxIconSize: Util.getProp(rawConfig, 'maxIconSize', 256),
			maxIconCount: Util.getProp(rawConfig, 'maxIconCount', 10),
			iconOffsetX: Util.getProp(rawConfig, 'iconOffsetX', 10),
			iconDist: Util.getProp(rawConfig, 'iconDist', 32),
		}
	}

	static parseCommandsConfig_(rawCommandsConfigs, screensManager) {
		parsers := []
		windowNames := []
		for r in rawCommandsConfigs {
			switch r.command {
				case "placeWindow":
					parser := PlaceWindowCommandParser.parseConfig(r, screensManager)
					if (Util.arrayIndexOf(windowNames, parser.name) > 0) {
						throw ValueError("duplicate window name " parser.name)
					}
					windowNames.push(parser.name)
				case "resizeSplit":
					parser := ResizeSplitCommandParser.parseConfig(r, screensManager)
				case "comment":
					parser := CommentCommandParser.parseConfig(r)
				default:
					throw ValueError("invalid command: " r.command)
			}
			parsers.push(parser)
		}
		return parsers
	}

	static parseScreensConfig_(rawConfigs, guiRawConfig, addInput := false) {
		screens := []
		tileInputs := []
		for screenName, screenRawConfig in rawConfigs.ownProps() {
			if (addInput) {
				addInput := false
				Util.printDebug("choosing input GUI: {}", screenName)
				if (!screenRawConfig.hasProp("ui")) {
					screenRawConfig.ui := {}
				}
				screenRawConfig.ui.input := true
			}
			s := Configuration.parseScreenConfig_(screenName, screenRawConfig, guiRawConfig)
			screens.push(s)
			for t in s.tiles {
				if (Util.arrayIndexOf(tileInputs, t.input) > 0) {
					throw ValueError("duplicate screen input " t.input)
				}
				tileInputs.push(t.input)
			}
		}
		sm := ScreensManager(screens)
		if (!sm.screenWithInput) {
			return Configuration.parseScreensConfig_(rawConfigs, guiRawConfig, true)
		}

		return sm
	}

	static parseScreenConfig_(name, rawConfig, guiRawConfig) {
		pos := Position(
			Util.requireInteger(rawConfig.x, "screen x"),
			Util.requireInteger(rawConfig.y, "screen y"),
			Util.requireInteger(rawConfig.w, "screen w"),
			Util.requireInteger(rawConfig.h, "screen h"))
		if !(rawConfig.split is String) {
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

		minMaxSplitValues := Util.getProp(rawConfig, "snap", ["0%", "100%"])
		if !(minMaxSplitValues is Array && minMaxSplitValues.length == 2) {
			throw ValueError("invalid screen snap (must be an array of two integers betwees 0 and 100, first < second)")
		}
		minSplitValue := Percentage.parse(minMaxSplitValues[1], maxSplitValue, "snap min")
		maxSplitValue := Percentage.parse(minMaxSplitValues[2], maxSplitValue, "snap max")
		if (minSplitValue.value + splitStepSize.value >= maxSplitValue.value) {
			throw ValueError("invalid screen snap (must be an array of two integers betwees 0 and 100, first + grid < second)")
		}

		if (rawConfig.inputs is Array && rawConfig.inputs.length == 2
			&& rawConfig.inputs[1] is String && rawConfig.inputs[2] is String) {
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

		uiRawConfig := Util.getProp(rawConfig, "ui", { x: pos.x, y: pos.y, scale: "100%", input: false })
		uiConfig := Configuration.parseScreenUiConfig_(uiRawConfig, pos)

		return Screen(name,
			SplitPosition(horizontal, pos, defaultSplitPercentage, minSplitValue, maxSplitValue, splitStepSize),
			uiConfig.position,
			uiConfig.hasInput,
			[tile1, tile2],
			guiRawConfig)
	}

	static parseScreenUiConfig_(rawConfig, screenPos) {
		input := Util.getProp(rawConfig, "input", false)
		if (input != false && input != true) {
			throw ValueError("invalid screen ui input")
		}
		x := Util.requireInteger(Util.getProp(rawConfig, "x", screenPos.x), "screen ui x")
		y := Util.requireInteger(Util.getProp(rawConfig, "y", screenPos.y), "screen ui y")
		p := Percentage(Util.requireNumber(regexReplace(Util.getProp(rawConfig, "scale", "100"), '%$', ''), 'screen ui scale'), 100)
		w := p.applyTo(screenPos.w)
		h := p.applyTo(screenPos.h)
		return {
			position: Position(x, y, w, h),
			hasInput: input
		}
	}

	static tileNameForInput_(tileInput) {
		return format('[ {} ]', tileInput)
	}
}