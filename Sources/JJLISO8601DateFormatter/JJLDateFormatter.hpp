// Copyright (c) 2018 Michael Eisel. All rights reserved.
// C++20 rewrite

#pragma once

#include <chrono>
#include <string>
#include <string_view>
#include <optional>
#include <cstdint>
#include <array>
#include <cmath>

namespace jjl {

// Format options matching NSISO8601DateFormatOptions
enum class FormatOptions : uint32_t {
    None = 0,
    Year                        = 1 << 0,
    Month                       = 1 << 1,
    WeekOfYear                  = 1 << 2,
    Day                         = 1 << 3,
    Time                        = 1 << 4,
    TimeZone                    = 1 << 5,
    SpaceBetweenDateAndTime     = 1 << 6,
    DashSeparatorInDate         = 1 << 7,
    ColonSeparatorInTime        = 1 << 8,
    ColonSeparatorInTimeZone    = 1 << 9,
    FractionalSeconds           = 1 << 10,
    
    // Convenience combinations
    FullDate = Year | Month | Day | DashSeparatorInDate,
    FullTime = Time | TimeZone | ColonSeparatorInTime | ColonSeparatorInTimeZone,
    InternetDateTime = FullDate | FullTime,
};

constexpr FormatOptions operator|(FormatOptions a, FormatOptions b) {
    return static_cast<FormatOptions>(static_cast<uint32_t>(a) | static_cast<uint32_t>(b));
}

constexpr FormatOptions operator&(FormatOptions a, FormatOptions b) {
    return static_cast<FormatOptions>(static_cast<uint32_t>(a) & static_cast<uint32_t>(b));
}

constexpr bool hasOption(FormatOptions options, FormatOptions flag) {
    return (static_cast<uint32_t>(options) & static_cast<uint32_t>(flag)) != 0;
}

// Use system_clock for UTC time points with millisecond precision
using TimePoint = std::chrono::time_point<std::chrono::system_clock, std::chrono::milliseconds>;
using Duration = std::chrono::milliseconds;

class ISO8601DateFormatter {
public:
    // Fast integer to string conversion with zero-padding
    static char* writeNumber(char* buf, int value, int width) {
        char* end = buf + width;
        char* p = end;
        int v = value < 0 ? -value : value;
        
        while (p > buf) {
            *--p = '0' + (v % 10);
            v /= 10;
        }
        return end;
    }
    
