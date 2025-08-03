#include %A_SCRIPTDIR%/lib/window-util.ahk

; One "half" of a Screen
class Tile {
	__new(index, name, input) {
		this.index := index
		this.name := name
		this.input := input
		this.screen := false
		this.windows := [] ; array of Tile.Window
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
		this.windows := Util.arrayDeleteWhere(this.windows, w => !winExist(w.id))
	}

	containsWindow(windowId) {
		return this.indexOfWindow(windowId) > 0
	}

	indexOfWindow(windowId) {
		return Util.arrayIndexOfWhere(this.windows, x => x.id == windowId)
	}

	addWindow(window) {
		Util.checkType(Tile.Window, window)
		removeUndo := this.removeWindow(window.id)
		this.windows.push(window)
		undo() {
			this.windows.removeAt(-1)
			removeUndo()
		}
		return undo
	}

	removeWindow(windowId) {
		i := Util.arrayIndexOfWhere(this.windows, x => x.id == windowId)
		if (i > 0) {
			window := this.windows.delete(i)
		}
		undo() {
			if (i > 0) {
				this.windows.insertAt(i, window)
			}
		}
		return undo
	}

	moveLatestWindow(errorHandler) {
		if (this.windows.length > 0) {
			this.screen.moveWindowToTileIndex(this.windows[-1].id, this.index, errorHandler)
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