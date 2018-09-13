// Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <XCTest/XCTest.h>
#import <JJLISO8601DateFormatter/JJLISO8601DateFormatter.h>

@interface JJLISO8601DateFormatterTesting : XCTestCase

@end

@implementation JJLISO8601DateFormatterTesting

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
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

// leap seconds
// neg nums
- (void)testSimpleFormatting {
    // NSISO8601DateFormatter *appleFormatter = [[NSISO8601DateFormatter alloc] init];
    // appleFormatter.timeZone = brazilTimeZone;
    // appleFormatter stringFromDate
    NSString *str = [NSISO8601DateFormatter stringFromDate:[NSDate date] timeZone:brazilTimeZone formatOptions:0];
    JJLISO8601DateFormatter *myFormatter = [[JJLISO8601DateFormatter alloc] init];
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

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    JJLISO8601DateFormatter *formatter = [[JJLISO8601DateFormatter alloc] init];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:400];
    [self measureBlock:^{
        for (NSInteger i = 0; i < 1e3; i++) {
            [formatter stringFromDate:date];
        }
    }];
}

@end
