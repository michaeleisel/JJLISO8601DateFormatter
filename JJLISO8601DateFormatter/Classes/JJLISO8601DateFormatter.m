// Copyright (c) 2018 Michael Eisel. All rights reserved.

#import "JJLISO8601DateFormatter.h"
#import "tzfile.h"
#import "JJLInternal.h"
#import <pthread.h>


#define JJL_ALWAYS_INLINE __attribute__((always_inline))

// Note: this class does not use ARC

@interface JJLISO8601DateFormatter ()

@property (nonatomic) BOOL alwaysUseNSTimeZone;

@end

@implementation JJLISO8601DateFormatter {
    timezone_t _cTimeZone;
    pthread_rwlock_t _timeZoneVarsLock;
}

static NSTimeZone *sGMTTimeZone = nil;
static NSMutableDictionary <NSString *, NSValue *> *sNameToTimeZoneValue;
static pthread_rwlock_t sDictionaryLock = PTHREAD_RWLOCK_INITIALIZER;

@synthesize formatOptions = _formatOptions;
@synthesize timeZone = _timeZone;

- (void)_performInitialSetupIfNecessary
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sGMTTimeZone = [[NSTimeZone timeZoneWithName:@"GMT"] retain];
        sNameToTimeZoneValue = [[NSMutableDictionary dictionary] retain];
        JJLPerformInitialSetup();
    });
}

-(id)init
{
    self = [super init];
    if (self) {
        [self _performInitialSetupIfNecessary];

        _timeZoneVarsLock = (pthread_rwlock_t)PTHREAD_RWLOCK_INITIALIZER;
        _formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime | NSISO8601DateFormatWithColonSeparatorInTimeZone;
        self.timeZone = sGMTTimeZone;
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

// If the date is of the form "GMT+xxxx", invert the sign and add a colon, because that seems to be how tzdb interprets it correctly
// todo: add support for other time zones with a "+"?
static NSString *JJLAdjustedTimeZoneName(NSString *name) {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^GMT(\\+|-)(\\d{2})(\\d{2})$" options:0 error:NULL];
    NSArray <NSTextCheckingResult *> *matches = [regex matchesInString:name options:0 range:NSMakeRange(0, name.length)];
    NSTextCheckingResult *match = matches.firstObject;
    if (!match) {
        return name;
    }
    char origSign = [name characterAtIndex:[match rangeAtIndex:1].location];
    char sign = origSign == '-' ? '+' : '-';
    NSString *hours = [name substringWithRange:[match rangeAtIndex:2]];
    NSString *minutes = [name substringWithRange:[match rangeAtIndex:3]];
    return [NSString stringWithFormat:@"GMT%c%@:%@", sign, hours, minutes];
}

// Note that the returned timezone_t could be null if it failed for some reason
static timezone_t JJLCTimeZoneForTimeZone(NSTimeZone *timeZone, BOOL alwaysUseNSTimeZone)
{
    if (alwaysUseNSTimeZone) {
        return NULL;
    }

    timezone_t cTimeZone = NULL;

    NS_VALID_UNTIL_END_OF_SCOPE NSString *name = JJLAdjustedTimeZoneName(timeZone.name);
    NSValue *timeZoneValue = nil;

    pthread_rwlock_rdlock(&sDictionaryLock);
    ({
        timeZoneValue = sNameToTimeZoneValue[name];
    });
    pthread_rwlock_unlock(&sDictionaryLock);

    if (!timeZoneValue) {
        cTimeZone = jjl_tzalloc([name UTF8String]);
        timeZoneValue = [NSValue valueWithPointer:cTimeZone];
        if (cTimeZone == NULL) {
            NSLog(@"[JJLISO8601DateFormatter] Warning: time zone not found for name %@, falling back to NSTimeZone. Performance will be degraded", name);
        }
        pthread_rwlock_wrlock(&sDictionaryLock);
        ({
            sNameToTimeZoneValue[name] = timeZoneValue;
        });
        pthread_rwlock_unlock(&sDictionaryLock);
    } else {
        cTimeZone = [timeZoneValue pointerValue];
    }

    return cTimeZone;
}

- (void)dealloc
{
    [super dealloc];

    [_timeZone autorelease];
    pthread_rwlock_destroy(&_timeZoneVarsLock);
}

- (void)setTimeZone:(NSTimeZone *)timeZone
{
    NSTimeZone *oldTimeZone = _timeZone;

    pthread_rwlock_wrlock(&_timeZoneVarsLock);
    ({
        _timeZone = timeZone ?: sGMTTimeZone;
        _cTimeZone = JJLCTimeZoneForTimeZone(_timeZone, _alwaysUseNSTimeZone);
    });
    pthread_rwlock_unlock(&_timeZoneVarsLock);

    [_timeZone retain];
    [oldTimeZone autorelease];
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
    NSString *string = nil;

    pthread_rwlock_rdlock(&_timeZoneVarsLock);
    ({
        string = JJLStringFromDate(date, _formatOptions, _cTimeZone, _timeZone);
    });
    pthread_rwlock_unlock(&_timeZoneVarsLock);

    return string;
}

- (nullable NSDate *)dateFromString:(NSString *)string
{
    return nil;
}

+ (NSString *)stringFromDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone formatOptions:(NSISO8601DateFormatOptions)formatOptions
{
    timezone_t cTimeZone = JJLCTimeZoneForTimeZone(timeZone, NO);
    return JJLStringFromDate(date, formatOptions, cTimeZone, timeZone);
}

static inline NSString *JJLStringFromDate(NSDate *date, NSISO8601DateFormatOptions formatOptions, timezone_t cTimeZone, NSTimeZone *timeZone)
{
    if (!date) {
        return nil;
    }
    NSString *string = nil;
    double time = date.timeIntervalSince1970;
    double offset = cTimeZone ? 0 : [timeZone secondsFromGMTForDate:date];
    if (offset != 0) {
        ;
    }
    char buffer[JJL_MAX_DATE_LENGTH] = {0};
    char *bufferPtr = (char *)buffer;
    JJLFillBufferForDate(bufferPtr, time, NO, (CFISO8601DateFormatOptions)formatOptions, cTimeZone, offset);
    string = CFAutorelease(CFStringCreateWithCString(kCFAllocatorDefault, buffer, kCFStringEncodingUTF8));
    return string;
}

@end
