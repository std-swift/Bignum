//
//  BigUInt.h
//  CBignum
//

#pragma once

#include "BigUInt.h"

void _BigUInt_ShiftAddOne(size_t* accumulator, size_t shift,
                          size_t element);

void _BigUInt_ShiftAddTwo(size_t* accumulator, size_t shift,
                          size_t element1, size_t element2);

bool _BigUInt_GetBit(size_t* words, size_t i);

void _BigUInt_SetBit(size_t* words, size_t i, bool value);

bool _BigUInt_Seeking_LessThan(size_t* lhs, size_t lhsCount,
                               size_t* rhs, size_t rhsCount);

size_t _BigUInt_ActualCount(size_t* number, size_t count);

size_t _BigUInt_ActualCountFromStart(size_t* number, size_t count);
