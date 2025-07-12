class ScreensManager {
	__new(screens) {
		if (screens.length < 1) {
			throw ValueError("no screens")
		}
		this.screenWithInput := false
		for s in screens {
			if (s.hasInput()) {
				if (this.screenWithInput) {
					throw ValueError("multiple GUIs with input")
				} else {
					this.screenWithInput := s
				}
			}
		}
		this.screens := screens
	}

	; TODO refactor: Pass less than the full Mostil app.
	; Or move all ScreensManager functionality inside class Mostil.
	show(app) {
		this.forEachScreenInputScreenLast(s => s.show(app))
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

	containsWindowId(windowId) {
		for s in this.screens {
			if (s.gui.hwnd == windowId) {
				return true
			}
		}
		return false
	}
}
