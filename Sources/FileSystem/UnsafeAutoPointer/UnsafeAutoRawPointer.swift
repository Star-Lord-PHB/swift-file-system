import PlatformCLib



struct UnsafeOwnedRawAutoPointer: ~Copyable {

    let unsafeRawPtr: UnsafeRawPointer
    let allocator: MemoryAllocatorType

    init(owningPointer ptr: consuming UnsafeRawPointer, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    init(_ ptr: consuming UnsafeOwnedMutableRawAutoPointer) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(ptr.take())
    }

    deinit {
        allocator.dealloc(pointer: unsafeRawPtr)
    }

    consuming func assumingMemoryBound<Pointee>(to type: Pointee.Type) -> UnsafeOwnedAutoPointer<Pointee> {
        let typedPtr = unsafeRawPtr.assumingMemoryBound(to: Pointee.self)
        let allocator = self.allocator
        discard self
        return UnsafeOwnedAutoPointer(owningPointer: typedPtr, allocator: allocator)
    }

    consuming func bindMemory<Pointee>(to type: Pointee.Type, capacity: Int) -> UnsafeOwnedAutoPointer<Pointee> {
        let typedPtr = unsafeRawPtr.bindMemory(to: Pointee.self, capacity: capacity)
        let allocator = self.allocator
        discard self
        return UnsafeOwnedAutoPointer(owningPointer: typedPtr, allocator: allocator)
    }

    consuming func deallocate() {
        let ptr = unsafeRawPtr
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    consuming func take() -> UnsafeRawPointer {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    static func swiftAllocate(byteCount: Int, alignment: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: alignment)
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr, allocator: .swift)
    }

    static func mallocAllocate(byteCount: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = malloc(byteCount)!
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr, allocator: .malloc)
    }

    #if canImport(WinSDK)
    static func globalAllocAllocate(byteCount: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = GlobalAlloc(UINT(GMEM_FIXED), SIZE_T(byteCount))
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr!, allocator: .globalAlloc)  
    }

    static func localAllocAllocate(byteCount: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = LocalAlloc(UINT(LMEM_FIXED), SIZE_T(byteCount))
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr!, allocator: .localAlloc)  
    }
    #endif

    @_lifetime(borrow self)
    func unownedView() -> UnsafeUnownedRawPointer {
        return .init(unownedPointer: unsafeRawPtr)
    }

    consuming func unsafeMutableCast() -> UnsafeOwnedMutableRawAutoPointer {
        .init(mutating: self)
    }

    var unsafelyCastedMutableRawPtr: UnsafeMutableRawPointer {
        .init(mutating: unsafeRawPtr)
    }

}



struct UnsafeUnownedRawPointer: ~Escapable {

    let unsafeRawPtr: UnsafeRawPointer

    @_lifetime(immortal)
    init(unownedPointer ptr: UnsafeRawPointer) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(copy ptr)
    init(_ ptr: UnsafeUnownedMutableRawPointer) {
        self.unsafeRawPtr = .init(ptr.unsafeRawPtr)
    }

    @_lifetime(copy self)
    func assumingMemoryBound<Pointee>(to type: Pointee.Type) -> UnsafeUnownedPointer<Pointee> {
        let typedPtr = unsafeRawPtr.assumingMemoryBound(to: Pointee.self)
        return .init(unownedPointer: typedPtr)
    }

    @_lifetime(copy self)
    func bindMemory<Pointee>(to type: Pointee.Type, capacity: Int) -> UnsafeUnownedPointer<Pointee> {
        let typedPtr = unsafeRawPtr.bindMemory(to: Pointee.self, capacity: capacity)
        return .init(unownedPointer: typedPtr)
    }

    @_lifetime(copy self)
    func unsafeMutableCast() -> UnsafeUnownedMutableRawPointer {
        .init(unownedMutating: unsafeRawPtr)
    }

