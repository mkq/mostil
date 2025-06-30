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

class Position {
	__new(x, y, w, h) {
		this.x := x
		this.y := y
		this.w := w
		this.h := h
	}

	toString() {
		return format('{}({}, {}, {}x{})', type(this), this.x, this.y, this.w, this.h)
	}
}

; An area split vertically or horizontally, thereby consisting of two Tiles.
class Screen {
	__new(name, pos, horizontal, minSplitValue, maxSplitValue, defaultSplitValue, splitStepSize, uiConfig, tiles) {
		this.config := {
			name: name,
			position: pos,
			horizontal: horizontal,
			minSplitValue: minSplitValue,
			maxSplitValue: maxSplitValue,
			defaultSplitValue: defaultSplitValue,
			splitStepSize: splitStepSize,
			gui: uiConfig
		}
		this.tiles := tiles ; Map: input -> Tile
		this.tiles.default := false
		this.splitValue := this.config.defaultSplitValue
		this.gui := {
			gui: (g := Screen.initGui_(name, pos, uiConfig)).gui,
			input: g.input,
			statusBar: g.statusBar
		}
		for , t in tiles {
			t.screen := this
		}
	}

	static initGui_(name, pos, uiConfig) {
		printDebug("init GUI for screen {}", name)
		g := Gui("+Theme", format('{} - screen "{}"', LONG_PROGRAM_NAME, name))
		result := { gui: g, input: false, statusBar: false }
		;g.backColor := "81f131"
		;winSetTransColor(g.backColor, g)
		if (uiConfig.hasInput) {
			input := g.addComboBox("w280 vCmd", [])
			input.onEvent("Change", onValueChange)
			okButton := g.addButton("Default w60 x+0", "OK")
			cancelButton := g.addButton("w60 x+0", "Cancel")
			okButton.onEvent("Click", (*) => submit())
			cancelButton.onEvent("Click", (*) => cancel('Button'))
			result.input := input
			result.statusBar := g.addStatusBar()
		}
		g.onEvent("Close", (*) => cancel('window closed'))
		g.onEvent("Escape", (*) => cancel('escape'))
		g.show()
		moveWindowToPos(g, pos)

		g.hide()
		return result
	}

	toString() {
		return format('{}("{}", {})', type(this), this.config.name, String(this.config.position))
	}

	hasInput() {
		return this.gui.input != false
	}

	computeTilePositions_() {
		p := config.position
		if (this.config.horizontal) {
			; +-------+--------------+    y
			; |       |              |
			; +-------+--------------+   y+h
			; x      x+s            x+w
			results := [ ;
				{ x: p.x, y: p.y, w: this.splitValue, h: p.h }, ;
				{ x: p.x + this.splitValue, y: p.y, w: p.w - this.splitValue, h: p.h }]
		} else {
			; +-------+  y
			; |       |
			; |       |
			; +-------+ y+s
			; |       |
			; +-------+ y+h
			; x      x+w
			results := [ ;
				{ x: p.x, y: p.y, w: p.w, h: this.splitValue }, ;
				{ x: p.x, y: p.y + this.splitValue, w: p.w, h: p.h - this.splitValue }]
		}
		printDebugF("computeTilePositions_() == {}", () => [dump(results)])
		return results
	}

	moveSplit(tileIndex := 0) {
		this.splitValue := tileIndex == 1 ? max(this.splitValue - this.config.splitStepSize, this.config.minSplitValue) :
			tileIndex == 2 ? min(this.splitValue + this.config.splitStepSize, this.config.maxSplitValue) :
			this.config.defaultSplitValue
		tilePositions := this.computeTilePositions_()
		this.tiles[1].setPosition(tilePositions[1])
		this.tiles[2].setPosition(tilePositions[2])
	}

	resetSplit() {
		return this.moveSplit()
	}
}

; One "half" of a Screen
class Tile {
	__new(index, name) {
		this.screen := false
		this.index := index
		this.name := name
		this.icon := { handle: 0, file: "", index: 0 }
		this.text := ""
		this.windowIds := []
	}

	toString() {
		return format("{}({}[{}], key `"{}`")", type(this), this.screen.toString(), this.index, this.name)
	}

	drawTo(pos)
	{
		; TODO: complete
		; TODO: move to Screen?
		;this.guiCtrl := this.screen.gui.gui.addGroupBox(
		;	format("x{} y{} w{} h{}", pos.x + PAD_X, pos.y + PAD_Y, pos.w - 2 * PAD_X, pos.h - 2 * PAD_Y),
		;	this.name)
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
		if (moveWindowToPos(windowId, this.pos)) {
			this.windowIds.push(windowId)
		}
	}

	getText() {
		; TODO
	}
	setText(text) {
		; TODO
	}

	getIcon() {
		;TODO
	}
	setIcon(previousSetIconResult) {
		;TODO
	}
	setIconFromFile(file, index := 1) {
		; TODO set icon and return something that setIcon can handle
	}
	setIconFromHandle(hIcon) {
		; TODO set icon and return something that setIcon can handle
	}
}

class ScreensManager {
	__new(screens) {
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
		if (!this.screenWithInput) {
			this.screenWithInput := screens[0]
			printDebugF("choosing input GUI: {}", this.screenWithInput)
		}
		this.screens := screens
	}

	show() {
		this.forEachInputScreenLast_(s => s.gui.gui.show())
	}

	hide() {
		this.forEachInputScreenLast_(s => s.gui.gui.hide())
	}

	forEachInputScreenLast_(f) {
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