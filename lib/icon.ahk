#include %A_SCRIPTDIR%/lib/util.ahk

; An icon which can be set via a handle or file. One of the static factory methods from…() or
; blank() should be used to create an Icon.
; It stores only that basic information and does not have any GUI component.
; It can however be "applied to" a given picture GUI control.
class Icon {
	; private constructor
	__new(filename, index, handle, fallbackIcon := false) {
		if (fallbackIcon == this) {
			throw ValueError("fallbackIcon == this")
		}
		this.filename := filename
		this.index := index
		this.handle := handle
		this.fallbackIcon := fallbackIcon
	}

	static blank() {
		return Icon('', 0, 0)
	}

	static fromFile(filename, index := 1, fallbackIcon := false) {
		return Icon(filename, index, 0, fallbackIcon)
	}

	static fromHandle(hIcon, fallbackIcon := false) {
		return Icon('', 0, hIcon, fallbackIcon)
	}

	; Can be used to save and restore the current state. The concrete value returned by get is
	; unspecified and should only be passed to set.
	internalFormat {
		get => { filename: this.filename, index: this.index, handle: this.handle }
		set {
			this.filename := Util.getProp(value, "filename", "")
			this.index := Util.getProp(value, "index", 1)
			this.handle := Util.getProp(value, "handle", 0)
		}
	}

	equals(other) {
		return type(this) == type(other)
			&& this.handle == other.handle
			&& this.index == other.index
			&& this.filename == other.filename
			&& Util.equal(this.fallbackIcon, other.fallbackIcon)
	}

	; Draws this icon on a given Picture control
	updatePicture(pic) {
		try {
			this.updatePictureImpl_(pic)
		} catch as e {
			Util.printDebug('error setting picture to {}: {}', this, e)
			if (this.fallbackIcon) {
				this.fallbackIcon.updatePicture(pic)
			}
		}
	}

	updatePictureImpl_(pic) {
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