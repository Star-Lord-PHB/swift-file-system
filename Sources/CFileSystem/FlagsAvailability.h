#include <fcntl.h>


#if defined(O_PATH) || defined(O_SYMLINK) || defined(_WIN32)
#define _SUPPORT_SYMLINK_DESCRIPTOR 1
#else
#define _SUPPORT_SYMLINK_DESCRIPTOR 0
#endif