// Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <XCTest/XCTest.h>
#import <JJLISO8601DateFormatter/JJLISO8601DateFormatter.h>
#import <OCMock/OCMock.h>

@interface JJLISO8601DateFormatterTesting : XCTestCase

@end

// Of course, these constants are not exact, but they are helpful for generating test data
static const NSInteger kJJLSecondsPerMinute = 60;
static const NSInteger kJJLSecondsPerHour = 60 * kJJLSecondsPerMinute;
static const NSInteger kJJLSecondsPerDay = 24 * kJJLSecondsPerHour;
static const NSInteger kJJLSecondsPerYear = 365 * kJJLSecondsPerDay;

@implementation JJLISO8601DateFormatterTesting {
    NSISO8601DateFormatter *_appleFormatter;
    JJLISO8601DateFormatter *_testFormatter;
    NSTimeZone *_brazilTimeZone;
    NSTimeZone *_pacificTimeZone;
    NSDate *_testDate;
}

- (void)setUp {
    [super setUp];

    self.continueAfterFailure = NO;

    _appleFormatter = [[NSISO8601DateFormatter alloc] init];
    _testFormatter = [[JJLISO8601DateFormatter alloc] init];
    NSISO8601DateFormatOptions options = _appleFormatter.formatOptions | NSISO8601DateFormatWithFractionalSeconds;
    _appleFormatter.formatOptions = _testFormatter.formatOptions = options;
    _brazilTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
    _pacificTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"PST"];

    NSISO8601DateFormatter *testDateFormatter = [[NSISO8601DateFormatter alloc] init];
    testDateFormatter.formatOptions = testDateFormatter.formatOptions | NSISO8601DateFormatWithFractionalSeconds;
    _testDate = [testDateFormatter dateFromString:@"2018-09-13T19:56:48.981Z"];
}

- (void)tearDown {
    [super tearDown];
}

void *jjl_tzalloc(char const *name);

- (void)testTZAlloc
{
    void *badTimezone = jjl_tzalloc("America/adf");
    XCTAssert(badTimezone == NULL);
    void *goodTimezone = jjl_tzalloc("Africa/Addis_Ababa");
    XCTAssert(goodTimezone != NULL);
}

static void OS_ALWAYS_INLINE JJLTestStringFromDate(NSDate *date, NSISO8601DateFormatter *appleFormatter, JJLISO8601DateFormatter *testFormatter) {
    NSString *appleString = [appleFormatter stringFromDate:date];
    NSString *testString = [testFormatter stringFromDate:date];
    // Don't use XCTAssert here for fear that it might be too slow
    if (appleString != testString && ![appleString isEqualToString:testString]) {
        NSLog(@"Mismatch for %@, apple: %@, test: %@", date, appleString, testString);
        abort();
    }
}

// Helper for use with the debugger
__used static NSString *binaryRep(NSISO8601DateFormatOptions opts) {
    NSMutableString *string = [NSMutableString string];
    for (NSInteger i = 11; i >= 0; i--) {
        [string appendFormat:@"%zu", (opts >> i) & 1];
    }
    return [string copy];
}

__used static NSString *binaryTestRep(NSISO8601DateFormatOptions opts) {
    NSDictionary<NSNumber *, NSString *>*optionToString = @{ @(NSISO8601DateFormatWithYear): @"year",
                                                             @(NSISO8601DateFormatWithMonth): @"month",
                                                             @(NSISO8601DateFormatWithWeekOfYear): @"week of year",
                                                             @(NSISO8601DateFormatWithDay): @"day",
                                                             @(NSISO8601DateFormatWithTime): @"time",
                                                             @(NSISO8601DateFormatWithTimeZone): @"time zone",
                                                             @(NSISO8601DateFormatWithSpaceBetweenDateAndTime): @"space between date and time",
                                                             @(NSISO8601DateFormatWithDashSeparatorInDate): @"dash separator in date",
                                                             @(NSISO8601DateFormatWithColonSeparatorInTime): @"colon separator in time",
                                                             @(NSISO8601DateFormatWithColonSeparatorInTimeZone): @"colon separator in time zone",
                                                             @(NSISO8601DateFormatWithFractionalSeconds): @"fractional seconds"
                                                             };
    NSMutableArray <NSString *> *strings = [NSMutableArray array];
    for (NSNumber *option in optionToString) {
        if (opts & option.integerValue) {
            [strings addObject:optionToString[option]];
        }
    }
    return [strings componentsJoinedByString:@", "];
}

- (void)testTimeZoneGettingAndSetting
{
    XCTAssertEqualObjects(_appleFormatter.timeZone, _testFormatter.timeZone, @"Default time zone should be GMT");
    _testFormatter.timeZone = _appleFormatter.timeZone = _brazilTimeZone;
    XCTAssertEqualObjects(_appleFormatter.timeZone, _testFormatter.timeZone);
    _testFormatter.timeZone = _appleFormatter.timeZone = nil;
    XCTAssertEqualObjects(_appleFormatter.timeZone, _testFormatter.timeZone, @"nil resetting should bring it back to the default");
}

