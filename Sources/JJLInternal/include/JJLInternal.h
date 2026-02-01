//Copyright (c) 2018 Michael Eisel. All rights reserved.

#ifndef JJLInternal_h
#define JJLInternal_h

#import <time.h>
#import <CoreFoundation/CFDateFormatter.h>
#include "tzdb.h"

// This C file does the heavy lifting for the libraries. This is to allow maximum portability in the future, in case we want to make a Swift version, a version that can run on Linux, etc.

static const int32_t kJJLMaxDateLength = 50; // Extra to be safe

// Core functions for date formatting
void JJLFillBufferForDate(char *buffer, double timeInSeconds, CFISO8601DateFormatOptions options, timezone_t timeZone, double fallbackOffset);
double JJLTimeIntervalForString(const char *string, int32_t length, CFISO8601DateFormatOptions options, timezone_t timeZone, _Bool *errorOccurred);
void JJLPerformInitialSetup(void);

// Testing injection functions for EINTR retry logic
typedef ssize_t (*JJLReadFunction)(int fd, void *buffer, size_t nbytes);
typedef int (*JJLOpenFunctionNonVariadic)(const char *path, int mode);

ssize_t JJLSafeReadInjection(int fd, void *buffer, size_t nbytes, JJLReadFunction readPtr);
int JJLSafeOpenInjectionNonVariadic(const char *path, int mode, JJLOpenFunctionNonVariadic openPtr);

#endif /* JJLInternal_h */
