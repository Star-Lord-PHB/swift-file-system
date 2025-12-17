#ifdef __linux__

#define _GNU_SOURCE

#include <linux/fs.h>
#include <sys/stat.h>


const unsigned long _FS_IOC_GETFLAGS = FS_IOC_GETFLAGS;
const unsigned long _FS_IOC_SETFLAGS = FS_IOC_SETFLAGS;

const unsigned long _UTIME_OMIT = UTIME_OMIT;

#endif