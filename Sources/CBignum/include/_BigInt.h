//
//  BigUInt.h
//  CBignum
//

#pragma once

#include "BigUInt.h"

bool _BigInt_IsValueNegative(size_t value);

bool _BigInt_IsNegative(size_t* number, size_t count);

void _BigInt_TwosComplement(size_t* number, size_t count);
