#ifdef __linux__

#include <linux/fs.h>

const unsigned long _FS_IOC_GETFLAGS = FS_IOC_GETFLAGS;
const unsigned long _FS_IOC_SETFLAGS = FS_IOC_SETFLAGS;

#endif