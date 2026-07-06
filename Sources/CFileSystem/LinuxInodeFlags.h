#ifdef __linux__

#include <linux/fs.h>

extern const unsigned long _FS_IOC_GETFLAGS;
extern const unsigned long _FS_IOC_SETFLAGS;

#ifndef FS_SECRM_FL
#define	FS_SECRM_FL 0x00000001
#endif

#ifndef FS_UNRM_FL
#define	FS_UNRM_FL 0x00000002
#endif

#ifndef FS_COMPR_FL
#define	FS_COMPR_FL 0x00000004
#endif

#ifndef FS_SYNC_FL
#define FS_SYNC_FL 0x00000008
#endif

#ifndef FS_IMMUTABLE_FL
#define FS_IMMUTABLE_FL 0x00000010
#endif

#ifndef FS_APPEND_FL
#define FS_APPEND_FL 0x00000020
#endif

#ifndef FS_NODUMP_FL
#define FS_NODUMP_FL 0x00000040
#endif

#ifndef FS_NOATIME_FL
#define FS_NOATIME_FL 0x00000080
#endif

#ifndef FS_DIRTY_FL
#define FS_DIRTY_FL 0x00000100
#endif

#ifndef FS_COMPRBLK_FL
#define FS_COMPRBLK_FL 0x00000200
#endif

#ifndef FS_NOCOMP_FL
#define FS_NOCOMP_FL 0x00000400
#endif

#ifndef FS_ENCRYPT_FL
#define FS_ENCRYPT_FL 0x00000800
#endif

#ifndef FS_BTREE_FL
#define FS_BTREE_FL 0x00001000
#endif

#ifndef FS_INDEX_FL
#define FS_INDEX_FL 0x00001000
#endif

#ifndef FS_IMAGIC_FL
#define FS_IMAGIC_FL 0x00002000
#endif

#ifndef FS_JOURNAL_DATA_FL
#define FS_JOURNAL_DATA_FL 0x00004000
#endif

#ifndef FS_NOTAIL_FL
#define FS_NOTAIL_FL 0x00008000
#endif

#ifndef FS_DIRSYNC_FL
#define FS_DIRSYNC_FL 0x00010000
#endif

#ifndef FS_TOPDIR_FL
#define FS_TOPDIR_FL 0x00020000
#endif

#ifndef FS_HUGE_FILE_FL
#define FS_HUGE_FILE_FL 0x00040000
#endif

#ifndef FS_EXTENT_FL
#define FS_EXTENT_FL 0x00080000
#endif

#ifndef FS_VERITY_FL
#define FS_VERITY_FL 0x00100000
#endif

#ifndef FS_EA_INODE_FL
#define FS_EA_INODE_FL 0x00200000
#endif

#ifndef FS_EOFBLOCKS_FL
#define FS_EOFBLOCKS_FL 0x00400000
#endif

#ifndef FS_NOCOW_FL
#define FS_NOCOW_FL 0x00800000
#endif

#ifndef FS_DAX_FL
#define FS_DAX_FL 0x02000000
#endif

#ifndef FS_INLINE_DATA_FL
#define FS_INLINE_DATA_FL 0x10000000
#endif

#ifndef FS_PROJINHERIT_FL
#define FS_PROJINHERIT_FL 0x20000000
#endif

#ifndef FS_CASEFOLD_FL
#define FS_CASEFOLD_FL 0x40000000
#endif

#ifndef FS_RESERVED_FL
#define FS_RESERVED_FL 0x80000000
#endif

#ifndef FS_FL_USER_VISIBLE
#define FS_FL_USER_VISIBLE 0x0003DFFF
#endif 

#ifndef FS_FL_USER_MODIFIABLE
#define FS_FL_USER_MODIFIABLE 0x000380FF
#endif

#endif 