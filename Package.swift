// swift-tools-version:5.0
//
//  Package.swift
//  Bignum
//

import PackageDescription

let package = Package(
	name: "Bignum",
	products: [
		.library(
			name: "Bignum",
			targets: ["Bignum"]),
	],
	dependencies: [
		.package(url: "https://github.com/std-swift/ModularArithmetic.git",
		         from: "1.0.0")
	],
	targets: [
		.target(
			name: "CBignum",
			dependencies: []),
		.target(
			name: "Bignum",
			dependencies: ["CBignum", "ModularArithmetic"]),
		.testTarget(
			name: "BignumTests",
			dependencies: ["Bignum"]),
	],
	cLanguageStandard: .c11
)
