//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <time.h>

#define JJL_MAX_DATE_LENGTH 50

void JJLFillBufferForDate(char *buffer, double timeInSeconds, int32_t firstWeekday, bool local, CFISO8601DateFormatOptions options, timezone_t timeZone, double fallbackOffset);
