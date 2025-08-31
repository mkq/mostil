class ScreensManager {
	__new(screens) {
		if (screens.length < 1) {
			throw ValueError("no screens")
		}
		this.screenWithInput := false
		for s in screens {
			Util.checkType(Screen, s)
			if (s.hasInput) {
				if (this.screenWithInput) {
					throw ValueError("multiple GUIs with input")
				} else {
					this.screenWithInput := s
				}
			}
		}
		this.screens := screens
	}

	show(app, errorHandler) {
		this.forEachScreenInputScreenLast(s => s.show(app, errorHandler))
	}

	hide() {
		this.forEachScreen(s => s.hide())
	}

	forEachScreen(f) {
		results := []
		for s in this.screens {
			results.push(f(s))
		}
		return results
	}

	forEachScreenInputScreenLast(f) {
		results := []
		for s in this.screens {
			if (s !== this.screenWithInput) {
				results.push(f(s))
			}
		}
		results.push(f(this.screenWithInput))
		return results
	}

	forEachTile(f) {
		results := []
		for s in this.screens {
			for t in s.tiles {
				results.push(f(t))
			}
		}
		return results
	}

	moveWindowToTile(window, selectedTile, errorHandler) {
		Util.checkType(Tile.Window, window)
		Util.checkType(Tile, selectedTile)
		undoFunctions := this.forEachTile(t => t == selectedTile ? t.addWindow(window, errorHandler) : t.removeWindow(window, errorHandler))
		undo() {
			while (undoFunctions.length > 0) {
				undoFunctions.removeAt(-1).call()
			}
		}
		return (*) => undo()
	}

	containsWindowId(windowId) {
		for s in this.screens {
			if (s.gui.gui.hwnd == windowId) {
				return true
			}
		}
		return false
	}
}