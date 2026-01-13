//Copyright (c) 2018 Michael Eisel. All rights reserved.

#ifndef JJLINTERNAL_H
#define JJLINTERNAL_H

#import <time.h>
#import <CoreFoundation/CFDateFormatter.h>

// timezone_t type definition
typedef struct state *timezone_t;

// Timezone functions from tzdb
struct state *jjl_tzalloc(char const *name);
void jjl_tzfree(struct state *sp);
struct tm * jjl_localtime_rz(struct state *sp, time_t const *timep, struct tm *tmp);
time_t jjl_mktime_z(struct state *sp, struct tm *tmp);

// This C file does the heavy lifting for the libraries. This is to allow maximum portability in the future, in case we want to make a Swift version, a version that can run on Linux, etc.

static const int32_t kJJLMaxDateLength = 50; // Extra to be safe

void JJLFillBufferForDate(char *buffer, double timeInSeconds, CFISO8601DateFormatOptions options, timezone_t timeZone, double fallbackOffset);
double JJLTimeIntervalForString(const char *string, int32_t length, CFISO8601DateFormatOptions options, timezone_t timeZone, bool *errorOccurred);
void JJLPerformInitialSetup(void);

#endif /* JJLINTERNAL_H */
