#ifdef __linux__
#define _GNU_SOURCE

#include "Statx.h"
#include <sys/stat.h>
#include <fcntl.h> 

int systemStatCompat(const int32_t fd, struct StatCompat*const outStat) {

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
    outStat->st_atim = st.st_atim;
    outStat->st_mtim = st.st_mtim;
    outStat->st_ctim = st.st_ctim;
    outStat->has_btime = 0;

    return result;

#endif

}

#endif // __linux__