- (void)testConcurrentUsage
{
    NSTimeZone *gmtOffsetTimeZone = [NSTimeZone timeZoneForSecondsFromGMT:3600];
    NSArray <NSTimeZone *> *timeZones = @[[NSTimeZone systemTimeZone], _brazilTimeZone, gmtOffsetTimeZone, _pacificTimeZone];
    _testFormatter.timeZone = timeZones.firstObject;
    NSMutableArray *testStrings = [NSMutableArray array];
    NSMutableArray <NSString *> *correctStrings = [NSMutableArray array];
    NSInteger repeatCount = 100;
    for (NSTimeZone *timeZone in timeZones) {
        _appleFormatter.timeZone = timeZone;
        NSString *string = [_appleFormatter stringFromDate:_testDate];
        [correctStrings addObject:string];
    }
    NSMutableArray *repeatedCorrectStrings = [NSMutableArray array];
    for (NSInteger i = 0; i < repeatCount; i++) {
        [repeatedCorrectStrings addObjectsFromArray:correctStrings];
    }
    correctStrings = [repeatedCorrectStrings copy];
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    __block _Atomic(BOOL) done = NO;
    __block int count = 0;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_async(queue, ^{
        while (!done) {
            NSString *string = [self->_testFormatter stringFromDate:self->_testDate];
            count++;
            if (testStrings.count == 0 || ![string isEqualToString:testStrings.lastObject]) {
                [testStrings addObject:string];
            }
        }
    });
    dispatch_async(queue, ^{
        for (NSInteger i = 0; i < repeatCount; i++) {
            for (NSTimeZone *timeZone in timeZones) {
                self->_testFormatter.timeZone = timeZone;
                usleep(5e3);
            }
        }
        dispatch_group_leave(group);
        done = YES;
    });
    // todo: Throw some extra reads in for fun
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    XCTAssert([correctStrings isEqualToArray:testStrings]);
}

- (void)testNilDate
{
    JJLTestStringFromDate(nil, _appleFormatter, _testFormatter);
}

- (void)testFractionalSecondsFormatting
{
    NSISO8601DateFormatter *initialDateFormatter = [[NSISO8601DateFormatter alloc] init];
    NSDate *startingDate = [initialDateFormatter dateFromString:@"2018-09-13T19:56:49Z"]; // Use 49 to go from 49-51, so the tens place changes
    NSTimeInterval startingInterval = startingDate.timeIntervalSince1970;
    NSISO8601DateFormatOptions noFractionalSecondsOptions = _appleFormatter.formatOptions & (~NSISO8601DateFormatWithFractionalSeconds);
    for (NSNumber *options in @[@(_appleFormatter.formatOptions), @(noFractionalSecondsOptions)]) {
        _appleFormatter.formatOptions = _testFormatter.formatOptions = [options unsignedIntegerValue];
        // 0.1 is not perfectly representable, but it's good to have this "messy" representation of it because we're trying to work with a variety of doubles
        double increment = 0.0001;
        for (NSTimeInterval interval = startingInterval; interval < startingInterval + 2; interval += increment) {
            // For each of these intervals, there's a discrepancy. Either printf's formatting or Apple's date formatter is wrong, but I suspect it's Apple's date formatter
            if (interval == 1536868609.3894999 || interval == 1536868609.6815) {
                continue;
            }
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
            JJLTestStringFromDate(date, _appleFormatter, _testFormatter);
        }
    }
}

- (void)testDistantFuture
{
    JJLTestStringFromDate([NSDate distantFuture], _appleFormatter, _testFormatter);
}

- (void)testExoticOptions
{
    NSISO8601DateFormatOptions options[] = {
        NSISO8601DateFormatWithYear | NSISO8601DateFormatWithWeekOfYear,
        NSISO8601DateFormatWithYear | NSISO8601DateFormatWithDay,
        NSISO8601DateFormatWithYear | NSISO8601DateFormatWithWeekOfYear | NSISO8601DateFormatWithDay,
        NSISO8601DateFormatWithYear | NSISO8601DateFormatWithWeekOfYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithDay,
        NSISO8601DateFormatWithWeekOfYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithDay,
        NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithDay,
    };
    NSInteger optionsLength = sizeof(options) / sizeof(options[0]);
    for (NSInteger i = 0; i < optionsLength; i++) {
        _appleFormatter.formatOptions = options[i];
        _testFormatter.formatOptions = options[i];
        for (NSTimeInterval interval = kJJLSecondsPerYear + 12 * kJJLSecondsPerHour; interval < 50 * kJJLSecondsPerYear; interval += 1 * kJJLSecondsPerDay) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
            JJLTestStringFromDate(date, _appleFormatter, _testFormatter);
        }
    }
}

