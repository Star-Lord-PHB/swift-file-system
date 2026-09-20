#ifdef __linux__

#include <sys/types.h>
#include <stdint.h>
#include <time.h>


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


// statx(2)-shaped: dirfd, path and flags address the item exactly as the syscall does (AT_EMPTY_PATH with an
// empty path for a handle, AT_FDCWD with a path otherwise, AT_SYMLINK_NOFOLLOW to stat a link itself); the
// mask is fixed to the basic stats plus the birth time. Where the statx syscall is unavailable the result comes
// from fstatat and carries neither a birth time (has_btime == 0) nor attributes.
int _statx(int dirfd, const char *path, int flags, struct StatCompat *out);


// Kernel ABI values, copied here because glibc gates AT_EMPTY_PATH behind _GNU_SOURCE and the STATX_ATTR_*
// constants live in <linux/stat.h>, which the Swift side does not need otherwise.

#ifndef AT_EMPTY_PATH
#define AT_EMPTY_PATH 0x1000
#endif

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
