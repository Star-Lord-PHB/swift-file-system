#ifdef __linux__

#define _GNU_SOURCE

#include <sys/stat.h>
#include <stdint.h>
#include <stdbool.h>


struct StatCompat {
    int64_t st_size;
    uid_t st_uid;
    gid_t st_gid;
    mode_t st_mode;
    struct timespec st_atim;
    struct timespec st_mtim;
    struct timespec st_ctim;
    struct timespec st_btim;
    int has_btime;
    uint64_t st_attributes;
    uint64_t st_attributes_mask;
};


int systemStatCompat(int32_t fd, struct StatCompat* outStat);


#ifndef STATX_ATTR_COMPRESSED
#define STATX_ATTR_COMPRESSED 0
const static bool HAS_STATX_ATTR_COMPRESSED = false;
#else
const static bool HAS_STATX_ATTR_COMPRESSED = true;
#endif

#ifndef STATX_ATTR_IMMUTABLE
#define STATX_ATTR_IMMUTABLE 0
const static bool HAS_STATX_ATTR_IMMUTABLE = false;
#else
const static bool HAS_STATX_ATTR_IMMUTABLE = true;
#endif

#ifndef STATX_ATTR_APPEND
#define STATX_ATTR_APPEND 0
const static bool HAS_STATX_ATTR_APPEND = false;
#else
const static bool HAS_STATX_ATTR_APPEND = true;
#endif

#ifndef STATX_ATTR_NODUMP
#define STATX_ATTR_NODUMP 0
const static bool HAS_STATX_ATTR_NODUMP = false;
#else
const static bool HAS_STATX_ATTR_NODUMP = true;
#endif

#ifndef STATX_ATTR_ENCRYPTED
#define STATX_ATTR_ENCRYPTED 0
const static bool HAS_STATX_ATTR_ENCRYPTED = false;
#else
const static bool HAS_STATX_ATTR_ENCRYPTED = true;
#endif

#ifndef STATX_ATTR_AUTOMOUNT
#define STATX_ATTR_AUTOMOUNT 0
const static bool HAS_STATX_ATTR_AUTOMOUNT = false;
#else
const static bool HAS_STATX_ATTR_AUTOMOUNT = true;
#endif

#ifndef STATX_ATTR_MOUNT_ROOT
#define STATX_ATTR_MOUNT_ROOT 0
const static bool HAS_STATX_ATTR_MOUNT_ROOT = false;
#else
const static bool HAS_STATX_ATTR_MOUNT_ROOT = true;
#endif

#ifndef STATX_ATTR_VERITY
#define STATX_ATTR_VERITY 0
const static bool HAS_STATX_ATTR_VERITY = false;
#else
const static bool HAS_STATX_ATTR_VERITY = true;
#endif

#ifndef STATX_ATTR_WRITE_ATOMIC
#define STATX_ATTR_WRITE_ATOMIC 0
const static bool HAS_STATX_ATTR_WRITE_ATOMIC = false;
#else
const static bool HAS_STATX_ATTR_WRITE_ATOMIC = true;
#endif

#ifndef STATX_ATTR_DAX
#define STATX_ATTR_DAX 0
const static bool HAS_STATX_ATTR_DAX = false;
#else
const static bool HAS_STATX_ATTR_DAX = true;
#endif

#endif // __linux__