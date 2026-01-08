//Copyright (c) 2018 Michael Eisel. All rights reserved.

#ifndef JJLInternal_h
#define JJLInternal_h

#import <time.h>
#import <CoreFoundation/CFDateFormatter.h>

// This C file does the heavy lifting for the libraries. This is to allow maximum portability in the future, in case we want to make a Swift version, a version that can run on Linux, etc.

static const int32_t kJJLMaxDateLength = 50; // Extra to be safe

// From tzdb
typedef struct state *timezone_t;

timezone_t jjl_tzalloc(char const *name);
void jjl_tzfree(timezone_t sp);
struct tm * jjl_localtime_rz(timezone_t sp, time_t const *timep, struct tm *tmp);
time_t jjl_mktime_z(timezone_t sp, struct tm *tmp);

// Core functions for date formatting
void JJLFillBufferForDate(char *buffer, double timeInSeconds, CFISO8601DateFormatOptions options, timezone_t timeZone, double fallbackOffset);
double JJLTimeIntervalForString(const char *string, int32_t length, CFISO8601DateFormatOptions options, timezone_t timeZone, _Bool *errorOccurred);
void JJLPerformInitialSetup(void);


#endif /* JJLInternal_h */
