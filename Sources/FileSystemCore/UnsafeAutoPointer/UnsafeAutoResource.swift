import PlatformCLib



package struct UnsafeOwnedAutoResource: ~Copyable {

    package private(set) var unsafeResourcePtr: UnsafeMutableRawPointer
    package let freeingFunc: (UnsafeMutableRawPointer) -> Void

    private var free: Bool = false

    package init(
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

    package consuming func deallocate() {
        freeingFunc(unsafeResourcePtr)
        free = true
    }

    @_lifetime(borrow self)
    package func unownedView() -> UnsafeUnownedResource {
        return .init(unownedResource: unsafeResourcePtr)
    }

}



package struct UnsafeUnownedResource: ~Escapable {

    package private(set) var unsafeResourcePtr: UnsafeMutableRawPointer

    @_lifetime(immortal)
    package init(unownedResource ptr: UnsafeMutableRawPointer) {
        self.unsafeResourcePtr = ptr
    }

}