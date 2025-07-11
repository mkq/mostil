#include %A_SCRIPTDIR%/lib/window-util.ahk

; One "half" of a Screen
class Tile {
	__new(index, name, input) {
		this.index := index
		this.name := name
		this.input := input
		this.screen := false
		this.windowIds := Map() ; a set of window IDs represented as Map windowId -> true
		this.text_ := ""
	}

	toString() {
		return format("{} [{}] of {}", type(this), this.index, this.screen.toString())
	}

	text {
		get => this.text_
		set => this.text_ := value
	}

	; A Tile has a real icon and text only temporarily when PlaceWindowCommand sets it to show
	; a preview of its action. However, this is implemented as an always present Icon instance
	; which can also (and initially does) represent a null Icon:
	icon {
		get => this.screen.icons[this.index]
	}

	; Moves the parent screen's split in the direction corresponding to this tile, making this tile smaller and the sibling
	; tile bigger.
	moveSplit(screensMgr) {
		this.screen.moveSplit(screensMgr, this.index)
	}

	; Called by the parent screen to move all windows placed in this tile to the given coordinates.
	; Also deletes remembered window IDs which no longer exist.
	setPosition(windowPos, errorHandler) {
		this.pos := windowPos
		for (wid in this.windowIds) {
			if (winExist(wid)) {
				WindowUtil.moveWindowToPos(wid, windowPos, errorHandler)
			} else {
				this.windowIds.delete(wid)
			}
		}
	}

	containsWindow(windowId) {
		return this.windowIds.has(windowId)
	}

	addWindow(windowId, screensManager, errorHandler) {
		if (this.containsWindow(windowId)) {
			return
		}
		if (this.screen.moveWindowToTileIndex(windowId, this.index, errorHandler)) {
			screensManager.forEachTile(t => t.removeWindow(windowId)) ; remove from all tiles
			this.windowIds.set(windowId, true)
		}
	}

	removeWindow(windowId) {
		this.windowIds.delete(windowId)
	}
}
