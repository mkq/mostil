#Requires AutoHotkey v2
#ErrorStdOut UTF-8
#Warn All, StdOut
#SingleInstance force
#include mostil.ahk.conf ;TODO #include %A_ScriptFullPath%.conf

; TODO
; - allow a screen to have a parent tile instead of fixed x, y, w, h ⇒ become a real tiling window manager
; - refactor main script into a function and make the config script the main script?
; - configurable size how many pixels or percent a window should extend past the split
; - configurable max. number of windows to activate when undoing FocusWindowCommand

; ____________________________________ init GUI

SHORT_PROGRAM_NAME := "Mostil"
LONG_PROGRAM_NAME := SHORT_PROGRAM_NAME " - Mostly tiling window layout manager"
printDebug("init GUI")
config := Configuration(config)
ui := {
	main: Gui("+AlwaysOnTop +Theme +Resize", LONG_PROGRAM_NAME)
}
ui := {
	main: ui.main,
	input: ui.main.add("ComboBox", "w280 vCmd", []),
	defaultInputs: [],
	okButton: ui.main.add("Button", "Default w60 x+0", "OK"),
	cancelButton: ui.main.add("Button", "w60 x+0", "Cancel"),
	status: ui.main.add("StatusBar"),
}
initGuiPos(ui, config)

closeOnFocusLost := true
onMessage(0x6, ; WM_ACTIVATE
	(wp, lp, msg, hwnd) => (closeOnFocusLost && hwnd == ui.main.hwnd && !wp) ? cancel('focus lost') : 1)
ui.main.onEvent("Close", (*) => cancel('window closed'))
ui.main.onEvent("Escape", (*) => cancel('escape'))
ui.input.onEvent("Change", onValueChange)
ui.okButton.onEvent("Click", (*) => submit())
ui.cancelButton.onEvent("Click", (*) => cancel('Button'))

; ____________________________________ init

printDebug("init")
hotkey(config.hotkey, hk => ui.main.show())
pendingCmds := []
submittable := true

; ____________________________________ core logic

submit() {
	printDebug("submit")
	if (!submittable) {
		return
	}
	ui.main.hide()

	while pendingCmds.length > 0 {
		cmd := pendingCmds.removeAt(1)
		printDebug("submit {}", cmd)
		cmd.submit()
	}

	cmdStr := normalizeCommandString(ui.input.value)
	ui.defaultInputs := moveToOrInsertAt0(ui.defaultInputs, cmdStr)
	ui.input.delete()
	ui.input.add(ui.defaultInputs)
}

cancel(reasonMessage) {
	printDebug("cancel(" reasonMessage ")")
	while pendingCmds.length > 0 {
		cmd := pendingCmds.removeAt(-1)
		printDebug("undo {}", cmd)
		cmd.undo()
	}
	ui.input.value := ""
	ui.main.hide()
}

onValueChange(srcControl, *) {
	cmds := parseCommands(ui.input.text)
	try {
		handleCommandChange(cmds)
	} finally {
		global pendingCmds := cmds
	}
}

handleCommandChange(cmds) {
	printDebug("handleCommandChange")
	diffIndex := findDiffIndex(pendingCmds, cmds, (a, b) => a.equals(b))
	if (diffIndex == 0) {
		return
	}

	global closeOnFocusLost := false
	try {
		; undo pendingCmds which are not in cmds:
		loop pendingCmds.length - diffIndex + 1 {
			cmd := pendingCmds.removeAt(-1)
			printDebug("undo {}", cmd)
			cmd.undo()
		}

		; execute new cmds:
		i := diffIndex
		while (i <= cmds.length) {
			cmd := cmds[i++]
			printDebug("executePreview {}", cmd)
			cmd.executePreview()
		}
	} finally {
		closeOnFocusLost := true
	}
}

