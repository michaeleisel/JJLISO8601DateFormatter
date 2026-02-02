# JJLISO8601DateFormatter

`JJLISO8601DateFormatter` is a thread-safe, feature complete, drop-in replacement for `NSISO8601DateFormatter` and a high-performance alternative to `ISO8601FormatStyle`, with faster conversion to and from dates than both.

Compared to newer Swift `Date` conversions ([string to date](https://developer.apple.com/documentation/foundation/date/iso8601formatstyle/3766499-parse) and [date to string](https://developer.apple.com/documentation/foundation/date/3766420-iso8601format)), for newer versions of iOS, see the updated measurements in "Benchmarks (iOS Release)" below.

More info on how the benchmark was done is [here](https://github.com/michaeleisel/JJLISO8601DateFormatter#how-is-the-benchmarking-done).

## Benchmarks (iOS Release)

Benchmarking code now lives in `Benchmark/` as a standalone package so it can run in Release on both iOS and macOS:

- `BenchmarkiOSApp`: iOS app that runs benchmarks on device
- `BenchmarkCLI`: macOS CLI (`swift run -c release BenchmarkCLI`)

To run on iOS: open `Benchmark/Package.swift` in Xcode, select the `BenchmarkiOSApp` scheme, choose a physical device, switch the build configuration to Release, and run.

The string -> date measurements use ISO 8601 strings that include time zone offsets to exercise the fast parsing path.

### Date -> String (ISO8601DateFormatter baseline)

Device: iPhone 17 Pro Max (iOS 26.2)

| API | Runs/sec | Speedup vs ISO8601DateFormatter |
| --- | ---: | ---: |
| JJLISO8601DateFormatter | 16640384.28 | 12.77x |
| ISO8601FormatStyle | 6747453.46 | 5.18x |
| FormatStyle | 4354399.09 | 3.34x |
| ISO8601DateFormatter | 1303465.58 | 1.00x |

### String -> Date (fast path, time zone offsets)

Device: iPhone 17 Pro Max (iOS 26.2)

| API | Runs/sec | Speedup vs ISO8601DateFormatter |
| --- | ---: | ---: |
| JJLISO8601DateFormatter | 27444341.29 | 533.17x |
| ISO8601FormatStyle | 1789599.13 | 34.77x |
| FormatStyle | 1576687.82 | 30.63x |
| ISO8601DateFormatter | 51473.83 | 1.00x |

## Usage

Because it is drop-in, you can simply replace the word `NSISO8601DateFormatter` with `JJLISO8601DateFormatter` and add the header include, `#import <JJLISODateFormatter/JJLISODateFormatter.h>` or `import JJLISODateFormatter` in Swift.

## Requirements

- iOS 10.0+
- MacOS 10.13+

## Installation

### Cocoapods
JJLISO8601DateFormatter is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'JJLISO8601DateFormatter'
```

## FAQ
##### How does this date formatting library stay up-to-date with new changes in time zones?

It uses the time zone files provided by the system, the same ones that POSIX functions like `localtime` use. If it can't find them, it will fall back to using Apple's date formatting libraries.

##### Why is it so much faster?

There's nothing special about the library. It is written in straight-forward C and tries to avoid unnecessary allocations, locking, etc. It uses versions of `mktime` and `localtime` from `tzdb`. A better question is, why is Apple's so much slower? Apple's date formatting classes are built on top of [ICU](http://site.icu-project.org/home), which although reliable, is a fairly slow library. It's hard from a glance to say exactly why, but it seems to have a lot of extra abstraction, needless copying, etc., and in general doesn't prioritize performance as much.

##### Date formatting is [hard](http://yourcalendricalfallacyis.com/). How does this library ensure correctness?

Although date formatting is difficult, this library has an extensive set of unit tests that cover edge cases like:
- All different format options
- All different time zones
- Leap seconds (neither us nor Apple actually handle them)
- Leap days
- Concurrent usage

Things are also easier because, for ISO 8601, we only need to support Gregorian calendar.

##### Is it literally the same for everything?

For nonsensical format options (week of year but no year) and malformed date strings, the behavior is slightly different. But for all intents and purposes, it is the exact same. Feel free to submit a ticket if you find otherwise.

##### Why is the prefix "JJL"?

Because it's easy to type with the left pinky on the shift key.

##### Are there other Apple libraries ripe for optimization?

Yes, there are a lot, the question is which ones are worth optimizing. Feel free to request optimizations for libraries that are causing performance issues for you.

### How is the benchmarking done?

It's done by timing repeated date -> string and string -> date conversions using `BenchmarkCore` in `Benchmark/Sources`. The iOS app target (`BenchmarkiOSApp`) runs the same benchmark logic on device in Release; the macOS CLI prints markdown tables, and you can get nice benchmarking output yourself by running that project. I normally run the benchmarks on a physical iPhone; numbers can vary by device and OS version.

## Future Improvements and Contribution

Contributors are always welcome. Here are some possible improvements:

- Full rewrite of NSDateFormatter (doable but is it worth it?)
- Method that returns a `char *` instead of an `NSString` for going from date to string.
- watchOS and tvOS support

## Author

Michael Eisel, michael.eisel@gmail.com

## License

JJLISO8601DateFormatter is available under the MIT license. See the LICENSE file for more info.
