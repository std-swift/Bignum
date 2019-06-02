//
//  BigUInt.c
//  CBignum
//

#include "common.h"
#include "macros.h"
#include "_BigInt.h"
#include "_BigUInt.h"

#include <string.h>

size_t _BigInt_SignConversion(size_t* words, size_t wordsCount,
                              bool wordsNegative, bool resultNegative,
                              size_t* result) {
	size_t new = 0;
	size_t count = wordsCount;
	
	if (wordsNegative == resultNegative) {
		while (count-- > 0) {
			*result++ = *words++;
		}
		new = *(result - 1);
	} else {
		bool overflow = true;
		while (count-- > 0) {
			new = ~*words++;
			if (overflow) {
				overflow = ++new == 0;
			}
			*result++ = new;
		}
	}
	
	if (_BigInt_IsValueNegative(new)) {
		if (!resultNegative) {
			*result = 0;
			return wordsCount + 1;
		}
	} else {
		if (resultNegative) {
			*result = ~((size_t)0);
			return wordsCount + 1;
		}
	}
	return wordsCount;
}

size_t _BigInt_BitwiseAnd(size_t* lhs, size_t lhsCount, bool lhsNegative,
                          size_t* rhs, size_t rhsCount, bool rhsNegative,
                          size_t* result, size_t resultCount) {
	size_t minCount = MIN(lhsCount, rhsCount);
	size_t count = resultCount - minCount;
	
	size_t* r = result;
	while (minCount--) {
		*r++ = *lhs++ & *rhs++;
	}
	
	if (lhsCount > rhsCount) {
		if (rhsNegative) {
			while (count--) {
				*r++ = *lhs++;
			}
		} else {
			while (count--) {
				*r++ = 0;
			}
		}
	} else {
		if (lhsNegative) {
			while (count--) {
				*r++ = *rhs++;
			}
		} else {
			while (count--) {
				*r++ = 0;
			}
		}
	}
	
	if (_BigInt_IsNegative(result, resultCount)) {
		_BigInt_TwosComplement(result, resultCount);
	}
	return _BigUInt_ActualCountFromStart(result, resultCount);
}

size_t _BigInt_BitwiseOr(size_t* lhs, size_t lhsCount, bool lhsNegative,
                         size_t* rhs, size_t rhsCount, bool rhsNegative,
                         size_t* result, size_t resultCount) {
	size_t minCount = MIN(lhsCount, rhsCount);
	size_t count = resultCount - minCount;
	
	size_t* r = result;
	while (minCount--) {
		*r++ = *lhs++ | *rhs++;
	}
	
	if (lhsCount > rhsCount) {
		if (rhsNegative) {
			while (count--) {
				*r++ = (size_t)-1;
			}
		} else {
			while (count--) {
				*r++ = *lhs++;
			}
		}
	} else {
		if (lhsNegative) {
			while (count--) {
				*r++ = (size_t)-1;
			}
		} else {
			while (count--) {
				*r++ = *rhs++;
			}
		}
	}
	
	if (_BigInt_IsNegative(result, resultCount)) {
		_BigInt_TwosComplement(result, resultCount);
	}
	return _BigUInt_ActualCountFromStart(result, resultCount);
}

size_t _BigInt_BitwiseXor(size_t* lhs, size_t lhsCount, bool lhsNegative,
                          size_t* rhs, size_t rhsCount, bool rhsNegative,
                          size_t* result, size_t resultCount) {
	size_t minCount = MIN(lhsCount, rhsCount);
	size_t count = resultCount - minCount;
	
	size_t* r = result;
	while (minCount--) {
		*r++ = *lhs++ ^ *rhs++;
	}
	
	if (lhsCount > rhsCount) {
		if (rhsNegative) {
			while (count--) {
				*r++ = ~(*lhs++);
			}
		} else {
			while (count--) {
				*r++ = *lhs++;
			}
		}
	} else {
		if (lhsNegative) {
			while (count--) {
				*r++ = ~(*rhs++);
			}
		} else {
			while (count--) {
				*r++ = *rhs++;
			}
		}
	}
	
	if (_BigInt_IsNegative(result, resultCount)) {
		_BigInt_TwosComplement(result, resultCount);
	}
	return _BigUInt_ActualCountFromStart(result, resultCount);
}

bool _BigInt_IsValueNegative(size_t value) {
	return clz(value) == 0;
}

bool _BigInt_IsNegative(size_t* number, size_t count) {
	return clz(number[count - 1]) == 0;
}

void _BigInt_TwosComplement(size_t* number, size_t count) {
	size_t new = 0;
	bool overflow = true;
	
	while (count-- > 0) {
		new = ~*number;
		if (overflow) {
			overflow = ++new == 0;
		}
		*number++ = new;
	}
}
