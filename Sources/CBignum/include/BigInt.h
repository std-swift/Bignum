//
//  BigInt.h
//  CBignum
//

#pragma once

#include <stdbool.h>
#include <stddef.h>

size_t _BigInt_SignConversion(size_t* words, size_t wordsCount,
                              bool wordsNegative, bool resultNegative,
                              size_t* result);

size_t _BigInt_BitwiseAnd(size_t* lhs, size_t lhsCount, bool lhsNegative,
                          size_t* rhs, size_t rhsCount, bool rhsNegative,
                          size_t* result, size_t resultCount);

size_t _BigInt_BitwiseOr(size_t* lhs, size_t lhsCount, bool lhsNegative,
                         size_t* rhs, size_t rhsCount, bool rhsNegative,
                         size_t* result, size_t resultCount);

size_t _BigInt_BitwiseXor(size_t* lhs, size_t lhsCount, bool lhsNegative,
                          size_t* rhs, size_t rhsCount, bool rhsNegative,
                          size_t* result, size_t resultCount);
