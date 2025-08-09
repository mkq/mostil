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
			return format('<a {}>', type(x))
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
				return Util.toString(o)
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
			maxValue := Integer(arg1)
		} else {
			i := Integer(arg1)
			maxValue := Integer(arg2)
		}
		if (i <= maxValue) {
			enum(&out) {
				if (i <= maxValue) {
					out := i++
					return true
				}
				return false
			}
			return enum
		} else {
			enumDesc(&out) {
				if (i >= maxValue) {
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

	static nextTooltipId_ := 1

	static showTooltip(text, duration, x, y) {
		if (Util.nextTooltipId_ > 20) {
			return
		}
		id := Util.nextTooltipId_++
		tooltip(text, x, y, id)
		setTimer(() => tooltip(, , , (Util.nextTooltipId_--, id)), -duration)
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
			round(Util.checkType(Number, x)),
			round(Util.checkType(Number, y)),
			round(Util.checkType(Number, w)),
			round(Util.checkType(Number, h)))
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

	; @param perc a ratio between 0 and 1 or a IntOrPercentage
	center(perc) {
		perc2 := perc is IntOrPercentage ? perc :
			IntOrPercentage.createPercentage(1000 * Number(perc), 1000)
		w := perc2.of(this.w)
		h := perc2.of(this.h)
		result := Position.ofFloats(this.x + (this.w - w) / 2, this.y + (this.h - h) / 2, w, h)
		Util.printDebugF('{}.center({}) == {}', () => [this, perc, result])
		return result
	}
}

; A helper to split/divide a Position either horizontally (side-by-side) or vertically (top, bottom). The
; split can be moved in steps of size stepPercentage in a range from minSplitPercentage to maxSplitPercentage,
; inclusive. It is initially at defaultSplitPercentage and can be reset to that value.
class SplitPosition {
	__new(horizontal, pos, defaultSplitPercentage, minSplitPercentage, maxSplitPercentage, stepPercentage) {
		this.horizontal := Util.checkType('boolean', horizontal)
		this.position := Util.checkType(Position, pos)
		this.defaultSplitPercentage := Util.checkType(IntOrPercentage, defaultSplitPercentage)
		this.minSplitPercentage := Util.checkType(IntOrPercentage, minSplitPercentage)
		this.maxSplitPercentage := Util.checkType(IntOrPercentage, maxSplitPercentage)
		this.stepPercentage := Util.checkType(IntOrPercentage, stepPercentage)
		this.splitPercentage := Util.checkType(IntOrPercentage, defaultSplitPercentage)
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
		Util.checkType(IntOrPercentage, perc)
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
			splitValue := round(this.splitPercentage.of(pos.w))
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
			splitValue := round(this.splitPercentage.of(pos.h))
			results := [ ;
				Position(pos.x, pos.y, pos.w, splitValue), ;
				Position(pos.x, pos.y + splitValue, pos.w, pos.h - splitValue)]
		}
		Util.printDebugF("getChildPositions() == {}", () => [Util.dump(results)])
		return results
	}
}

; Represents a percentage or absolute number.
; In order for a percentage to be pixel accurate when parsed from an absolute value, it stores the given value and
; reference (max) value. For example a 1000 pixel wide (horizontally split) screen's default split value configured as
; 600 is represented as a Percentage with value 600 and max 1000.
class IntOrPercentage {
	__new(isPercentage, value, max) {
		this.isPercentage := Util.checkType('boolean', isPercentage)
		this.value := Number(value)
		this.max := Number(max)
	}

	static createAbsolute(value) {
		return IntOrPercentage(false, Integer(value), 0)
	}

	static createPercentage(value, max := 100) {
		return IntOrPercentage(true, value, max)
	}

	; Examples:
	; - parse(40, 500, ''): 8%, but yielding exactly 40 when calculating these 8% of 500;
	; - parse('8%', 500, ''): 8%, same as above if calculating 8% of 500 is exactly 40;
	; - parse('8%', 0, ''): 8%, internally represented as 8 of 100 (100 being the default max value);
	static parse(str, max, valueDescription) {
		isPercentage := false
		if (substr(str, -1, 1) == "%") {
			isPercentage := true
			str := substr(str, 1, -1)
		}
		try {
			value := Number(str)
		} catch {
			throw TypeError(valueDescription)
		}
		if (!isPercentage) {
			return IntOrPercentage.createAbsolute(value)
		}
		if (value < 0 || value > 100) {
			throw ValueError("invalid percentage " valueDescription)
		}
		if (max = 0) {
			return IntOrPercentage.createPercentage(value)
		}
		try {
			max := Number(max)
		} catch {
			throw TypeError(valueDescription)
		}
		return IntOrPercentage.createPercentage(max * value / 100, max)
	}

	toString() {
		return this.isPercentage
			? format('{}/{} (~ {}%)', this.value, this.max, round(100 * this.value / this.max))
			: this.value
	}

	toFactor() {
		if (!this.isPercentage) {
			throw TypeError('absolute number ' this.value ' cannot be converted to factor')
		}
		return this.value / this.max
	}

	of(value) {
		return !this.isPercentage ? this.value :
			this.value == this.max ? value : (value * this.value / this.max)
	}

	; Returns a Percentage (possibly this) with the given max and
	; - representing the same factor / percentage as this if this is a percentage;
	; - this.value as the value if this is absolute.
	; This can be used to create a Percentage lazily: If e.g. something is configure to have absolute width 150 and is
	; contained in something of variable width currently at 500, build a percentage 150/500. A percentage 75/250 at max
	; 500 would give the same 150/500.
	at(maxValue) {
		return this.isPercentage
			? (this.max == maxValue ? this : IntOrPercentage.createPercentage(this.value * maxValue / this.max, maxValue))
			: IntOrPercentage.createPercentage(this.value, maxValue)
	}

	lessThan(other) {
		if (this.isPercentage && other is IntOrPercentage && other.isPercentage) {
			return this.max == other.max ? this.value < other.value
				: this.toFactor() < other.factor()
		} else if (!this.isPercentage && other is IntOrPercentage && !other.isPercentage) {
			return this.value < other.value
		} else if (!this.isPercentage && isNumber(other)) {
			return this.value < Number(other)
		} else {
			throw TypeError('cannot compare ' this ' to ' other)
		}
	}
	greaterThan(otherPercentage) {
		return otherPercentage.lessThan(this)
	}

	; Returns a new Percentage with <multiplier> times <otherPercentage> added.
	; <otherPercentage> must have the same max as this, or both must be absolute.
	addPercentage(other, multiplier) {
		if (this.isPercentage != other.isPercentage) {
			throw ValueError('adding percentage and absolute value not supported')
		}
		if (!this.isPercentage) {
			return IntOrPercentage.createAbsolute(this.value + other.value)
		}
		if (other.max != this.max) {
			throw ValueError('different max values not supported')
		}
		newValue := this.value + multiplier * other.value
		newValue := min(this.max, max(0, newValue))
		return IntOrPercentage.createPercentage(newValue, this.max)
	}
}