//
//  StringShim.swift
//  Bignum
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import func Darwin.C.string.memcpy
#endif

#if os(Linux)
import func SwiftGlibc.C.string.memcpy
#endif

@discardableResult
func _memcpy(_ destination: UnsafeMutableRawPointer!,
             _ source: UnsafeRawPointer!,
             _ count: Int) -> UnsafeMutableRawPointer! {
	return memcpy(destination, source, count)
}
