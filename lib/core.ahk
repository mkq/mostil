#include %A_ScriptDir%/lib/util.ahk

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
	__new(input, command) {
		this.input := input
		this.command := command
	}

	toString() {
		return format('["{}" → {}]', this.input, String(this.command))
	}
}

; An area split vertically or horizontally, thereby consisting of two Tiles.
class Screen {
	__new(name, targetSplitPosition, guiPosition, withInput, tiles) {
		if !(tiles is Array && tiles.length == 2) {
			throw ValueError("tiles is not an array of length 2")
		}
		this.name := name
		this.input := withInput
		this.targetSplitPosition := targetSplitPosition
		this.guiPosition := guiPosition
		this.tiles := tiles
		for t in tiles {
			t.screen := this
		}
		this.gui := false ; when initialized: { gui: Gui, input: ComboBox, statusBar: StatusBar, splitPosition: SplitPosition }
	}

	toString() {
		return format('{}("{}", {})', type(this), this.name, String(this.targetSplitPosition))
	}

	hasInput() {
		return this.input
	}

	show() {
		if (!this.gui) {
			this.initGui_()
		}
		this.gui.gui.show()
	}

	hide() {
		if (this.gui) {
			this.gui.gui.hide()
		}
	}

	initGui_() {
		printDebug("init GUI for screen {}", this.toString())
		g := Gui("+Theme", format('{} - screen "{}"', LONG_PROGRAM_NAME, this.name))

		g.show()
		moveWindowToPos(g, this.guiPosition)
		windowRelativePos := getWindowClientPos(g)
		windowRelativePos.x := windowRelativePos.y := 0
		splitPos := SplitPosition(this.targetSplitPosition.horizontal,
			windowRelativePos,
			this.targetSplitPosition.defaultSplitPercentage,
			this.targetSplitPosition.minSplitPercentage,
			this.targetSplitPosition.maxSplitPercentage,
			this.targetSplitPosition.stepPercentage)
		groupBoxes := []
		for i, tilePos in splitPos.getChildPositions() {
			groupBoxes.push(g.addGroupBox(, this.tiles[i].name))
		}

		input := false
		status := false
		if (this.hasInput()) {
			g.onEvent("Close", (*) => exitApp())
			; TODO center input and buttons
			input := g.addComboBox("w280 vCmd", [])
			input.focus()
			input.onEvent("Change", onValueChange)
			okButton := g.addButton("Default w60 x+0", "OK")
			cancelButton := g.addButton("w60 x+0", "Cancel")
			okButton.onEvent("Click", (*) => submit())
			cancelButton.onEvent("Click", (*) => cancel('Button'))
			status := g.addStatusBar()
		}
		g.onEvent("Close", (*) => cancel('window closed'))
		g.onEvent("Escape", (*) => cancel('escape'))

		this.gui := {
			splitPosition: splitPos,
			gui: g,
			input: input,
			groupBoxes: groupBoxes,
			statusBar: status
		}
		this.onMoveSplit_()
	}

	resetSplit() {
		return this.moveSplit()
	}

	moveSplit(tileIndex := 0) {
		if (tileIndex == 0) {
			this.targetSplitPosition.reset()
			this.gui.splitPosition.reset()
		} else if (tileIndex == 1 || tileIndex == 2) {
			inc := tileIndex == 1 ? -1 : 1
			this.targetSplitPosition.increment(inc)
			this.gui.splitPosition.increment(inc)
		} else {
			throw ValueError("tile index " tileIndex)
		}
		this.onMoveSplit_()
	}

	onMoveSplit_() {
		if (!this.gui) {
			return
		}
		for i, gbp in this.gui.splitPosition.getChildPositions() {
			controlMove(gbp.x, gbp.y, gbp.w, gbp.h, this.gui.groupBoxes[i])
		}
	}

	moveWindowToTileIndex(windowId, i) {
		pos := this.targetSplitPosition.getChildPositions()[i]
		return moveWindowToPos(windowId, pos)
	}

	updateWindowPositions() {
		; TODO
	}
}

; One "half" of a Screen
class Tile {
	__new(index, name, input) {
		this.index := index
		this.name := name
		this.input := input
		this.screen := false
		this.windowIds := []
		this.icon_ := Icon()
		this.text_ := ""
	}

	toString() {
		return format("{} [{}] of {}", type(this), this.index, this.screen.toString())
	}

	text {
		get => this.text_
		set => this.text_ := value
	}

	; A Tile has a real icon and text only temporarily when PlaceWindowCommand sets it to show
	; a preview of its action. However, this is implemented as an always present Icon instance
	; which can also (and initially does) represent a null Icon:
	icon {
		get => this.icon_
	}

	; Moves the parent screen's split in the direction corresponding to this tile, making this tile smaller and the sibling
	; tile bigger.
	moveSplit() {
		this.screen.moveSplit(this.index)
	}

	; Called by the parent screen to move all windows placed in this tile to the given coordinates.
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
		if (this.screen.moveWindowToTileIndex(windowId, this.index)) {
			this.windowIds.push(windowId)
		}
	}
}

class Icon {
	__new() {
		this.file := ""
		this.index := 0
		this.handle := 0
	}

	guiAddOption {
		get => strlen(this.file) > 0 && this.index ? ("Icon" this.index) : false
	}
	guiAddArg {
		get => strlen(this.file) > 0 ? this.file : this.handle ? ("hicon" this.handle) : false
	}
	; can be used to save and restore the current state, but uses an internal unspecified format:
	internalFormat {
		get => { file: this.file, index: this.index, handle: this.handle }
		set {
			this.file := getProp(value, "file", "")
			this.index := getProp(value, "index", 1)
			this.handle := getProp(value, "handle", 0)
		}
	}

	setToFile(file, index := 1) {
		this.internalFormat := { file: file, index: index }
	}

	setToHandle(hIcon) {
		this.internalFormat := { handle: hIcon }
	}
}

class ScreensManager {
	__new(screens) {
		if (screens.length < 1) {
			throw ValueError("no screens")
		}
		this.screenWithInput := false
		for s in screens {
			if (s.hasInput()) {
				if (this.screenWithInput) {
					throw ValueError("multiple GUIs with input")
				} else {
					this.screenWithInput := s
				}
			}
		}
		this.screens := screens
	}

	show() {
		this.forEachScreenInputScreenLast(s => s.show())
	}

	hide() {
		this.forEachScreen(s => s.hide())
	}

	forEachScreen(f) {
		for s in this.screens {
			f(s)
		}
	}

	forEachScreenInputScreenLast(f) {
		for s in this.screens {
			if (s !== this.screenWithInput) {
				f(s)
			}
		}
		f(this.screenWithInput)
	}

	containsWindowId(windowId) {
		for s in this.screens {
			if (s.gui.hwnd == windowId) {
				return true
			}
		}
		return false
	}
}
