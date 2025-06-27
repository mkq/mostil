#Requires AutoHotkey v2
#ErrorStdOut UTF-8
#Warn All, StdOut
#SingleInstance force
#include mostil.ahk.conf ;TODO #include %A_ScriptFullPath%.conf
traySetIcon("shell32.dll", 251)
setTitleMatchMode("RegEx")

; TODO
; - allow nesting like a real tiling window manager (a screen can have a parent tile instead of fixed x, y, w, h)
; - allow screen to have an input key ("maximize" shortcut without moving the split to 0% or 100%)
; - for maximizing only: allow a screen without tiles, but with an input key
; - refactor main script into a function and make the config script the main script?
; - configurable size how many pixels or percent a window should overlap the split
; - configurable max. number of windows to activate when undoing FocusWindowCommand
; - Add configurable command separator char? That would e.g. enable multiple focus commands even if a placeWindow input starts
;   with a char equal to a tile.
; - ScreenGuiManager: add scaling option (as percent of its screen)
; - If any own window is activated, activate the one with input instead.

DEBUG := true ; later overwritten with configured value

; ____________________________________ init
SHORT_PROGRAM_NAME := "Mostil"
LONG_PROGRAM_NAME := SHORT_PROGRAM_NAME " - Mostly tiling window layout manager"
g := {} ; instead of most global variables

init() {
	printDebug("init")
	c := Configuration(config)
	g.commandParsers := c.commandParsers
	g.guiManager := c.guiManager
	g.closeOnFocusLostAllowed := true
	DEBUG := c.debug
	onMessage(0x6, (wp, lp, msg, hwnd) => ; WM_ACTIVATE
		(c.closeOnFocusLost && g.closeOnFocusLostAllowed && !wp && g.guiManager.containsWindowId(hwnd))
			? cancel('focus lost') : 1)

	hotkey(c.hotkey, hk => g.guiManager.show())
	g.pendingCommandParseResults := []
	g.submittable := true
}
init()

; ____________________________________ core logic

submit() {
	printDebug("submit")
	if (!g.submittable) {
		return
	}
	g.guiManager.hide()

	while g.pendingCommandParseResults.length > 0 {
		cpr := g.pendingCommandParseResults.removeAt(1)
		printDebug("submit {}", cpr)
		cpr.command.submit()
	}

	input := g.guiManager.inputSGM.input
	cmdStr := normalizeCommandString(input.value)
	g.defaultInputs := moveToOrInsertAt0(g.defaultInputs, cmdStr)
	input.delete()
	input.add(g.defaultInputs)
}

cancel(reasonMessage) {
	printDebug("cancel({})", reasonMessage)
	while g.pendingCommandParseResults.length > 0 {
		cpr := g.pendingCommandParseResults.removeAt(-1)
		printDebug("undo {}", cpr)
		cpr.command.undo()
	}
	g.guiManager.inputSGM.input.value := ""
	g.guiManager.hide()
}

onValueChange(srcControl, *) {
	cmdStr := g.guiManager.inputSGM.input.text
	printDebug('__________ onValueChange("{}") __________', cmdStr)
	newCommandPRs := parseCommands(cmdStr)
	try {
		handleCommandChange(newCommandPRs)
	} finally {
		g.pendingCommandParseResults := newCommandPRs
	}
}

handleCommandChange(commandParseResults) {
	printDebug("handleCommandChange")
	diffIndex := findDiffIndex(g.pendingCommandParseResults, commandParseResults, (a, b) => a.input == b.input)
	if (diffIndex == 0) {
		return
	}

	global closeOnFocusLostAllowed := false
	try {
		; undo pendingCommandParseResults which are not in commandParseResults:
		loop g.pendingCommandParseResults.length - diffIndex + 1 {
			cpr := g.pendingCommandParseResults.removeAt(-1)
			printDebug("undo {}", cpr)
			cpr.command.undo()
		}

		; execute new commands:
		i := diffIndex
		while (i <= commandParseResults.length) {
			cpr := commandParseResults[i++]
			printDebug("executePreview {}", cpr)
			cpr.command.executePreview()
		}
	} finally {
		closeOnFocusLostAllowed := true
	}
}

