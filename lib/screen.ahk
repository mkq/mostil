#include %A_SCRIPTDIR%/lib/util.ahk
#include %A_SCRIPTDIR%/lib/tile.ahk

; An area split vertically or horizontally, thereby consisting of two Tiles.
class Screen {
	static ICON_COUNT {
		get => 8
	}
	static MAX_ICON_SIZE {
		get => 256
	}

	__new(name, targetSplitPosition, guiPosition, withInput, tiles) {
		if !(tiles is Array && tiles.length == 2) {
			throw ValueError("tiles is not an array of length 2")
		}
		this.name := name
		this.hasInput := withInput
		Util.printDebug('hasInput: {}', this.hasInput)
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

	input {
		get => this.gui.input
	}

	initGui_(app, errorHandler) {
		Util.printDebug("init GUI for screen {}", this.toString())
		g := Gui("+Theme -DPIScale -Caption", format('{} - screen "{}"', app.name, this.name))
		this.gui := { gui: g }

		g.show()
		WindowUtil.moveWindowToPos(g, this.guiPosition, errorHandler)
		windowClientPos := Position.ofWindowClient(g)
		splitPos := Screen.computeGuiSplitPos_(windowClientPos, this.targetSplitPosition)
		groupBoxes := []
		for i, tilePos in splitPos.getChildPositions() {
			groupBoxes.push(g.addGroupBox(, this.tiles[i].name))
		}
		Screen.setGroupBoxSizes_(groupBoxes, splitPos)

		inputControl := false
		status := false
		if (this.hasInput) {
			g.onEvent("Close", (*) => exitApp())
			buttonW := 80
			inputW := min(600, windowClientPos.w)
			inputControl := g.addComboBox(format('w{} x{} y{} vCmd',
				inputW,
				(windowClientPos.w - inputW - 3 * buttonW) / 2,
				windowClientPos.h / 2 - 20))
			inputControl.focus()
			inputControl.onEvent("Change", (*) => app.onValueChange())
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

		this.gui := {
			splitPosition: splitPos,
			gui: g,
			input: inputControl,
			; 2-element array (one per tile) of at most ICON_COUNT-element arrays.
			; Grows as needed, but never shrinks, because class Gui has no method to remove a control.
			pictures: [[], []],
			groupBoxes: groupBoxes,
			statusBar: status
		}
	}

	windowInserted(tileIndex, windows, windowIndex) {
		pictures := this.gui.pictures[tileIndex]
		if (windowIndex > pictures.length) {
			pos := Screen.iconPos_(this.gui.groupBoxes[tileIndex], tileIndex).toGuiOption()
			pic := this.gui.gui.addPicture(pos, A_AHKPATH)
			pictures.insertAt(windowIndex, pic)
		}
		for i in Util.seq(pictures.length, windowIndex) {
			windows[i].icon.updatePicture(pictures[i])
		}
	}

	windowRemoved(tileIndex, windows, windowIndex) {
		pictures := this.gui.pictures[tileIndex]
		for i in Util.seq(pictures.length, windowIndex) {
			ico := i > windows.length ? Icon.blank() : windows[i].icon
			ico.updatePicture(pictures[i])
		}
	}

	static computeGuiSplitPos_(guiPosition, targetSplitPosition) {
		windowRelativePos := Position(0, 0, guiPosition.w, guiPosition.h)
		return SplitPosition(targetSplitPosition.horizontal,
			windowRelativePos,
			targetSplitPosition.defaultSplitPercentage,
			targetSplitPosition.minSplitPercentage,
			targetSplitPosition.maxSplitPercentage,
			targetSplitPosition.stepPercentage)
	}

	; Moves the split "towards" a tile given by index or resets it to the default position.
	; @param tileIndex: 0 = reset; 1 = make tile 1 smaller and 2 bigger; 2 = make tile 2 smaller and 1 bigger
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

	resetSplit(errorHandler) {
		return this.moveSplit(errorHandler)
	}

	updateTileGui_(errorHandler) {
		Screen.setGroupBoxSizes_(this.gui.groupBoxes, this.gui.splitPosition)
		for i, pics in this.gui.pictures {
			gb := this.gui.groupBoxes[i]
			for j, pic in pics {
				WindowUtil.moveWindowToPos(pic, Screen.iconPos_(gb, j), errorHandler)
				; gb.redraw()
				; TODO move tile texts
			}
		}
		winRedraw(this.gui.gui) ; TODO Is gb.redraw() sufficient?
	}

	updateWindowPositions() {
		; TODO
	}

	static iconPos_(parentControl, i) {
		p := Position.ofGuiControl(parentControl).center(1 / 8)
		p.x := 10 + 20 * i
		p.h := p.w := min(p.h, p.w, Screen.MAX_ICON_SIZE) ; make square & limit size
		return p
	}

	static setGroupBoxSizes_(groupBoxes, splitPosition) {
		for i, gbp in splitPosition.getChildPositions() {
			controlMove(gbp.x, gbp.y, gbp.w, gbp.h, groupBoxes[i])
		}
	}

	moveWindowToTileIndex(windowId, i, errorHandler) {
		pos := this.targetSplitPosition.getChildPositions()[i]
		return WindowUtil.moveWindowToPos(windowId, pos, errorHandler)
	}

	setSplitToPercentage(p, errorHandler) {
		windowClientPos := Position.ofWindowClient(this.gui.gui)
		this.targetSplitPosition.setSplitPercentage(Util.checkType(Percentage, p))
		this.gui.splitPosition.setSplitPercentage(p)
		this.updateTileGui_(errorHandler)
	}

	show(app, errorHandler) {
		if (!this.gui) {
			this.initGui_(app, errorHandler)
		}
		this.gui.gui.show()
	}

	hide() {
		if (this.gui) {
			this.gui.gui.hide()
		}
	}
}