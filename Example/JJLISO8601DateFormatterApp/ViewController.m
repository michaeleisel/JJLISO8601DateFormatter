// Copyright (c) 2018 Michael Eisel. All rights reserved.

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

- (NSArray *)recursiveSearchForDirectory:(NSString *)directory
{
    NSMutableArray *array = [NSMutableArray array];
    for (NSString *url in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil]) {
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:url isDirectory:&isDirectory];
        if (isDirectory) {
            [array addObjectsFromArray:[self recursiveSearchForDirectory:url]];
        } else {
            [array addObject:url];
        }
    }
    return [array copy];
}

typedef struct {
    char *buffer;
    int32_t length;
} JJLString;

- (void)viewDidLoad {
    [super viewDidLoad];

    NSTimeZone *brazilTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
    NSTimeZone *americaTimeZone = [NSTimeZone timeZoneWithName:@"America/Indiana/Indianapolis"];
    NSTimeZone *gmtTimeZone = [NSTimeZone timeZoneWithName:@"GMT"];

    NSISO8601DateFormatOptions fullOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithColonSeparatorInTimeZone | NSISO8601DateFormatWithFractionalSeconds;
    NSDate *currentStartDate = [NSDate dateWithTimeIntervalSinceNow:-15 * DAYS];
    NSDate *currentEndDate = [NSDate dateWithTimeIntervalSinceNow:15 * DAYS];
    BOOL stringToDate = YES;

    for (NSTimeZone *timeZone in @[brazilTimeZone, americaTimeZone, gmtTimeZone]) {
        NSLog(@"%@", timeZone.name);
        NSLog(@"Recent dates");
        [self _testPerformanceWithStartDate:currentStartDate endDate:currentEndDate includeApple:YES formatOptions:fullOptions stringToDate:stringToDate];

        NSLog(@"Dates from 1970 until now");
        NSDate *epochDate = [NSDate dateWithTimeIntervalSince1970:0];
        [self _testPerformanceWithStartDate:epochDate endDate:currentEndDate includeApple:YES formatOptions:fullOptions stringToDate:stringToDate];
        NSLog(@"\n\n\n");
    }
}

- (CFTimeInterval)_testPerformanceWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate includeApple:(BOOL)includeApple formatOptions:(NSISO8601DateFormatOptions)options stringToDate:(BOOL)stringToDate
{
    CFTimeInterval testDuration = 0;
    NSISO8601DateFormatter *appleFormatter = [[NSISO8601DateFormatter alloc] init];
    JJLISO8601DateFormatter *testFormatter = [[JJLISO8601DateFormatter alloc] init];
    NSISO8601DateFormatWithFractionalSeconds
    NSISO8601DateFormatWithInternetDateTime
    appleFormatter.formatOptions = testFormatter.formatOptions = options;
    appleFormatter.formatOptions = options | NSISO8601DateFormatWithColonSeparatorInTimeZone;
    NSInteger iterations = 1e6;
    NSTimeInterval endInterval = endDate.timeIntervalSince1970;
    NSTimeInterval startInterval = startDate.timeIntervalSince1970;
    NSTimeInterval increment = (endInterval - startInterval) / iterations;
    NSMutableArray <NSDate *> *dates = [NSMutableArray array];
    NSMutableArray <NSString *> *strings = [NSMutableArray array];
    NSInteger sleepMicros = 2e5;
    for (NSInteger interval = startInterval; interval < endInterval; interval += increment) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:interval];
        if (stringToDate) {
            NSString *string = [testFormatter stringFromDate:date];
            [strings addObject:string];
        } else {
            [dates addObject:date];
        }
    }
    ({
        CFTimeInterval startTime = CACurrentMediaTime();
        JJLISO8601DateFormatter *formatter = [[JJLISO8601DateFormatter alloc] init];
        /*if (stringToDate) {
            for (NSString *string in strings) {
                [testFormatter dateFromString:string];
            }
        } else {
            for (NSDate *date in dates) {
                [testFormatter stringFromDate:date];
            }
        }*/
        CFTimeInterval endTime = CACurrentMediaTime();
        NSLog(@"JJL: %@", @(endTime - startTime));
        testDuration = endTime - startTime;
    });
    usleep(sleepMicros);

    if (includeApple) {
        ({
            CFTimeInterval startTime = CACurrentMediaTime();
            NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
            /*if (stringToDate) {
                for (NSString *string in strings) {
                    [appleFormatter dateFromString:string];
                }
            } else {
                for (NSDate *date in dates) {
                    [appleFormatter stringFromDate:date];
                }
            }*/
            CFTimeInterval endTime = CACurrentMediaTime();
            NSLog(@"Apple: %@", @(endTime - startTime));
        });
        usleep(sleepMicros);
    }

    return testDuration;
}

@end
