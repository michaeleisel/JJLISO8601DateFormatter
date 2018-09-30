// Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <XCTest/XCTest.h>
#import <JJLISO8601DateFormatter/JJLISO8601DateFormatter.h>
#import <OCMock/OCMock.h>

@interface JJLISO8601DateFormatterTesting : XCTestCase

@end

@implementation JJLISO8601DateFormatterTesting {
    NSISO8601DateFormatter *_appleFormatter;
    JJLISO8601DateFormatter *_myFormatter;
}

- (void)setUp {
    [super setUp];

    _appleFormatter = [[NSISO8601DateFormatter alloc] init];
    _myFormatter = [[JJLISO8601DateFormatter alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (void)stuff {
    /*NSDateComponents *comps = [[NSDateComponents alloc] init];
     comps.year = 2018;
     // comps.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
     NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:comps];
     [appleFormatter stringFromDate:date];*/
     // NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
}

static NSString *binaryRep(NSISO8601DateFormatOptions opts) {
    NSMutableString *string = [NSMutableString string];
    for (NSInteger i = 11; i >= 0; i--) {
        [string appendFormat:@"%zu", (opts >> i) & 1];
    }
    return [string copy];
}

// test for multi threading stability

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
    XCTAssertEqualObjects(_appleFormatter.timeZone, _myFormatter.timeZone, @"Default time zone should be GMT");
    _myFormatter.timeZone = _appleFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
    XCTAssertEqualObjects(_appleFormatter.timeZone, _myFormatter.timeZone);
    _myFormatter.timeZone = _appleFormatter.timeZone = nil;
    XCTAssertEqualObjects(_appleFormatter.timeZone, _myFormatter.timeZone, @"nil resetting should bring it back to the default");
}

// Note: swizzling apple library methods like these can cause flaky test failures
- (void)_setLocale:(NSLocale *)locale
{
    OCMStub([NSLocale currentLocale]).andReturn(locale);
    OCMStub([NSLocale autoupdatingCurrentLocale]).andReturn(locale);
    [[NSNotificationCenter defaultCenter] postNotificationName:NSCurrentLocaleDidChangeNotification object:locale/*correct?*/];
}

- (void)testNilDate
{
    NSDate *date = nil;
    XCTAssertEqualObjects([_appleFormatter stringFromDate:date], [_myFormatter stringFromDate:date]);
}

// leap seconds
// neg nums
- (void)testFormattingAcrossAllOptions
{
    // NSTimeZone *brazilTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
    // appleFormatter.timeZone = brazilTimeZone;
    NSISO8601DateFormatter *initialDateFormatter = [[NSISO8601DateFormatter alloc] init];
    initialDateFormatter.formatOptions = initialDateFormatter.formatOptions | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *date = [initialDateFormatter dateFromString:@"2018-09-13T19:56:48.981Z"];
    // Run through a couple locales with different starting days of the week
    for (NSString *identifier in @[@"en_US", @"ar_IQ"]) {
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:identifier];
        [self _setLocale:locale];
        for (NSISO8601DateFormatOptions options = 0; options < (NSISO8601DateFormatOptions)(1 << 12); options++) {
            if (!JJLIsValidFormatOptions(options)) {
                continue;
            }
            _appleFormatter.formatOptions = options;
            _myFormatter.formatOptions = options;
            NSString *appleString = [_appleFormatter stringFromDate:date];
            NSString *myString = [_myFormatter stringFromDate:date];
            XCTAssertEqualObjects(appleString, myString);
        }
    }
}

- (void)testFormattingAcrossTimes
{
    return; /////////////
    for (NSInteger i = 0; i < 60 * 60 * 24 * 365 * 50; i += 101) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:i];
        NSString *appleString = [_appleFormatter stringFromDate:date];
        NSString *myString = [_myFormatter stringFromDate:date];
        if (i % (60 * 60 * 24 * 365) == 0) {
            printf("i: %zd\n", i);
        }
        // assert([appleString isEqualToString:myString]);
        XCTAssertEqualObjects(appleString, myString);
    }
}

- (void)testSimpleFormatting {
    NSISO8601DateFormatter *appleFormatter = [[NSISO8601DateFormatter alloc] init];
    // NSTimeZone *brazilTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
    JJLISO8601DateFormatter *myFormatter = [[JJLISO8601DateFormatter alloc] init];
    // appleFormatter.timeZone = brazilTimeZone;
    /*for (NSInteger i = 0; i < 60 * 60 * 24 * 365 * 50; i += 101) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:i];
        NSString *appleString = [appleFormatter stringFromDate:date];
        // NSString *myString = [myFormatter stringFromDate:date];
        if (i % (60 * 60 * 24 * 365) == 0) {
            printf("i: %zd\n", i);
        }
        // assert([appleString isEqualToString:myString]);
        // XCTAssertEqualObjects(appleString, myString);
    }*/
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
