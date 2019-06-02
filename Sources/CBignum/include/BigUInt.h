//
//  BigUInt.h
//  CBignum
//

#pragma once

#include <stdbool.h>
#include <stddef.h>

size_t _BigUInt_Addition(size_t* lhs, size_t lhsCount,
                         size_t* rhs, size_t rhsCount,
                         size_t* sum);

size_t _BigUInt_Subtraction(size_t* lhs, size_t lhsCount,
                            size_t* rhs, size_t rhsCount,
                            size_t* diff);

size_t _BigUInt_Multiplication(size_t* lhs, size_t lhsCount,
                               size_t* rhs, size_t rhsCount,
                               size_t* prod);

void _BigUInt_QuotientAndRemainder(size_t* lhs, size_t lhsCount,
                                   size_t* rhs, size_t rhsCount,
                                   size_t* quotient, size_t* quotientCount,
                                   size_t* remainder, size_t* remainderCount);

size_t _BigUInt_LeftShift(size_t* shifting, size_t shiftingCount,
                          size_t* shifted, size_t amount);

size_t _BigUInt_RightShift(size_t* shifted, size_t shiftedCount,
                           size_t amount);

size_t _BigUInt_BitwiseNegate(size_t* negating, size_t negatingCount,
                              size_t* negated);

size_t _BigUInt_BitwiseAnd(size_t* lhs,
                           size_t* rhs,
                           size_t* result, size_t resultCount);

size_t _BigUInt_BitwiseOr(size_t* lhs, size_t lhsCount,
                          size_t* rhs, size_t rhsCount,
                          size_t* result);

size_t _BigUInt_BitwiseXor(size_t* lhs, size_t lhsCount,
                           size_t* rhs, size_t rhsCount,
                           size_t* result);

bool _BigUInt_LessThan(size_t* lhs, size_t lhsCount,
                       size_t* rhs, size_t rhsCount);

void _BigUInt_DigitsToString(size_t* digits, size_t digitsCount,
                             char* string, size_t stringCount,
                             size_t digitDigits);

size_t _BigUInt_TrailingZeroBitCount(size_t* words, size_t wordsCount);
