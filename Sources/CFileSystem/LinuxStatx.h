#ifdef __linux__

#define _GNU_SOURCE

#if defined(__has_include) && __has_include(<linux/stat.h>)
#include <linux/stat.h>
#endif

#include <sys/stat.h>
#include <stdint.h>


struct StatCompat {
    int64_t st_size;
    uid_t st_uid;
    gid_t st_gid;
    mode_t st_mode;
    nlink_t st_nlink;
    dev_t st_dev;
    dev_t st_rdev;
    ino_t st_ino;
    struct timespec st_atim;
    struct timespec st_mtim;
    struct timespec st_ctim;
    struct timespec st_btim;
    int has_btime;
    uint64_t st_attributes;
    uint64_t st_attributes_mask;
};


int systemFStatCompat(int32_t fd, struct StatCompat* outStat);
int systemStatCompat(const char* path, int flags, struct StatCompat*const outStat);


#ifndef STATX_ATTR_COMPRESSED
#define STATX_ATTR_COMPRESSED 0x00000004
#endif

#ifndef STATX_ATTR_IMMUTABLE
#define STATX_ATTR_IMMUTABLE 0x00000010
#endif

#ifndef STATX_ATTR_APPEND
#define STATX_ATTR_APPEND 0x00000020
#endif

#ifndef STATX_ATTR_NODUMP
#define STATX_ATTR_NODUMP 0x00000040
#endif

#ifndef STATX_ATTR_ENCRYPTED
#define STATX_ATTR_ENCRYPTED 0x00000800
#endif

#ifndef STATX_ATTR_AUTOMOUNT
#define STATX_ATTR_AUTOMOUNT 0x00001000
#endif

#ifndef STATX_ATTR_MOUNT_ROOT
#define STATX_ATTR_MOUNT_ROOT 0x00002000
#endif

#ifndef STATX_ATTR_VERITY
#define STATX_ATTR_VERITY 0x00100000
#endif

#ifndef STATX_ATTR_WRITE_ATOMIC
#define STATX_ATTR_WRITE_ATOMIC 0x00400000
#endif

#ifndef STATX_ATTR_DAX
#define STATX_ATTR_DAX 0x00200000
#endif

#endif // __linux__