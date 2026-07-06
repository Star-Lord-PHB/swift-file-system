#ifdef __linux__

int _renameat2(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, unsigned int flags);

#endif // __linux__