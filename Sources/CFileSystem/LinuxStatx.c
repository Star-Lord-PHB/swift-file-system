#ifdef __linux__

#include "LinuxStatx.h"
#include <sys/stat.h>
#include <fcntl.h> 
#include <sys/sysmacros.h>

#ifndef STATX_ATTR_COMPRESSED
const int _STATX_ATTR_COMPRESSED = 0
const bool HAS_STATX_ATTR_COMPRESSED = false;
#else
const int _STATX_ATTR_COMPRESSED = STATX_ATTR_COMPRESSED;
const bool HAS_STATX_ATTR_COMPRESSED = true;
#endif

#ifndef STATX_ATTR_IMMUTABLE
const int _STATX_ATTR_IMMUTABLE = 0;
const bool HAS_STATX_ATTR_IMMUTABLE = false;
#else
const int _STATX_ATTR_IMMUTABLE = STATX_ATTR_IMMUTABLE;
const bool HAS_STATX_ATTR_IMMUTABLE = true;
#endif

#ifndef STATX_ATTR_APPEND
const int _STATX_ATTR_APPEND = 0;
const bool HAS_STATX_ATTR_APPEND = false;
#else
const int _STATX_ATTR_APPEND = STATX_ATTR_APPEND;
const bool HAS_STATX_ATTR_APPEND = true;
#endif

#ifndef STATX_ATTR_NODUMP
const int _STATX_ATTR_NODUMP = 0;
const bool HAS_STATX_ATTR_NODUMP = false;
#else
const int _STATX_ATTR_NODUMP = STATX_ATTR_NODUMP;
const bool HAS_STATX_ATTR_NODUMP = true;
#endif

#ifndef STATX_ATTR_ENCRYPTED
const int _STATX_ATTR_ENCRYPTED = 0;
const bool HAS_STATX_ATTR_ENCRYPTED = false;
#else
const int _STATX_ATTR_ENCRYPTED = STATX_ATTR_ENCRYPTED;
const bool HAS_STATX_ATTR_ENCRYPTED = true;
#endif

#ifndef STATX_ATTR_AUTOMOUNT
const int _STATX_ATTR_AUTOMOUNT = 0;
const bool HAS_STATX_ATTR_AUTOMOUNT = false;
#else
const int _STATX_ATTR_AUTOMOUNT = STATX_ATTR_AUTOMOUNT;
const bool HAS_STATX_ATTR_AUTOMOUNT = true;
#endif

#ifndef STATX_ATTR_MOUNT_ROOT
const int _STATX_ATTR_MOUNT_ROOT = 0;
const bool HAS_STATX_ATTR_MOUNT_ROOT = false;
#else
const int _STATX_ATTR_MOUNT_ROOT = STATX_ATTR_MOUNT_ROOT;
const bool HAS_STATX_ATTR_MOUNT_ROOT = true;
#endif

#ifndef STATX_ATTR_VERITY
const int _STATX_ATTR_VERITY = 0;
const bool HAS_STATX_ATTR_VERITY = false;
#else
const int _STATX_ATTR_VERITY = STATX_ATTR_VERITY;
const bool HAS_STATX_ATTR_VERITY = true;
#endif

#ifndef STATX_ATTR_WRITE_ATOMIC
const int _STATX_ATTR_WRITE_ATOMIC = 0;
const bool HAS_STATX_ATTR_WRITE_ATOMIC = false;
#else
const int _STATX_ATTR_WRITE_ATOMIC = STATX_ATTR_WRITE_ATOMIC;
const bool HAS_STATX_ATTR_WRITE_ATOMIC = true;
#endif

#ifndef STATX_ATTR_DAX
const int _STATX_ATTR_DAX = 0;
const bool HAS_STATX_ATTR_DAX = false;
#else
const int _STATX_ATTR_DAX = STATX_ATTR_DAX;
const bool HAS_STATX_ATTR_DAX = true;
#endif


