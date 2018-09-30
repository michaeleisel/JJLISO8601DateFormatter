//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import "ViewController.h"
#import <JJLISO8601DateFormatter/JJLISO8601DateFormatter.h>

@interface ViewController ()

@end

@implementation ViewController

#define SECONDS (1)
#define MINUTES (60 * SECONDS)
#define HOURS (60 * MINUTES)
#define DAYS (24 * HOURS)
#define YEARS (365 * DAYS)

- (void)viewDidLoad {
    [super viewDidLoad];

    // [self testSimpleFormatting];
    NSTimeZone *brazilTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
    NSISO8601DateFormatOptions opts =
    NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime | NSISO8601DateFormatWithColonSeparatorInTimeZone | NSISO8601DateFormatWithFractionalSeconds;

    NSLog(@"Recent dates");
    NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:-15 * DAYS];
    NSDate *endDate = [NSDate dateWithTimeIntervalSinceNow:15 * DAYS];
    [self _testPerformanceWithStartDate:startDate endDate:endDate];

    NSLog(@"Dates from 1970 until now");
    startDate = [NSDate dateWithTimeIntervalSince1970:0];
    [self _testPerformanceWithStartDate:startDate endDate:endDate];
}

- (void)_testPerformanceWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
    NSISO8601DateFormatter *appleFormatter = [[NSISO8601DateFormatter alloc] init];
    JJLISO8601DateFormatter *myFormatter = [[JJLISO8601DateFormatter alloc] init];
    NSInteger iterations = 1e6;
    NSTimeInterval endInterval = endDate.timeIntervalSince1970;
    NSTimeInterval startInterval = startDate.timeIntervalSince1970;
    NSTimeInterval increment = (endInterval - startInterval) / iterations;
    NSMutableArray <NSDate *> *dates = [NSMutableArray array];
    for (NSInteger interval = startInterval; interval < endInterval; interval += increment) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
        [dates addObject:date];
    }
    ({
        CFTimeInterval startTime = CACurrentMediaTime();
        for (NSDate *date in dates) {
            [myFormatter stringFromDate:date];
        }
        CFTimeInterval endTime = CACurrentMediaTime();
        NSLog(@"JJL: %@", @(endTime - startTime));
    });
    usleep(5e5);
    ({
        CFTimeInterval startTime = CACurrentMediaTime();
        for (NSDate *date in dates) {
            [appleFormatter stringFromDate:date];
        }
        CFTimeInterval endTime = CACurrentMediaTime();
        NSLog(@"Apple: %@", @(endTime - startTime));
    });
}

__used static NSString *binaryRep(NSISO8601DateFormatOptions opts) {
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

// leap seconds
// neg nums
- (void)testSimpleFormatting {
    NSISO8601DateFormatter *appleFormatter = [[NSISO8601DateFormatter alloc] init];
    NSTimeZone *brazilTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
    JJLISO8601DateFormatter *myFormatter = [[JJLISO8601DateFormatter alloc] init];
    // appleFormatter.timeZone = brazilTimeZone;
    NSDate *date = [appleFormatter dateFromString:@"2018-09-13T19:56:48Z"];// [NSDate dateWithTimeIntervalSince1970:12 * SECONDS + 23 * MINUTES + 34 * HOURS + 45 * DAYS + 5 * YEARS];
    NSMutableArray *array = [NSMutableArray array];
    for (NSISO8601DateFormatOptions opts = 0; opts < (NSISO8601DateFormatOptions)(1 << 12); opts++) {
        if (!JJLIsValidFormatOptions(opts)) {
            continue;
        }
        appleFormatter.formatOptions = opts;
        myFormatter.formatOptions = opts;
        NSString *appleString = [appleFormatter stringFromDate:date];
        NSString *myString = [myFormatter stringFromDate:date];
        if (appleString.length > 1 && ![appleString isEqualToString:myString]) {
            printf("");
        }
        /*if (!appleString || appleString.length == 0) {
            NSLog(@"%@", binaryRep(opts));
            // [array addObject:@(opts)];
        }*/
    }
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

@end
