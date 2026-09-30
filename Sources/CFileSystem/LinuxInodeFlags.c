#ifdef __linux__

#include "LinuxInodeFlags.h"


#ifndef FS_IOC_GETFLAGS
#include <sys/ioctl.h>

// Copied from <linux/fs.h>
#define FS_IOC_GETFLAGS _IOR('f', 1, long)
#define FS_IOC_SETFLAGS _IOW('f', 2, long)
#endif


const unsigned long _FS_IOC_GETFLAGS = FS_IOC_GETFLAGS;
const unsigned long _FS_IOC_SETFLAGS = FS_IOC_SETFLAGS;

#endif 