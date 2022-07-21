#pragma once
#define quote(s)            #s
#define str(s)              quote(s)
#define MAGISK_FULL_VER     MAGISK_VERSION "(" str(MAGISK_VER_CODE) ")"
#define NAME_WITH_VER(name) str(name) " " MAGISK_FULL_VER
#define MAGISK_VERSION      "8423dc8d"
#define MAGISK_VER_CODE     25102
#define MAGISK_DEBUG        0