    // Format a time point to ISO 8601 string
    // tzOffsetSeconds: offset from UTC in seconds (positive = east of UTC)
    static std::string format(TimePoint tp, FormatOptions options, int32_t tzOffsetSeconds = 0) {
        using namespace std::chrono;
        
        // Check for degenerate options - NSISO8601DateFormatter returns empty for these
        uint32_t optVal = static_cast<uint32_t>(options);
        if (optVal == 0 || (optVal & (optVal - 1)) == 0) {
            // 0 or power of 2 (single flag) - not enough info to format meaningfully
            return "";
        }
        
        // Apply timezone offset to get local time
        auto adjusted_tp = tp + seconds{tzOffsetSeconds};
        auto sys_tp = time_point_cast<milliseconds>(adjusted_tp);
        
        // Split into days and time-of-day
        auto dp = floor<days>(sys_tp);
        year_month_day ymd{dp};
        hh_mm_ss<milliseconds> hms{sys_tp - dp};
        
        // Build output string
        std::array<char, 64> buffer;
        char* p = buffer.data();
        
        const bool showYear = hasOption(options, FormatOptions::Year);
        const bool showMonth = hasOption(options, FormatOptions::Month);
        const bool showDay = hasOption(options, FormatOptions::Day);
        
        // Week is suppressed when all components of InternetDateTime are present with all separators
        const bool isFullInternetDateTime = 
            hasOption(options, FormatOptions::Year) &&
            hasOption(options, FormatOptions::Month) &&
            hasOption(options, FormatOptions::Day) &&
            hasOption(options, FormatOptions::Time) &&
            hasOption(options, FormatOptions::TimeZone) &&
            hasOption(options, FormatOptions::DashSeparatorInDate) &&
            hasOption(options, FormatOptions::ColonSeparatorInTime) &&
            hasOption(options, FormatOptions::ColonSeparatorInTimeZone);
        const bool showWeekOfYear = hasOption(options, FormatOptions::WeekOfYear) && !isFullInternetDateTime;
        const bool showDateSeparator = hasOption(options, FormatOptions::DashSeparatorInDate);
        const bool showTime = hasOption(options, FormatOptions::Time);
        const bool showTimeSeparator = hasOption(options, FormatOptions::ColonSeparatorInTime);
        const bool showTimeZone = hasOption(options, FormatOptions::TimeZone);
        const bool showTZSeparator = hasOption(options, FormatOptions::ColonSeparatorInTimeZone);
        const bool showFractional = hasOption(options, FormatOptions::FractionalSeconds);
        const bool spaceBeforeTime = hasOption(options, FormatOptions::SpaceBetweenDateAndTime);
        
        const bool showDate = showYear || showMonth || showDay || showWeekOfYear;
        
        int year = static_cast<int>(ymd.year());
        unsigned month = static_cast<unsigned>(ymd.month());
        unsigned day = static_cast<unsigned>(ymd.day());
        
        // Calculate day of year and week info if needed
        auto jan1 = year_month_day{ymd.year(), std::chrono::January, std::chrono::day{1}};
        int dayOfYear = static_cast<int>((dp - sys_days{jan1}).count()) + 1;
        
        // ISO week calculation
        weekday jan1_wd{sys_days{jan1}};
        weekday this_wd{dp};
        int daysAfterFirstWeekday = (this_wd.c_encoding() - 1 + 7) % 7; // Monday = 0
        
        // Check if this date belongs to previous/next year's week
        bool usePreviousYear = showWeekOfYear && (daysAfterFirstWeekday - (dayOfYear - 1) > 3);
        int daysInYear = ymd.year().is_leap() ? 366 : 365;
        bool useNextYear = showWeekOfYear && ((dayOfYear - 1) - daysAfterFirstWeekday + 7 - daysInYear >= 4);
        
        // Date part
        if (showYear) {
            int yearToShow = year;
            if (usePreviousYear) yearToShow--;
            else if (useNextYear) yearToShow++;
            p = writeNumber(p, yearToShow, 4);
        }
        
        if (showMonth) {
            if (showDateSeparator && showYear) *p++ = '-';
            p = writeNumber(p, month, 2);
        }
        
        if (showWeekOfYear) {
            if (showDateSeparator && (showYear || showMonth)) *p++ = '-';
            *p++ = 'W';
            
            int week = 0;
            if (useNextYear) {
                week = 0;
            } else {
                int daysToDivide = (dayOfYear - 1) - daysAfterFirstWeekday;
                if (usePreviousYear) {
                    int prevYearDays = year_month_day{ymd.year() - years{1}, std::chrono::December, std::chrono::day{31}}.year().is_leap() ? 366 : 365;
                    daysToDivide += prevYearDays;
                }
                week = daysToDivide / 7;
                if (daysToDivide % 7 >= 4) week++;
            }
            p = writeNumber(p, week + 1, 2);
        }
        
        if (showDay) {
            if (showDateSeparator && (showYear || showMonth || showWeekOfYear)) *p++ = '-';
            if (showWeekOfYear) {
                p = writeNumber(p, daysAfterFirstWeekday + 1, 2);
            } else if (showMonth) {
                p = writeNumber(p, day, 2);
            } else {
                p = writeNumber(p, dayOfYear, 3);
            }
        }
        
        // Time part
        if (showTime) {
            if (showDate) {
                *p++ = spaceBeforeTime ? ' ' : 'T';
            }
            
            p = writeNumber(p, static_cast<int>(hms.hours().count()), 2);
            if (showTimeSeparator) *p++ = ':';
            p = writeNumber(p, static_cast<int>(hms.minutes().count()), 2);
            if (showTimeSeparator) *p++ = ':';
            p = writeNumber(p, static_cast<int>(hms.seconds().count()), 2);
            
            if (showFractional) {
                *p++ = '.';
                int millis = static_cast<int>(hms.subseconds().count());
                p = writeNumber(p, millis, 3);
            }
        }
        
        // Timezone part
        if (showTimeZone) {
            if (tzOffsetSeconds == 0) {
                *p++ = 'Z';
            } else {
                *p++ = tzOffsetSeconds >= 0 ? '+' : '-';
                int absOffset = tzOffsetSeconds < 0 ? -tzOffsetSeconds : tzOffsetSeconds;
                int tzHours = absOffset / 3600;
                int tzMinutes = (absOffset % 3600) / 60;
                int tzSeconds = absOffset % 60;
                
                p = writeNumber(p, tzHours, 2);
                if (showTZSeparator) *p++ = ':';
                p = writeNumber(p, tzMinutes, 2);
                
                if (tzSeconds > 0) {
                    if (showTZSeparator) *p++ = ':';
                    p = writeNumber(p, tzSeconds, 2);
                }
            }
        }
        
        return std::string(buffer.data(), static_cast<size_t>(p - buffer.data()));
    }
    
