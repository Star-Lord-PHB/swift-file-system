#ifdef __linux__

#include "LinuxRenameat2.h"

#include <unistd.h>
#include <sys/syscall.h>
#include <errno.h>


// The raw syscall (Linux 3.15) rather than the libc function: glibc gates renameat2 behind _GNU_SOURCE, musl has
// no wrapper for it at all and Bionic requires API 30. Errors are reported through errno as the syscall does.
int _renameat2(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, unsigned int flags) {

#ifdef SYS_renameat2

    return (int)syscall(SYS_renameat2, olddirfd, oldpath, newdirfd, newpath, flags);

#else

    (void)olddirfd; (void)oldpath; (void)newdirfd; (void)newpath; (void)flags;
    errno = ENOSYS;
    return -1;

#endif

}

#endif // __linux__
