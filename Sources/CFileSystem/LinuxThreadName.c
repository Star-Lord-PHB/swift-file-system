#ifdef __linux__

#include "LinuxThreadName.h"

#define _GNU_SOURCE

#include <pthread.h>

int _pthread_setname_current(const char *name) {
    return pthread_setname_np(pthread_self(), name);
}

#endif // __linux__
