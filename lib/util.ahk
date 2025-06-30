printDebug(formatStr, values*) {
	if (!DEBUG_OUTPUT) {
		return
	}
	stringValues := []
	for v in values {
		stringValues.push(String(v))
	}
	msg := format(formatStr "`n", stringValues*)
	;fileAppend("DEBUG: " msg, '**')
	outputDebug(msg)
}

; printDebug with function for lazy evaluation:
printDebugF(formatStr, valuesFunc) {
	if (DEBUG_OUTPUT) {
		return printDebug(formatStr, valuesFunc.call()*)
	}
}

eq(a, b) {
	return a == false ? b == false : a == b
}

getProp(o, propName, defaultValue := false) {
	return o.hasProp(propName) ? o.%propName% : defaultValue
}

getMandatoryProp(o, propName, errorMessage := (o '.' propName ' not set')) {
	if (o.hasProp(propName)) {
		return o.%propName%
	}
	throw ValueError(errorMessage)
}

join(sep, a) {
	start := true
	result := ""
	for (elem in a) {
		if (start) {
			start := false
		} else {
			result .= sep
		}
		result .= String(elem)
	}
	return result
}

dump(o) {
	switch type(o) {
		case "Array":
			parts := []
			for (elem in o) {
				parts.push(dump(elem))
			}
			return "[" join(", ", parts) "]"
		case "Object":
			result := "{ "
			start := true
			for n, v in o.ownProps() {
				if (start) {
					start := false
				} else {
					result .= ", "
				}
				result .= n ": " dump(v)
			}
			result .= " }"
			return result
		default:
			return String(o)
	}
}

arrayIndexOf(array, elem, startIndex := 1) {
	i := startIndex
	while (i <= array.length) {
		if (array[i] == elem) {
			return i
		}
		i++
	}
	return 0
}

arrayMap(array, f) {
	withIndex := f.maxParams > 1
	results := []
	for i, elem in array {
		result := withIndex ? f(i, elem) : f(elem)
		results.push(result)
	}
	return results
}

charAt(str, index) {
	return substr(str, index, 1)
}

skip(str, prefix, &i) {
	pl := strlen(prefix)
	matches := substr(str, i, pl) == prefix
	if (matches) {
		i += pl
	}
	return matches
}

requireInteger(val, valueDescription := "value") {
	if (!isInteger(val)) {
		throw ValueError(valueDescription " is not an integer")
	}
	return Integer(val)
}

requireStrLen(str, len) {
	if (!(str is String) || strlen(str) !== len) {
		throw ValueError(format("expected string of length {}, but got {}", len, strlen(str)))
	}
	return str
}

findDiffIndex(array1, array2, elemEqualsPredicate) {
	i := 1
	while (i <= array1.length && i <= array2.length) {
		if (!elemEqualsPredicate(array1[i], array2[i])) {
			return i
		}
		i++
	}
	if (i <= array1.length || i <= array2.length) {
		return i
	}
	return 0
}

moveToOrInsertAt0(array, elem) {
	resultArray := [elem]
	for e in array {
		if (e !== elem) {
			resultArray.push(e)
		}
	}
	return resultArray
}

parseTileParameter(cmdString, &i, &cmdStrPart) {
	for s in gl.screensManager.screens {
		for inp, t in s.tiles {
			if (skip(cmdString, inp, &i)) {
				cmdStrPart := inp
				return t
			}
		}
	}
	return false
}

parsePercentage(str, maxValue, valueDescription) {
	isPercentage := false
	if (substr(str, -1, 1) == "%") {
		isPercentage := true
		str := substr(str, 1, -1)
	}
	value := requireInteger(str, valueDescription)
	if (isPercentage) {
		if (value < 0 || value > 100) {
			throw ValueError("invalid " valueDescription " percentage")
		}
		return maxValue * value / 100
	}
	return value
}

computePercentage(value, percentage) {
	return percentage == 100 ? value : (value * percentage / 100)
}

getWindowPos(windowId) {
	x := y := w := h := ""
	winGetPos(&x, &y, &w, &h, windowId)
	return Position(x, y, w, h)
}

moveWindowToPos(windowId, pos) {
	try {
		return winMove(pos.x, pos.y, pos.w, pos.h, windowId)
	} catch Error as e {
		; TODO This should not need to know such GUI internals
		gl.screensManager.screenWithInput.gui.statusBar.setText('ERROR moving window: ' e.message)
	}
}

winSetMinMax(windowId, value) {
	try {
		switch (value) {
			case -1: winMinimize(windowId)
			case +1: winMaximize(windowId)
			default: winRestore(windowId)
		}
	} catch Error as e {
		; TODO This should not need to know such GUI internals
		gl.screensManager.screenWithInput.gui.statusBar.setText('ERROR setting window min/max/restored state: ' e.message)
	}
}

getNormalWindowIds() {
	printDebugF('my window ids: {}', () => arrayMap(gl.screensManager.screens, s => s.gui.hwnd))
	results := []
	for wid_ in winGetList() {
		wid := wid_ ; workaround for Autohotkey bug? Loop variable does not exist in the printDebugF closure, but this copy does.
		title := winGetTitle(wid)
		include := title !== '' ; TODO: better criterium to exclude non-window results like Shell_TrayWnd?
		printDebugF('winGetList(): id: {}, processName: {}, class: {}, title: {}, include: {}', () =>
			[wid, winGetProcessName(wid), winGetClass(wid), title, include])
		if (include) {
			results.push(wid)
		}
	}
	return results
}

getWindowIcon(windowId) {
	return sendMessage(0x7F, 1, , windowId) ; 0x7F = WM_GETICON, wParam 1 = large, lParam = DPI
}