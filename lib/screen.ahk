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

	initGui_(app) {
		Mostil.Util.printDebug("init GUI for screen {}", this.toString())
		g := Gui("+Theme", format('{} - screen "{}"', Mostil.LONG_PROGRAM_NAME, this.name))

		g.show()
		Mostil.WindowUtil.moveWindowToPos(g, this.guiPosition, app.errorHandler)
		windowClientPos := Mostil.Position.ofWindowClient(g)
		windowRelativePos := Mostil.Position(0, 0, windowClientPos.w, windowClientPos.h)
		splitPos := Mostil.SplitPosition(this.targetSplitPosition.horizontal,
			windowRelativePos,
			this.targetSplitPosition.defaultSplitPercentage,
			this.targetSplitPosition.minSplitPercentage,
			this.targetSplitPosition.maxSplitPercentage,
			this.targetSplitPosition.stepPercentage)
		groupBoxes := []
		for i, tilePos in splitPos.getChildPositions() {
			groupBoxes.push(g.addGroupBox(, this.tiles[i].name))
		}
		Mostil.Screen.setGroupBoxSizes_(groupBoxes, splitPos)

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

		pics := Mostil.Util.arrayMap(this.tiles, t => g.addPicture(Mostil.Screen.iconPos_(groupBoxes[t.index]).toGuiOption(), A_AHKPATH))
		icons := Mostil.Util.arrayMap(pics, p => Mostil.Icon(p))
		Mostil.Util.arrayMap(icons, i => i.updatePicture()) ; clear dummy icon from picture

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

	resetSplit(errorHandler) {
		return this.moveSplit(errorHandler)
	}

	moveSplit(errorHandler, tileIndex := 0) {
		oldPos := this.gui.splitPosition.splitPercentage
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
		Mostil.Screen.setGroupBoxSizes_(this.gui.groupBoxes, this.gui.splitPosition)
		diffPos := this.gui.splitPosition.splitPercentage.addPercentage(oldPos, -1)
		for i, p in this.gui.pictures {
			gb := this.gui.groupBoxes[i]
			Mostil.WindowUtil.moveWindowToPos(p, Mostil.Screen.iconPos_(gb), errorHandler)
			gb.redraw()
			; TODO move tile texts
		}
	}

	static iconPos_(gb) {
		; TODO make icons square and limit size
		return Mostil.Position.ofGuiControl(gb).center(1 / 12)
	}

	static setGroupBoxSizes_(groupBoxes, splitPosition) {
		for i, gbp in splitPosition.getChildPositions() {
			controlMove(gbp.x, gbp.y, gbp.w, gbp.h, groupBoxes[i])
		}
	}

	moveWindowToTileIndex(windowId, i, errorHandler) {
		pos := this.targetSplitPosition.getChildPositions()[i]
		return Mostil.WindowUtil.moveWindowToPos(windowId, pos, errorHandler)
	}

	updateWindowPositions() {
		; TODO
	}
}
