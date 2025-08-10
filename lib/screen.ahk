#include %A_SCRIPTDIR%/lib/util.ahk
#include %A_SCRIPTDIR%/lib/tile.ahk
#include %A_SCRIPTDIR%/lib/screen-gui.ahk

; An area split into two Tiles either vertically or horizontally.
; This class is model + controller; class ScreenGui is the view.
class Screen {
	__new(name, targetSplitPosition, guiPosition, withInput, tiles, guiConfig) {
		this.name := name
		this.targetSplitPosition := targetSplitPosition
		this.hasInput := withInput
		if !(tiles is Array && tiles.length == 2) {
			throw ValueError("tiles is not an array of length 2")
		}
		this.tiles := tiles
		for t in tiles {
			t.screen := this
		}
		this.gui := ScreenGui(this, guiPosition, guiConfig, withInput, targetSplitPosition)
	}

	toString() {
		return format('{}("{}", {})', type(this), this.name, String(this.targetSplitPosition))
	}

	input {
		get => this.gui.input
	}

	show(app, errorHandler) {
		; "Reality check": Update this.windows to the current state of actual windows: Remove those
		; which no longer exist or have been moved.
		tilePositions := this.targetSplitPosition.getChildPositions()
		for i, t in this.tiles {
			t.removeNonExistingWindows()
			t.removeMisplacedWindows(tilePositions[i])
		}

		this.gui.show(app, errorHandler)
	}

	hide() {
		this.gui.hide()
	}

	windowsChanged(tileIndex, windows) {
		this.gui.windowsChanged(tileIndex, windows)
	}

	; Moves the split "towards" a tile given by index or resets it to the default position.
	; @param tileIndex: 0 = reset; 1 = make tile 1 smaller and 2 bigger; 2 = make tile 2 smaller and 1 bigger
	moveSplit(errorHandler, tileIndex := 0) {
		if (tileIndex == 0) {
			oldPercentage := this.targetSplitPosition.reset()
		} else if (tileIndex == 1 || tileIndex == 2) {
			inc := tileIndex == 1 ? -1 : 1
			oldPercentage := this.targetSplitPosition.increment(inc)
		} else {
			throw ValueError("tile index " tileIndex)
		}
		this.gui.moveSplit(errorHandler, tileIndex)
		return oldPercentage
	}

	resetSplit(errorHandler) {
		return this.moveSplit(errorHandler)
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

	setSplitToPercentage(p, errorHandler) {
		this.targetSplitPosition.setSplitPercentage(Util.checkType(IntOrPercentage, p))
		this.gui.setSplitToPercentage(p, errorHandler)
	}
}