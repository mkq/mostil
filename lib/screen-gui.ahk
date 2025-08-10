#include %A_SCRIPTDIR%/lib/util.ahk
#include %A_SCRIPTDIR%/lib/icon.ahk
#include %A_SCRIPTDIR%/lib/screen.ahk
#include %A_SCRIPTDIR%/lib/tile.ahk

class ScreenGui {
	__new(scr, pos, config, withInput, targetSplitPosition) {
		Util.printDebug("init GUI for screen {} (with{} input)", scr.toString(), withInput ? '' : 'out')
		this.screen := scr
		this.position := pos
		this.config := config
		this.hasInput := withInput
		this.targetSplitPosition := targetSplitPosition

		this.gui := false
		this.input := false
	}

	show(app, errorHandler) {
		if (!this.gui) {
			this.initGui_(app, errorHandler)
		}
		this.gui.show()
	}

	hide() {
		this.gui.hide()
	}

	initGui_(app, errorHandler) {
		this.gui := g := Gui("+Theme -DPIScale -Caption", format('{} - screen "{}"', app.name, this.screen.name))
		g.show()
		WindowUtil.moveWindowToPos(g, this.position, errorHandler)
		windowClientPos := Position.ofWindowClient(g)
		this.splitPosition := SplitPosition(this.targetSplitPosition.horizontal,
			Position(0, 0, windowClientPos.w, windowClientPos.h), ; window-relative position
			this.targetSplitPosition.defaultSplitPercentage,
			this.targetSplitPosition.minSplitPercentage,
			this.targetSplitPosition.maxSplitPercentage,
			this.targetSplitPosition.stepPercentage)

		this.statusBar := false
		if (this.hasInput) {
			g.onEvent("Close", (*) => exitApp())
			buttonW := 80
			inputW := min(600, windowClientPos.w)
			this.input := g.addComboBox(format('w{} x{} y{} vCmd',
				inputW,
				(windowClientPos.w - inputW - 3 * buttonW) / 2,
				windowClientPos.h / 2 - 20))
			this.input.focus()
			this.input.onEvent("Change", (*) => app.onValueChange())
			okButton := g.addButton(format('Default w{} x+0', buttonW), "OK")
			cancelButton := g.addButton(format('w{} x+0', buttonW), "Cancel")
			reloadButton := g.addButton(format('w{} x+0', buttonW), "&Reload")
			okButton.onEvent("Click", (*) => app.submit())
			cancelButton.onEvent("Click", (*) => app.cancel('Button'))
			reloadButton.onEvent("Click", (*) => reload()) ; TODO remove
			this.statusBar := g.addStatusBar()
		}
		g.onEvent("Close", (*) => app.cancel('window closed'))
		g.onEvent("Escape", (*) => app.cancel('escape'))

		this.tiles := Util.arrayMap(this.screen.tiles, (ti, t) => this.initTileGui_(t, ti, g, this.splitPosition))
		this.setGroupBoxSizes_()
	}

	; the per-Tile GUI elements
	initTileGui_(t, tileIndex, g, splitPos) {
		gb := g.addGroupBox(, t.name)
		pos := this.splitPosition.getChildPositions()[tileIndex]
		Util.printDebugF('GroupBox[{}] position: {}', () => [tileIndex, pos])
		controlMove(pos.x, pos.y, pos.w, pos.h, gb)
		pics := []
		pics.length := this.config.maxIconCount
		; reverse order in case of overlapping icons ([1] hides [2], etc.)
		for ii in Util.seq(this.config.maxIconCount, 1) {
			pictureOpts := ScreenGui.iconPos_(gb, ii, this.config).toGuiOption()
			pic := g.addPicture(pictureOpts, A_AHKPATH)
			pics[ii] := pic
			Icon.blank().updatePicture(pic)
			ii2 := ii
			Util.printDebugF('[{}] Picture[{}] options: {}', () => [ii2, pics.length, pictureOpts])
		}
		return {
			groupBox: gb,
			pictures: pics,
		}
	}

	windowsChanged(tileIndex, windows) {
		pictures := this.tiles[tileIndex].pictures
		for i, pic in pictures {
			ico := i > windows.length ? Icon.blank() : windows[i].icon
			ico.updatePicture(pic)
		}
	}

	moveSplit(errorHandler, tileIndex) {
		if (tileIndex == 0) {
			this.splitPosition.reset()
		} else if (tileIndex == 1 || tileIndex == 2) {
			inc := tileIndex == 1 ? -1 : 1
			this.splitPosition.increment(inc)
		} else {
			throw ValueError("tile index " tileIndex)
		}
		this.updateTiles_(errorHandler)
	}

	setSplitToPercentage(p, errorHandler) {
		windowClientPos := Position.ofWindowClient(this.gui)
		this.splitPosition.setSplitPercentage(p)
		this.updateTiles_(errorHandler)
	}

	updateTiles_(errorHandler) {
		this.setGroupBoxSizes_()
		for i, gt in this.tiles {
			for j, pic in gt.pictures {
				WindowUtil.moveWindowToPos(pic, ScreenGui.iconPos_(gt.groupBox, j, this.config), errorHandler)
				gt.groupBox.redraw()
				; TODO move tile text(s)
			}
		}
	}

	updateWindowPositions(errorHandler) {
		for ti, t in this.tiles {
			pos := this.targetSplitPosition.getChildPositions()[ti]
			for w in t.windows {
				WindowUtil.moveWindowToPos(w.id, pos, errorHandler)
			}
		}
	}

	moveWindowToTileIndex(windowId, i, errorHandler) {
		pos := this.targetSplitPosition.getChildPositions()[i]
		return WindowUtil.moveWindowToPos(windowId, pos, errorHandler)
	}

	static iconPos_(parentControl, i, config) {
		pParent := Position.ofGuiControl(parentControl)
		pSize := min(pParent.h, pParent.w)
		pCenter := pParent.center(config.iconScale.toFactor())
		maxSize := config.maxIconSize.of(pSize)
		size := min(pCenter.h, pCenter.w, maxSize) ; make square & limit size
		pos := Position.ofFloats(
			pParent.x + config.iconOffsetX.of(pSize) + config.iconDist.of(pSize) * (i - 1),
			pCenter.y,
			size,
			size)
		Util.printDebugF('iconPos_({}, {}, {}) == {}', () => [Util.dump(parentControl), i, Util.dump(config), pos])
		return pos
	}

	setGroupBoxSizes_() {
		for ti, tPos in this.splitPosition.getChildPositions() {
			controlMove(tPos.x, tPos.y, tPos.w, tPos.h, this.tiles[ti].groupBox)
		}
	}
}