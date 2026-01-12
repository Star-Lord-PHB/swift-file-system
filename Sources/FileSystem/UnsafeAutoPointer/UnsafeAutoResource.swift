import PlatformCLib



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