import PlatformCLib 



struct UnsafeOwnedAutoBufferPointer<Element: ~Copyable>: ~Copyable {
    
    let unsafeRawPtr: UnsafeBufferPointer<Element>
    let allocator: MemoryAllocatorType

    var count: Int { unsafeRawPtr.count }

    var baseAddress: UnsafeUnownedPointer<Element>? {
        guard let baseAddr = unsafeRawPtr.baseAddress else {
            return nil
        }
        return .init(unownedPointer: baseAddr)
    }

    init(owningBuffer ptr: consuming UnsafeBufferPointer<Element>, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    init(_ ptr: consuming UnsafeOwnedMutableAutoBufferPointer<Element>) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(ptr.take())
    }

    deinit {
        if let baseAddr = unsafeRawPtr.baseAddress {
            allocator.dealloc(pointer: baseAddr)
        }
    }

    subscript(index: Int) -> Element {
        _read { yield unsafeRawPtr[index] }
    }

    consuming func deallocate() {
        let ptr = unsafeRawPtr.baseAddress!
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    consuming func take() -> UnsafeBufferPointer<Element> {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    @_lifetime(borrow self)
    func unownedView() -> UnsafeUnownedBufferPointer<Element> {
        return .init(unownedBuffer: unsafeRawPtr)
    }

    consuming func unsafeMutableCast() -> UnsafeOwnedMutableAutoBufferPointer<Element> {
        .init(mutating: self)
    }

    var unsafelyCastedMutableRawPtr: UnsafeMutableBufferPointer<Element> {
        .init(mutating: unsafeRawPtr)
    }

}



extension UnsafeOwnedAutoBufferPointer {
    subscript(index: Int) -> Element {
        unsafeRawPtr[index]
    }
}



struct UnsafeUnownedBufferPointer<Element: ~Copyable>: ~Escapable {

    let unsafeRawPtr: UnsafeBufferPointer<Element>

    var count: Int { unsafeRawPtr.count }

    var baseAddress: UnsafeUnownedPointer<Element>? {
        @_lifetime(copy self)
        get {
            guard let baseAddr = unsafeRawPtr.baseAddress else {
                return nil
            }
            return .init(unownedPointer: baseAddr)
        }
    }

    @_lifetime(immortal)
    init(unownedBuffer ptr: UnsafeBufferPointer<Element>) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(copy ptr)
    init(_ ptr: UnsafeUnownedMutableBufferPointer<Element>) {
        self.unsafeRawPtr = .init(ptr.unsafeRawPtr)
    }

    subscript(index: Int) -> Element {
        _read { yield unsafeRawPtr[index] }
    }

    @_lifetime(copy self)
    func unsafeMutableCast() -> UnsafeUnownedMutableBufferPointer<Element> {
        return .init(unownedMutating: unsafeRawPtr)
    }

    var unsafelyCastedMutableRawPtr: UnsafeMutableBufferPointer<Element> {
        .init(mutating: unsafeRawPtr)
    }

}



extension UnsafeUnownedBufferPointer {
    subscript(index: Int) -> Element {
        unsafeRawPtr[index]
    }
}



struct UnsafeOwnedMutableAutoBufferPointer<Element: ~Copyable>: ~Copyable {

    let unsafeRawPtr: UnsafeMutableBufferPointer<Element>
    let allocator: MemoryAllocatorType

    var count: Int {
        return unsafeRawPtr.count
    }

    var baseAddress: UnsafeUnownedPointer<Element>? {
        guard let baseAddr = unsafeRawPtr.baseAddress else {
            return nil
        }
        return .init(unownedPointer: baseAddr)
    }

    init(owningBuffer ptr: consuming UnsafeMutableBufferPointer<Element>, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    init(mutating ptr: consuming UnsafeOwnedAutoBufferPointer<Element>) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(mutating: ptr.take())
    }

    deinit {
        if let baseAddr = unsafeRawPtr.baseAddress {
            allocator.dealloc(pointer: baseAddr)
        }
    }

    subscript(index: Int) -> Element {
        _read { yield unsafeRawPtr[index] }
        _modify { yield &unsafeRawPtr[index] }
    }

    consuming func deallocate() {
        let ptr = unsafeRawPtr.baseAddress!
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    consuming func take() -> UnsafeMutableBufferPointer<Element> {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    func unownedView() -> UnsafeUnownedMutableBufferPointer<Element> {
        return .init(unownedBuffer: unsafeRawPtr)
    }

}



extension UnsafeOwnedMutableAutoBufferPointer {
    subscript(index: Int) -> Element {
        get { unsafeRawPtr[index] }
        set { unsafeRawPtr[index] = newValue }
    }
}



struct UnsafeUnownedMutableBufferPointer<Element: ~Copyable>: ~Escapable {

    let unsafeRawPtr: UnsafeMutableBufferPointer<Element>

    var count: Int { unsafeRawPtr.count }

    var baseAddress: UnsafeUnownedMutablePointer<Element>? {
        @_lifetime(copy self)
        get {
            guard let baseAddr = unsafeRawPtr.baseAddress else {
                return nil
            }
            return .init(unownedPointer: baseAddr)
        }
    }

    @_lifetime(immortal)
    init(unownedBuffer ptr: UnsafeMutableBufferPointer<Element>) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(immortal)
    init(unownedMutating ptr: UnsafeBufferPointer<Element>) {
        self.unsafeRawPtr = .init(mutating: ptr)
    }

    subscript(index: Int) -> Element {
        _read { yield unsafeRawPtr[index] }
        nonmutating _modify { yield &unsafeRawPtr[index] }
    }

    @_lifetime(copy self)
    func immutableCast() -> UnsafeUnownedBufferPointer<Element> {
        .init(self)
    }

}