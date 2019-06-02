//
//  macros.h
//  CBignum
//

#pragma once

#define MAX(a,b) \
	({ \
		__typeof__ (a) _a = (a); \
		__typeof__ (b) _b = (b); \
		_a > _b ? _a : _b; \
	})

#define MIN(a,b) \
	({ \
		__typeof__ (a) _a = (a); \
		__typeof__ (b) _b = (b); \
		_a > _b ? _b : _a; \
	})

#define BITSIZEOF(t) sizeof(t) * __CHAR_BIT__
