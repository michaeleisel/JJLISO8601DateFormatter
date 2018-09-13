//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import "ViewController.h"
#import <JJLISO8601DateFormatter/JJLISO8601DateFormatter.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSTimeZone *brazilTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"BRT"];
    NSISO8601DateFormatOptions opts =
    NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime | NSISO8601DateFormatWithColonSeparatorInTimeZone;
    NSString *str = [NSISO8601DateFormatter stringFromDate:[NSDate date] timeZone:brazilTimeZone formatOptions:opts];
    NSISO8601DateFormatter *appleFormatter = [[NSISO8601DateFormatter alloc] init];
    JJLISO8601DateFormatter *myFormatter = [[JJLISO8601DateFormatter alloc] init];
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:-60 * 60 * 24];
    CFTimeInterval start = CACurrentMediaTime();
    for (NSInteger i = 0; i < 1e6; i++) {
        [myFormatter stringFromDate:date];
    }
    CFTimeInterval end = CACurrentMediaTime();
    NSLog(@"%@", @(end - start));
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