int systemFStatCompat(const int32_t fd, struct StatCompat*const outStat) {

#ifdef __statx_defined

    struct statx stx;

    int result = statx(fd, "", AT_EMPTY_PATH, STATX_BASIC_STATS | STATX_BTIME, &stx);

    if (result != 0) {
        return result;
    }

    outStat->st_size = stx.stx_size;
    outStat->st_uid = stx.stx_uid;
    outStat->st_gid = stx.stx_gid;
    outStat->st_mode = stx.stx_mode;
    outStat->st_nlink = stx.stx_nlink;
    outStat->st_dev = makedev(stx.stx_dev_major, stx.stx_dev_minor);
    outStat->st_rdev = makedev(stx.stx_rdev_major, stx.stx_rdev_minor);
    outStat->st_ino = stx.stx_ino;
    outStat->st_atim.tv_sec = stx.stx_atime.tv_sec;
    outStat->st_atim.tv_nsec = stx.stx_atime.tv_nsec;
    outStat->st_mtim.tv_sec = stx.stx_mtime.tv_sec;
    outStat->st_mtim.tv_nsec = stx.stx_mtime.tv_nsec;
    outStat->st_ctim.tv_sec = stx.stx_ctime.tv_sec;
    outStat->st_ctim.tv_nsec = stx.stx_ctime.tv_nsec;
    outStat->st_attributes = stx.stx_attributes;
    outStat->st_attributes_mask = stx.stx_attributes_mask;

    if (stx.stx_mask & STATX_BTIME) {
        outStat->st_btim.tv_sec = stx.stx_btime.tv_sec;
        outStat->st_btim.tv_nsec = stx.stx_btime.tv_nsec;
        outStat->has_btime = 1;
    } else {
        outStat->has_btime = 0;
    }

    return 0;

#else 

    struct stat st;

    int result = fstat(fd, &st);
    if (result != 0) {
        return result;
    }

    outStat->st_size = st.st_size;
    outStat->st_uid = st.st_uid;
    outStat->st_gid = st.st_gid;
    outStat->st_mode = st.st_mode;
    outStat->st_nlink = st.st_nlink;
    outStat->st_dev = st.st_dev;
    outStat->st_rdev = st.st_rdev;
    outStat->st_ino = st.st_ino;
    outStat->st_atim = st.st_atim;
    outStat->st_mtim = st.st_mtim;
    outStat->st_ctim = st.st_ctim;
    outStat->has_btime = 0;

    return result;

#endif

}



int systemStatCompat(const char* path, int flags, struct StatCompat*const outStat) {

#ifdef __statx_defined

    struct statx stx;

    int result = statx(AT_FDCWD, path, flags, STATX_BASIC_STATS | STATX_BTIME, &stx);

    if (result != 0) {
        return result;
    }

    outStat->st_size = stx.stx_size;
    outStat->st_uid = stx.stx_uid;
    outStat->st_gid = stx.stx_gid;
    outStat->st_mode = stx.stx_mode;
    outStat->st_nlink = stx.stx_nlink;
    outStat->st_dev = makedev(stx.stx_dev_major, stx.stx_dev_minor);
    outStat->st_rdev = makedev(stx.stx_rdev_major, stx.stx_rdev_minor);
    outStat->st_ino = stx.stx_ino;
    outStat->st_atim.tv_sec = stx.stx_atime.tv_sec;
    outStat->st_atim.tv_nsec = stx.stx_atime.tv_nsec;
    outStat->st_mtim.tv_sec = stx.stx_mtime.tv_sec;
    outStat->st_mtim.tv_nsec = stx.stx_mtime.tv_nsec;
    outStat->st_ctim.tv_sec = stx.stx_ctime.tv_sec;
    outStat->st_ctim.tv_nsec = stx.stx_ctime.tv_nsec;
    outStat->st_attributes = stx.stx_attributes;
    outStat->st_attributes_mask = stx.stx_attributes_mask;

    if (stx.stx_mask & STATX_BTIME) {
        outStat->st_btim.tv_sec = stx.stx_btime.tv_sec;
        outStat->st_btim.tv_nsec = stx.stx_btime.tv_nsec;
        outStat->has_btime = 1;
    } else {
        outStat->has_btime = 0;
    }

    return 0;

#else 

    struct stat st;

    int result = lstat(path, &st);
    if (result != 0) {
        return result;
    }

    outStat->st_size = st.st_size;
    outStat->st_uid = st.st_uid;
    outStat->st_gid = st.st_gid;
    outStat->st_mode = st.st_mode;
    outStat->st_nlink = st.st_nlink;
    outStat->st_dev = st.st_dev;
    outStat->st_rdev = st.st_rdev;
    outStat->st_ino = st.st_ino;
    outStat->st_atim = st.st_atim;
    outStat->st_mtim = st.st_mtim;
    outStat->st_ctim = st.st_ctim;
    outStat->has_btime = 0;

    return result;

#endif

}

#endif // __linux__