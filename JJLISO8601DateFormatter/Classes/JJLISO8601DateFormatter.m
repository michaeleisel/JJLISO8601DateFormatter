// Copyright (c) 2018 Michael Eisel. All rights reserved.

#import "JJLISO8601DateFormatter.h"
#import "itoa.h"
#import "JJLInternal.h"

#define JJL_ALWAYS_INLINE __attribute__((always_inline))

// Note: this class does not use ARC

@implementation JJLISO8601DateFormatter

static NSTimeZone *sGMTTimeZone = nil;
static NSInteger sFirstWeekday = 0;

@synthesize formatOptions = _formatOptions;
@synthesize timeZone = _timeZone;

static void *kJJLCurrentLocaleContext = &kJJLCurrentLocaleContext;

// Thread-safe because sFirstWeekday is the only thing being changed, and it is a simple primitive
+ (void)_localeDidChange
{
    NSCalendar *gregorianCalendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    gregorianCalendar.locale = [NSLocale currentLocale];
    sFirstWeekday = gregorianCalendar.firstWeekday;
}

- (void)_performInitialSetupIfNecessary
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sGMTTimeZone = [[NSTimeZone timeZoneWithName:@"GMT"] retain];
        [[NSNotificationCenter defaultCenter] addObserver:[self class] selector:@selector(_localeDidChange) name:NSCurrentLocaleDidChangeNotification object:nil];
        [[self class] _localeDidChange];
    });
}

// make full test plan: test all supported OSes, test performance, and test unit tests
// -Werror?
// todo: does the C assert function turn off in release?
// allow for "+" unary operator
// asserts for invalid minute, year, etc.?
// todo: sizeof long?
// todo: max length correct? large numbers?
// all calls to -timeZone must go through property, not ivar, to be atomic
// use ios 9 and not 10 as minimum?
// distant future? distant past?
// todo: NSFormatter subclassing and secure coding!
// todo: do MRC properties automatically retain and release?
// clang format?
-(id)init
{
    self = [super init];
    if (self) {
        [self _performInitialSetupIfNecessary];
        _formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime | NSISO8601DateFormatWithColonSeparatorInTimeZone;
        _timeZone = sGMTTimeZone;
    }
    return self;
}

// This property is atomic, but since it is a simple primitive, it's fine to just return it
- (NSISO8601DateFormatOptions)formatOptions
{
    return _formatOptions;
}

// This property is atomic, but since it is a simple primitive, it's fine to just set it
- (void)setFormatOptions:(NSISO8601DateFormatOptions)formatOptions
{
    NSAssert(JJLIsValidFormatOptions(formatOptions), @"Invalid format option, must satisfy formatOptions == 0 || !(formatOptions & ~(NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithWeekOfYear | NSISO8601DateFormatWithDay | NSISO8601DateFormatWithTime | NSISO8601DateFormatWithTimeZone | NSISO8601DateFormatWithSpaceBetweenDateAndTime | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime | NSISO8601DateFormatWithColonSeparatorInTimeZone | NSISO8601DateFormatWithFractionalSeconds | NSISO8601DateFormatWithFullDate | NSISO8601DateFormatWithFullTime | NSISO8601DateFormatWithInternetDateTime))");
    _formatOptions = formatOptions;
}

- (NSTimeZone *)timeZone
{
    NSTimeZone *timeZone = nil;
    @synchronized(self) {
        timeZone = _timeZone;
    }
    return timeZone;
}

- (void)setTimeZone:(NSTimeZone *)timeZone
{
    @synchronized(self) {
        NSTimeZone *oldTimeZone = timeZone;
        _timeZone = timeZone ?: sGMTTimeZone;
        [_timeZone retain];
        [oldTimeZone autorelease];
    }
}

BOOL JJLIsValidFormatOptions(NSISO8601DateFormatOptions formatOptions) {
    NSISO8601DateFormatOptions mask = NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithWeekOfYear | NSISO8601DateFormatWithDay | NSISO8601DateFormatWithTime | NSISO8601DateFormatWithTimeZone | NSISO8601DateFormatWithSpaceBetweenDateAndTime | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime | NSISO8601DateFormatWithColonSeparatorInTimeZone |  NSISO8601DateFormatWithFullDate | NSISO8601DateFormatWithFullTime | NSISO8601DateFormatWithInternetDateTime;
    if (@available(iOS 11.0, *)) {
        mask |= NSISO8601DateFormatWithFractionalSeconds;
    }
    return formatOptions == 0 || !(formatOptions & ~mask);
}

- (NSString *)stringFromDate:(NSDate *)date
{
    return JJLStringFromDate(date, nil, _formatOptions);
}

- (nullable NSDate *)dateFromString:(NSString *)string
{
    return nil;
}

+ (NSString *)stringFromDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone formatOptions:(NSISO8601DateFormatOptions)formatOptions
{
    return @"";
}

static inline NSString *JJLStringFromDate(NSDate *date, NSTimeZone *timeZone, NSISO8601DateFormatOptions formatOptions)
{
    if (!date) {
        return nil;
    }
    /*if (!timeZone) {
        timeZone = [NSTimeZone defaultTimeZone];
    }*/
    double time = date.timeIntervalSince1970;// - [timeZone secondsFromGMTForDate:date];
    char buffer[kJJLMaxLength] = {0};
    char *bufferPtr = (char *)buffer;
    int32_t firstWeekday = (int32_t)sFirstWeekday; // Use a copy of sFirstWeekday in case it changes
    JJLFillBufferForDate(bufferPtr, time, firstWeekday, NO, (CFISO8601DateFormatOptions)formatOptions);
    return CFAutorelease(CFStringCreateWithCString(kCFAllocatorDefault, buffer, kCFStringEncodingUTF8));
}

@end
