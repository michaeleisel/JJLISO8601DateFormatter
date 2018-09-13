//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <time.h>
#import <assert.h>
#import <string.h>

#import "JJLInternal.h"
#import "itoa.h"

#define JJL_COPY(...) \
({ \
char __tmpBuffer[] = {__VA_ARGS__}; \
memcpy(buffer, __tmpBuffer, sizeof(__tmpBuffer)); \
(*bufferPtr) += sizeof(__tmpBuffer); \
})

static inline void JJLFillBufferWithMonth(int month, char **bufferPtr) {
    assert(1 <= month && month <= 12);
    char *buffer = *bufferPtr;
    if (month < 10) {
        JJL_COPY('0', month + '0');
    } else {
        JJL_COPY('1', month - 10 + '0');
    }
}

// Requires buffer to be at least 5 bytes
static inline void JJLFillBufferWithYear(int year, char **bufferPtr) {
    char *buffer = *bufferPtr;
    if (2010 <= year && year <= 2019) {
        JJL_COPY('2', '0', '1', year - 2010 + '0');
        return;
    }

    if (2020 <= year && year <= 2029) {
        JJL_COPY('2', '0', '2', year - 2010 + '0');
        return;
    }

    uint32_t u = (uint32_t)year;
    if (year < 0) {
        *buffer++ = '-';
        u = ~u + 1;
    }
    if (u < 10) {
        *buffer++ = '0';
    }
    if (u < 100) {
        *buffer++ = '0';
    }
    if (u < 1000) {
        *buffer++ = '0';
    }
    u32toa(u, buffer); // ignore return value
    (*bufferPtr) += strlen(*bufferPtr);
}

static inline void JJLFillBufferWithUpTo60(int time, char **bufferPtr) {
    assert(0 <= time && time <= 60);
    char *buffer = *bufferPtr;
    int32_t tens = 0;
    if (time >= 30) {
        tens += 3;
        time -= 30;
    }
    if (time >= 10) {
        tens += 1;
        time -= 10;
        if (time >= 10) {
            tens += 1;
            time -= 10;
            if (time >= 10) { // Last one for leap seconds
                tens += 1;
                time -= 10;
            }
        }
    }

    JJL_COPY('0' + tens, '0' + time);
    return;
}

void JJLFillBufferForDate(char *buffer, time_t time) {
    struct tm components = {0};
    char **bufferPtr = &buffer;
    localtime_r(&time, &components);
    time -= components.tm_gmtoff;
    JJLFillBufferWithYear(components.tm_year + 1900, &buffer);
    JJL_COPY('-');
    JJLFillBufferWithMonth(components.tm_mon + 1, &buffer);
    JJL_COPY('-');
    JJLFillBufferWithUpTo60(components.tm_mday, &buffer);
    JJL_COPY('T');
    JJLFillBufferWithUpTo60(components.tm_hour, &buffer);
    JJL_COPY(':');
    JJLFillBufferWithUpTo60(components.tm_min, &buffer);
    JJL_COPY(':');
    JJLFillBufferWithUpTo60(components.tm_sec, &buffer);
    JJL_COPY('Z');
}