parseCommands(cmdStr) {
	global submittable := true
	g.guiManager.inputSGM.status.setText("")
	cprs := []
	i := 1, len := strlen(cmdStr)
	while (i <= len) {
		prevLength := cprs.length
		prevI := i
		for (p in g.commandParsers) {
			if (p.parse(cmdStr, &i, cprs)) { ; p parsed something at i; continue with 1st parser at (already incremented) index
				printDebug("parsed `"{}`" (next index {} → {}) into {} commands. ⇒ All commands:",
					cmdStr, prevI, i, cprs.length - prevLength)
				arrayMap(cprs, cpr => printDebug("- {}", cpr))
				break
			}
		}
		if (prevLength == cprs.length) {
			global submittable := false
			g.guiManager.inputSGM.status.setText(format("Invalid or incomplete input starting at index {}: {}", prevI - 1, substr(cmdStr, i)))
			break
		}
	}
	return cprs
}

normalizeCommandString(cmdStr) {
	; TODO
	return cmdStr " [" A_NOW "]"
}

; ____________________________________ core types

class CommandParser {
	; @param cmdStr command string to parse
	; @param i start index; will be incremented to point to the first position which was not understood by this parser
	; @param commandParseResults CommandParseResult[] to which to append
	; @return boolean whether successful
	parse(cmdStr, &i, commandParseResults) {
		return false
	}
}

class Command {
	toString() {
		return type(this)
	}

	; Executes this command, but only so far that it can be undone.
	; Other actions are deferred until submit().
	executePreview() {
		throw Error("must be overridden")
	}

	; Called when the input that produced this command is deleted before it has been submitted.
	undo() {
		throw Error("must be overridden")
	}

	submit() {
	}
}

class CommandParseResult {
	input := unset
	command := unset
	__new(input, command) {
		this.input := input
		this.command := command
	}
	toString() {
		return format('["{}" → {}]', this.input, String(this.command))
	}
}

; handles all GUIs (ScreenGuiManagers)
class GuiManager {
	__new() {
		this.screenGuiManagers := []
		this.inputSGM := false
	}

	show() {
		this.forEach(sgm => sgm.gui.show())
	}

	hide() {
		this.forEach(sgm => sgm.gui.hide())
	}

	forEach(f) {
		for sgm in this.screenGuiManagers {
			if (sgm !== this.inputSGM) {
				f(sgm)
			}
		}
		f(this.inputSGM)
	}

	containsWindowId(windowId) {
		for sgm in this.screenGuiManagers {
			if (sgm.gui.hwnd == windowId) {
				return true
			}
		}
		return false
	}
}

; handles the GUI for a single screen
class ScreenGuiManager {
	__new(config, screen) {
		printDebug("init GUI for {}", screen)
		this.screen := screen
		this.gui := Gui("+Theme", format('{} - screen "{}"', LONG_PROGRAM_NAME, screen.name))
		;this.gui.backColor := "81f131"
		;winSetTransColor(this.gui.backColor, this.gui)
		this.input := false
		if (getProp(config, 'input', false)) {
			this.input := this.gui.add("ComboBox", "w280 vCmd", [])
			this.input.onEvent("Change", onValueChange)
			this.okButton := this.gui.add("Button", "Default w60 x+0", "OK")
			this.cancelButton := this.gui.add("Button", "w60 x+0", "Cancel")
			this.status := this.gui.add("StatusBar")
			this.okButton.onEvent("Click", (*) => submit())
			this.cancelButton.onEvent("Click", (*) => cancel('Button'))
		}

		this.gui.onEvent("Close", (*) => cancel('window closed'))
		this.gui.onEvent("Escape", (*) => cancel('escape'))
		this.gui.show()
		winMove(config.x, config.y, screen.w, screen.h, this.gui)
		this.gui.hide()
	}
}

class Screen {
	__new(name, config) {
		this.name := name
		this.x := requireInteger(config.x, "screen x")
		this.y := requireInteger(config.y, "screen y")
		this.w := requireInteger(config.w, "screen w")
		this.h := requireInteger(config.h, "screen h")

		if (type(config.split) !== "String") {
			throw ValueError("invalid screen split mode type " type(config.split))
		}
		splitMatcher := ""
		if (!regexMatch(config.split, "^([hv])(\d+%?)?$", &splitMatcher)) {
			throw ValueError("invalid screen split mode " config.split)
		}
		this.horizontal := splitMatcher[1] == "h"
		maxSplitValue := this.horizontal ? this.w : this.h
		this.defaultSplitValue := parsePercentage(splitMatcher[2] == "" ? "50%" : splitMatcher[2], maxSplitValue,
			"screen split default value")
		this.splitValue := this.defaultSplitValue
		this.grid := config.hasProp("grid") ? parsePercentage(config.grid, maxSplitValue, "screen grid") : 20
		if (this.defaultSplitValue < 0 || this.grid <= 0) {
			throw ValueError("invalid negative value in screen config")
		}

		snap := getProp(config, "snap", ["0%", "100%"])
		if (snap is Array && snap.length == 2
			&& (this.minValue := parsePercentage(snap[1], maxSplitValue, "snap min")) >= 0
			&& (this.maxValue := parsePercentage(snap[2], maxSplitValue, "snap max")) >= 0
			&& this.minValue + this.grid < this.maxValue) {
			;
		} else {
			throw ValueError("invalid screen snap (must be an array of two integers betwees 0 and 100, first < second)")
		}

		if (type(config.inputs) == "Array" && config.inputs.length == 2
			&& type(config.inputs[1]) == "String" && type(config.inputs[2]) == "String") {
			t1input := config.inputs[1]
			t2input := config.inputs[2]
			if (t1input == t2input) {
				throw ValueError("duplicate screen key " t1input)
			}
		} else {
			throw ValueError("invalid screen inputs (must be an array of two different strings)")
		}
		tilePositions := this.computeTilePositions_()
		this.tiles := [Tile(this, 1, t1input, tilePositions[1]), Tile(this, 2, t2input, tilePositions[2])]
	}

	toString() {
		return format('{}("{}", {}, {}, {}x{})', type(this), this.name, this.x, this.y, this.w, this.h)
	}

	getTileForInput(inputChar) {
		for (t in this.tiles) {
			if (t.key == inputChar) {
				return t
			}
		}
		return false
	}

	computeTilePositions_() {
		if (this.horizontal) {
			; +-------+--------------+    y
			; |       |              |
			; +-------+--------------+   y+h
			; x      x+s            x+w
			results := [ ;
				{ x: this.x, y: this.y, w: this.splitValue, h: this.h }, ;
				{ x: this.x + this.splitValue, y: this.y, w: this.w - this.splitValue, h: this.h }]
		} else {
			; +-------+  y
			; |       |
			; |       |
			; +-------+ y+s
			; |       |
			; +-------+ y+h
			; x      x+w
			results := [ ;
				{ x: this.x, y: this.y, w: this.w, h: this.splitValue }, ;
				{ x: this.x, y: this.y + this.splitValue, w: this.w, h: this.h - this.splitValue }]
		}
		printDebugF("computeTilePositions_() == {}", () => [dump(results)])
		return results
	}

	moveSplit(tileIndex := 0) {
		this.splitValue := tileIndex == 1 ? max(this.splitValue - this.grid, this.minValue) :
			tileIndex == 2 ? min(this.splitValue + this.grid, this.maxValue) :
			this.defaultSplitValue
		tilePositions := this.computeTilePositions_()
		this.tiles[1].setPosition(tilePositions[1])
		this.tiles[2].setPosition(tilePositions[2])
	}

	resetSplit() {
		return this.moveSplit()
	}
}

class Tile {
	__new(screen, index, input, pos) {
		this.screen := screen
		this.index := index
		this.input := input
		this.pos := pos
		this.windowIds := []
	}

	toString() {
		return format("{}({}[{}], key `"{}`")", type(this), this.screen.toString(), this.index, this.input)
	}

	; Moves the parent screen's split in the direction corresponding to this tile, making this tile smaller and the sibling
	; tile bigger.
	moveSplit() {
		this.screen.moveSplit(this.index)
	}

	; Called by the paren screen to move all windows placed in this tile to the given coordinates.
	; Also deletes remembered window IDs which no longer exist.
	setPosition(windowPos) {
		this.pos := windowPos
		newWindowIds := []
		for (wid in this.windowIds) {
			if (winExist(wid)) {
				newWindowIds.push(wid)
				moveWindowToPos(wid, windowPos)
			}
		}
		this.windowIds := newWindowIds
	}

	grabWindow(windowId) {
		if (moveWindowToPos(windowId, this.pos)) {
			this.windowIds.push(windowId)
		}
	}
}

; ____________________________________ commands

class PlaceWindowCommandParser extends CommandParser {
	static parseConfig(config) {
		return PlaceWindowCommandParser(
			config.input,
			getProp(config, "name", ""),
			getProp(config, "criteria"),
			getProp(config, "run", ""))
	}
	__new(windowInput, name, criteria, launchCmdStr := "") {
		this.windowInput := windowInput
		this.name := name
		this.criteria := criteria
		this.launchCmdStr := launchCmdStr
	}
	parse(cmdStr, &i, commandParseResults) {
		if (!skip(cmdStr, this.windowInput, &i)) {
			return super.parse(cmdStr, &i, commandParseResults)
		}
		tileInput := ""
		t := parseTileParameter(cmdStr, &i, &tileInput)
		cmd := PlaceWindowCommand(t, this.name, this.criteria, this.launchCmdStr)
		; A PlaceWindowCommand with selected tile should replace one for the same window.
		; This happens all the time when the user types the window name followed by the tile.
		; TODO Is the condition sufficient or must all preceding commands in pendingCommandParseResults and
		; commandParseResults be equal?
		; TODO Make this less hacky. Maybe handle it in parseCommands: Save command start indexes instead of
		; inputs & detect replacement with them? E.g. with a window called "e" and a tile "t" and command "e"
		; having the same index in pendingCommandParseResults as "et" in commands, we know that the former became the
		; latter and should be replaced.
		if (t && g.pendingCommandParseResults.length > 0) {
			replacedCommandParseResult := g.pendingCommandParseResults[-1]
			if (replacedCommandParseResult.command is PlaceWindowCommand
				&& replacedCommandParseResult.command.windowSpec.name == this.name) {
				printDebug('replacing command "{}"', replacedCommandParseResult.input)
				g.pendingCommandParseResults.removeAt(-1)
			}
		}
		commandParseResults.push(CommandParseResult(this.windowInput . tileInput, cmd))
		return true
	}
}

class PlaceWindowCommand extends Command {
	__new(selectedTileInfo, name, criteria, launchCmdStr := "") {
		this.selectedTileInfo := selectedTileInfo
		this.windowSpec := {
			name: name,
			criteria: criteria,
			launchCommand: launchCmdStr
		}
		this.windowId := 0
		this.launchPending := false
		this.oldTileText := selectedTileInfo.guiManager.getText()
		this.oldTileIcon := selectedTileInfo.guiManager.getIcon()
	}

	toString() {
		return format("{}({}, {})", type(this), this.windowSpec.name, String(this.selectedTileInfo.tile))
	}

	executePreview() {
		if (this.windowSpec.criteria) {
			this.windowId := winExist(this.windowSpec.criteria)
		} else { ; MRU mode
			myWindowIds := arrayMap(g.guiManager.screenGuiManagers, gm => gm.gui.hwnd)
			this.windowId := 0
			for wid in getNormalWindowIds() {
				if (arrayIndexOf(myWindowIds, wid) > 0) {
					this.windowId := wid
					break
				}
			}
		}

		this.launchPending := !this.windowId
		if (this.launchPending) { ; selected window does not exist
			if (!this.selectedTileInfo) { ; no tile, i.e. focus-only mode, but selected window does not exist: do nothing
				return
			}
			if (!this.windowSpec.launchCommand) {
				return
			}
			this.selectedTileInfo.guiManager.setText(this.windowSpec.launchCommand " (pending launch)")
			this.selectedTileInfo.guiManager.setIcon(getIconForCommand(this.windowSpec.launchCommand))
		} else {
			this.selectedTileInfo.guiManager.setIcon(getWindowIcon(this.windowId))
		}
	}

	submit() {
		if (this.launchPending) {
			this.launchPending := false
			this.selectedTileInfo.guiManager.setText(this.oldTileText)
			this.selectedTileInfo.guiManager.setIcon(this.oldTileIcon)

			printDebug('run: {}', this.windowSpec.launchCommand)
			run(this.windowSpec.launchCommand)
			printDebug('waiting for window {}', this.windowSpec.criteria)
			this.windowId := winWait(this.windowSpec.criteria, , 20)
			printDebug('winWait returned {}', this.windowId)

			if (!this.windowId) {
				g.guiManager.gui.status.setText(format('WARN: running {} did not yield a window matching {}',
					this.windowSpec.launchCommand, this.windowSpec.criteria))
				return
			}
		}

		winActivate(this.windowId)
		if (this.selectedTileInfo) {
			this.selectedTileInfo.tile.grabWindow(this.windowId)
		}
	}

	undo() {
		this.launchPending := false
		this.selectedTileInfo.guiManager.setText(this.oldTileText)
		this.selectedTileInfo.guiManager.setIcon(this.oldTileIcon)
	}
}

class ResizeSplitCommandParser extends CommandParser {
	static parseConfig(config) {
		return ResizeSplitCommandParser(config.input)
	}
	__new(input) {
		this.input := input
	}
	parse(cmdStr, &i, commandParseResults) {
		origI := i
		if (!skip(cmdStr, this.input, &i)) {
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
		if (skip(cmdStr, resetChar, &i)) {
			return ResizeSplitCommand()
		}
		input := ""
		t := parseTileParameter(cmdStr, &i, &input)
		return t == false ? false : CommandParseResult(inputPrefix . input, ResizeSplitCommand(t))
	}
}

class ResizeSplitCommand extends Command {
	__new(selectedTile := false) {
		this.selectedTile := selectedTile
	}

	toString() {
		return format("{}({})", type(this), this.selectedTile is Tile ? this.selectedTile.toString() : "")
	}

	executePreview() {
		if (this.selectedTile is Tile) {
			this.selectedTile.moveSplit()
		} else {
			g.guiManager.forEachScreen(s => s.resetSplit())
		}
		; TODO resize all windows in the tile and its sibling tile
		return this
	}

	submit() {
		;TODO
	}

	undo() {
		;TODO
	}
}

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

; ____________________________________ config

class Configuration {
	__new(rawConfig) {
		this.debug := getProp(rawConfig, "debug", false)
		this.closeOnFocusLost := getProp(rawConfig, "closeOnFocusLost", true)
		this.hotkey := rawConfig.hotkey
		this.guiManager := GuiManager()
		this.parseScreensConfig_(getMandatoryProp(rawConfig, 'screens', 'no screens configured'))
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

	parseScreensConfig_(rawConfigs) {
		screens := []
		tileInputs := []
		for name, rawConfig in rawConfigs.ownProps() {
			s := Screen(name, rawConfig)
			screens.push(s)
			if (arrayIndexOf(tileInputs, s.tiles[1].input) > 0 || arrayIndexOf(tileInputs, s.tiles[2].input) > 0) {
				throw ValueError("duplicate screen input in " s.tiles[1].input s.tiles[2].input)
			}
			tileInputs.push(s.tiles[1].input, s.tiles[2].input)

			uiRawConfig := getProp(rawConfig, "ui", { x: s.x, y: s.y, scale: "100%" })
			sgm := ScreenGuiManager(uiRawConfig, s)
			this.guiManager.screenGuiManagers.push(sgm)
			if (sgm.input) {
				if (this.guiManager.inputSGM) {
					throw ValueError("multiple GUIs with input: true")
				} else {
					this.guiManager.inputSGM := sgm
				}
			}
		}
		if (screens.length == 0) {
			throw ValueError("no screens configured")
		}
		if (!this.guiManager.inputSGM) {
			this.guiManager.inputSGM := this.guiManager.screenGuiManagers[0]
			printDebugF("choosing input GUI: {}", this.guiManager.inputSGM.screen)
			this.guiManager.inputSGM.input := true
		}
	}
}

; ____________________________________ utilities
printDebug(formatStr, values*) {
	if (!DEBUG) {
		return
	}
	stringValues := []
	for v in values {
		stringValues.push(String(v))
	}
	msg := format(formatStr "`n", stringValues*)
	;fileAppend("DEBUG: " msg, '**')
	outputDebug(msg)
}

; printDebug with function for lazy evaluation:
printDebugF(formatStr, valuesFunc) {
	if (DEBUG) {
		return printDebug(formatStr, valuesFunc.call()*)
	}
}

eq(a, b) {
	return a == false ? b == false : a == b
}

getProp(o, propName, defaultValue := false) {
	return o.hasProp(propName) ? o.%propName% : defaultValue
}

getMandatoryProp(o, propName, errorMessage := (o '.' propName ' not set')) {
	if (o.hasProp(propName)) {
		return o.%propName%
	}
	throw ValueError(errorMessage)
}

join(sep, a) {
	start := true
	result := ""
	for (elem in a) {
		if (start) {
			start := false
		} else {
			result .= sep
		}
		result .= String(elem)
	}
	return result
}

dump(o) {
	switch type(o) {
		case "Array":
			parts := []
			for (elem in o) {
				parts.push(dump(elem))
			}
			return "[" join(", ", parts) "]"
		case "Object":
			result := "{ "
			start := true
			for n, v in o.ownProps() {
				if (start) {
					start := false
				} else {
					result .= ", "
				}
				result .= n ": " dump(v)
			}
			result .= " }"
			return result
		default:
			return String(o)
	}
}

arrayIndexOf(array, elem, startIndex := 1) {
	i := startIndex
	while (i <= array.length) {
		if (array[i] == elem) {
			return i
		}
		i++
	}
	return 0
}

arrayMap(array, f) {
	withIndex := f.maxParams > 1
	results := []
	for i, elem in array {
		result := withIndex ? f(i, elem) : f(elem)
		results.push(result)
	}
	return results
}

charAt(str, index) {
	return substr(str, index, 1)
}

skip(str, prefix, &i) {
	pl := strlen(prefix)
	matches := substr(str, i, pl) == prefix
	if (matches) {
		i += pl
	}
	return matches
}

requireInteger(val, valueDescription := "value") {
	if (!isInteger(val)) {
		throw ValueError(valueDescription " is not an integer")
	}
	return Integer(val)
}

requireStrLen(str, len) {
	if (!(str is String) || strlen(str) !== len) {
		throw ValueError(format("expected string of length {}, but got {}", len, strlen(str)))
	}
	return str
}

findDiffIndex(array1, array2, elemEqualsPredicate) {
	i := 1
	while (i <= array1.length && i <= array2.length) {
		if (!elemEqualsPredicate(array1[i], array2[i])) {
			return i
		}
		i++
	}
	if (i <= array1.length || i <= array2.length) {
		return i
	}
	return 0
}

moveToOrInsertAt0(array, elem) {
	resultArray := [elem]
	for e in array {
		if (e !== elem) {
			resultArray.push(e)
		}
	}
	return resultArray
}

parseTileParameter(cmdString, &i, &cmdStrPart) {
	for sgm in g.guiManager.screenGuiManagers {
		for i, t in sgm.tiles {
			if (skip(cmdString, t.input, &i)) {
				cmdStrPart := t.input
				return { index: i, tile: t, screenGuiManager: sgm }
			}
		}
	}
	return false
}

parsePercentage(str, maxValue, valueDescription) {
	isPercentage := false
	if (substr(str, -1, 1) == "%") {
		isPercentage := true
		str := substr(str, 1, -1)
	}
	value := requireInteger(str, valueDescription)
	if (isPercentage) {
		if (value < 0 || value > 100) {
			throw ValueError("invalid " valueDescription " percentage")
		}
		return maxValue * value / 100
	}
	return value
}

getWindowPos(windowId) {
	x := y := w := h := ""
	winGetPos(&x, &y, &w, &h, windowId)
	return { x: x, y: y, w: w, h: h }
}

moveWindowToPos(windowId, pos) {
	try {
		return winMove(pos.x, pos.y, pos.w, pos.h, windowId)
	} catch Error as e {
		g.guiManager.inputSGM.status.setText('ERROR moving window: ' e.message)
	}
}

winSetMinMax(windowId, value) {
	try {
		switch (value) {
			case -1: winMinimize(windowId)
			case +1: winMaximize(windowId)
			default: winRestore(windowId)
		}
	} catch Error as e {
		g.guiManager.inputSGM.status.setText('ERROR setting window min/max/restored state: ' e.message)
	}
}

getNormalWindowIds() {
	printDebugF('my window id: {}', () => arrayMap(g.guiManager.screenGuiManagers, gm => gm.gui.hwnd))
	results := []
	for wid_ in winGetList() {
		wid := wid_ ; workaround for Autohotkey bug? Loop variable does not exist in the printDebugF closure, but this copy does.
		title := winGetTitle(wid)
		include := title !== '' ; TODO: better criterium to exclude non-window results like Shell_TrayWnd?
		printDebugF('winGetList(): id: {}, processName: {}, class: {}, title: {}, include: {}', () =>
			[wid, winGetProcessName(wid), winGetClass(wid), title, include])
		if (include) {
			results.push(wid)
		}
	}
	return results
}