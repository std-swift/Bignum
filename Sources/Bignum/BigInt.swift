//
//  BigInt.swift
//  Bignum
//

import CBignum
import ModularArithmetic

public struct BigInt: SignedInteger {
	private typealias Element = Words.Element
	private typealias Storage = ContiguousArray<Element>
	private typealias CStorage = UnsafeMutablePointer<Element>
	
	private var negative: Bool
	public let magnitude: BigUInt
	
	private var _words: ArraySlice<Element> {
		let words = self.magnitude._words
		var result = Storage(repeating: 0, count: words.count + 1)
		
		var length = 0
		result.withUnsafeMutableBufferPointer { result in
			words.withUnsafeBufferPointer { words in
				let wordsPointer = CStorage(mutating: words.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
				let resultPointer = CStorage(mutating: result.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
				length = _BigInt_SignConversion(wordsPointer, words.count,
				                                false, self.negative,
				                                resultPointer)
			}
		}
		return result[..<length]
	}
	
	private init(negative: Bool, magnitude: BigUInt) {
		self.negative = negative && magnitude != 0
		self.magnitude = magnitude
	}
	
	public init?<S : StringProtocol>(_ text: S, radix: Int = 10) {
		precondition(radix >= 2, "Radix not in range 2...36")
		precondition(radix <= 26, "Radix not in range 2...36")
		
		if text.first == "-" {
			self.negative = true
			guard let magnitude = BigUInt(text.dropFirst(), radix: radix) else { return nil }
			self.magnitude = magnitude
		} else {
			self.negative = false
			guard let magnitude = BigUInt(text, radix: radix) else { return nil }
			self.magnitude = magnitude
		}
	}
	
	@inlinable
	public func exponentiating<T: BinaryInteger>(by exponent: T) -> BigInt {
		if exponent  < 0 { return 0 }
		if exponent == 0 { return 1 }
		if exponent == 1 { return self }
		
		var base = self
		var exponent = exponent
		var y: BigInt = 1
		
		while exponent > 1 {
			if exponent & 1 != 0 { y *= base }
			base *= base
			exponent >>= 1
		}
		return base * y
	}
}

extension BigInt: BinaryInteger {
	public init?<T: BinaryFloatingPoint>(exactly source: T) {
		guard let magnitude = BigUInt(exactly: source.magnitude) else { return nil }
		self.magnitude = magnitude
		self.negative = source < 0
	}
	
	public init<T: BinaryFloatingPoint>(_ source: T) {
		self.negative = source < 0
		self.magnitude = BigUInt(source.magnitude)
	}
	
	public init<T: BinaryInteger>(_ source: T) {
		self.negative = source < 0
		self.magnitude = BigUInt(source.magnitude)
	}
	
	@inlinable
	public init<T: BinaryInteger>(truncatingIfNeeded source: T) {
		self.init(source)
	}
	
	@inlinable
	public init<T: BinaryInteger>(clamping source: T) {
		self.init(source)
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
	public static func / (lhs: BigInt, rhs: BigInt) -> BigInt {
		return lhs.quotientAndRemainder(dividingBy: rhs).quotient
	}
	
	@inlinable
	public static func % (lhs: BigInt, rhs: BigInt) -> BigInt {
		return lhs.quotientAndRemainder(dividingBy: rhs).remainder
	}
	
	@inlinable
	public static func /= (lhs: inout BigInt, rhs: BigInt) {
		lhs = lhs / rhs
	}
	
	@inlinable
	public static func %= (lhs: inout BigInt, rhs: BigInt) {
		lhs = lhs % rhs
	}
	
	public prefix static func ~ (x: BigInt) -> BigInt {
		if x > 0 { return BigInt(negative: true, magnitude: x.magnitude + 1) }
		if x == 0 { return BigInt(negative: true, magnitude: 1) }
		return BigInt(negative: false, magnitude: x.magnitude - 1)
	}
	
	public static func & (lhs: BigInt, rhs: BigInt) -> BigInt {
		let lhsWords = lhs._words
		let rhsWords = rhs._words
		
		let lhsNegative = lhs.negative
		let rhsNegative = rhs.negative
		
		let count = lhs.negative == rhs.negative
			? Swift.max(lhsWords.count, rhsWords.count)
			: lhs.negative ? rhsWords.count : lhsWords.count
		var result = Storage(repeating: 0, count: count)
		
		var length = 0
		result.withUnsafeMutableBufferPointer { result in
			lhsWords.withUnsafeBufferPointer { lhs in
				rhsWords.withUnsafeBufferPointer { rhs in
					let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let resultPointer = CStorage(mutating: result.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					length = _BigInt_BitwiseAnd(lhsPointer, lhs.count, lhsNegative,
					                            rhsPointer, rhs.count, rhsNegative,
					                            resultPointer, result.count)
				}
			}
		}
		let magnitude = BigUInt(words: result[..<length])
		return BigInt(negative: lhs.negative && rhs.negative,
		              magnitude: magnitude)
	}
	
	public static func | (lhs: BigInt, rhs: BigInt) -> BigInt {
		let lhsWords = lhs._words
		let rhsWords = rhs._words
		
		let lhsNegative = lhs.negative
		let rhsNegative = rhs.negative
		
		let count = Swift.max(lhsWords.count, rhsWords.count)
		var result = Storage(repeating: 0, count: count)
		
		var length = 0
		result.withUnsafeMutableBufferPointer { result in
			lhsWords.withUnsafeBufferPointer { lhs in
				rhsWords.withUnsafeBufferPointer { rhs in
					let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let resultPointer = CStorage(mutating: result.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					length = _BigInt_BitwiseOr(lhsPointer, lhs.count, lhsNegative,
					                           rhsPointer, rhs.count, rhsNegative,
					                           resultPointer, result.count)
				}
			}
		}
		let magnitude = BigUInt(words: result[..<length])
		return BigInt(negative: lhs.negative || rhs.negative,
		              magnitude: magnitude)
	}
	
	public static func ^ (lhs: BigInt, rhs: BigInt) -> BigInt {
		let lhsWords = lhs._words
		let rhsWords = rhs._words
		
		let lhsNegative = lhs.negative
		let rhsNegative = rhs.negative
		
		let count = Swift.max(lhsWords.count, rhsWords.count)
		var result = Storage(repeating: 0, count: count)
		
		var length = 0
		result.withUnsafeMutableBufferPointer { result in
			lhsWords.withUnsafeBufferPointer { lhs in
				rhsWords.withUnsafeBufferPointer { rhs in
					let lhsPointer = CStorage(mutating: lhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let rhsPointer = CStorage(mutating: rhs.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					let resultPointer = CStorage(mutating: result.baseAddress!).withMemoryRebound(to: Int.self, capacity: 1) { $0 }
					length = _BigInt_BitwiseXor(lhsPointer, lhs.count, lhsNegative,
					                            rhsPointer, rhs.count, rhsNegative,
					                            resultPointer, result.count)
				}
			}
		}
		let magnitude = BigUInt(words: result[..<length])
		return BigInt(negative: lhs.negative != rhs.negative,
		              magnitude: magnitude)
	}
	
	public static func >> <RHS: BinaryInteger>(lhs: BigInt, rhs: RHS) -> BigInt {
		return BigInt(negative: lhs.negative, magnitude: lhs.magnitude >> rhs)
	}
	
	public static func << <RHS: BinaryInteger>(lhs: BigInt, rhs: RHS) -> BigInt {
		return BigInt(negative: lhs.negative, magnitude: lhs.magnitude << rhs)
	}
	
	@inlinable
	public static func &= (lhs: inout BigInt, rhs: BigInt) {
		lhs = lhs & rhs
	}
	
	@inlinable
	public static func |= (lhs: inout BigInt, rhs: BigInt) {
		lhs = lhs | rhs
	}
	
	@inlinable
	public static func ^= (lhs: inout BigInt, rhs: BigInt) {
		lhs = lhs ^ rhs
	}
	
	@inlinable
	public static func >>= <RHS: BinaryInteger>(lhs: inout BigInt, rhs: RHS) {
		lhs = lhs >> rhs
	}
	
	@inlinable
	public static func <<= <RHS: BinaryInteger>(lhs: inout BigInt, rhs: RHS) {
		lhs = lhs << rhs
	}
	
	public func quotientAndRemainder(dividingBy rhs: BigInt) -> (quotient: BigInt, remainder: BigInt) {
		let negative = self.negative != rhs.negative
		let (quotient, remainder) = self.magnitude.quotientAndRemainder(dividingBy: rhs.magnitude)
		return (
			BigInt(negative: negative, magnitude: quotient),
			BigInt(negative: self.negative, magnitude: remainder)
		)
	}
	
	@inlinable
	public func isMultiple(of other: BigInt) -> Bool {
		return self.magnitude.isMultiple(of: other.magnitude)
	}
	
	public func signum() -> BigInt {
		if self.negative { return -1 }
		return BigInt(negative: false, magnitude: self.magnitude.signum())
	}
}

extension BigInt: LosslessStringConvertible {
	@inlinable
	public init?(_ description: String) {
		self.init(description, radix: 10)
	}
}

extension BigInt: CustomStringConvertible {
	public var description: String {
		if !self.negative { return self.magnitude.description }
		return "-" + self.magnitude.description
	}
}

extension BigInt: SignedNumeric {
	public mutating func negate() {
		self.negative.toggle()
	}
}

extension BigInt: Numeric {
	public init?<T: BinaryInteger>(exactly source: T) {
		self.negative = source < 0
		guard let magnitude = BigUInt(exactly: source.magnitude) else { return nil }
		self.magnitude = magnitude
	}
	
	public static func * (lhs: BigInt, rhs: BigInt) -> BigInt {
		let negative = lhs.negative != rhs.negative
		let magnitude = lhs.magnitude * rhs.magnitude
		return BigInt(negative: negative, magnitude: magnitude)
	}
	
	@inlinable
	public static func *= (lhs: inout BigInt, rhs: BigInt) {
		lhs = lhs * rhs
	}
}

extension BigInt: Strideable {
	@inlinable
	public func distance(to other: BigInt) -> BigInt {
		return other - self
	}
	
	@inlinable
	public func advanced(by n: BigInt) -> BigInt {
		return self + n
	}
}

extension BigInt: AdditiveArithmetic {
	public static func + (lhs: BigInt, rhs: BigInt) -> BigInt {
		if lhs.negative == rhs.negative {
			let magnitude = lhs.magnitude + rhs.magnitude
			return BigInt(negative: lhs.negative, magnitude: magnitude)
		}
		if lhs.negative {
			return rhs - -lhs
		}
		return lhs - -rhs
	}
	
	public static func - (lhs: BigInt, rhs: BigInt) -> BigInt {
		if lhs.negative == rhs.negative {
			if lhs.magnitude > rhs.magnitude {
				return BigInt(negative: lhs.negative, magnitude: lhs.magnitude - rhs.magnitude)
			} else {
				return BigInt(negative: !lhs.negative, magnitude: rhs.magnitude - lhs.magnitude)
			}
		}
		return lhs + -rhs
	}
	
	@inlinable
	public static func += (lhs: inout BigInt, rhs: BigInt) {
		lhs = lhs + rhs
	}
	
	@inlinable
	public static func -= (lhs: inout BigInt, rhs: BigInt) {
		lhs = lhs - rhs
	}
}

extension BigInt: ExpressibleByIntegerLiteral {
	public init(integerLiteral value: Int64) {
		self.negative = value < 0
		self.magnitude = BigUInt(value.magnitude)
	}
}

extension BigInt: Hashable {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(self.negative)
		hasher.combine(self.magnitude)
	}
}

extension BigInt: Comparable {
	public static func < (lhs: BigInt, rhs: BigInt) -> Bool {
		if lhs.negative != rhs.negative {
			return lhs.negative
		}
		if lhs.negative {
			return lhs.magnitude > rhs.magnitude
		}
		return lhs.magnitude < rhs.magnitude
	}
}

extension BigInt: Equatable {
	public static func == (lhs: BigInt, rhs: BigInt) -> Bool {
		return lhs.negative == rhs.negative && lhs.magnitude == rhs.magnitude
	}
}

extension BigInt: ModularOperations {
	@inlinable
	public func adding(_ other: BigInt, modulo: BigInt) -> BigInt {
		precondition(modulo > 0, "modulus is not greater than zero")
		let lhs = self.modulo(modulo)
		let rhs = other.modulo(modulo)
		return (lhs + rhs).modulo(modulo)
	}
	
	@inlinable
	public func subtracting(_ other: BigInt, modulo: BigInt) -> BigInt {
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
	public func multiplying(_ other: BigInt, modulo: BigInt) -> BigInt {
		precondition(modulo > 0, "modulus is not greater than zero")
		let lastBit = BigInt(1) << (self.bitWidth - 1)
		
		var lhs = self.modulo(modulo)
		let rhs = other.modulo(modulo)
		var d: BigInt = 0
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