parseCommands(cmdStr) {
	global submittable := true
	ui.status.setText("")
	commands := []
	i := 1, len := strlen(cmdStr)
	while (i <= len) {
		currCommands := false
		for (p in config.commandParsers) {
			currCommands := p.parse(cmdStr, &i)
			if (currCommands !== false) { ; p parsed something at i; continue with 1st parser at (already incremented) index
				printDebug(format("parsed `"{}`" (next index {}) into {} commands:", cmdStr, i, currCommands.length))
				for (c in currCommands) {
					printDebug("- {}", c)
					commands.push(c)
				}
				break
			}
		}
		if (currCommands == false) {
			global submittable := false
			ui.status.setText(format("Invalid or incomplete input starting at index {}: {}", i - 1, substr(cmdStr, i)))
			break
		}
	}
	return commands
}

normalizeCommandString(cmdStr) {
	; TODO
	return cmdStr " [" A_NOW "]"
}

; ____________________________________ core types

class CommandParser {
	; returns a Command[] (possibly empty) on success, false otherwise
	parse(cmdStr, &i) {
		return false
	}
}

class Command {
	toString() {
		return type(this)
	}

	equals(other) {
		return type(this) == type(other)
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

class Screen {
	__new(config) {
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
		this.grid := config.hasOwnProp("grid") ? parsePercentage(config.grid, maxSplitValue, "screen grid") : 20
		if (this.defaultSplitValue < 0 || this.grid <= 0) {
			throw ValueError("invalid negative value in screen config")
		}

		if (config.snap is Array && config.snap.length == 2
			&& (this.minValue := parsePercentage(config.snap[1], maxSplitValue, "snap min")) >= 0
			&& (this.maxValue := parsePercentage(config.snap[2], maxSplitValue, "snap max")) >= 0
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
		return format("{}({}, {}, {}x{})", type(this), this.x, this.y, this.w, this.h)
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
			results := [{
				x: this.x,
				y: this.y,
				w: this.splitValue,
				h: this.h }, ;
			{
				x: this.x + this.splitValue,
				y: this.y,
				w: this.w - this.splitValue,
				h: this.h }]
		} else {
			; +-------+  y
			; |       |
			; |       |
			; +-------+ y+s
			; |       |
			; +-------+ y+h
			; x      x+w
			results := [{
				x: this.x,
				y: this.y,
				w: this.w,
				h: this.splitValue }, ;
			{
				x: this.x,
				y: this.y + this.splitValue,
				w: this.w,
				h: this.h - this.splitValue }]
		}
		printDebug("computeTilePositions_() == " dump(results))
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

	addWindow(windowId) {
		if (moveWindowToPos(windowId, this.pos)) {
			this.windowIds.push(windowId)
		}
	}
}

; ____________________________________ commands

class FocusOrPlaceWindowCommandParser extends CommandParser {
	static parseConfig(config) {
		cmd := config.hasOwnProp("run") ? config.run : ""
		return FocusOrPlaceWindowCommandParser(config.input, config.name, config.criteria, cmd)
	}
	__new(windowInput, name, criteria, launchCmdStr := "") {
		this.windowInput := windowInput
		this.name := name
		this.criteria := criteria
		this.launchCmdStr := launchCmdStr
	}
	parse(cmdStr, &i) {
		if (!skip(cmdStr, this.windowInput, &i)) {
			return super.parse(cmdStr, &i)
		}
		t := parseTileParameter(cmdStr, &i)
		cmd := t == false ? FocusWindowCommand(this.name, this.criteria) ;
			: PlaceWindowCommand(t, this.name, this.criteria, this.launchCmdStr)
		return [cmd]
	}
}

class FocusWindowCommand extends Command {
	__new(name, criteria) {
		this.name := name
		this.criteria := criteria
		this.minMax := 0
		this.windowId := 0
	}

	toString() {
		return format("{}({})", type(this), this.name)
	}

	executePreview() {
		this.windowId := winExist(this.criteria)
		if (!this.windowId) {
			return
		}
		this.minMax := winGetMinMax(this.windowId)
		this.otherWindowIds := []
		for wid in winGetList() {
			if (wid == this.windowId) {
				break
			}
			title := winGetTitle(wid)
			printDebug("window before selected: " wid "`t(" WinGetProcessName(wid) ', "' title '")')
			if (wid !== ui.main.hwnd && title !== "") {
				this.otherWindowIds.insertAt(1, wid)
			}
		}

		; save combobox edit position
		this.editSel := sendMessage(0x0140, , , ui.input) ;CB_GETEDITSEL
		printDebug("sendMessage CB_GETEDITSEL result: {} ({}, {})", this.editSel, this.editSel & 0xFFFF, this.editSel >> 16)
		try {
			; focus selected window, then back to our window
			winActivate(this.windowId)
			winActivate(ui.main.hwnd)
		} finally {
			winWaitActive(ui.main.hwnd, , 3)
			; restore combobox edit position
			sendMessage(0x0142, , this.editSel, ui.input) ;CB_SETEDITSEL
		}
	}

	submit() {
		; nothing to do
	}

	; FIXME PlaceWindowCommand builds upon FocusWindowCommand, so FocusWindowCommand must not be undone when
	; replaced by corresponding PlaceWindowCommand.
	undo() {
		if (!this.windowId) {
			return
		}
		switch (this.minMax) {
			case -1: winMinimize(this.windowId)
			case +1: winMaximize(this.windowId)
			default: winRestore(this.windowId)
		}
		for wid in this.otherWindowIds {
			printDebug("restore z-order: " wid)
			;winMoveTop(wid)
			winActivate(wid)
		}
		this.otherWindowIds := []
		winActivate(ui.main.hwnd)
	}
}

class PlaceWindowCommand extends Command {
	__new(selectedTile, name, criteria, launchCmdStr := "") {
		this.selectedTile := selectedTile
		this.windowSpec := {
			name: name,
			criteria: criteria,
			launchCommand: launchCmdStr
		}
		this.placeholderWindow := false
		this.wid := false
		this.oldPosition := false
	}

	toString() {
		return format("{}({}, {})", type(this), this.windowSpec.name, this.selectedTile.toString())
	}

	executePreview() {
		this.wid := winExist(this.windowSpec.criteria)
		if (this.wid) {
			this.oldPosition := getWindowPos(this.wid)
			this.selectedTile.addWindow(this.wid)
			this.placeholderWindow := false
		} else {
			pui := Gui("+Theme +Resize", SHORT_PROGRAM_NAME " - " this.windowSpec.name " (pending launch)")
			pui.addText(, "about to launch: " this.windowSpec.launchCommand)
			; TODO? pui.show()
			; winMoveBottom(pui.hwnd)
			this.selectedTile.addWindow(pui.hwnd)
			this.placeholderWindow := pui
		}
	}

	submit() {
		if (this.placeholderWindow) {
			run(this.windowSpec.launchCommand)
			wid := winWait(this.windowSpec.criteria, , 15)
			if (wid) {
				this.selectedTile.addWindow(wid)
			}
			this.placeholderWindow.destroy()
			this.placeholderWindow := false
			this.oldPosition := false
		}
	}

	undo() {
		if (this.placeholderWindow) {
			this.placeholderWindow.destroy()
			this.placeholderWindow := false
		} else {
			moveWindowToPos(this.wid, this.oldPosition)
			this.wid := false
		}
	}
}

class ResizeSplitCommandParser extends CommandParser {
	static parseConfig(config) {
		return ResizeSplitCommandParser(config.input)
	}
	__new(input) {
		this.input := input
	}
	parse(cmdStr, &i) {
		origI := i
		if (!skip(cmdStr, this.input, &i)) {
			return super.parse(cmdStr, &i)
		}
		resetChar := substr(this.input, -1)
		commands := []

		; 1st arg is mandatory; reset index if missing
		cmd := this.parseArg_(cmdStr, &i, resetChar)
		if (cmd == false) {
			i := origI
			return false
		}
		commands.push(cmd)

		; more optional args
		while (cmd := this.parseArg_(cmdStr, &i, resetChar)) != false {
			commands.push(cmd)
		}
		return commands
	}
	; We create a new Command for each arg in order to get proper undo() e.g. on each press of backspace key
	parseArg_(cmdStr, &i, resetChar) {
		len := strlen(cmdStr)
		if (skip(cmdStr, resetChar, &i)) {
			return ResizeSplitCommand()
		}
		t := parseTileParameter(cmdStr, &i)
		return t == false ? false : ResizeSplitCommand(t)
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
			for (, s in config.screens) {
				s.resetSplit()
			}
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
	parse(cmdStr, &i) {
		if (charAt(cmdStr, i) !== this.startCommentChar) {
			return super.parse(cmdStr, &i)
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
		return []
	}
}

; ____________________________________ config

class Configuration {
	__new(rawConfig) {
		this.hotkey := rawConfig.hotkey
		this.focusKey := rawConfig.focusKey
		this.screens := Configuration.parseScreensConfig_(rawConfig.screens)
		this.commandParsers := Configuration.parseCommandsConfig_(rawConfig.commands)
		printDebug("Configuration ctor end")
	}

	static parseCommandsConfig_(rawCommandsConfigs) {
		parsers := []
		for r in rawCommandsConfigs {
			switch r.command {
				case "placeWindow":
					parser := FocusOrPlaceWindowCommandParser.parseConfig(r)
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
		screens := Map()
		tileInputs := []
		for name, rawConfig in rawConfigs.ownProps() {
			s := Screen(rawConfig)
			screens.set(name, s)
			if (arrayIndexOf(tileInputs, s.tiles[1].input) > 0 || arrayIndexOf(tileInputs, s.tiles[2].input) > 0) {
				throw ValueError("duplicate screen input in " s.tiles[1].input s.tiles[2].input)
			}
			tileInputs.push(s.tiles[1].input, s.tiles[2].input)
		}
		return screens
	}
}

; ____________________________________ utilities

printDebug(formatStr, values*) {
	stringValues := []
	for v in values {
		stringValues.push(String(v))
	}
	fileAppend(format("DEBUG: " formatStr "`n", stringValues*), '**')
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

parseTileParameter(cmdString, &i) {
	for , s in config.screens {
		for t in s.tiles {
			if (skip(cmdString, t.input, &i)) {
				return t
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

initGuiPos(ui, config) {
	ui.main.show()
	pos := getWindowPos(ui.main.hwnd)
	; center in 1st screen:
	for , sTmp in config.screens {
		s := sTmp
		break
	}
	winMove(
		s.x + s.w / 2 - pos.w / 2,
		s.y + s.h / 2 - pos.h / 2, , ,
		ui.main)
	ui.main.hide()
}

getWindowPos(windowId) {
	x := y := w := h := ""
	winGetPos(&x, &y, &w, &h, windowId)
	return { x: x, y: y, w: w, h: h }
}

moveWindowToPos(windowId, pos) {
	return winMove(pos.x, pos.y, pos.w, pos.h, windowId)
}
