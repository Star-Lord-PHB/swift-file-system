#if canImport(WinSDK)
import WinSDK
#endif 


enum MemoryAllocatorType {

    #if canImport(WinSDK)
    case globalAlloc, localAlloc
    #endif
    case swift, malloc

    func dealloc(pointer: UnsafeMutableRawPointer) {
        switch self {
            #if canImport(WinSDK)
            case .globalAlloc:  GlobalFree(pointer)
            case .localAlloc:   LocalFree(pointer)
            #endif
            case .swift:        pointer.deallocate()
            case .malloc:       free(pointer)
        }
    }

}



struct UnsafeOwnedAutoPointer<Pointee: ~Copyable>: ~Copyable {

    private(set) var unsafeRawPtr: UnsafeMutablePointer<Pointee>
    let allocator: MemoryAllocatorType

    var pointee: Pointee {
        _read { yield unsafeRawPtr.pointee }
        nonmutating _modify { yield &unsafeRawPtr.pointee }
    }

    init(owningPointer ptr: consuming UnsafeMutablePointer<Pointee>, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    deinit {
        allocator.dealloc(pointer: unsafeRawPtr)
    }


    consuming func deallocate() {
        let ptr = unsafeRawPtr
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }


    @_lifetime(borrow self)
    func unownedView() -> UnsafeUnownedPointer<Pointee> {
        return .init(unownedPointer: unsafeRawPtr)
    }

}



extension UnsafeOwnedAutoPointer {

    var pointee: Pointee {
        get { unsafeRawPtr.pointee }
        nonmutating set { unsafeRawPtr.pointee = newValue }
    }

}



struct UnsafeUnownedPointer<Pointee: ~Copyable>: ~Escapable {

    private(set) var unsafeRawPtr: UnsafeMutablePointer<Pointee>

    var pointee: Pointee {
        _read { yield unsafeRawPtr.pointee }
        nonmutating _modify { yield &unsafeRawPtr.pointee }
    }

    @_lifetime(immortal)
    init(unownedPointer ptr: UnsafeMutablePointer<Pointee>) {
        self.unsafeRawPtr = ptr
    }


    static func withPointer<R: ~Copyable, E: Error>(
        to value: borrowing Pointee, 
        _ body: (UnsafeUnownedPointer<Pointee>) throws(E) -> R
    ) throws(E) -> R {
        try withUnsafePointer(to: value) { (ptr) throws(E) in 
            let unownedPtr = UnsafeUnownedPointer(unownedPointer: UnsafeMutablePointer(mutating: ptr))
            return try body(unownedPtr)
        }
    }


    static func withPointer<R: ~Copyable, E: Error>(
        to value: inout Pointee, 
        _ body: (UnsafeUnownedPointer<Pointee>) throws(E) -> R
    ) throws(E) -> R {
        try withUnsafeMutablePointer(to: &value) { (ptr) throws(E) in 
            let unownedPtr = UnsafeUnownedPointer(unownedPointer: ptr)
            return try body(unownedPtr)
        }
    }

}



extension UnsafeUnownedPointer {
    var pointee: Pointee {
        get { unsafeRawPtr.pointee }
        nonmutating set { unsafeRawPtr.pointee = newValue }
    }
}



struct UnsafeOwnedRawAutoPointer: ~Copyable {

    private(set) var unsafeRawPtr: UnsafeMutableRawPointer
    let allocator: MemoryAllocatorType

    init(owningPointer ptr: consuming UnsafeMutableRawPointer, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
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

    static func swiftAllocate(byteCount: Int, alignment: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: alignment)
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr, allocator: .swift)
    }

    static func globalAllocAllocate(byteCount: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = GlobalAlloc(UINT(GMEM_FIXED), SIZE_T(byteCount))
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr!, allocator: .globalAlloc)  
    }

    static func localAllocAllocate(byteCount: Int) -> UnsafeOwnedRawAutoPointer {
        let ptr = LocalAlloc(UINT(LMEM_FIXED), SIZE_T(byteCount))
        return UnsafeOwnedRawAutoPointer(owningPointer: ptr!, allocator: .localAlloc)  
    }

    @_lifetime(borrow self)
    func unownedView() -> UnsafeUnownedRawPointer {
        return .init(unownedPointer: unsafeRawPtr)
    }

}



struct UnsafeUnownedRawPointer: ~Escapable {

    private(set) var unsafeRawPtr: UnsafeMutableRawPointer

    @_lifetime(immortal)
    init(unownedPointer ptr: UnsafeMutableRawPointer) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(copy self)
    func assumingMemoryBound<Pointee>(to type: Pointee.Type) -> UnsafeUnownedPointer<Pointee> {
        let typedPtr = unsafeRawPtr.assumingMemoryBound(to: Pointee.self)
        return UnsafeUnownedPointer(unownedPointer: typedPtr)
    }

    @_lifetime(copy self)
    func bindMemory<Pointee>(to type: Pointee.Type, capacity: Int) -> UnsafeUnownedPointer<Pointee> {
        let typedPtr = unsafeRawPtr.bindMemory(to: Pointee.self, capacity: capacity)
        return UnsafeUnownedPointer(unownedPointer: typedPtr)
    }

}



struct UnsafeOwnedAutoResource: ~Copyable {

    private(set) var unsafeResourcePtr: UnsafeMutableRawPointer
    let freeingFunc: (UnsafeMutableRawPointer) -> Void

    private var free: Bool = false

    init(
        owningResource ptr: consuming UnsafeMutableRawPointer, 
        freeingFunc: @escaping (UnsafeMutableRawPointer) -> Void
    ) {
        self.unsafeResourcePtr = ptr
        self.freeingFunc = freeingFunc
    }

    deinit {
        if !free {
            freeingFunc(unsafeResourcePtr)
        }
    }

    consuming func deallocate() {
        freeingFunc(unsafeResourcePtr)
        free = true
    }

    @_lifetime(borrow self)
    func unownedView() -> UnsafeUnownedResource {
        return .init(unownedResource: unsafeResourcePtr)
    }

}



struct UnsafeUnownedResource: ~Escapable {

    private(set) var unsafeResourcePtr: UnsafeMutableRawPointer

    @_lifetime(immortal)
    init(unownedResource ptr: UnsafeMutableRawPointer) {
        self.unsafeResourcePtr = ptr
    }

}