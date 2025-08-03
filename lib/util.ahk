#include %A_ScriptDir%/lib/util.ahk

class Util {
	static DEBUG_OUTPUT := true

	static printDebug(formatStr, values*) {
		if (!Util.DEBUG_OUTPUT) {
			return
		}
		stringValues := []
		for v in values {
			stringValues.push(Util.toString(v))
		}
		msg := format(formatStr "`n", stringValues*)
		;fileAppend("DEBUG: " msg, '**')
		outputDebug(msg)
	}

	; printDebug with function for lazy evaluation:
	static printDebugF(formatStr, valuesFunc) {
		if (Util.DEBUG_OUTPUT) {
			return Util.printDebug(formatStr, valuesFunc.call()*)
		}
	}

	; Checks a value's type
	; @param requiredType a Class or a type name as string or "Boolean"
	; @return value
	static checkType(requiredType, value) {
		requiredType2 := requiredType = 'boolean' ? 'Integer' : requiredType
		valid := requiredType2 is String ? (type(value) = requiredType2) : (value is requiredType2)
		if (requiredType = 'boolean') {
			valid := valid && (value == 0 || value == 1)
		}
		if (!valid) {
			throw TypeError(format('invalid type {}: {}', type(value), Util.toString(value)))
		}
		return value
	}

	; Adds debug logging to a given function with a given name.
	; Especially for closures which don't have a name.
	static addPrintDebugN(f, name) {
		Util.printDebug('addPrintDebugN(..)')
		fWithDebugOut(args*) {
			result := f(args*)
			Util.printDebug('{}({}) == {}', name, Util.toString(args), Util.toString(result))
			return result
		}
		return fWithDebugOut
	}
	; Adds debug logging to a given function (using its name).
	static addPrintDebug(f) {
		return Util.addPrintDebugN(f, f.name)
	}

	static eq(a, b) {
		return a == false ? b == false : a == b
	}

	static getProp(o, propName, defaultValue := false) {
		return o.hasProp(propName) ? o.%propName% : defaultValue
	}

	static getMandatoryProp(o, propName, errorMessage := (o '.' propName ' not set')) {
		if (o.hasProp(propName)) {
			return o.%propName%
		}
		throw ValueError(errorMessage)
	}

	static toString(x) {
		try {
			return x is Array ? Util.join(', ', x) : String(x)
		} catch Error as e {
			return format('<a {} without toString()>', type(x))
		}
	}

