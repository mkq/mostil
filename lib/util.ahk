#include %A_ScriptDir%/lib/util.ahk

printDebug(formatStr, values*) {
	if (!DEBUG_OUTPUT) {
		return
	}
	stringValues := []
	for v in values {
		stringValues.push(toString(v))
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

; Adds debug logging to a given function with a given name.
; Especially for closures which don't have a name.
addPrintDebugN(f, name) {
	printDebug('addPrintDebugN(..)')
	fWithDebugOut(args*) {
		result := f(args*)
		printDebug('{}({}) == {}', name, toString(args), toString(result))
		return result
	}
	return fWithDebugOut
}
; Adds debug logging to a given function (using its name).
addPrintDebug(f) {
	return addPrintDebugN(f, f.name)
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

toString(x) {
	try {
		return x is Array ? join(', ', x) : String(x)
	} catch Error as e {
		return format('<a {} without toString()>', type(x))
	}
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

requireNumber(val, valueDescription := "value") {
	if (!isNumber(val)) {
		throw ValueError(valueDescription " is not a number")
	}
	return Number(val)
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

parseTileParameter(cmdString, screensMgr, &i, &cmdStrPart) {
	for s in screensMgr.screens {
		for t in s.tiles {
			if (skip(cmdString, t.input, &i)) {
				cmdStrPart := t.input
				return t
			}
		}
	}
	return false
}

class Position {
	__new(x, y, w, h) {
		this.x := x
		this.y := y
		this.w := w
		this.h := h
	}

	static ofWindow(windowId) {
		x := y := w := h := ""
		winGetPos(&x, &y, &w, &h, windowId)
		return Position(x, y, w, h)
	}

	static ofWindowClient(windowId) {
		x := y := w := h := ""
		winGetClientPos(&x, &y, &w, &h, windowId)
		return Position(x, y, w, h)
	}

	static ofGuiControl(gc) {
		x := y := w := h := ""
		gc.getPos(&x, &y, &w, &h)
		return Position(x, y, w, h)
	}

	toString() {
		return format('{}({}, {}, {}x{})', type(this), this.x, this.y, this.w, this.h)
	}

	toGuiOption() {
		return format('x{} y{} w{} h{}', this.x, this.y, this.w, this.h)
	}

	center(ratio) {
		w := this.w * ratio
		h := this.h * ratio
		return Position(this.x + (this.w - w) / 2, this.y + (this.h - h) / 2, w, h)
	}
}

class SplitPosition {
	__new(horizontal, pos, defaultSplitPercentage, minSplitPercentage, maxSplitPercentage, stepPercentage) {
		this.horizontal := horizontal
		this.position := pos
		this.defaultSplitPercentage := defaultSplitPercentage
		this.minSplitPercentage := minSplitPercentage
		this.maxSplitPercentage := maxSplitPercentage
		this.stepPercentage := stepPercentage
		this.splitPercentage := defaultSplitPercentage
	}

	toString() {
		return format('{}({}, {}{}(def:{}), {}..{}s{})', type(this),
			String(this.position),
			this.horizontal ? "h" : "v", String(this.splitPercentage), String(this.defaultSplitPercentage),
			String(this.minSplitPercentage), String(this.maxSplitPercentage), String(this.stepPercentage))
	}

	reset() {
		printDebugF('before reset: {}', () => [this.toString()])
		this.splitPercentage := this.defaultSplitPercentage
	}

	decrement() {
		return this.increment(-1)
	}

	increment(stepCount := 1) {
		printDebugF('before increment({}): {}', () => [stepCount, this.toString()])
		this.splitPercentage := this.splitPercentage.addPercentage(this.stepPercentage, stepCount)
		if (this.splitPercentage.lessThan(this.minSplitPercentage)) {
			printDebug('set to min')
			this.splitPercentage := this.minSplitPercentage
		}
		if (this.splitPercentage.greaterThan(this.maxSplitPercentage)) {
			printDebug('set to max')
			this.splitPercentage := this.maxSplitPercentage
		}
		printDebugF('after  increment({}): {}', () => [stepCount, this.toString()])
	}

	getChildPositions() {
		pos := this.position
		if (this.horizontal) {
			; +-------+--------------+    y
			; |       |              |
			; +-------+--------------+   y+h
			; x      x+s            x+w
			splitValue := round(this.splitPercentage.applyTo(pos.w))
			results := [ ;
				Position(pos.x, pos.y, splitValue, pos.h), ;
				Position(pos.x + splitValue, pos.y, pos.w - splitValue, pos.h)]
		} else {
			; +-------+  y
			; |       |
			; |       |
			; +-------+ y+s
			; |       |
			; +-------+ y+h
			; x      x+w
			splitValue := round(this.splitPercentage.applyTo(pos.h))
			results := [ ;
				Position(pos.x, pos.y, pos.w, splitValue), ;
				Position(pos.x, pos.y + splitValue, pos.w, pos.h - splitValue)]
		}
		printDebugF("getChildPositions() == {}", () => [dump(results)])
		return results
	}
}

; Represents a percentage. But in order to be pixel accurate when parsed from an absolute value,
; it stores the given value and reference (max) value.
class Percentage {
	__new(value, max) {
		this.value := Number(value)
		this.max := Number(max)
	}

	static parse(str, max, valueDescription) {
		isPercentage := false
		if (substr(str, -1, 1) == "%") {
			isPercentage := true
			str := substr(str, 1, -1)
		}
		try {
			value := Number(str)
			max := Number(max)
		} catch {
			throw TypeError(valueDescription)
		}
		if (isPercentage) {
			if (value < 0 || value > 100) {
				throw ValueError("invalid percentage " valueDescription)
			}
			value := max * value / 100
		} else if (value > max) {
			throw ValueError("invalid percentage " valueDescription)
		}
		return Percentage(value, max)
	}

	toString() {
		return round(100 * this.value / this.max) '%'
	}

	factor() {
		return this.value / this.max
	}

	applyTo(value) {
		return this.value == this.max ? value : (value * this.value / this.max)
	}

	lessThan(otherPercentage) {
		return this.max == otherPercentage.max ? this.value < otherPercentage.value
			: this.factor() < otherPercentage.factor()
	}
	greaterThan(otherPercentage) {
		return otherPercentage.lessThan(this)
	}

	; Returns a new Percentage with <multiplier> times <otherPercentage> added.
	; <otherPercentage> must have the same max as this.
	addPercentage(otherPercentage, multiplier) {
		if (otherPercentage.max != this.max) {
			throw ValueError('different max values not supported')
		}
		newValue := this.value + multiplier * otherPercentage.value
		newValue := min(this.max, max(0, newValue))
		return Percentage(newValue, this.max)
	}
}
