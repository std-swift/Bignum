//
//  BigUInt.c
//  CBignum
//

#include "common.h"
#include "macros.h"

size_t clzllCorrection = BITSIZEOF(unsigned long long) - BITSIZEOF(size_t);

size_t ctz(size_t x) {
	return __builtin_ctzll(x);
}

size_t clz(size_t x) {
	return __builtin_clzll(x) - clzllCorrection;
}
