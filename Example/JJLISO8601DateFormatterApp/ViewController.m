//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import "ViewController.h"
#import <JJLISO8601DateFormatter/JJLISO8601DateFormatter.h>
#import <malloc/malloc.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // [self testSimpleFormatting];
    NSTimeZone *brazilTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
    NSISO8601DateFormatOptions opts =
    NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime | NSISO8601DateFormatWithColonSeparatorInTimeZone;
    NSString *str = [NSISO8601DateFormatter stringFromDate:[NSDate date] timeZone:brazilTimeZone formatOptions:opts];
    NSISO8601DateFormatter *appleFormatter = [[NSISO8601DateFormatter alloc] init];
    JJLISO8601DateFormatter *myFormatter = [[JJLISO8601DateFormatter alloc] init];
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-60 * 60 * 24];
    NSInteger sum = 0;
    NSInteger total = 1e7;
    ({
        CFTimeInterval start = CACurrentMediaTime();
        /*for (NSInteger i = 0; i < 1e6; i++) {
            [appleFormatter stringFromDate:date];
        }*/
        for (NSInteger i = 0; i < total; i++) {
            void *ptr = malloc(16);
            sum += (NSInteger)ptr;
            free(ptr);
        }
        CFTimeInterval end = CACurrentMediaTime();
        NSLog(@"%@", @(end - start));
    });
    usleep(5e5);
    unsigned batchCount = 5;
    malloc_zone_t *defaultZone = malloc_default_zone();
    ({
        CFTimeInterval start = CACurrentMediaTime();
        /*for (NSInteger i = 0; i < 1e6; i++) {
            [myFormatter stringFromDate:date];
        }*/
        void *results[batchCount];
        for (NSInteger i = 0; i < total / batchCount; i++) {
            unsigned count = malloc_zone_batch_malloc(defaultZone, 16, results, batchCount);
            assert(count == batchCount);
            sum += (NSInteger)results[batchCount - 1];
            malloc_zone_batch_free(defaultZone, results, count);
        }
        CFTimeInterval end = CACurrentMediaTime();
        NSLog(@"%@", @(end - start));
    });
    NSLog(@"%zd", sum);
}

#define SECONDS (1)
#define MINUTES (60 * SECONDS)
#define HOURS (60 * MINUTES)
#define DAYS (24 * HOURS)
#define YEARS (365 * DAYS)

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
