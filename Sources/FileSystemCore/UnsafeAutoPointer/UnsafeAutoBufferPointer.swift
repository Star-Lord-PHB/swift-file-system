import PlatformCLib 



package struct UnsafeOwnedAutoBufferPointer<Element: ~Copyable>: ~Copyable {
    
    package let unsafeRawPtr: UnsafeBufferPointer<Element>
    package let allocator: MemoryAllocatorType

    package var count: Int { unsafeRawPtr.count }

    package var baseAddress: UnsafeUnownedPointer<Element>? {
        guard let baseAddr = unsafeRawPtr.baseAddress else {
            return nil
        }
        return .init(unownedPointer: baseAddr)
    }

    package init(owningBuffer ptr: consuming UnsafeBufferPointer<Element>, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    package init(_ ptr: consuming UnsafeOwnedMutableAutoBufferPointer<Element>) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(ptr.take())
    }

    deinit {
        if let baseAddr = unsafeRawPtr.baseAddress {
            allocator.dealloc(pointer: baseAddr)
        }
    }

    package subscript(index: Int) -> Element {
        _read { yield unsafeRawPtr[index] }
    }

    package consuming func deallocate() {
        let ptr = unsafeRawPtr.baseAddress!
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    package consuming func take() -> UnsafeBufferPointer<Element> {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    @_lifetime(borrow self)
    package func unownedView() -> UnsafeUnownedBufferPointer<Element> {
        return .init(unownedBuffer: unsafeRawPtr)
    }

    package consuming func unsafeMutableCast() -> UnsafeOwnedMutableAutoBufferPointer<Element> {
        .init(mutating: self)
    }

    package var unsafelyCastedMutableRawPtr: UnsafeMutableBufferPointer<Element> {
        .init(mutating: unsafeRawPtr)
    }

}



extension UnsafeOwnedAutoBufferPointer {
    package subscript(index: Int) -> Element {
        unsafeRawPtr[index]
    }
}



package struct UnsafeUnownedBufferPointer<Element: ~Copyable>: ~Escapable {

    package let unsafeRawPtr: UnsafeBufferPointer<Element>

    package var count: Int { unsafeRawPtr.count }

    package var baseAddress: UnsafeUnownedPointer<Element>? {
        @_lifetime(copy self)
        get {
            guard let baseAddr = unsafeRawPtr.baseAddress else {
                return nil
            }
            return .init(unownedPointer: baseAddr)
        }
    }

    @_lifetime(immortal)
    package init(unownedBuffer ptr: UnsafeBufferPointer<Element>) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(copy ptr)
    package init(_ ptr: UnsafeUnownedMutableBufferPointer<Element>) {
        self.unsafeRawPtr = .init(ptr.unsafeRawPtr)
    }

    package subscript(index: Int) -> Element {
        _read { yield unsafeRawPtr[index] }
    }

    @_lifetime(copy self)
    package func unsafeMutableCast() -> UnsafeUnownedMutableBufferPointer<Element> {
        return .init(unownedMutating: unsafeRawPtr)
    }

    package var unsafelyCastedMutableRawPtr: UnsafeMutableBufferPointer<Element> {
        .init(mutating: unsafeRawPtr)
    }

}



extension UnsafeUnownedBufferPointer {
    package subscript(index: Int) -> Element {
        unsafeRawPtr[index]
    }
}



package struct UnsafeOwnedMutableAutoBufferPointer<Element: ~Copyable>: ~Copyable {

    package let unsafeRawPtr: UnsafeMutableBufferPointer<Element>
    package let allocator: MemoryAllocatorType

    package var count: Int {
        return unsafeRawPtr.count
    }

    package var baseAddress: UnsafeUnownedPointer<Element>? {
        guard let baseAddr = unsafeRawPtr.baseAddress else {
            return nil
        }
        return .init(unownedPointer: baseAddr)
    }

    package init(owningBuffer ptr: consuming UnsafeMutableBufferPointer<Element>, allocator: MemoryAllocatorType) {
        self.unsafeRawPtr = ptr
        self.allocator = allocator
    }

    package init(mutating ptr: consuming UnsafeOwnedAutoBufferPointer<Element>) {
        self.allocator = ptr.allocator
        self.unsafeRawPtr = .init(mutating: ptr.take())
    }

    deinit {
        if let baseAddr = unsafeRawPtr.baseAddress {
            allocator.dealloc(pointer: baseAddr)
        }
    }

    package subscript(index: Int) -> Element {
        _read { yield unsafeRawPtr[index] }
        _modify { yield &unsafeRawPtr[index] }
    }

    package consuming func deallocate() {
        let ptr = unsafeRawPtr.baseAddress!
        let allocator = self.allocator
        discard self 
        allocator.dealloc(pointer: ptr)
    }

    package consuming func take() -> UnsafeMutableBufferPointer<Element> {
        let ptr = unsafeRawPtr
        discard self
        return ptr
    }

    package func unownedView() -> UnsafeUnownedMutableBufferPointer<Element> {
        return .init(unownedBuffer: unsafeRawPtr)
    }

}



extension UnsafeOwnedMutableAutoBufferPointer {
    package subscript(index: Int) -> Element {
        get { unsafeRawPtr[index] }
        set { unsafeRawPtr[index] = newValue }
    }
}



package struct UnsafeUnownedMutableBufferPointer<Element: ~Copyable>: ~Escapable {

    package let unsafeRawPtr: UnsafeMutableBufferPointer<Element>

    package var count: Int { unsafeRawPtr.count }

    package var baseAddress: UnsafeUnownedMutablePointer<Element>? {
        @_lifetime(copy self)
        get {
            guard let baseAddr = unsafeRawPtr.baseAddress else {
                return nil
            }
            return .init(unownedPointer: baseAddr)
        }
    }

    @_lifetime(immortal)
    package init(unownedBuffer ptr: UnsafeMutableBufferPointer<Element>) {
        self.unsafeRawPtr = ptr
    }

    @_lifetime(immortal)
    package init(unownedMutating ptr: UnsafeBufferPointer<Element>) {
        self.unsafeRawPtr = .init(mutating: ptr)
    }

    package subscript(index: Int) -> Element {
        _read { yield unsafeRawPtr[index] }
        nonmutating _modify { yield &unsafeRawPtr[index] }
    }

    @_lifetime(copy self)
    package func immutableCast() -> UnsafeUnownedBufferPointer<Element> {
        .init(self)
    }

}