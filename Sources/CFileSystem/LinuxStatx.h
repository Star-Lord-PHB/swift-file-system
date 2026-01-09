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


extern const int _STATX_ATTR_COMPRESSED;
extern const bool HAS_STATX_ATTR_COMPRESSED;

extern const int _STATX_ATTR_IMMUTABLE;
extern const bool HAS_STATX_ATTR_IMMUTABLE;

extern const int _STATX_ATTR_APPEND;
extern const bool HAS_STATX_ATTR_APPEND;

extern const int _STATX_ATTR_NODUMP;
extern const bool HAS_STATX_ATTR_NODUMP;

extern const int _STATX_ATTR_ENCRYPTED;
extern const bool HAS_STATX_ATTR_ENCRYPTED;

extern const int _STATX_ATTR_AUTOMOUNT;
extern const bool HAS_STATX_ATTR_AUTOMOUNT;

extern const int _STATX_ATTR_MOUNT_ROOT;
extern const bool HAS_STATX_ATTR_MOUNT_ROOT;

extern const int _STATX_ATTR_VERITY;
extern const bool HAS_STATX_ATTR_VERITY;

extern const int _STATX_ATTR_WRITE_ATOMIC;
extern const bool HAS_STATX_ATTR_WRITE_ATOMIC;

extern const int _STATX_ATTR_DAX;
extern const bool HAS_STATX_ATTR_DAX;

#endif // __linux__