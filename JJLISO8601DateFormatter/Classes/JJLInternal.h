//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <time.h>

const uint32_t kJJLMaxLength = 40;

void JJLFillBufferForDate(char *buffer, double timeInSeconds, int32_t firstWeekday, bool local, CFISO8601DateFormatOptions options, timezone_t timeZone, double fallbackOffset);

typedef char JJLBuffer[kJJLMaxLength];
