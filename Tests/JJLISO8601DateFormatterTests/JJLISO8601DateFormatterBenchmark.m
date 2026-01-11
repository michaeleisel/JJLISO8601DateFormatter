#import <XCTest/XCTest.h>
@import JJLISO8601DateFormatter;
#import <time.h>

@interface JJLISO8601DateFormatterBenchmark : XCTestCase
@end

static double currentTime(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static void JJLBenchmark(NSString *name, void (^block)(void)) {
    // Warmup run (untimed)
    block();
    
    double totalElapsed = 0;
    NSUInteger runs = 0;
    double targetSeconds = 1.0;
    
    while (totalElapsed < targetSeconds) {
        double start = currentTime();
        block();
        double end = currentTime();
        
        totalElapsed += (end - start);
        runs++;
    }
    
    double runsPerSecond = (double)runs / totalElapsed;
    
    NSLog(@"%@: %.2f runs/sec", name, runsPerSecond);
}

@implementation JJLISO8601DateFormatterBenchmark

- (void)testDateFromStringBenchmark {
    JJLISO8601DateFormatter *jjlFormatter = [[JJLISO8601DateFormatter alloc] init];
    jjlFormatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    
    NSISO8601DateFormatter *appleFormatter = [[NSISO8601DateFormatter alloc] init];
    appleFormatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    
    NSString *dateString = @"2018-09-13T19:56:48.981Z";
    
    JJLBenchmark(@"JJLISO8601DateFormatter dateFromString", ^{
        @autoreleasepool {
            for (NSInteger i = 0; i < 1000; i++) {
                [jjlFormatter dateFromString:dateString];
            }
        }
    });
    
    JJLBenchmark(@"NSISO8601DateFormatter dateFromString", ^{
        @autoreleasepool {
            for (NSInteger i = 0; i < 1000; i++) {
                [appleFormatter dateFromString:dateString];
            }
        }
    });
}

- (void)testStringFromDateBenchmark {
    JJLISO8601DateFormatter *jjlFormatter = [[JJLISO8601DateFormatter alloc] init];
    jjlFormatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    
    NSISO8601DateFormatter *appleFormatter = [[NSISO8601DateFormatter alloc] init];
    appleFormatter.formatOptions |= NSISO8601DateFormatWithFractionalSeconds;
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1536868608.981];
    
    JJLBenchmark(@"JJLISO8601DateFormatter stringFromDate", ^{
        @autoreleasepool {
            for (NSInteger i = 0; i < 1000; i++) {
                [jjlFormatter stringFromDate:date];
            }
        }
    });
    
    JJLBenchmark(@"NSISO8601DateFormatter stringFromDate", ^{
        @autoreleasepool {
            for (NSInteger i = 0; i < 1000; i++) {
                [appleFormatter stringFromDate:date];
            }
        }
    });
}

@end
