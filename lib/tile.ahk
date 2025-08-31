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

	addWindow(w, errorHandler) {
		Util.checkType(Tile.Window, w)
		; adding an already owned window should move it to the end, so remove and add
		removeUndo := this.removeWindow(w, errorHandler)
		this.windows.insertAt(1, w)
		undo() {
			if (this.windows.length > 0) {
				this.windows.removeAt(1)
				this.windowsChanged_(errorHandler)
			}
			removeUndo()
		}
		this.windowsChanged_(errorHandler)
		return (*) => undo()
	}

	removeWindow(w, errorHandler) {
		Util.checkType(Tile.Window, w)
		i := Util.arrayIndexOfWhere(this.windows, x => x.equals(w))
		if (i <= 0) {
			return (*) => {}
		}
		window := this.windows.removeAt(i)
		this.windowsChanged_(errorHandler)
		undo() {
			this.windows.insertAt(min(this.windows.length, i), window)
			this.windowsChanged_(errorHandler)
		}
		return (*) => undo()
	}

	removeNonExistingWindows(errorHandler) {
		this.removeWindowsWhere_(w => !winExist(w.id), errorHandler)
	}

	removeMovedWindows(thisPosition, errorHandler) {
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
		this.removeWindowsWhere_(w => !matchesPos(w.id), errorHandler)
	}

	removeWindowsWhere_(predicate, errorHandler) {
		oldCount := this.windows.length
		this.windows := Util.arrayRemoveWhere(this.windows, predicate)
		if (this.windows.length != oldCount) {
			this.windowsChanged_(errorHandler)
		}
	}

	replaceWindow(oldTw, newTw, errorHandler) {
		found := false
		for i, tw in this.windows {
			if (tw.equals(oldTw)) {
				found := true
				this.windows[i] := newTw
			}
		}
		if (found) {
			this.windowsChanged_(errorHandler)
		}
	}

	windowsChanged_(errorHandler) {
		this.screen.windowsChanged(this.index, this.windows, errorHandler)
	}

	moveWindowId(windowId, errorHandler) {
		if (windowId) {
			this.screen.moveWindowToTileIndex(windowId, this.index, errorHandler)
		}
	}

	; info about a window placed inside a Tile
	class Window {
		__new(id, ico, text) {
			this.id := Util.checkType(Integer, id)
			this.icon := Util.checkType(Icon, ico)
			this.text := Util.checkType(String, text)
		}

		equals(other) {
			return type(this) == type(other)
				&& this.id == other.id
				&& this.text == other.text
				&& Util.equal(this.icon, other.icon)
		}
	}
}