    // Parse an ISO 8601 string to a time point
    // defaultTzOffsetSeconds: if no timezone is in the string, assume input is in this timezone
    static std::optional<TimePoint> parse(std::string_view str, FormatOptions options, 
                                          int32_t defaultTzOffsetSeconds = 0) {
        using namespace std::chrono;
        
        if (str.empty()) return std::nullopt;
        
        // Check for degenerate options
        uint32_t optVal = static_cast<uint32_t>(options);
        if (optVal == 0 || (optVal & (optVal - 1)) == 0) {
            // 0 or power of 2 (single flag) - not enough info to parse
            return std::nullopt;
        }
        
        const char* p = str.data();
        const char* end = str.data() + str.size();
        
        auto consumeNumber = [&](int maxDigits) -> std::optional<int> {
            if (p >= end) return std::nullopt;
            
            int value = 0;
            int digits = 0;
            bool negative = false;
            
            if (*p == '-') {
                negative = true;
                ++p;
            }
            
            while (p < end && (maxDigits < 0 || digits < maxDigits) && *p >= '0' && *p <= '9') {
                value = value * 10 + (*p - '0');
                ++p;
                ++digits;
            }
            
            if (digits == 0) return std::nullopt;
            return negative ? -value : value;
        };
        
        auto consumeChar = [&](char c) -> bool {
            if (p >= end || *p != c) return false;
            ++p;
            return true;
        };
        
        auto consumeSeparator = [&]() -> bool {
            if (p >= end) return false;
            if (*p == '-' || *p == ':' || *p == ' ') {
                ++p;
                return true;
            }
            return false;
        };
        
        const bool showYear = hasOption(options, FormatOptions::Year);
        const bool showMonth = hasOption(options, FormatOptions::Month);
        const bool showDay = hasOption(options, FormatOptions::Day);
        const bool showDateSeparator = hasOption(options, FormatOptions::DashSeparatorInDate);
        const bool showTime = hasOption(options, FormatOptions::Time);
        const bool showTimeSeparator = hasOption(options, FormatOptions::ColonSeparatorInTime);
        const bool showTimeZone = hasOption(options, FormatOptions::TimeZone);
        const bool showTZSeparator = hasOption(options, FormatOptions::ColonSeparatorInTimeZone);
        const bool showFractional = hasOption(options, FormatOptions::FractionalSeconds);
        
        // Week is suppressed when all components of InternetDateTime are present with all separators
        const bool isFullInternetDateTime = 
            showYear && showMonth && showDay && showTime && showTimeZone &&
            showDateSeparator && showTimeSeparator && showTZSeparator;
        const bool showWeekOfYear = hasOption(options, FormatOptions::WeekOfYear) && !isFullInternetDateTime;
        const bool showDate = showYear || showMonth || showDay || showWeekOfYear;
        
        int yearVal = 2000;
        int monthVal = 1;
        int dayOffset = 1;
        int hourVal = 0;
        int minVal = 0;
        int secVal = 0;
        int millisVal = 0;
        int tzOffsetSeconds = 0;
        
        // Parse date
        if (showYear) {
            auto y = consumeNumber(4);
            if (!y) return std::nullopt;
            yearVal = *y;
        }
        
        if (showMonth) {
            if (showDateSeparator && showYear) consumeSeparator();
            auto m = consumeNumber(2);
            if (!m) return std::nullopt;
            monthVal = *m;
        }
        
        if (showWeekOfYear) {
            if (showDateSeparator && (showYear || showMonth)) consumeSeparator();
            if (!consumeChar('W')) return std::nullopt;
            auto w = consumeNumber(2);
            if (!w) return std::nullopt;
            int weeks = *w - 1;
            
            // Calculate first Monday of year
            year_month_day jan1{year{yearVal}, std::chrono::January, std::chrono::day{1}};
            weekday jan1_wd{sys_days{jan1}};
            int firstMonday = (7 - jan1_wd.c_encoding() + 1) % 7;
            if (firstMonday < 4) {
                dayOffset = firstMonday + 1;
            } else {
                dayOffset = firstMonday - 6;
            }
            dayOffset += weeks * 7;
        }
        
        if (showDay) {
            if (showDateSeparator && (showYear || showMonth || showWeekOfYear)) consumeSeparator();
            auto d = consumeNumber(-1); // -1 = no limit
            if (!d) return std::nullopt;
            dayOffset += *d - 1;
        }
        
        // Parse time
        if (showTime) {
            if (showDate) {
                if (p < end && (*p == 'T' || *p == ' ')) ++p;
            }
            
            auto h = consumeNumber(2);
            if (!h) return std::nullopt;
            hourVal = *h;
            
            if (showTimeSeparator) consumeSeparator();
            
            auto m = consumeNumber(2);
            if (!m) return std::nullopt;
            minVal = *m;
            
            if (showTimeSeparator) consumeSeparator();
            
            auto s = consumeNumber(2);
            if (!s) return std::nullopt;
            secVal = *s;
            
            if (showFractional && p < end && (*p == '.' || *p == ',')) {
                ++p;
                const char* fracStart = p;
                auto frac = consumeNumber(3);
                if (frac) {
                    int fracDigits = static_cast<int>(p - fracStart);
                    millisVal = *frac;
                    while (fracDigits < 3) { millisVal *= 10; ++fracDigits; }
                }
                // Consume remaining fractional digits
                while (p < end && *p >= '0' && *p <= '9') ++p;
            }
        }
        
        // Parse timezone
        if (showTimeZone && p < end) {
            if (*p == 'Z') {
                ++p;
                tzOffsetSeconds = 0;
            } else if (*p == '+' || *p == '-') {
                bool negative = (*p == '-');
                ++p;
                
                auto tzH = consumeNumber(2);
                if (!tzH) return std::nullopt;
                
                if (showTZSeparator && p < end && *p == ':') ++p;
                
                auto tzM = consumeNumber(2);
                if (!tzM) return std::nullopt;
                
                int tzS = 0;
                if (p < end) {
                    if (showTZSeparator && *p == ':') {
                        ++p;
                        auto s = consumeNumber(2);
                        if (s) tzS = *s;
                    } else if (!showTZSeparator && *p >= '0' && *p <= '9') {
                        auto s = consumeNumber(2);
                        if (s) tzS = *s;
                    }
                }
                
                tzOffsetSeconds = (*tzH * 3600) + (*tzM * 60) + tzS;
                if (negative) tzOffsetSeconds = -tzOffsetSeconds;
            }
        }
        
        // Build the time point
        try {
            TimePoint result;
            
            if (showMonth && !showWeekOfYear) {
                year_month_day ymd{year{yearVal}, month{static_cast<unsigned>(monthVal)}, 
                                  day{static_cast<unsigned>(dayOffset)}};
                if (!ymd.ok()) return std::nullopt;
                
                result = time_point_cast<milliseconds>(sys_days{ymd});
            } else {
                // Day of year or week-based
                year_month_day jan1{year{yearVal}, std::chrono::January, std::chrono::day{1}};
                auto dp = sys_days{jan1} + days{dayOffset - 1};
                
                // Check for year overflow
                year_month_day resultYmd{dp};
                if (static_cast<int>(resultYmd.year()) != yearVal && !showWeekOfYear) {
                    // Adjust year
                    jan1 = year_month_day{year{static_cast<int>(resultYmd.year())}, std::chrono::January, std::chrono::day{1}};
                }
                
                result = time_point_cast<milliseconds>(dp);
            }
            
            result += hours{hourVal} + minutes{minVal} + seconds{secVal} + milliseconds{millisVal};
            
            // Adjust for timezone offset (convert local time to UTC)
            // If we parsed a timezone from the string, use that; otherwise use the default
            if (showTimeZone) {
                result -= seconds{tzOffsetSeconds};
            } else {
                // No timezone in string - assume input is in the default timezone
                result -= seconds{defaultTzOffsetSeconds};
            }
            
            return result;
        } catch (...) {
            return std::nullopt;
        }
    }
};

} // namespace jjl
