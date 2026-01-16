#ifdef __linux__

#define _GNU_SOURCE

#include <linux/fs.h>
#include <sys/stat.h>


const unsigned long _FS_IOC_GETFLAGS = FS_IOC_GETFLAGS;
const unsigned long _FS_IOC_SETFLAGS = FS_IOC_SETFLAGS;

const int _FS_APPEND_FL = FS_APPEND_FL;
const int _FS_COMPR_FL = FS_COMPR_FL;
const int _FS_DIRSYNC_FL = FS_DIRSYNC_FL;
const int _FS_IMMUTABLE_FL = FS_IMMUTABLE_FL;
const int _FS_JOURNAL_DATA_FL = FS_JOURNAL_DATA_FL;
const int _FS_NOATIME_FL = FS_NOATIME_FL;
const int _FS_NOCOW_FL = FS_NOCOW_FL;
const int _FS_NODUMP_FL = FS_NODUMP_FL;
const int _FS_NOTAIL_FL = FS_NOTAIL_FL;
const int _FS_PROJINHERIT_FL = FS_PROJINHERIT_FL;
const int _FS_SECRM_FL = FS_SECRM_FL;
const int _FS_SYNC_FL = FS_SYNC_FL;
const int _FS_TOPDIR_FL = FS_TOPDIR_FL;
const int _FS_UNRM_FL = FS_UNRM_FL;
const int _FS_ENCRYPT_FL = FS_ENCRYPT_FL;
const int _FS_VERITY_FL = FS_VERITY_FL;

const unsigned long _UTIME_OMIT = UTIME_OMIT;
const unsigned long _UTIME_NOW = UTIME_NOW;

#endif