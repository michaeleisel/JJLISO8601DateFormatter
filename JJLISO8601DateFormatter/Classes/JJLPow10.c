//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import "JJLPow10.h"
#import <assert.h>

static const double pow10[] = {
    1e+0,
    1e+1,  1e+2,  1e+3,  1e+4,  1e+5,  1e+6,  1e+7,  1e+8,  1e+9,  1e+10, 1e+11, 1e+12, 1e+13, 1e+14, 1e+15, 1e+16, 1e+17, 1e+18, 1e+19, 1e+20,
    1e+21, 1e+22
};

inline double JJLPow10(int64_t exp) {
    int64_t length = sizeof(pow10) / sizeof(*pow10);
    assert(0 <= exp && exp < length);
    return pow10[exp];
}
