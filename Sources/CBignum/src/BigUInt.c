//
//  BigUInt.c
//  CBignum
//

#include "common.h"
#include "macros.h"
#include "_BigUInt.h"

#include <stdio.h>

size_t sizetBits = BITSIZEOF(size_t);
size_t shiftAmount = BITSIZEOF(size_t) - 1;
size_t sizetBitMask = BITSIZEOF(size_t) - 1;

size_t _BigUInt_Addition(size_t* lhs, size_t lhsCount,
                         size_t* rhs, size_t rhsCount,
                         size_t* sum) {
	size_t maxCount = MAX(lhsCount, rhsCount);
	
	int lhsRemaining = lhsCount;
	int rhsRemaining = rhsCount;
	
	size_t new = 0;
	bool overflow = false;
	
	while ((lhsRemaining > 0) && (rhsRemaining > 0)) {
		new = *lhs + *rhs++;
		if (overflow) {
			overflow = new < *lhs++;
			overflow |= ++new == 0;
		} else {
			overflow = new < *lhs++;
		}
		*sum++ = new;
		--lhsRemaining;
		--rhsRemaining;
	}
	
	if (lhsRemaining == 0) {
		lhsRemaining = rhsRemaining;
		lhs = rhs;
	}
	while (lhsRemaining-- > 0) {
		if (overflow) {
			new = *lhs++ + 1;
			overflow = new == 0;
			*sum++ = new;
		} else {
			*sum++ = *lhs++;
		}
	}
	
	if (overflow) {
		*sum = 1;
		return maxCount + 1;
	}
	return maxCount;
}

size_t _BigUInt_Subtraction(size_t* lhs, size_t lhsCount,
                            size_t* rhs, size_t rhsCount,
                            size_t* diff) {
	int lhsRemaining = lhsCount;
	int rhsRemaining = rhsCount;
	
	size_t new = 0;
	bool overflow = false;
	
	while (rhsRemaining > 0) {
		new = *lhs - *rhs++;
		if (overflow) {
			overflow = new > *lhs++;
			overflow |= --new == __SIZE_MAX__;
		} else {
			overflow = new > *lhs++;
		}
		*diff++ = new;
		--lhsRemaining;
		--rhsRemaining;
	}
	
	while (overflow) {
		new = *lhs++ - 1;
		overflow = new == __SIZE_MAX__;
		*diff++ = new;
		--lhsRemaining;
	}
	
	while (lhsRemaining-- > 0) {
		*diff++ = *lhs++;
	}
	
	return _BigUInt_ActualCount(diff, lhsCount);
}

size_t _BigUInt_Multiplication(size_t* lhs, size_t lhsCount,
                               size_t* rhs, size_t rhsCount,
                               size_t* prod) {
	for (size_t i = 0; i < lhsCount; ++i) {
		size_t l = lhs[i];
		if (l == 0) { continue; }
		for (size_t j = 0; j < rhsCount; ++j) {
			size_t r = rhs[j];
			if (r == 0) { continue; }
			__uint128_t result = ((__uint128_t)l) * ((__uint128_t)r);
			size_t low = (size_t)result;
			size_t high = (size_t)(result >> sizetBits);
			if (high != 0) { _BigUInt_ShiftAddTwo(prod, i + j, low, high); }
			else           { _BigUInt_ShiftAddOne(prod, i + j, low); }
		}
	}
	
	size_t count = lhsCount + rhsCount;
	return _BigUInt_ActualCountFromStart(prod, count);
}

