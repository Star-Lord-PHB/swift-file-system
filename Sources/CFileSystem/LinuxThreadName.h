#ifdef __linux__

// pthread_setname_np is _GNU_SOURCE-guarded and not exposed through the Swift Glibc module.
int _pthread_setname_current(const char *name);

#endif // __linux__
