#pragma once
#define quote(s)            #s
#define str(s)              quote(s)
#define MAGISK_FULL_VER     MAGISK_VERSION "(" str(MAGISK_VER_CODE) ")"
#define NAME_WITH_VER(name) str(name) " " MAGISK_FULL_VER
#define MAGISK_VERSION      "44643ad7"
#define MAGISK_VER_CODE     25205
#define MAGISK_DEBUG        0
