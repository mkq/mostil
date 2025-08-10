#include %A_SCRIPTDIR%/lib/window-util.ahk

; One "half" of a Screen.
; This is a model class; the GUI is handled in class Screen.
class Tile {
	__new(index, name, input, matchWindowPositionTolerance) {
		this.index := index
		this.name := name
		this.input := input
		this.matchWindowPositionTolerance := matchWindowPositionTolerance
		this.screen := false
		this.windows := [] ; array of Tile.Window, most recently added at [1]
	}

	toString() {
		return format("{} [{}] of {}", type(this), this.index, this.screen.name)
	}

	; Moves the parent screen's split in the direction corresponding to this tile, making this tile smaller and the sibling
	; tile bigger.
	moveSplit(screensMgr) {
		return this.screen.moveSplit(screensMgr, this.index)
	}

	; Called by the parent screen to move all windows placed in this tile to the given coordinates.
	; Also deletes remembered window IDs which no longer exist.
	setPosition(windowPos, errorHandler) {
		this.pos := windowPos
		for (w in this.windows) {
			if (winExist(w.id)) {
				WindowUtil.moveWindowToPos(w, windowPos, errorHandler)
			}
		}
	}

	containsWindow(windowId) {
		return this.indexOfWindow(windowId) > 0
	}

	indexOfWindow(windowId) {
		return Util.arrayIndexOfWhere(this.windows, x => x.id == windowId)
	}

	addWindow(w) {
		Util.checkType(Tile.Window, w)
		; adding an already owned window should move it to the end, so remove and add
		removeUndo := this.removeWindow(w)
		this.windows.insertAt(1, w)
		undo() {
			if (this.windows.length > 0) {
				this.windows.removeAt(1)
			}
			removeUndo()
		}
		this.windowsChanged_()
		return (*) => undo()
	}

	removeWindow(w) {
		Util.checkType(Tile.Window, w)
		i := Util.arrayIndexOf(this.windows, w)
		if (i <= 0) {
			return (*) => {}
		}
		window := this.windows.removeAt(i)
		this.windowsChanged_()
		undo() {
			this.windows.insertAt(min(this.windows.length, i), window)
			this.windowsChanged_()
		}
		return (*) => undo()
	}

	removeNonExistingWindows() {
		this.windows := Util.arrayRemoveWhere(this.windows, w => !winExist(w.id))
	}

	removeMisplacedWindows(thisPosition) {
		approxEq(a, b) {
			return abs(a - b) <= this.matchWindowPositionTolerance
		}
		matchesPos(windowId) {
			wPos := Position.ofWindow(windowId)
			matches := approxEq(wPos.xl, thisPosition.xl)
				&& approxEq(wPos.yt, thisPosition.yt)
				&& approxEq(wPos.xr, thisPosition.xr)
				&& approxEq(wPos.yb, thisPosition.yb)
			if (!matches) {
				Util.printDebug('removing window {} at {} (tile {} position: {}', windowId, wPos, this.name, thisPosition)
			}
			return matches
		}
		this.windows := Util.arrayRemoveWhere(this.windows, w => !matchesPos(w.id))
	}

	windowsChanged_() {
		this.screen.windowsChanged(this.index, this.windows)
	}

	moveLatestWindow(errorHandler) {
		if (this.windows.length > 0) {
			this.screen.moveWindowToTileIndex(this.windows[1].id, this.index, errorHandler)
		}
	}

	; info about a window placed inside a Tile
	class Window {
		__new(id, ico, text) {
			this.id := Util.checkType(Integer, id)
			this.icon := Util.checkType(Icon, ico)
			this.text := Util.checkType(String, text)
		}
	}
}