    var unsafelyCastedMutableRawPtr: UnsafeMutableRawPointer {
        .init(mutating: unsafeRawPtr)
    }

}



struct UnsafeOwnedMutableRawAutoPointer: ~Copyable {

    let unsafeRawPtr: UnsafeMutableRawPointer
    let allocator: MemoryAllocatorType

    init(owningPointer ptr: consuming UnsafeMutableRawPointer, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    init(mutating ptr: consuming UnsafeOwnedRawAutoPointer) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(mutating: ptr.take())
    }

    deinit {
        allocator.dealloc(pointer: unsafeRawPtr)
    }

    consuming func assumingMemoryBound<Pointee>(to type: Pointee.Type) -> UnsafeOwnedMutableAutoPointer<Pointee> {
        let typedPtr = unsafeRawPtr.assumingMemoryBound(to: Pointee.self)
        let allocator = self.allocator
        discard self
        return .init(owningPointer: typedPtr, allocator: allocator)
    }

    consuming func bindMemory<Pointee>(to type: Pointee.Type, capacity: Int) -> UnsafeOwnedMutableAutoPointer<Pointee> {
        let typedPtr = unsafeRawPtr.bindMemory(to: Pointee.self, capacity: capacity)
        let allocator = self.allocator
        discard self
        return .init(owningPointer: typedPtr, allocator: allocator)
    }

    consuming func deallocate() {
        let ptr = unsafeRawPtr
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    consuming func take() -> UnsafeMutableRawPointer {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    static func swiftAllocate(byteCount: Int, alignment: Int) -> UnsafeOwnedMutableRawAutoPointer {
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: alignment)
        return .init(owningPointer: ptr, allocator: .swift)
    }

    static func mallocAllocate(byteCount: Int) -> UnsafeOwnedMutableRawAutoPointer {
        let ptr = malloc(byteCount)!
        return .init(owningPointer: ptr, allocator: .malloc)
    }

    #if canImport(WinSDK)
    static func globalAllocAllocate(byteCount: Int) -> UnsafeOwnedMutableRawAutoPointer {
        let ptr = GlobalAlloc(UINT(GMEM_FIXED), SIZE_T(byteCount))
        return .init(owningPointer: ptr!, allocator: .globalAlloc)  
    }

    static func localAllocAllocate(byteCount: Int) -> UnsafeOwnedMutableRawAutoPointer {
        let ptr = LocalAlloc(UINT(LMEM_FIXED), SIZE_T(byteCount))
        return .init(owningPointer: ptr!, allocator: .localAlloc)  
    }
    #endif

    @_lifetime(borrow self)
    func unownedView() -> UnsafeUnownedMutableRawPointer {
        return .init(unownedPointer: unsafeRawPtr)
    }

}



struct UnsafeUnownedMutableRawPointer: ~Escapable {

    let unsafeRawPtr: UnsafeMutableRawPointer

    @_lifetime(immortal)
    init(unownedPointer ptr: UnsafeMutableRawPointer) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(immortal)
    init(unownedMutating ptr: UnsafeRawPointer) {
        self.unsafeRawPtr = .init(mutating: ptr)
    }

    @_lifetime(copy self)
    func immutableCast() -> UnsafeUnownedRawPointer {
        .init(self)
    }

    @_lifetime(copy self)
    func assumingMemoryBound<Pointee>(to type: Pointee.Type) -> UnsafeUnownedMutablePointer<Pointee> {
        let typedPtr = unsafeRawPtr.assumingMemoryBound(to: Pointee.self)
        return .init(unownedPointer: typedPtr)
    }

    @_lifetime(copy self)
    func bindMemory<Pointee>(to type: Pointee.Type, capacity: Int) -> UnsafeUnownedMutablePointer<Pointee> {
        let typedPtr = unsafeRawPtr.bindMemory(to: Pointee.self, capacity: capacity)
        return .init(unownedPointer: typedPtr)
    }

}