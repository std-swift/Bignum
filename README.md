# Bignum

[![](https://img.shields.io/badge/Swift-5.0-orange.svg)][1]
[![](https://img.shields.io/badge/os-macOS%20|%20Linux-lightgray.svg)][1]
[![](https://travis-ci.com/std-swift/Bignum.svg?branch=master)][2]
[![](https://codecov.io/gh/std-swift/Bignum/branch/master/graph/badge.svg)][3]
[![](https://codebeat.co/badges/14666597-f937-4f39-b6fd-9164c7fb39cd)][4]

[1]: https://swift.org/download/#releases
[2]: https://travis-ci.com/std-swift/Bignum
[3]: https://codecov.io/gh/std-swift/Bignum
[4]: https://codebeat.co/projects/github-com-std-swift-bignum-master

Arbitrary precision arithmetic with `BigInt` and `BigUInt` with decent performance

## Importing

```Swift
import Bignum
```

```Swift
dependencies: [
	.package(url: "https://github.com/std-swift/Bignum.git",
	         from: "1.0.0")
],
targets: [
	.target(
		name: "",
		dependencies: [
			"Bignum"
		]),
]
```

## Using

- `BigInt` conforms to `SignedInteger`
- `BigUInt` conforms to `UnsignedInteger`
