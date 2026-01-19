import PlatformCLib


package enum MemoryAllocatorType {

    #if canImport(WinSDK)
    case globalAlloc, localAlloc
    #endif
    case swift, malloc

    package func dealloc(pointer: UnsafeRawPointer) {
        switch self {
            #if canImport(WinSDK)
            case .globalAlloc:  GlobalFree(UnsafeMutableRawPointer(mutating: pointer))
            case .localAlloc:   LocalFree(UnsafeMutableRawPointer(mutating: pointer))
            #endif
            case .swift:        UnsafeMutableRawPointer(mutating: pointer).deallocate()
            case .malloc:       free(UnsafeMutableRawPointer(mutating: pointer))
        }
    }

}



package struct UnsafeOwnedAutoPointer<Pointee: ~Copyable>: ~Copyable {

    package let unsafeRawPtr: UnsafePointer<Pointee>
    package let allocator: MemoryAllocatorType

    package var pointee: Pointee {
        _read { yield unsafeRawPtr.pointee }
    }

    package init(owningPointer ptr: consuming UnsafePointer<Pointee>, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    package init(_ ptr: consuming UnsafeOwnedMutableAutoPointer<Pointee>) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(ptr.take())
    }

    deinit {
        allocator.dealloc(pointer: unsafeRawPtr)
    }

    package consuming func take() -> UnsafePointer<Pointee> {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    package consuming func deallocate() {
        let ptr = unsafeRawPtr
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    @_lifetime(borrow self)
    package func unownedView() -> UnsafeUnownedPointer<Pointee> {
        return .init(unownedPointer: unsafeRawPtr)
    }

    @_lifetime(borrow self)
    package func pointer<Member>(to member: KeyPath<Pointee, Member>) -> UnsafeUnownedPointer<Member> {
        return .init(unownedPointer: unsafeRawPtr.pointer(to: member)!)
    }

    @_lifetime(borrow self)
    package func advance(by n: Int) -> UnsafeUnownedPointer<Pointee> {
        let advancedPtr = unsafeRawPtr.advanced(by: n)
        return .init(unownedPointer: advancedPtr)
    }

    package consuming func unsafeMutableCast() -> UnsafeOwnedMutableAutoPointer<Pointee> {
        .init(mutating: self)
    }

    package var unsafelyCastedMutableRawPtr: UnsafeMutablePointer<Pointee> {
        .init(mutating: unsafeRawPtr)
    }

    package static func swiftAllocate(capacity: Int) -> UnsafeOwnedAutoPointer<Pointee> {
        let ptr = UnsafeMutablePointer<Pointee>.allocate(capacity: capacity)
        return .init(owningPointer: ptr, allocator: .swift)
    }

}



extension UnsafeOwnedAutoPointer {
    package var pointee: Pointee {
        unsafeRawPtr.pointee
    }
}



package struct UnsafeUnownedPointer<Pointee: ~Copyable>: ~Escapable {

    package private(set) var unsafeRawPtr: UnsafePointer<Pointee>

    package var pointee: Pointee {
        _read { yield unsafeRawPtr.pointee }
    }

    @_lifetime(immortal)
    package init(unownedPointer ptr: UnsafePointer<Pointee>) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(copy ptr)
    package init(_ ptr: UnsafeUnownedMutablePointer<Pointee>) {
        self.unsafeRawPtr = .init(ptr.unsafeRawPtr)
    }

    @_lifetime(copy self)
    package func pointer<Member>(to member: KeyPath<Pointee, Member>) -> UnsafeUnownedPointer<Member> {
        .init(unownedPointer: unsafeRawPtr.pointer(to: member)!)
    }

    @_lifetime(copy self)
    package func advance(by n: Int) -> UnsafeUnownedPointer<Pointee> {
        let advancedPtr = unsafeRawPtr.advanced(by: n)
        return .init(unownedPointer: advancedPtr)
    }

    @_lifetime(copy self)
    package func unsafeMutableCast() -> UnsafeUnownedMutablePointer<Pointee> {
        .init(unownedMutating: unsafeRawPtr)
    }

    package var unsafelyCastedMutableRawPtr: UnsafeMutablePointer<Pointee> {
        .init(mutating: unsafeRawPtr)
    }

    package static func withPointer<R: ~Copyable, E: Error>(
        to value: borrowing Pointee, 
        _ body: (UnsafeUnownedPointer<Pointee>) throws(E) -> R
    ) throws(E) -> R {
        try withUnsafePointer(to: value) { (ptr) throws(E) in 
            let unownedPtr = UnsafeUnownedPointer(unownedPointer: ptr)
            return try body(unownedPtr)
        }
    }

    package static func withPointer<R: ~Copyable, E: Error>(
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
    package var pointee: Pointee {
        unsafeRawPtr.pointee
    }
}



package struct UnsafeOwnedMutableAutoPointer<Pointee: ~Copyable>: ~Copyable {

    package let unsafeRawPtr: UnsafeMutablePointer<Pointee>
    package let allocator: MemoryAllocatorType

    package var pointee: Pointee {
        _read { yield unsafeRawPtr.pointee }
        nonmutating _modify { yield &unsafeRawPtr.pointee }
    }

    package init(owningPointer ptr: consuming UnsafeMutablePointer<Pointee>, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    package init(mutating ptr: consuming UnsafeOwnedAutoPointer<Pointee>) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(mutating: ptr.take())
    }

    deinit {
        allocator.dealloc(pointer: unsafeRawPtr)
    }

    package consuming func take() -> UnsafeMutablePointer<Pointee> {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    package consuming func deallocate() {
        let ptr = unsafeRawPtr
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    @_lifetime(borrow self)
    package func pointer<Member>(to member: WritableKeyPath<Pointee, Member>) -> UnsafeUnownedMutablePointer<Member> {
        return .init(unownedPointer: unsafeRawPtr.pointer(to: member)!)
    }

    @_lifetime(borrow self)
    package func advance(by n: Int) -> UnsafeUnownedMutablePointer<Pointee> {
        let advancedPtr = unsafeRawPtr.advanced(by: n)
        return .init(unownedPointer: advancedPtr)
    }

    @_lifetime(borrow self)
    package func unownedView() -> UnsafeUnownedMutablePointer<Pointee> {
        return .init(unownedPointer: unsafeRawPtr)
    }

    package static func swiftAllocate(capacity: Int) -> UnsafeOwnedMutableAutoPointer<Pointee> {
        let ptr = UnsafeMutablePointer<Pointee>.allocate(capacity: capacity)
        return .init(owningPointer: ptr, allocator: .swift)
    }

}



extension UnsafeOwnedMutableAutoPointer {
    package var pointee: Pointee {
        get { unsafeRawPtr.pointee }
        nonmutating set { unsafeRawPtr.pointee = newValue }
    }
}



package struct UnsafeUnownedMutablePointer<Pointee: ~Copyable>: ~Escapable {

    package private(set) var unsafeRawPtr: UnsafeMutablePointer<Pointee>

    package var pointee: Pointee {
        _read { yield unsafeRawPtr.pointee }
        nonmutating _modify { yield &unsafeRawPtr.pointee }
    }

    @_lifetime(immortal)
    package init(unownedPointer ptr: UnsafeMutablePointer<Pointee>) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(immortal)
    package init(unownedMutating ptr: UnsafePointer<Pointee>) {
        self.unsafeRawPtr = .init(mutating: ptr)
    }

    @_lifetime(copy self)
    package func pointer<Member>(to member: WritableKeyPath<Pointee, Member>) -> UnsafeUnownedMutablePointer<Member> {
        .init(unownedPointer: unsafeRawPtr.pointer(to: member)!)
    }

    @_lifetime(copy self)
    package func immutableCast() -> UnsafeUnownedPointer<Pointee> {
        .init(self)
    }

    @_lifetime(copy self)
    package func advance(by n: Int) -> UnsafeUnownedMutablePointer<Pointee> {
        let advancedPtr = unsafeRawPtr.advanced(by: n)
        return .init(unownedPointer: advancedPtr)
    }

    package static func withPointer<R: ~Copyable, E: Error>(
        to value: inout Pointee, 
        _ body: (UnsafeUnownedMutablePointer<Pointee>) throws(E) -> R
    ) throws(E) -> R {
        try withUnsafeMutablePointer(to: &value) { (ptr) throws(E) in 
            return try body(.init(unownedPointer: ptr))
        }
    }

}



extension UnsafeUnownedMutablePointer {
    package var pointee: Pointee {
        get { unsafeRawPtr.pointee }
        @_lifetime(copy self)
        nonmutating set { unsafeRawPtr.pointee = newValue }
    }
}