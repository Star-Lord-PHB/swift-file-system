import PlatformCLib


enum MemoryAllocatorType {

    #if canImport(WinSDK)
    case globalAlloc, localAlloc
    #endif
    case swift, malloc

    func dealloc(pointer: UnsafeRawPointer) {
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



struct UnsafeOwnedAutoPointer<Pointee: ~Copyable>: ~Copyable {

    let unsafeRawPtr: UnsafePointer<Pointee>
    let allocator: MemoryAllocatorType

    var pointee: Pointee {
        _read { yield unsafeRawPtr.pointee }
    }

    init(owningPointer ptr: consuming UnsafePointer<Pointee>, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    init(_ ptr: consuming UnsafeOwnedMutableAutoPointer<Pointee>) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(ptr.take())
    }

    deinit {
        allocator.dealloc(pointer: unsafeRawPtr)
    }

    consuming func take() -> UnsafePointer<Pointee> {
        let ptr = unsafeRawPtr
        discard self
        return ptr
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

    @_lifetime(borrow self)
    func pointer<Member>(to member: KeyPath<Pointee, Member>) -> UnsafeUnownedPointer<Member> {
        return .init(unownedPointer: unsafeRawPtr.pointer(to: member)!)
    }

    @_lifetime(borrow self)
    func advance(by n: Int) -> UnsafeUnownedPointer<Pointee> {
        let advancedPtr = unsafeRawPtr.advanced(by: n)
        return .init(unownedPointer: advancedPtr)
    }

    consuming func unsafeMutableCast() -> UnsafeOwnedMutableAutoPointer<Pointee> {
        .init(mutating: self)
    }

    var unsafelyCastedMutableRawPtr: UnsafeMutablePointer<Pointee> {
        .init(mutating: unsafeRawPtr)
    }

    static func swiftAllocate(capacity: Int) -> UnsafeOwnedAutoPointer<Pointee> {
        let ptr = UnsafeMutablePointer<Pointee>.allocate(capacity: capacity)
        return .init(owningPointer: ptr, allocator: .swift)
    }

}



extension UnsafeOwnedAutoPointer {
    var pointee: Pointee {
        unsafeRawPtr.pointee
    }
}



struct UnsafeUnownedPointer<Pointee: ~Copyable>: ~Escapable {

    private(set) var unsafeRawPtr: UnsafePointer<Pointee>

    var pointee: Pointee {
        _read { yield unsafeRawPtr.pointee }
    }

    @_lifetime(immortal)
    init(unownedPointer ptr: UnsafePointer<Pointee>) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(copy ptr)
    init(_ ptr: UnsafeUnownedMutablePointer<Pointee>) {
        self.unsafeRawPtr = .init(ptr.unsafeRawPtr)
    }

    @_lifetime(copy self)
    func pointer<Member>(to member: KeyPath<Pointee, Member>) -> UnsafeUnownedPointer<Member> {
        .init(unownedPointer: unsafeRawPtr.pointer(to: member)!)
    }

    @_lifetime(copy self)
    func advance(by n: Int) -> UnsafeUnownedPointer<Pointee> {
        let advancedPtr = unsafeRawPtr.advanced(by: n)
        return .init(unownedPointer: advancedPtr)
    }

    @_lifetime(copy self)
    func unsafeMutableCast() -> UnsafeUnownedMutablePointer<Pointee> {
        .init(unownedMutating: unsafeRawPtr)
    }

    var unsafelyCastedMutableRawPtr: UnsafeMutablePointer<Pointee> {
        .init(mutating: unsafeRawPtr)
    }

    static func withPointer<R: ~Copyable, E: Error>(
        to value: borrowing Pointee, 
        _ body: (UnsafeUnownedPointer<Pointee>) throws(E) -> R
    ) throws(E) -> R {
        try withUnsafePointer(to: value) { (ptr) throws(E) in 
            let unownedPtr = UnsafeUnownedPointer(unownedPointer: ptr)
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
        unsafeRawPtr.pointee
    }
}



struct UnsafeOwnedMutableAutoPointer<Pointee: ~Copyable>: ~Copyable {

    let unsafeRawPtr: UnsafeMutablePointer<Pointee>
    let allocator: MemoryAllocatorType

    var pointee: Pointee {
        _read { yield unsafeRawPtr.pointee }
        nonmutating _modify { yield &unsafeRawPtr.pointee }
    }

    init(owningPointer ptr: consuming UnsafeMutablePointer<Pointee>, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    init(mutating ptr: consuming UnsafeOwnedAutoPointer<Pointee>) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(mutating: ptr.take())
    }

    deinit {
        allocator.dealloc(pointer: unsafeRawPtr)
    }

    consuming func take() -> UnsafeMutablePointer<Pointee> {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    consuming func deallocate() {
        let ptr = unsafeRawPtr
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    @_lifetime(borrow self)
    func pointer<Member>(to member: WritableKeyPath<Pointee, Member>) -> UnsafeUnownedMutablePointer<Member> {
        return .init(unownedPointer: unsafeRawPtr.pointer(to: member)!)
    }

    @_lifetime(borrow self)
    func advance(by n: Int) -> UnsafeUnownedMutablePointer<Pointee> {
        let advancedPtr = unsafeRawPtr.advanced(by: n)
        return .init(unownedPointer: advancedPtr)
    }

    @_lifetime(borrow self)
    func unownedView() -> UnsafeUnownedMutablePointer<Pointee> {
        return .init(unownedPointer: unsafeRawPtr)
    }

    static func swiftAllocate(capacity: Int) -> UnsafeOwnedMutableAutoPointer<Pointee> {
        let ptr = UnsafeMutablePointer<Pointee>.allocate(capacity: capacity)
        return .init(owningPointer: ptr, allocator: .swift)
    }

}



extension UnsafeOwnedMutableAutoPointer {
    var pointee: Pointee {
        get { unsafeRawPtr.pointee }
        set { unsafeRawPtr.pointee = newValue }
    }
}



struct UnsafeUnownedMutablePointer<Pointee: ~Copyable>: ~Escapable {

    private(set) var unsafeRawPtr: UnsafeMutablePointer<Pointee>

    var pointee: Pointee {
        _read { yield unsafeRawPtr.pointee }
        nonmutating _modify { yield &unsafeRawPtr.pointee }
    }

    @_lifetime(immortal)
    init(unownedPointer ptr: UnsafeMutablePointer<Pointee>) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(immortal)
    init(unownedMutating ptr: UnsafePointer<Pointee>) {
        self.unsafeRawPtr = .init(mutating: ptr)
    }

    @_lifetime(copy self)
    func pointer<Member>(to member: WritableKeyPath<Pointee, Member>) -> UnsafeUnownedMutablePointer<Member> {
        .init(unownedPointer: unsafeRawPtr.pointer(to: member)!)
    }

    @_lifetime(copy self)
    func immutableCast() -> UnsafeUnownedPointer<Pointee> {
        .init(self)
    }

    @_lifetime(copy self)
    func advance(by n: Int) -> UnsafeUnownedMutablePointer<Pointee> {
        let advancedPtr = unsafeRawPtr.advanced(by: n)
        return .init(unownedPointer: advancedPtr)
    }

    static func withPointer<R: ~Copyable, E: Error>(
        to value: inout Pointee, 
        _ body: (UnsafeUnownedMutablePointer<Pointee>) throws(E) -> R
    ) throws(E) -> R {
        try withUnsafeMutablePointer(to: &value) { (ptr) throws(E) in 
            return try body(.init(unownedPointer: ptr))
        }
    }

}



extension UnsafeUnownedMutablePointer {
    var pointee: Pointee {
        get { unsafeRawPtr.pointee }
        @_lifetime(copy self)
        set { unsafeRawPtr.pointee = newValue }
    }
}