void _BigUInt_QuotientAndRemainder(size_t* lhs, size_t lhsCount,
                                   size_t* rhs, size_t rhsCount,
                                   size_t* quotient, size_t* quotientCount,
                                   size_t* remainder, size_t* remainderCount) {
	size_t qCount = *quotientCount;
	size_t rCount = *remainderCount;
	
	size_t usedBits = lhsCount * sizetBits - clz(lhs[lhsCount-1]);
	for (ptrdiff_t i = usedBits - 1; i >= 0; --i) {
		_BigUInt_LeftShift(remainder, rCount, remainder, 1);
		bool bit = _BigUInt_GetBit(lhs, i);
		_BigUInt_SetBit(remainder, 0, bit);
		if (!_BigUInt_Seeking_LessThan(remainder, rCount, rhs, rhsCount)) {
			_BigUInt_Subtraction(remainder, rCount,
			                     rhs, rhsCount, remainder);
			_BigUInt_SetBit(quotient, i, true);
		}
	}
	*quotientCount = _BigUInt_ActualCountFromStart(quotient, qCount);
	*remainderCount = _BigUInt_ActualCountFromStart(remainder, rCount);
}

size_t _BigUInt_LeftShift(size_t* shifting, size_t shiftingCount,
                          size_t* shifted, size_t amount) {
	size_t previousCarry = 0;
	size_t shiftAmount = sizetBits - amount;
	
	size_t* shiftingEnd = shifting + shiftingCount;
	while (shifting < shiftingEnd) {
		size_t element = *shifting++;
		if (amount != 0) {
			size_t carry = element >> shiftAmount;
			element <<= amount;
			element |= previousCarry;
			previousCarry = carry;
		}
		*shifted++ = element;
	}
	
	if (previousCarry != 0) {
		*shifted = previousCarry;
		return shiftingCount + 1;
	}
	return shiftingCount;
}

size_t _BigUInt_RightShift(size_t* shifted, size_t shiftedCount,
                           size_t amount) {
	size_t* shiftedStart = shifted;
	size_t previousCarry = 0;
	size_t shiftAmount = sizetBits - amount;
	
	shifted += shiftedCount;
	while (shifted-- > shiftedStart) {
		size_t element = *shifted;
		if (amount != 0) {
			size_t carry = element << shiftAmount;
			element >>= amount;
			element |= previousCarry;
			previousCarry = carry;
		}
		*shifted = element;
	}
	
	return _BigUInt_ActualCountFromStart(shiftedStart, shiftedCount);
}

size_t _BigUInt_BitwiseNegate(size_t* negating, size_t negatingCount,
                              size_t* negated) {
	size_t count = negatingCount;
	while (count--) {
		*negated++ = ~*negating++;
	}
	return _BigUInt_ActualCount(negated, negatingCount);
}

size_t _BigUInt_BitwiseAnd(size_t* lhs,
                           size_t* rhs,
                           size_t* result, size_t resultCount) {
	size_t count = resultCount;
	while (count--) {
		*result++ = *lhs++ & *rhs++;
	}
	return _BigUInt_ActualCount(result, resultCount);
}

size_t _BigUInt_BitwiseOr(size_t* lhs, size_t lhsCount,
                          size_t* rhs, size_t rhsCount,
                          size_t* result) {
	size_t maxCount = MAX(lhsCount, rhsCount);
	size_t minCount = MIN(lhsCount, rhsCount);
	size_t count = maxCount - minCount;
	
	while (minCount--) {
		*result++ = *lhs++ | *rhs++;
	}
	
	if (lhsCount > rhsCount) {
		while (count--) {
			*result++ = *lhs++;
		}
	} else {
		while (count--) {
			*result++ = *rhs++;
		}
	}
	
	return _BigUInt_ActualCount(result, maxCount);
}

size_t _BigUInt_BitwiseXor(size_t* lhs, size_t lhsCount,
                           size_t* rhs, size_t rhsCount,
                           size_t* result) {
	size_t maxCount = MAX(lhsCount, rhsCount);
	size_t minCount = MIN(lhsCount, rhsCount);
	size_t count = maxCount - minCount;
	
	while (minCount--) {
		*result++ = *lhs++ ^ *rhs++;
	}
	
	if (lhsCount > rhsCount) {
		while (count--) {
			*result++ = *lhs++;
		}
	} else {
		while (count--) {
			*result++ = *rhs++;
		}
	}
	
	return _BigUInt_ActualCount(result, maxCount);
}

