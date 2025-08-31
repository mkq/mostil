#include %A_SCRIPTDIR%/lib/util.ahk
#include %A_SCRIPTDIR%/lib/icon.ahk
#include %A_SCRIPTDIR%/lib/screen.ahk
#include %A_SCRIPTDIR%/lib/tile.ahk

class ScreenGui {
	static BLANK_ICON_ := Icon.blank()
	static DUMMY_TILE_WINDOW_ := Tile.Window(0, ScreenGui.BLANK_ICON_, '')

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
		g.setFont('s12')
		this.splitPosition := SplitPosition(this.targetSplitPosition.horizontal,
			Position(0, 0, windowClientPos.w, windowClientPos.h), ; window-relative position
			this.targetSplitPosition.defaultSplitPercentage,
			this.targetSplitPosition.minSplitPercentage,
			this.targetSplitPosition.maxSplitPercentage,
			this.targetSplitPosition.stepPercentage)

		this.tiles := Util.arrayMap(this.screen.tiles, (ti, t) => this.initTileGui_(t, ti, g, this.splitPosition, errorHandler))
		this.setGroupBoxSizes_()
		this.moveTexts_(errorHandler)

		this.statusBar := false
		if (this.hasInput) {
			g.onEvent("Close", (*) => exitApp())
			inputW := min(700, windowClientPos.w)
			this.input := g.addComboBox(format('w{} x{} y{} vCmd',
				inputW,
				(windowClientPos.w - inputW) / 2,
				windowClientPos.h / 2 - 20))
			this.input.focus()
			this.input.onEvent("Change", (*) => app.onValueChange())
			; invisible OK button to handle enter in the combobox:
			okButton := g.addButton('Default w42 x+0', "OK")
			okButton.onEvent("Click", (*) => app.submit())
			okButton.visible := false
			this.statusBar := g.addStatusBar()
		}

		for ti, t in this.screen.tiles {
			this.windowsChanged(ti, t.windows.length > 0 ? t.windows : [ScreenGui.DUMMY_TILE_WINDOW_], errorHandler)
		}
		g.onEvent("Close", (*) => app.cancel('window closed'))
		g.onEvent("Escape", (*) => app.cancel('escape'))
	}

	; the per-Tile GUI elements
	initTileGui_(t, tileIndex, g, splitPos, errorHandler) {
		gb := g.addGroupBox(, t.name)
		pos := this.splitPosition.getChildPositions()[tileIndex]
		Util.printDebugF('GroupBox[{}] position: {}', () => [tileIndex, pos])
		controlMove(pos.x, pos.y, pos.w, pos.h, gb)
		text := g.addText('w10', '')
		text.setFont('s12')

		return {
			groupBox: gb,
			pictures: [],
			text: text,
		}
	}

	windowsChanged(tileIndex, windows, errorHandler) {
		tg := this.tiles[tileIndex]

		; update existing pictures
		for i, pic in tg.pictures {
			ico := i > windows.length ? ScreenGui.BLANK_ICON_ : windows[i].icon
			ico.updatePicture(pic)
		}

		; add pictures
		requiredPictureCount := min(windows.length, this.config.maxIconCount)
		if (tg.pictures.length < requiredPictureCount) {
			for i in Util.seq(tg.pictures.length + 1, requiredPictureCount) {
				pictureOpts := ScreenGui.iconPos_(tg.groupBox, i, this.config).toGuiOption()
				pic := this.gui.addPicture(pictureOpts, A_AHKPATH)
				windows[i].icon.updatePicture(pic)
				tg.pictures.push(pic)
				i2 := i ; copy for closure bug
				Util.printDebugF('[{}] Picture[{}] options: {}', () => [i2, tg.pictures.length, pictureOpts])
				winMoveTop(pic)
			}
		}

		tg.text.text := windows.length > 0 ? windows[1].text : ''
		this.moveTexts_(errorHandler)
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
			gb := gt.groupBox
			for j, pic in gt.pictures {
				WindowUtil.moveWindowToPos(pic, ScreenGui.iconPos_(gb, j, this.config), errorHandler)
			}
			gb.redraw()
		}
		this.moveTexts_(errorHandler)
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
			; For groupboxes on top of each other with distance 0, both borders are visible (because the top border is
			; "misplaced" by half the label height). For side-by-side groupboxes, the borders draw over each other.
			; ┌─[v1]──┐  ┌─[h1]───┬─[h2]────┐
			; │       │  │        │         │
			; └───────┘  └────────┴─────────┘
			; ┌─[v2]──┐
			; └───────┘
			; Therefore, for a consistent look, shrink them a bit in horizontal mode:
			if (this.splitPosition.horizontal) {
				tPos.w -= 4
				if (ti == 2) {
					tPos.x += 4
				}
			}

			controlMove(tPos.x, tPos.y, tPos.w, tPos.h, this.tiles[ti].groupBox)
		}
	}

	moveTexts_(errorHandler) {
		for ti, tg in this.tiles {
			if (tg.pictures.length == 0) {
				continue
			}
			picPos := Position.ofGuiControl(tg.pictures[1])
			gbPos := Position.ofGuiControl(tg.groupBox)
			textPos := Position.ofGuiControl(tg.text)
			newTextPos := Position.ofFloats(picPos.x, picPos.y + picPos.h + textPos.h / 2, gbPos.w, textPos.h)
			Util.printDebugF('moveTexts_: {} → {}', () => [textPos, newTextPos])
			WindowUtil.moveWindowToPos(tg.text, newTextPos, errorHandler)
		}
	}
}