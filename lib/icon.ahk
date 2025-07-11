#include %A_SCRIPTDIR%/lib/util.ahk

; an icon which draws itself to a given Picture control
class Icon {
	__new(pic) {
		this.picture := pic
		this.file := ""
		this.index := 1
		this.handle := 0
	}

	guiAddOption {
		get => strlen(this.file) > 0 && this.index ? ("Icon" this.index) : false
	}
	guiAddArg {
		get => strlen(this.file) > 0 ? this.file : this.handle ? ("hicon" this.handle) : false
	}
	; can be used to save and restore the current state, but uses an internal unspecified format:
	internalFormat {
		get => { file: this.file, index: this.index, handle: this.handle }
		set {
			this.file := getProp(value, "file", "")
			this.index := getProp(value, "index", 1)
			this.handle := getProp(value, "handle", 0)
			this.updatePicture()
		}
	}

	updatePicture() {
		if (this.handle) {
			printDebug('updatePicture: handle {}', this.handle)
			this.picture.value := 'HICON:' this.handle
			this.picture.visible := true
		} else if (this.file != '') {
			printDebug('updatePicture: file {}, index {}', this.file, this.index)
			this.picture.value := format('*icon{} {}', this.index, this.file)
			this.picture.visible := true
		} else {
			printDebug('updatePicture: hide')
			this.picture.visible := false
		}
	}

	setToFile(file, index := 1) {
		this.internalFormat := { file: file, index: index }
		this.updatePicture()
	}

	setToHandle(hIcon) {
		this.internalFormat := { handle: hIcon }
		this.updatePicture()
	}
}
