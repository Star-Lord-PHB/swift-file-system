#ifdef __linux__

#include "LinuxCopyFileRange.h"

#include <unistd.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <errno.h>


ssize_t copy_file_range(int fd_in, off_t *off_in, int fd_out, off_t *off_out, size_t size, unsigned int flags) {

    #if defined(__GLIBC__) && __GLIBC_PREREQ(2, 27)
    // TODO: testing out the syscall directly, change it back to the libc function if this works well
    loff_t _off_in = off_in ? *off_in : 0;
    loff_t _off_out = off_out ? *off_out : 0;
    ssize_t copiedCount = syscall(SYS_copy_file_range, fd_in, off_in ? &_off_in : NULL, fd_out, off_out ? &_off_out : NULL, size, flags);
    if (copiedCount >= 0) {
        if (off_in) {
            *off_in = _off_in;
        }
        if (off_out) {
            *off_out = _off_out; 
        }
        return copiedCount;
    } else if (errno == ENOSYS || errno == EOPNOTSUPP || errno == EXDEV || errno == EINVAL) {
        errno = ENOSYS;
        return -1;
    } else {
        return -1;
    }
    // return copy_file_range(fd_in, off_in, fd_out, off_out, size, flags);
    #elif defined(__NR_copy_file_range)

    
        
    #else 

    errno = ENOSYS;

    #endif

}

#endif 