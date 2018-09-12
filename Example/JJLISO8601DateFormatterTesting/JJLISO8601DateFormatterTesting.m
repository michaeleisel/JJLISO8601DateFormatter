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
    NSISO8601DateFormatter *appleFormatter = [[NSISO8601DateFormatter alloc] init];
    // appleFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
    JJLISO8601DateFormatter *myFormatter = [[JJLISO8601DateFormatter alloc] init];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:0];
    NSString *appleString = [appleFormatter stringFromDate:date];
    NSString *myString = [myFormatter stringFromDate:date];
    XCTAssertEqualObjects(appleString, myString);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
