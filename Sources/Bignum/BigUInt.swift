//
//  BigUInt.swift
//  Bignum
//

import CBignum
import ModularArithmetic

private struct Bases {
	typealias Element = BigUInt.Element
	
	private static var digits: [Element : Double] = [:]
	private static var characters: [Element : (Int, Element)] = [:]
	
	static func DigitCount(for wordCount: Int, radix: Int) -> Int {
		let r = Element(radix)
		if let cached = Bases.digits[r] {
			return Int((cached * Double(wordCount)).rounded(.up))
		}
		
		var (_, power) = CharactersPerWord(radix: radix)
		if power == 0 { power = .max }
		let ratio = _log(Double(Element.max)) / _log(Double(power))
		Bases.digits[r] = ratio
		return Int((ratio * Double(wordCount)).rounded(.up))
	}
	
	static func CharactersPerWord(radix: Int) -> (count: Int, power: BigUInt.Element) {
		let radix = Element(radix)
		if let cached = Bases.characters[radix] { return cached }
		
		var power: Element = 0
		var newPower: Element = 1
		var overflow = false
		var count = -1
		while !overflow {
			count += 1
			power = newPower
			(newPower, overflow) = power.multipliedReportingOverflow(by: radix)
		}
		Bases.characters[radix] = (count, power)
		return (count, power)
	}
}

public struct BigUInt: UnsignedInteger {
	internal typealias Element = Words.Element
	private typealias Storage = ContiguousArray<Element>
	private typealias CStorage = UnsafeMutablePointer<Element>
	
	internal let _words: ArraySlice<Element>
	
	internal init(words: ArraySlice<Element>) {
		self._words = words
	}
	
	public init?<S : StringProtocol>(_ text: S, radix: Int = 10) {
		precondition(radix >= 2, "Radix not in range 2...36")
		precondition(radix <= 36, "Radix not in range 2...36")
		
		let (count, p) = Bases.CharactersPerWord(radix: radix)
		let power = p == 0 ? BigUInt(words: [0, 1]) : BigUInt(words: [p])
		
		var value: BigUInt = 0
		var base: BigUInt = 1
		
		let success = text.withCString { (pointer: UnsafePointer<CChar>) -> Bool in
			let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: count + 1)
			for endIndex in stride(from: text.count, to: 0, by: -count) {
				let startIndex = Swift.max(0, endIndex - count)
				let length = endIndex - startIndex
				
				_memcpy(buffer, pointer.advanced(by: startIndex), length)
				buffer[length] = 0
				
				let string = String(cString: buffer)
				if let number = Element(string, radix: radix) {
					let product = base * BigUInt(words: [number])
					value += product
					base *= power
				} else {
					return false
				}
			}
			buffer.deallocate()
			return true
		}
		
		if !success { return nil }
		self = value
	}
	
	@inlinable
	public func exponentiating<T: BinaryInteger>(by exponent: T) -> BigUInt {
		if exponent  < 0 { return 0 }
		if exponent == 0 { return 1 }
		if exponent == 1 { return self }
		
		var base = self
		var exponent = exponent
		var y: BigUInt = 1
		
		while exponent > 1 {
			if exponent & 1 != 0 { y *= base }
			base *= base
			exponent >>= 1
		}
		return base * y
	}
}

extension BigUInt: BinaryInteger {
	public init?<T: BinaryFloatingPoint>(exactly source: T) {
		if source.isZero {
			self._words = [0]
			return
		}
		guard source.isFinite else { return nil }
		guard source >= 0.0   else { return nil }
		guard source == source.rounded(.towardZero) else { return nil }
		
		let significand = source.significandBitPattern
		let exponent = BigUInt(source.exponent)
		let significandBitCount = BigUInt(T.significandBitCount)
		
		let high = BigUInt(1) << exponent
		let low = BigUInt(significand) >> (significandBitCount - exponent)
		self = high + low
	}
	
