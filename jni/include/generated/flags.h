#pragma once
#define quote(s)            #s
#define str(s)              quote(s)
#define MAGISK_FULL_VER     MAGISK_VERSION "(" str(MAGISK_VER_CODE) ")"
#define NAME_WITH_VER(name) str(name) " " MAGISK_FULL_VER
#define MAGISK_VERSION      "4264ae49"
#define MAGISK_VER_CODE     25201
#define MAGISK_DEBUG        0
