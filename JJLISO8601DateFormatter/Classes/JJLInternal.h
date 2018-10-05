//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <time.h>

static const int32_t kJJLMaxDateLength = 50; // Extra to be safe

void JJLFillBufferForDate(char *buffer, double timeInSeconds, CFISO8601DateFormatOptions options, timezone_t timeZone, double fallbackOffset);
double JJLTimeIntervalForString(const char *string, int32_t length, CFISO8601DateFormatOptions options, timezone_t timeZone, bool *errorOccurred);
void JJLPerformInitialSetup(void);
