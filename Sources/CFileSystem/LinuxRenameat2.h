#ifdef __linux__

#if __has_include(<linux/fs.h>)
#include <linux/fs.h>
#endif

// Copied from <linux/fs.h>
#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1 << 0)
#endif

int _renameat2(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, unsigned int flags);

#endif // __linux__
