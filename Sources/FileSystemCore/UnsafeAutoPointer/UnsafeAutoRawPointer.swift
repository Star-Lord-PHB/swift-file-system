import PlatformCLib



package struct UnsafeOwnedRawAutoPointer: ~Copyable {

    package let unsafeRawPtr: UnsafeRawPointer
    package let allocator: MemoryAllocatorType

    package init(owningPointer ptr: consuming UnsafeRawPointer, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    package init(_ ptr: consuming UnsafeOwnedMutableRawAutoPointer) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(ptr.take())
    }

    deinit {
        allocator.dealloc(pointer: unsafeRawPtr)
    }

    package consuming func assumingMemoryBound<Pointee>(to type: Pointee.Type) -> UnsafeOwnedAutoPointer<Pointee> {
        let typedPtr = unsafeRawPtr.assumingMemoryBound(to: Pointee.self)
        let allocator = self.allocator
        discard self
        return UnsafeOwnedAutoPointer(owningPointer: typedPtr, allocator: allocator)
    }

    package consuming func bindMemory<Pointee>(to type: Pointee.Type, capacity: Int) -> UnsafeOwnedAutoPointer<Pointee> {
        let typedPtr = unsafeRawPtr.bindMemory(to: Pointee.self, capacity: capacity)
        let allocator = self.allocator
        discard self
        return UnsafeOwnedAutoPointer(owningPointer: typedPtr, allocator: allocator)
    }

    package consuming func deallocate() {
        let ptr = unsafeRawPtr
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    package consuming func take() -> UnsafeRawPointer {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    package static func swiftAllocate(byteCount: Int, alignment: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: alignment)
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr, allocator: .swift)
    }

    package static func mallocAllocate(byteCount: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = malloc(byteCount)!
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr, allocator: .malloc)
    }

    #if canImport(WinSDK)
    package static func globalAllocAllocate(byteCount: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = GlobalAlloc(UINT(GMEM_FIXED), SIZE_T(byteCount))
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr!, allocator: .globalAlloc)  
    }

    package static func localAllocAllocate(byteCount: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = LocalAlloc(UINT(LMEM_FIXED), SIZE_T(byteCount))
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr!, allocator: .localAlloc)  
    }
    #endif

    @_lifetime(borrow self)
    package func unownedView() -> UnsafeUnownedRawPointer {
        return .init(unownedPointer: unsafeRawPtr)
    }

    package consuming func unsafeMutableCast() -> UnsafeOwnedMutableRawAutoPointer {
        .init(mutating: self)
    }

    package var unsafelyCastedMutableRawPtr: UnsafeMutableRawPointer {
        .init(mutating: unsafeRawPtr)
    }

}



package struct UnsafeUnownedRawPointer: ~Escapable {

    package let unsafeRawPtr: UnsafeRawPointer

    @_lifetime(immortal)
    package init(unownedPointer ptr: UnsafeRawPointer) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(copy ptr)
    package init(_ ptr: UnsafeUnownedMutableRawPointer) {
        self.unsafeRawPtr = .init(ptr.unsafeRawPtr)
    }

    @_lifetime(copy self)
    package func assumingMemoryBound<Pointee>(to type: Pointee.Type) -> UnsafeUnownedPointer<Pointee> {
        let typedPtr = unsafeRawPtr.assumingMemoryBound(to: Pointee.self)
        return .init(unownedPointer: typedPtr)
    }

    @_lifetime(copy self)
    package func bindMemory<Pointee>(to type: Pointee.Type, capacity: Int) -> UnsafeUnownedPointer<Pointee> {
        let typedPtr = unsafeRawPtr.bindMemory(to: Pointee.self, capacity: capacity)
        return .init(unownedPointer: typedPtr)
    }

    @_lifetime(copy self)
    package func unsafeMutableCast() -> UnsafeUnownedMutableRawPointer {
        .init(unownedMutating: unsafeRawPtr)
    }

    package var unsafelyCastedMutableRawPtr: UnsafeMutableRawPointer {
        .init(mutating: unsafeRawPtr)
    }

}



