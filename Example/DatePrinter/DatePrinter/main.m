//Copyright (c) 2018 Michael Eisel. All rights reserved.

#import <Foundation/Foundation.h>

int secondsPerYear = 60 * 60 * 24 * 365;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
        NSMutableString *string = [NSMutableString string];
        NSInteger last = 0;
        for (NSInteger i = 0; i < secondsPerYear * 20; i += 60) {
            if (i / secondsPerYear > last) {
                last = i / secondsPerYear;
                NSLog(@"%zd", last);
            }
            [string appendString:@"\n"];
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:i];
            [string appendString:[formatter stringFromDate:date]];
        }
        NSError *error = nil;
        [string writeToFile:@"/tmp/results" atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"########## ERROR: %@", error);
        }
    }
    return 0;
}