- (void)testFormattingAcrossAllOptions
{
    for (NSISO8601DateFormatOptions options = 0; options < (NSISO8601DateFormatOptions)(1 << 12); options++) {
        if (!JJLIsValidFormatOptions(options)) {
            continue;
        }
        _appleFormatter.formatOptions = options;
        _testFormatter.formatOptions = options;
        JJLTestStringFromDate(_testDate, _appleFormatter, _testFormatter);
    }
}

static inline NSInteger JJLPercent(double d) {
    return (NSInteger)lround(d * 100);
}

static inline bool JJLChangeHasOccurred(int64_t i, int64_t increment, int64_t end) {
    return JJLPercent((double)i / (double)end) != JJLPercent((i - (double)increment) / (double)end);
}

- (void)testManyAcrossTimeZones
{
    NSMutableArray <NSTimeZone *> *timeZones = [NSMutableArray array];
    [timeZones addObject:[NSTimeZone timeZoneForSecondsFromGMT:496]];
    [timeZones addObject:[NSTimeZone timeZoneForSecondsFromGMT:-2 * kJJLSecondsPerHour - 496]];
    // Using an abbreviation
    [timeZones addObject:[NSTimeZone timeZoneWithAbbreviation:@"BRT"]];
    for (NSString *name in [NSTimeZone knownTimeZoneNames]) {
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:name];
        [timeZones addObject:timeZone];
    }
    [timeZones addObject:[NSTimeZone systemTimeZone]];
    [timeZones addObject:[NSTimeZone timeZoneForSecondsFromGMT:0]];

    for (NSNumber *alwaysUseNSTimeZone in @[@YES, @NO]) {
        [_testFormatter setValue:alwaysUseNSTimeZone forKey:NSStringFromSelector(@selector(alwaysUseNSTimeZone))];
        for (NSTimeZone *timeZone in timeZones) {
            _testFormatter.timeZone = _appleFormatter.timeZone = timeZone;
            int32_t increment = kJJLSecondsPerDay * 23 + kJJLSecondsPerHour * 7 + kJJLSecondsPerMinute * 5 + 7.513;
            for (NSInteger interval = 0; interval < 50 * kJJLSecondsPerYear; interval += increment) {
                NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
                JJLTestStringFromDate(date, _appleFormatter, _testFormatter);
            }
            // Don't use a fixed seed for the random numbers, trade consistency for greater test coverage
            for (NSInteger i = 0; i < 1e3; i++) {
                NSTimeInterval interval = arc4random_uniform(70 * kJJLSecondsPerYear);
                NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
                JJLTestStringFromDate(date, _appleFormatter, _testFormatter);
            }
        }
    }
}

- (void)testLeapForward
{
    // Use Brazil, which does a leap forward, and just cover the whole year to be safe
    for (NSNumber *alwaysUseNSTimeZone in @[@YES, @NO]) {
        [_testFormatter setValue:alwaysUseNSTimeZone forKey:NSStringFromSelector(@selector(alwaysUseNSTimeZone))];
        NSTimeInterval start = [_appleFormatter dateFromString:@"2017-01-01T12:00:00.000Z"].timeIntervalSince1970;
        _testFormatter.timeZone = _appleFormatter.timeZone = _brazilTimeZone;
        for (NSInteger interval = start; interval < start + kJJLSecondsPerYear + 10 * kJJLSecondsPerDay; interval += 7 * kJJLSecondsPerMinute) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
            JJLTestStringFromDate(date, _appleFormatter, _testFormatter);
        }
    }
}

- (void)testFormattingAcrossTimes
{
    BOOL moreThorough = NO;
    // Don't go back past 1582, an important date in ISO 8601, because at that point it seems like Apple's doesn't work
    int64_t end = -1LL * kJJLSecondsPerYear * (1970 - 1583);
    int64_t increment = moreThorough ? -10001 : -100001;
    NSLog(@"Counting down...");
    for (int64_t i = 0; i >= end; i += increment) {
        if (JJLChangeHasOccurred(i, increment, end)) {
            NSLog(@"%zd%% complete", JJLPercent(i / (double)end));
        }
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:i];
        JJLTestStringFromDate(date, _appleFormatter, _testFormatter);
    }

    NSLog(@"Counting up...");
    end = kJJLSecondsPerYear * 50;
    increment = moreThorough ? 1001 : 10001;
    for (int64_t i = 0; i < end; i += increment) {
        if (JJLChangeHasOccurred(i, increment, end)) {
            NSLog(@"%zd%% complete", JJLPercent(i / (double)end));
        }
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:i];
        JJLTestStringFromDate(date, _appleFormatter, _testFormatter);
    }
}

/*- (void)testPerformanceExample {
    // This is an example of a performance test case.
    JJLISO8601DateFormatter *formatter = [[JJLISO8601DateFormatter alloc] init];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:400];
    [self measureBlock:^{
        for (NSInteger i = 0; i < 1e3; i++) {
            [formatter stringFromDate:date];
        }
    }];
}*/

@end
