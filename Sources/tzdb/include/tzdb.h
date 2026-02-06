//Copyright (c) 2018 Michael Eisel. All rights reserved.

#ifndef TZDB_H
#define TZDB_H

#include <time.h>

// Timezone type from tzdb
typedef struct state *timezone_t;

// Timezone API functions (implemented in localtime.c)
timezone_t jjl_tzalloc(char const *name);
void jjl_tzfree(timezone_t sp);
struct tm * jjl_localtime_rz(timezone_t sp, time_t const *timep, struct tm *tmp);
time_t jjl_mktime_z(timezone_t sp, struct tm *tmp);

#endif /* TZDB_H */
