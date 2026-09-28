#ifdef __linux__

#include "LinuxStatx.h"

#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#if __has_include(<sys/sysmacros.h>)
#include <sys/sysmacros.h>
#endif
#if __has_include(<linux/stat.h>)
#include <linux/stat.h>     // struct statx and the STATX_* constants: kernel ABI, independent of the libc
#endif


#ifdef SYS_statx
#define HAS_STATX_SYSCALL 1
#endif


// Copied from <sys/stat.h> of musl 1.2.5, which declares them only under _GNU_SOURCE
#if defined(HAS_STATX_SYSCALL) && !defined(STATX_BASIC_STATS)
#define STATX_BASIC_STATS 0x7ffU
#define STATX_BTIME 0x800U

struct statx_timestamp {
    int64_t tv_sec;
    uint32_t tv_nsec, __pad;
};

struct statx {
    uint32_t stx_mask;
    uint32_t stx_blksize;
    uint64_t stx_attributes;
    uint32_t stx_nlink;
    uint32_t stx_uid;
    uint32_t stx_gid;
    uint16_t stx_mode;
    uint16_t __pad0[1];
    uint64_t stx_ino;
    uint64_t stx_size;
    uint64_t stx_blocks;
    uint64_t stx_attributes_mask;
    struct statx_timestamp stx_atime;
    struct statx_timestamp stx_btime;
    struct statx_timestamp stx_ctime;
    struct statx_timestamp stx_mtime;
    uint32_t stx_rdev_major;
    uint32_t stx_rdev_minor;
    uint32_t stx_dev_major;
    uint32_t stx_dev_minor;
    uint64_t __pad1[14];
};
#endif


// _GNU_SOURCE-gated in glibc; the value is kernel ABI.
#ifndef AT_STATX_SYNC_TYPE
#define AT_STATX_SYNC_TYPE 0x6000
#endif


#ifdef HAS_STATX_SYSCALL
static void fillStatCompat(struct StatCompat *const out, const struct statx *const stx) {
    out->st_size = stx->stx_size;
    out->st_uid = stx->stx_uid;
    out->st_gid = stx->stx_gid;
    out->st_mode = stx->stx_mode;
    out->st_nlink = stx->stx_nlink;
    out->st_dev = makedev(stx->stx_dev_major, stx->stx_dev_minor);
    out->st_rdev = makedev(stx->stx_rdev_major, stx->stx_rdev_minor);
    out->st_ino = stx->stx_ino;
    out->st_atim.tv_sec = stx->stx_atime.tv_sec;
    out->st_atim.tv_nsec = stx->stx_atime.tv_nsec;
    out->st_mtim.tv_sec = stx->stx_mtime.tv_sec;
    out->st_mtim.tv_nsec = stx->stx_mtime.tv_nsec;
    out->st_ctim.tv_sec = stx->stx_ctime.tv_sec;
    out->st_ctim.tv_nsec = stx->stx_ctime.tv_nsec;
    out->st_attributes = stx->stx_attributes;
    out->st_attributes_mask = stx->stx_attributes_mask;
    if (stx->stx_mask & STATX_BTIME) {
        out->st_btim.tv_sec = stx->stx_btime.tv_sec;
        out->st_btim.tv_nsec = stx->stx_btime.tv_nsec;
        out->has_btime = 1;
    } else {
        out->st_btim.tv_sec = 0;
        out->st_btim.tv_nsec = 0;
        out->has_btime = 0;
    }
}
#endif


static void fillStatCompatFromStat(struct StatCompat *const out, const struct stat *const st) {
    out->st_size = st->st_size;
    out->st_uid = st->st_uid;
    out->st_gid = st->st_gid;
    out->st_mode = st->st_mode;
    out->st_nlink = st->st_nlink;
    out->st_dev = st->st_dev;
    out->st_rdev = st->st_rdev;
    out->st_ino = st->st_ino;
    out->st_atim = st->st_atim;
    out->st_mtim = st->st_mtim;
    out->st_ctim = st->st_ctim;
    out->st_btim.tv_sec = 0;
    out->st_btim.tv_nsec = 0;
    out->has_btime = 0;
    out->st_attributes = 0;
    out->st_attributes_mask = 0;
}


// Goes through the raw syscall so that no libc-specific declaration (glibc gates statx behind _GNU_SOURCE, musl
// defines its own struct statx there, Bionic requires API 30) or version check is needed. glibc and musl fall
// back to fstatat themselves when the kernel has no statx; this does the same, and also treats EPERM as
// "unavailable", which is what an old seccomp profile answers for a syscall it does not know.
int _statx(int dirfd, const char *path, int flags, struct StatCompat *out) {

#ifdef HAS_STATX_SYSCALL
    struct statx stx;
    if (syscall(SYS_statx, dirfd, path, flags, STATX_BASIC_STATS | STATX_BTIME, &stx) == 0) {
        fillStatCompat(out, &stx);
        return 0;
    }
    if (errno != ENOSYS && errno != EPERM) {
        return -1;
    }
#endif

    struct stat st;
    if (fstatat(dirfd, path, &st, flags & ~AT_STATX_SYNC_TYPE) != 0) {
        return -1;
    }
    fillStatCompatFromStat(out, &st);
    return 0;

}

#endif // __linux__
