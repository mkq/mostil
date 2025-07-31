#include %A_SCRIPTDIR%/lib/util.ahk

; An icon which can be set via a handle or file
class Icon {
	__new(filename, index, handle) {
		this.filename := filename
		this.index := index
		this.handle := handle
	}

	static fromFile(filename, index := 1) {
		return Icon(filename, index, 0)
	}

	static fromHandle(hIcon) {
		return Icon('', 0, hIcon)
	}

	guiAddOption {
		get => strlen(this.filename) > 0 && this.index ? ("Icon" this.index) : false
	}
	guiAddArg {
		get => strlen(this.filename) > 0 ? this.filename : this.handle ? ("hicon" this.handle) : false
	}

	; can be used to save and restore the current state, but uses an internal unspecified format:
	internalFormat {
		get => { filename: this.filename, index: this.index, handle: this.handle }
		set {
			this.filename := Util.getProp(value, "filename", "")
			this.index := Util.getProp(value, "index", 1)
			this.handle := Util.getProp(value, "handle", 0)
		}
	}

	; Draws this icon on a given Picture control
	updatePicture(pic) {
		if (this.handle) {
			Util.printDebug('updatePicture: handle {}', this.handle)
			pic.value := 'HICON:' this.handle
			pic.visible := true
		} else if (this.filename != '') {
			Util.printDebug('updatePicture: file {}, index {}', this.filename, this.index)
			pic.value := format('*icon{} {}', this.index, this.filename)
			pic.visible := true
		} else {
			Util.printDebug('updatePicture: hide')
			pic.visible := false
		}
	}
}
