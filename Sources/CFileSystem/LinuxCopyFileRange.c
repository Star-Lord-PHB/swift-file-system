#ifdef __linux__

#include "LinuxCopyFileRange.h"

#include <unistd.h>
#include <sys/syscall.h>
#include <errno.h>


// A thin wrapper over the raw syscall rather than the libc function: every Linux libc (glibc 2.27+, musl,
// Bionic 34+) implements copy_file_range as exactly this syscall, while the raw form needs no libc-specific
// version check and also serves older glibc releases. Errors are reported through errno untouched; deciding
// which of them mean "hand over to another copy mechanism" is left to the caller.
ssize_t _copy_file_range(int fd_in, off_t *off_in, int fd_out, off_t *off_out, size_t size, unsigned int flags) {

#ifdef SYS_copy_file_range

    // The kernel takes 64-bit offsets (loff_t); going through temporaries keeps the off_t interface correct on
    // 32-bit targets as well.
    long long in_offset = off_in ? *off_in : 0;
    long long out_offset = off_out ? *off_out : 0;

    long copied = syscall(
        SYS_copy_file_range,
        fd_in, off_in ? &in_offset : NULL, fd_out, off_out ? &out_offset : NULL, size, flags
    );

    if (copied >= 0) {
        if (off_in) { *off_in = (off_t)in_offset; }
        if (off_out) { *off_out = (off_t)out_offset; }
    }

    return copied;

#else

    (void)fd_in; (void)off_in; (void)fd_out; (void)off_out; (void)size; (void)flags;
    errno = ENOSYS;
    return -1;

#endif

}

#endif // __linux__
