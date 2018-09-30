//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <time.h>

const uint32_t kJJLMaxLength = 40;

void JJLFillBufferForDate(char *bufferOrig, double timeInSeconds, int32_t firstWeekday, bool local, CFISO8601DateFormatOptions options);

typedef char JJLBuffer[kJJLMaxLength];