bool _BigUInt_LessThan(size_t* lhs, size_t lhsCount,
                       size_t* rhs, size_t rhsCount) {
	if (lhsCount != rhsCount) {
		return lhsCount < rhsCount;
	}
	
	lhs += lhsCount;
	rhs += lhsCount;
	while (lhsCount--) {
		size_t left = *--lhs;
		size_t right = *--rhs;
		if (left < right) { return true; }
		if (left > right) { return false; }
	}
	return false;
}

void _BigUInt_DigitsToString(size_t* digits, size_t digitsCount,
                             char* string, size_t stringCount,
                             size_t digitDigits) {
	digits += digitsCount;
	
	size_t digit = *--digits;
	--digitsCount;
	int count = snprintf(string, stringCount, "%zu", digit);
	string += count;
	stringCount -= count;
	
	while (digitsCount-- > 0) {
		digit = *--digits;
		int count = snprintf(string, stringCount, "%0*zu", (int)digitDigits, digit);
		string += count;
		stringCount -= count;
	}
}

size_t _BigUInt_TrailingZeroBitCount(size_t* words, size_t wordsCount) {
	size_t count = 0;
	while (count < wordsCount) {
		if (*words++ != 0) { break; }
		++count;
	}
	size_t zeroBitCount = count * sizetBits;
	if (count < wordsCount) {
		return zeroBitCount + ctz(*--words);
	}
	return zeroBitCount;
}

void _BigUInt_ShiftAddOne(size_t* accumulator, size_t shift,
                          size_t element) {
	accumulator += shift;
	
	size_t new = *accumulator + element;
	bool overflow = new < *accumulator;
	*accumulator++ = new;
	
	while (overflow) {
		new = *accumulator + 1;
		overflow = new == 0;
		*accumulator++ = new;
	}
}

void _BigUInt_ShiftAddTwo(size_t* accumulator, size_t shift,
                          size_t element1, size_t element2) {
	accumulator += shift;
	
	size_t new = *accumulator + element1;
	bool overflow = new < *accumulator;
	*accumulator++ = new;
	
	if (overflow) {
		overflow = ++*accumulator == 0;
	}
	
	new = *accumulator + element2;
	overflow |= new < *accumulator;
	*accumulator++ = new;
	
	while (overflow) {
		new = *accumulator + 1;
		overflow = new == 0;
		*accumulator++ = new;
	}
}

bool _BigUInt_GetBit(size_t* words, size_t i) {
	size_t wordIndex = i >> ctz(sizetBits);
	size_t bitIndex = i & sizetBitMask;
	size_t value = words[wordIndex] & ((size_t)1 << bitIndex);
	return value != 0;
}

void _BigUInt_SetBit(size_t* words, size_t i, bool value) {
	size_t wordIndex = i >> ctz(sizetBits);
	size_t bitIndex = i & sizetBitMask;
	if (value) {
		words[wordIndex] |= (size_t)1 << bitIndex;
	} else {
		words[wordIndex] &= ~((size_t)1 << bitIndex);
	}
}

bool _BigUInt_Seeking_LessThan(size_t* lhs, size_t lhsCount,
                               size_t* rhs, size_t rhsCount) {
	size_t* lhsStart = lhs;
	size_t* rhsStart = rhs;
	lhs += lhsCount;
	rhs += rhsCount;
	while (*--lhs == 0) { --lhsCount; }
	while (*--rhs == 0) { --rhsCount; }
	return _BigUInt_LessThan(lhsStart, lhsCount, rhsStart, rhsCount);
}

size_t _BigUInt_ActualCount(size_t* number, size_t count) {
	while (count > 1) {
		if (*--number != 0) { break; }
		--count;
	}
	return count;
}

size_t _BigUInt_ActualCountFromStart(size_t* number, size_t count) {
	return _BigUInt_ActualCount(number + count, count);
}
