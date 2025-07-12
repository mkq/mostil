#include %A_SCRIPTDIR%/lib/util.ahk
#include %A_SCRIPTDIR%/lib/tile.ahk

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

	initGui_(app) {
		Util.printDebug("init GUI for screen {}", this.toString())
		captionOpt := this.hasInput() ? '' : ' -Caption'
		g := Gui("+Theme" . captionOpt, format('{} - screen "{}"', Mostil.LONG_PROGRAM_NAME, this.name))
		this.gui := { gui: g }

		g.show()
		WindowUtil.moveWindowToPos(g, this.guiPosition, app.errorHandler)
		windowClientPos := Position.ofWindowClient(g)
		splitPos := this.computeGuiSplitPos_()
		groupBoxes := []
		for i, tilePos in splitPos.getChildPositions() {
			groupBoxes.push(g.addGroupBox(, this.tiles[i].name))
		}
		Screen.setGroupBoxSizes_(groupBoxes, splitPos)

		input := false
		status := false
		if (this.hasInput()) {
			g.onEvent("Close", (*) => exitApp())
			buttonW := 50
			inputW := min(500, windowClientPos.w)
			input := g.addComboBox(format('w{} x{} y{} vCmd', inputW, (windowClientPos.w - inputW) / 2 - buttonW, windowClientPos.h / 2 - 20, []))
			input.focus()
			input.onEvent("Change", (*) => app.onValueChange())
			okButton := g.addButton(format('Default w{} x+0', buttonW), "OK")
			cancelButton := g.addButton(format('w{} x+0', buttonW), "Cancel")
			reloadButton := g.addButton(format('w{} x+0', buttonW), "&Reload")
			okButton.onEvent("Click", (*) => app.submit())
			cancelButton.onEvent("Click", (*) => app.cancel('Button'))
			reloadButton.onEvent("Click", (*) => reload()) ; TODO remove
			status := g.addStatusBar()
		}
		g.onEvent("Close", (*) => app.cancel('window closed'))
		g.onEvent("Escape", (*) => app.cancel('escape'))

		pics := Util.arrayMap(this.tiles, t => g.addPicture(Screen.iconPos_(groupBoxes[t.index]).toGuiOption(), A_AHKPATH))
		icons := Util.arrayMap(pics, p => Icon(p))
		Util.arrayMap(icons, i => i.updatePicture()) ; clear dummy icon from picture

		; TODO add tile texts

		this.gui := {
			splitPosition: splitPos,
			gui: g,
			input: input,
			pictures: pics,
			groupBoxes: groupBoxes,
			statusBar: status
		}
		this.icons := icons
	}

	computeGuiSplitPos_() {
		windowClientPos := Position.ofWindowClient(this.gui.gui)
		windowRelativePos := Position(0, 0, windowClientPos.w, windowClientPos.h)
		return SplitPosition(this.targetSplitPosition.horizontal,
			windowRelativePos,
			this.targetSplitPosition.defaultSplitPercentage,
			this.targetSplitPosition.minSplitPercentage,
			this.targetSplitPosition.maxSplitPercentage,
			this.targetSplitPosition.stepPercentage)
	}

	setSplitToPercentage(p, errorHandler) {
		this.targetSplitPosition.setSplitPercentage(Util.checkType(Percentage, p))
		this.gui.splitPosition := this.computeGuiSplitPos_()
		this.updateTileGui_(errorHandler)
	}

	resetSplit(errorHandler) {
		return this.moveSplit(errorHandler)
	}

	; Moves the split "towards" a tile given by index or resets it to the default position.
	; @param tileIndex: 0 = reset; 1 = make tile 1 smaller and 2 bigger; 2 make tile 2 smaller and 1 bigger
	moveSplit(errorHandler, tileIndex := 0) {
		if (tileIndex == 0) {
			oldPercentage := this.targetSplitPosition.reset()
			this.gui.splitPosition.reset()
		} else if (tileIndex == 1 || tileIndex == 2) {
			inc := tileIndex == 1 ? -1 : 1
			oldPercentage := this.targetSplitPosition.increment(inc)
			this.gui.splitPosition.increment(inc)
		} else {
			throw ValueError("tile index " tileIndex)
		}
		this.gui.splitPosition.splitPercentage.addPercentage(oldPercentage, -1)
		this.updateTileGui_(errorHandler)
		return oldPercentage
	}

	updateTileGui_(errorHandler) {
		Screen.setGroupBoxSizes_(this.gui.groupBoxes, this.gui.splitPosition)
		for i, p in this.gui.pictures {
			gb := this.gui.groupBoxes[i]
			WindowUtil.moveWindowToPos(p, Screen.iconPos_(gb), errorHandler)
			;gb.redraw()
			; TODO move tile texts
		}
		winRedraw(this.gui.gui) ; TODO Is gb.redraw() sufficient?
	}

	hasInput() {
		return this.input
	}

	show(app) {
		if (!this.gui) {
			this.initGui_(app)
		}
		this.gui.gui.show()
	}

	hide() {
		if (this.gui) {
			this.gui.gui.hide()
		}
	}

	moveWindowToTileIndex(windowId, i, errorHandler) {
		pos := this.targetSplitPosition.getChildPositions()[i]
		return WindowUtil.moveWindowToPos(windowId, pos, errorHandler)
	}

	updateWindowPositions() {
		; TODO
	}

	static iconPos_(gb) {
		; TODO make icons square and limit size
		return Position.ofGuiControl(gb).center(1 / 12)
	}

	static setGroupBoxSizes_(groupBoxes, splitPosition) {
		for i, gbp in splitPosition.getChildPositions() {
			controlMove(gbp.x, gbp.y, gbp.w, gbp.h, groupBoxes[i])
		}
	}
}
