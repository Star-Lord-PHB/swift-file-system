#ifdef __linux__

#include <sys/types.h>

ssize_t copy_file_range(int fd_in, off_t *off_in, int fd_out, off_t *off_out, size_t size, unsigned int flags);

#endif 