package struct UnsafeOwnedMutableRawAutoPointer: ~Copyable {

    package let unsafeRawPtr: UnsafeMutableRawPointer
    package let allocator: MemoryAllocatorType

    package init(owningPointer ptr: consuming UnsafeMutableRawPointer, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    package init(mutating ptr: consuming UnsafeOwnedRawAutoPointer) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(mutating: ptr.take())
    }

    deinit {
        allocator.dealloc(pointer: unsafeRawPtr)
    }

    package consuming func assumingMemoryBound<Pointee>(to type: Pointee.Type) -> UnsafeOwnedMutableAutoPointer<Pointee> {
        let typedPtr = unsafeRawPtr.assumingMemoryBound(to: Pointee.self)
        let allocator = self.allocator
        discard self
        return .init(owningPointer: typedPtr, allocator: allocator)
    }

    package consuming func bindMemory<Pointee>(to type: Pointee.Type, capacity: Int) -> UnsafeOwnedMutableAutoPointer<Pointee> {
        let typedPtr = unsafeRawPtr.bindMemory(to: Pointee.self, capacity: capacity)
        let allocator = self.allocator
        discard self
        return .init(owningPointer: typedPtr, allocator: allocator)
    }

    package consuming func deallocate() {
        let ptr = unsafeRawPtr
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    package consuming func take() -> UnsafeMutableRawPointer {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    package static func swiftAllocate(byteCount: Int, alignment: Int) -> UnsafeOwnedMutableRawAutoPointer {
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: alignment)
        return .init(owningPointer: ptr, allocator: .swift)
    }

    package static func mallocAllocate(byteCount: Int) -> UnsafeOwnedMutableRawAutoPointer {
        let ptr = malloc(byteCount)!
        return .init(owningPointer: ptr, allocator: .malloc)
    }

    #if canImport(WinSDK)
    package static func globalAllocAllocate(byteCount: Int) -> UnsafeOwnedMutableRawAutoPointer {
        let ptr = GlobalAlloc(UINT(GMEM_FIXED), SIZE_T(byteCount))
        return .init(owningPointer: ptr!, allocator: .globalAlloc)  
    }

    package static func localAllocAllocate(byteCount: Int) -> UnsafeOwnedMutableRawAutoPointer {
        let ptr = LocalAlloc(UINT(LMEM_FIXED), SIZE_T(byteCount))
        return .init(owningPointer: ptr!, allocator: .localAlloc)  
    }
    #endif

    @_lifetime(borrow self)
    package func unownedView() -> UnsafeUnownedMutableRawPointer {
        return .init(unownedPointer: unsafeRawPtr)
    }

}



package struct UnsafeUnownedMutableRawPointer: ~Escapable {

    package let unsafeRawPtr: UnsafeMutableRawPointer

    @_lifetime(immortal)
    package init(unownedPointer ptr: UnsafeMutableRawPointer) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(immortal)
    package init(unownedMutating ptr: UnsafeRawPointer) {
        self.unsafeRawPtr = .init(mutating: ptr)
    }

    @_lifetime(copy self)
    package func immutableCast() -> UnsafeUnownedRawPointer {
        .init(self)
    }

    @_lifetime(copy self)
    package func assumingMemoryBound<Pointee>(to type: Pointee.Type) -> UnsafeUnownedMutablePointer<Pointee> {
        let typedPtr = unsafeRawPtr.assumingMemoryBound(to: Pointee.self)
        return .init(unownedPointer: typedPtr)
    }

    @_lifetime(copy self)
    package func bindMemory<Pointee>(to type: Pointee.Type, capacity: Int) -> UnsafeUnownedMutablePointer<Pointee> {
        let typedPtr = unsafeRawPtr.bindMemory(to: Pointee.self, capacity: capacity)
        return .init(unownedPointer: typedPtr)
    }

}