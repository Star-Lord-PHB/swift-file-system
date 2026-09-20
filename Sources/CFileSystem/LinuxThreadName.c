#ifdef __linux__

#include "LinuxThreadName.h"

#include <string.h>
#include <errno.h>
#include <sys/prctl.h>


// pthread_setname_np is _GNU_SOURCE-gated in glibc. For the calling thread it is nothing but PR_SET_NAME, and
// prctl is declared unconditionally by glibc, musl and Bionic; the length check mirrors glibc, which reports
// ERANGE instead of letting the kernel truncate silently.
int _pthread_setname_current(const char *name) {

    if (strlen(name) > 15) {
        return ERANGE;
    }

    return prctl(PR_SET_NAME, name, 0, 0, 0) == 0 ? 0 : errno;

}

#endif // __linux__
