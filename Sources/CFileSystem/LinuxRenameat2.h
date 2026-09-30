#ifdef __linux__

#if __has_include(<linux/fs.h>)
#include <linux/fs.h>
#endif

// Copied from <linux/fs.h>
#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1 << 0)
#endif

// Bionic's <stdio.h> also defines RENAME_NOREPLACE, spelled differently from <linux/fs.h>, so Swift sees the
// macro as ambiguous on Android; PlatformCLib wraps this constant under the macro's name instead.
extern const unsigned int _RENAME_NOREPLACE;

int _renameat2(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, unsigned int flags);

#endif // __linux__