	@inlinable
	public init<T: BinaryFloatingPoint>(_ source: T) {
		precondition(source.isFinite, "BinaryFloatingPoint value cannot be converted to BigUInt because it is either infinite or NaN")
		precondition(source >= 0.0, "BinaryFloatingPoint value cannot be converted to BigUInt because the result would be less than BigUInt.min")
		self.init(exactly: source.rounded(.towardZero))!
	}
	
	public init<T: BinaryInteger>(_ source: T) {
		precondition(source >= 0, "Negative value is not representable")
		self._words = ContiguousArray(source.words)[...]
	}
	
	public init<T: BinaryInteger>(truncatingIfNeeded source: T) {
		self._words = ContiguousArray(source.words)[...]
	}
	
	public init<T: BinaryInteger>(clamping source: T) {
		if source < 0 {
			self._words = [0]
		} else {
			self._words = ContiguousArray(source.words)[...]
		}
	}
	
	public var words: [UInt] {
		return Words(self._words)
	}
	
	public var bitWidth: Int {
		return self._words.count * Element.bitWidth
	}
	
	public var trailingZeroBitCount: Int {
		return self._words.withUnsafeBufferPointer { words in
			let wordsPointer = CStorage(mutating: words.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
			return _BigUInt_TrailingZeroBitCount(wordsPointer, words.count)
		}
	}
	
	@inlinable
	public static func / (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
		return lhs.quotientAndRemainder(dividingBy: rhs).quotient
	}
	
	@inlinable
	public static func % (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
		return lhs.quotientAndRemainder(dividingBy: rhs).remainder
	}
	
	@inlinable
	public static func /= (lhs: inout BigUInt, rhs: BigUInt) {
		lhs = lhs / rhs
	}
	
	@inlinable
	public static func %= (lhs: inout BigUInt, rhs: BigUInt) {
		lhs = lhs % rhs
	}
	
	public prefix static func ~ (x: BigUInt) -> BigUInt {
		var result = Storage(repeating: 0, count: x._words.count)
		
		var length = 0
		result.withUnsafeMutableBufferPointer { result in
			x._words.withUnsafeBufferPointer { x in
				let xPointer = CStorage(mutating: x.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
				let resultPointer = CStorage(mutating: result.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
				length = _BigUInt_BitwiseNegate(xPointer, x.count,
				                                resultPointer)
			}
		}
		return BigUInt(words: result[..<length])
	}
	
	public static func & (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
		let minCount = Swift.min(lhs._words.count, rhs._words.count)
		var result = Storage(repeating: 0, count: minCount)
		
		var length = 0
		result.withUnsafeMutableBufferPointer { result in
			lhs._words.withUnsafeBufferPointer { lhs in
				rhs._words.withUnsafeBufferPointer { rhs in
					let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let resultPointer = CStorage(mutating: result.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					length = _BigUInt_BitwiseAnd(lhsPointer,
					                             rhsPointer,
					                             resultPointer, result.count)
				}
			}
		}
		return BigUInt(words: result[..<length])
	}
	
	public static func | (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
		let maxCount = Swift.max(lhs._words.count, rhs._words.count)
		var result = Storage(repeating: 0, count: maxCount)
		
		var length = 0
		result.withUnsafeMutableBufferPointer { result in
			lhs._words.withUnsafeBufferPointer { lhs in
				rhs._words.withUnsafeBufferPointer { rhs in
					let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let resultPointer = CStorage(mutating: result.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					length = _BigUInt_BitwiseOr(lhsPointer, lhs.count,
					                            rhsPointer, rhs.count,
					                            resultPointer)
				}
			}
		}
		return BigUInt(words: result[..<length])
	}
	
	public static func ^ (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
		let maxCount = Swift.max(lhs._words.count, rhs._words.count)
		var result = Storage(repeating: 0, count: maxCount)
		
		var length = 0
		result.withUnsafeMutableBufferPointer { result in
			lhs._words.withUnsafeBufferPointer { lhs in
				rhs._words.withUnsafeBufferPointer { rhs in
					let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let resultPointer = CStorage(mutating: result.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					length = _BigUInt_BitwiseXor(lhsPointer, lhs.count,
					                             rhsPointer, rhs.count,
					                             resultPointer)
				}
			}
		}
		return BigUInt(words: result[..<length])
	}
	
	public static func >> <RHS: BinaryInteger>(lhs: BigUInt,
	                                           rhs: RHS) -> BigUInt {
		if lhs == 0 || rhs >= lhs.bitWidth { return 0 }
		if rhs < 0 { return lhs << (0 - rhs) }
		
		let quotient = Int(rhs >> Element.bitWidth.trailingZeroBitCount)
		let remainder = Int(rhs & RHS(Element.bitWidth - 1))
		
		if quotient >= lhs._words.count { return 0 }
		var shifted = lhs._words[(lhs._words.startIndex + quotient)...]
		
		var length = 0
		shifted.withUnsafeMutableBufferPointer { shifted in
			let shiftedPointer = CStorage(mutating: shifted.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
			length = _BigUInt_RightShift(shiftedPointer, shifted.count,
			                             remainder)
		}
		return BigUInt(words: shifted[..<(shifted.startIndex + length)])
	}
	
	public static func << <RHS: BinaryInteger>(lhs: BigUInt,
		                                       rhs: RHS) -> BigUInt {
		if lhs == 0 { return 0 }
		if rhs < 0 { return lhs << (0 - rhs) }
		
		let quotient = Int(rhs >> Element.bitWidth.trailingZeroBitCount)
		let remainder = Int(rhs & RHS(Element.bitWidth - 1))
		
		var shifted = Storage(repeating: 0, count: lhs._words.count + quotient + 1)
		
		var length = 0
		shifted.withUnsafeMutableBufferPointer { shifted in
			lhs._words.withUnsafeBufferPointer { lhs in
				let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
				let shiftedPointer = CStorage(mutating: shifted.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
				length = _BigUInt_LeftShift(lhsPointer, lhs.count,
				                            shiftedPointer.advanced(by: quotient), remainder)
			}
		}
		return BigUInt(words: shifted[..<(quotient + length)])
	}
	
	@inlinable
	public static func &= (lhs: inout BigUInt, rhs: BigUInt) {
		lhs = lhs & rhs
	}
	
	@inlinable
	public static func |= (lhs: inout BigUInt, rhs: BigUInt) {
		lhs = lhs | rhs
	}
	
	@inlinable
	public static func ^= (lhs: inout BigUInt, rhs: BigUInt) {
		lhs = lhs ^ rhs
	}
	
	@inlinable
	public static func >>= <RHS: BinaryInteger>(lhs: inout BigUInt, rhs: RHS) {
		lhs = lhs >> rhs
	}
	
	@inlinable
	public static func <<= <RHS: BinaryInteger>(lhs: inout BigUInt, rhs: RHS) {
		lhs = lhs << rhs
	}
	
	public func quotientAndRemainder(dividingBy rhs: BigUInt) -> (quotient: BigUInt, remainder: BigUInt) {
		if rhs == 0 { fatalError("Division by zero on BigUInt") }
		
		if self < rhs { return (0, self) }
		if self == rhs { return (1, 0) }
		
		let lhsCount = self._words.count
		let rhsCount = rhs._words.count
		var quotient = Storage(repeating: 0, count: lhsCount - rhsCount + 1)
		var remainder = Storage(repeating: 0, count: rhsCount + 1)[...]
		
		var quotientLength = quotient.count
		var remainderLength = remainder.count
		quotient.withUnsafeMutableBufferPointer { quotient in
			remainder.withUnsafeMutableBufferPointer { remainder in
				self._words.withUnsafeBufferPointer { lhs in
					rhs._words.withUnsafeBufferPointer { rhs in
						let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
						let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
						let quotientPointer = CStorage(mutating: quotient.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
						let remainderPointer = CStorage(mutating: remainder.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
						_BigUInt_QuotientAndRemainder(lhsPointer, lhs.count,
						                              rhsPointer, rhs.count,
						                              quotientPointer, &quotientLength,
						                              remainderPointer, &remainderLength)
					}
				}
			}
		}
		return (
			BigUInt(words: quotient[..<quotientLength]),
			BigUInt(words: remainder[..<remainderLength])
		)
	}
	
	public func isMultiple(of other: BigUInt) -> Bool {
		if other == 0 { return self == 0 }
		if other == 1 { return true }
		if other == 2 { return self._words[0] & 1 == 0 }
		return self % other == 0
	}
	
	@inlinable
	public func signum() -> BigUInt {
		return self == 0 ? 0 : 1
	}
}

extension BigUInt: LosslessStringConvertible {
	@inlinable
	public init?(_ description: String) {
		self.init(description, radix: 10)
	}
}

extension BigUInt: CustomStringConvertible {
	public var description: String {
		let (count, p) = Bases.CharactersPerWord(radix: 10)
		let power = p == 0 ? BigUInt(words: [0, 1]) : BigUInt(words: [p])
		let digitCount = Bases.DigitCount(for: self._words.count, radix: 10)
		let characterCount = Int(_log10(Double(p)).rounded(.up)) * digitCount
		
		var digits = Storage(repeating: 0, count: digitCount)
		var cResult = ContiguousArray<CChar>(repeating: 0, count: characterCount + 1)
		return digits.withUnsafeMutableBufferPointer { digits in
			return cResult.withUnsafeMutableBufferPointer { cResult in
				var index = 0
				var (quotient, remainder) = (self, BigUInt())
				while quotient > 0 {
					(quotient, remainder) = quotient.quotientAndRemainder(dividingBy: power)
					digits[index] = remainder._words.withUnsafeBufferPointer { $0[0] }
					index += 1
				}
				
				let digitsPointer = CStorage(mutating: digits.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
				_BigUInt_DigitsToString(digitsPointer, Swift.max(index, 1),
				                        cResult.baseAddress!, cResult.count,
				                        count)
				return String(cString: cResult.baseAddress!)
			}
		}
	}
}

extension BigUInt: Numeric {
	@inlinable
	public var magnitude: BigUInt { return self }
	
	public init?<T: BinaryInteger>(exactly source: T) {
		if source < 0 { return nil }
		self._words = ContiguousArray(source.words)[...]
	}
	
	public static func * (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
		let sumCount = lhs._words.count + rhs._words.count
		var prod = Storage(repeating: 0, count: sumCount)
		
		var length = 0
		prod.withUnsafeMutableBufferPointer { prod in
			lhs._words.withUnsafeBufferPointer { lhs in
				rhs._words.withUnsafeBufferPointer { rhs in
					let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let prodPointer = CStorage(mutating: prod.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					length = _BigUInt_Multiplication(lhsPointer, lhs.count,
					                                 rhsPointer, rhs.count,
					                                 prodPointer)
				}
			}
		}
		return BigUInt(words: prod[..<length])
	}
	
	@inlinable
	public static func *= (lhs: inout BigUInt, rhs: BigUInt) {
		lhs = lhs * rhs
	}
}

extension BigUInt: Strideable {
	@inlinable
	public func distance(to other: BigUInt) -> BigInt {
		if self > other {
			if let result = BigInt(exactly: self - other) {
				return -result
			}
		} else {
			if let result = BigInt(exactly: other - self) {
				return result
			}
		}
		preconditionFailure("Distance is not representable in BigInt")
	}
	
	@inlinable
	public func advanced(by n: BigInt) -> BigUInt {
		return n < (0 as BigInt)
			? self - BigUInt(-n)
			: self + BigUInt(n)
	}
}

extension BigUInt: AdditiveArithmetic {
	public static func + (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
		let maxCount = Swift.max(lhs._words.count, rhs._words.count)
		var sum = Storage(repeating: 0, count: maxCount + 1)
		
		var length = 0
		sum.withUnsafeMutableBufferPointer { sum in
			lhs._words.withUnsafeBufferPointer { lhs in
				rhs._words.withUnsafeBufferPointer { rhs in
					let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let sumPointer = CStorage(mutating: sum.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					length = _BigUInt_Addition(lhsPointer, lhs.count,
					                           rhsPointer, rhs.count,
					                           sumPointer)
				}
			}
		}
		return BigUInt(words: sum[..<length])
	}
	
	public static func - (lhs: BigUInt, rhs: BigUInt) -> BigUInt {
		if lhs == rhs { return BigUInt(words: [0]) }
		precondition(lhs > rhs)
		
		var length = 0
		var diff = Storage(repeating: 0, count: lhs._words.count)
		diff.withUnsafeMutableBufferPointer { diff in
			lhs._words.withUnsafeBufferPointer { lhs in
				rhs._words.withUnsafeBufferPointer { rhs in
					let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let diffPointer = CStorage(mutating: diff.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					length = _BigUInt_Subtraction(lhsPointer, lhs.count,
					                              rhsPointer, rhs.count,
					                              diffPointer)
				}
			}
		}
		return BigUInt(words: diff[..<length])
	}
	
	@inlinable
	public static func += (lhs: inout BigUInt, rhs: BigUInt) {
		lhs = lhs + rhs
	}
	
	@inlinable
	public static func -= (lhs: inout BigUInt, rhs: BigUInt) {
		lhs = lhs - rhs
	}
}

extension BigUInt: ExpressibleByIntegerLiteral {
	public init(integerLiteral value: UInt64) {
		self._words = ContiguousArray(value.words)[...]
	}
}

extension BigUInt: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(self._words)
	}
}

extension BigUInt: Comparable {
	public static func < (lhs: BigUInt, rhs: BigUInt) -> Bool {
		return lhs._words.withUnsafeBufferPointer { lhs -> Bool in
			return rhs._words.withUnsafeBufferPointer { rhs -> Bool in
				let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
				let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
				return _BigUInt_LessThan(lhsPointer, lhs.count,
				                         rhsPointer, rhs.count)
			}
		}
	}
}

extension BigUInt: Equatable {
	public static func == (lhs: BigUInt, rhs: BigUInt) -> Bool {
		return lhs._words == rhs._words
	}
}

extension BigUInt: ModularOperations {
	@inlinable
	public func adding(_ other: BigUInt, modulo: BigUInt) -> BigUInt {
		precondition(modulo > 0, "modulus is not greater than zero")
		let lhs = self.modulo(modulo)
		let rhs = other.modulo(modulo)
		return (lhs + rhs).modulo(modulo)
	}
	
	@inlinable
	public func subtracting(_ other: BigUInt, modulo: BigUInt) -> BigUInt {
		precondition(modulo > 0, "modulus is not greater than zero")
		let lhs = self.modulo(modulo)
		let rhs = other.modulo(modulo)
		
		if lhs >= rhs {
			return lhs - rhs
		} else {
			return modulo - rhs + lhs
		}
	}
	
	@inlinable
	public func multiplying(_ other: BigUInt, modulo: BigUInt) -> BigUInt {
		precondition(modulo > 0, "modulus is not greater than zero")
		let lastBit = BigUInt(1) << (self.bitWidth - 1)
		
		var lhs = self.modulo(modulo)
		let rhs = other.modulo(modulo)
		var d: BigUInt = 0
		let mp2 = modulo >> 1
		for _ in 0..<self.bitWidth {
			d = (d > mp2) ? (d << 1) - modulo : d << 1
			if lhs & lastBit != 0 {
				d = d.adding(rhs, modulo: modulo)
			}
			lhs <<= 1
		}
		return d.modulo(modulo)
	}
}
