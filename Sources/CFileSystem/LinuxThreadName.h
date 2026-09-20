#ifdef __linux__

// Names the calling thread, like pthread_setname_np(pthread_self(), name), and returns 0 or an error number the
// same way: ERANGE when the name is longer than the 15 characters the kernel keeps.
int _pthread_setname_current(const char *name);

#endif // __linux__
