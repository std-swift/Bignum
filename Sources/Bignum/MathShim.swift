//
//  MathShim.swift
//  Bignum
//

// TODO: This file becomes obsolete when SE-0246 is implemented
// https://github.com/apple/swift-evolution/blob/master/proposals/0246-mathable.md

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import func Darwin.C.math.log
import func Darwin.C.math.log10
#endif

#if os(Linux)
import func SwiftGlibc.C.math.log
import func SwiftGlibc.C.math.log10
#endif

func _log(_ x: Double) -> Double {
	return log(x)
}

func _log10(_ x: Double) -> Double {
	return log10(x)
}
