#ifdef __linux__

#include "LinuxRenameat2.h"

#define _GNU_SOURCE

#include <fcntl.h>
#include <stdio.h>


const int _RENAME_NOREPLACE = RENAME_NOREPLACE;

int _renameat2(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, unsigned int flags) {
    return renameat2(olddirfd, oldpath, newdirfd, newpath, flags);
}

#endif // __linux__