	static join(sep, a) {
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

	static dump(o) {
		switch type(o) {
			case "Array":
				parts := []
				for (elem in o) {
					parts.push(Util.dump(elem))
				}
				return "[" Util.join(", ", parts) "]"
			case "Object":
				result := "{ "
				start := true
				for n, v in o.ownProps() {
					if (start) {
						start := false
					} else {
						result .= ", "
					}
					result .= n ": " Util.dump(v)
				}
				result .= " }"
				return result
			default:
				return String(o)
		}
	}

	static arrayIndexOfWhere(arr, predicate, startIndex := 1) {
		i := startIndex
		while (i <= arr.length) {
			if (predicate.call(arr[i])) {
				return i
			}
			i++
		}
		return 0
	}

	static arrayIndexOf(arr, elem, startIndex := 1) {
		return Util.arrayIndexOfWhere(arr, x => x == elem, startIndex)
	}

	static arrayRemoveWhere(arr, predicate) {
		resultArray := []
		for (elem in arr) {
			if (!predicate(elem)) {
				resultArray.push(elem)
			}
		}
		return resultArray
	}

	static arrayMap(arr, f) {
		withIndex := f.maxParams > 1
		results := []
		for i, elem in arr {
			result := withIndex ? f(i, elem) : f(elem)
			results.push(result)
		}
		return results
	}

	; An Integer enumerator.
	; When called with a single parameter, it starts at 1 and ends at the parameter (inclusive).
	; Otherwise, it starts at the 1st parameter and ends at the 2nd (inclusive).
	static seq(arg1, arg2 := '') {
		if (arg2 == '') {
			i := 1
			max := Integer(arg1)
		} else {
			i := Integer(arg1)
			max := Integer(arg2)
		}
		if (i <= max) {
			enum(&out) {
				if (i <= max) {
					out := i++
					return true
				}
				return false
			}
			return enum
		} else {
			enumDesc(&out) {
				if (i >= max) {
					out := i--
					return true
				}
				return false
			}
			return enumDesc
		}
	}

	static charAt(str, index) {
		return substr(str, index, 1)
	}

	static skip(str, prefix, &i) {
		pl := strlen(prefix)
		matches := substr(str, i, pl) == prefix
		if (matches) {
			i += pl
		}
		return matches
	}

	static requireInteger(val, valueDescription := "value") {
		if (!isInteger(val)) {
			throw ValueError(valueDescription " is not an integer")
		}
		return Integer(val)
	}

	static requireNumber(val, valueDescription := "value") {
		if (!isNumber(val)) {
			throw ValueError(valueDescription " is not a number")
		}
		return Number(val)
	}

	static findDiffIndex(array1, array2, elemEqualsPredicate) {
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

	static moveToOrInsertAt0(arr, elem) {
		resultArray := [elem]
		for e in arr {
			if (e !== elem) {
				resultArray.push(e)
			}
		}
		return resultArray
	}

	static parseTileParameter(cmdString, screensMgr, &i, &cmdStrPart) {
		for s in screensMgr.screens {
			for t in s.tiles {
				if (Util.skip(cmdString, t.input, &i)) {
					cmdStrPart := t.input
					return t
				}
			}
		}
		return false
	}

	static nextTooltipId_ := 1

	static showTooltip(text, duration, x, y) {
		if (Util.nextTooltipId_ > 20) {
			return
		}
		tooltip(text, x, y, Util.nextTooltipId_++)
		setTimer(() => tooltip(, , , --Util.nextTooltipId_), -duration)
	}
}

class Position {
	__new(x, y, w, h) {
		this.x := Util.checkType(Integer, x)
		this.y := Util.checkType(Integer, y)
		this.w := Util.checkType(Integer, w)
		this.h := Util.checkType(Integer, h)
	}

	static ofFloats(x, y, w, h) {
		return Position(
			round(Util.checkType(Float, x)),
			round(Util.checkType(Float, y)),
			round(Util.checkType(Float, w)),
			round(Util.checkType(Float, h)))
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
		return Position.ofFloats(this.x + (this.w - w) / 2, this.y + (this.h - h) / 2, w, h)
	}
}

; A helper to split/divide a Position either horizontally (side-by-side) or vertically (top, bottom). The
; split can be moved in steps of size stepPercentage in a range from minSplitPercentage to maxSplitPercentage,
; inclusive. It is initially at defaultSplitPercentage and can be reset to that value.
class SplitPosition {
	__new(horizontal, pos, defaultSplitPercentage, minSplitPercentage, maxSplitPercentage, stepPercentage) {
		this.horizontal := Util.checkType('boolean', horizontal)
		this.position := Util.checkType(Position, pos)
		this.defaultSplitPercentage := Util.checkType(Percentage, defaultSplitPercentage)
		this.minSplitPercentage := Util.checkType(Percentage, minSplitPercentage)
		this.maxSplitPercentage := Util.checkType(Percentage, maxSplitPercentage)
		this.stepPercentage := Util.checkType(Percentage, stepPercentage)
		this.splitPercentage := Util.checkType(Percentage, defaultSplitPercentage)
	}

	toString() {
		return format('{}({}, {}{}(def:{}), {}..{}s{})', type(this),
			String(this.position),
			this.horizontal ? "h" : "v", String(this.splitPercentage), String(this.defaultSplitPercentage),
			String(this.minSplitPercentage), String(this.maxSplitPercentage), String(this.stepPercentage))
	}

	reset() {
		Util.printDebug('reset')
		return this.setSplitPercentage(this.defaultSplitPercentage)
	}

	setSplitPercentage(perc) {
		Util.checkType(Percentage, perc)
		oldSP := this.splitPercentage
		this.splitPercentage := perc
		Util.printDebugF('setSplitPercentage: {} → {}', () => [oldSP, this.toString()])
		return oldSP
	}

	decrement() {
		return this.increment(-1)
	}

	increment(stepCount := 1) {
		oldSP := this.splitPercentage
		this.splitPercentage := this.splitPercentage.addPercentage(this.stepPercentage, Util.checkType(Integer, stepCount))
		if (this.splitPercentage.lessThan(this.minSplitPercentage)) {
			Util.printDebug('set to min')
			this.splitPercentage := this.minSplitPercentage
		}
		if (this.splitPercentage.greaterThan(this.maxSplitPercentage)) {
			Util.printDebug('set to max')
			this.splitPercentage := this.maxSplitPercentage
		}
		Util.printDebugF('increment({}): {} → {}', () => [stepCount, oldSP, this.toString()])
		return oldSP
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
		Util.printDebugF("getChildPositions() == {}", () => [Util.dump(results)])
		return results
	}
}

; Represents a percentage.
; In order to be pixel accurate when parsed from an absolute value, it stores the given value and reference (max)
; value. For example a 1000 pixel wide (horizontally split) screen's default split value configured as 600 is
; represented as a Percentage with value 600 and max 1000.
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