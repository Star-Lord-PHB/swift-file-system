#include <stdbool.h>
#include <stdint.h>


/// Storage for a one-shot atomic boolean flag.
///
/// Swift cannot express C atomics itself, and the Synchronization module's `Atomic` carries
/// an OS availability constraint on Apple platforms, so the flag lives here as plain storage
/// operated on exclusively through clang's `__atomic` builtins (available on every supported
/// platform: SwiftPM compiles C targets with clang everywhere, including Windows). Never
/// read or write `rawValue` directly, and never copy the struct while it is shared between
/// threads — all access must go through the functions below, against one stable address.
typedef struct {
    uint8_t rawValue;
} CFSAtomicFlag;


static inline void cfsAtomicFlagInitialize(CFSAtomicFlag *_Nonnull flag) {
    __atomic_store_n(&flag->rawValue, 0, __ATOMIC_RELAXED);
}


static inline void cfsAtomicFlagSet(CFSAtomicFlag *_Nonnull flag) {
    __atomic_store_n(&flag->rawValue, 1, __ATOMIC_RELEASE);
}


static inline bool cfsAtomicFlagIsSet(CFSAtomicFlag *_Nonnull flag) {
    return __atomic_load_n(&flag->rawValue, __ATOMIC_ACQUIRE) != 0;
}
