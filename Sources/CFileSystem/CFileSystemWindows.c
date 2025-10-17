#ifdef _WIN32

#include "CFileSystemWindows.h"

DWORD makeLanguageIdentifier(USHORT primary, USHORT sub) {
    return MAKELANGID(primary, sub);
}

#endif