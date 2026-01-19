

extension ByteBuffer {

    public var span: Span<Byte> {
        @inlinable
        @_lifetime(borrow self)
        get {
            return _overrideLifetime(
                Span<Byte>(_unsafeElements: .init(
                    start: storage.baseAddress?.advanced(by: startOffsetInStorage).assumingMemoryBound(to: Byte.self), 
                    count: count
                )), 
                borrowing: self
            )
        }
    }


    public var bytes: RawSpan {
        @inlinable
        @_lifetime(borrow self)
        get {
            return _overrideLifetime(
                RawSpan(_unsafeBytes: .init(start: storage.baseAddress?.advanced(by: startOffsetInStorage), count: count)), 
                borrowing: self
            )
        }
    }


    public var mutableSpan: MutableSpan<Byte> {
        @inlinable
        @_lifetime(&self)
        mutating get {
            _assessForWrite()
            return _overrideLifetime(
                MutableSpan<Byte>(_unsafeElements: .init(
                    start: storage.baseAddress?.advanced(by: startOffsetInStorage).assumingMemoryBound(to: Byte.self), 
                    count: count
                )),
                mutating: &self
            )
        }
    }


    public var mutableBytes: MutableRawSpan {
        @inlinable
        @_lifetime(&self)
        mutating get {
            _assessForWrite()
            return _overrideLifetime(
                MutableRawSpan(_unsafeBytes: .init(start: storage.baseAddress?.advanced(by: startOffsetInStorage), count: count)),
                mutating: &self
            )
        }
    }

}



extension ByteBuffer {

    @inlinable
    public init<E: Error>(rawCapacity: Int, initializingWith outputSpanInitializer: (inout OutputRawSpan) throws(E) -> Void) throws(E) {
        self.storage = Storage(capacity: rawCapacity)
        let buffer = storage.buffer
        var outputSpan = OutputRawSpan(buffer: buffer, initializedCount: 0)
        try outputSpanInitializer(&outputSpan)
        self.count = outputSpan.finalize(for: buffer)
        self.startOffsetInStorage = 0
    }


    @inlinable
    public init<E: Error>(capacity: Int, initializingWith outputSpanInitializer: (inout OutputSpan<Byte>) throws(E) -> Void) throws(E) {
        self.storage = Storage(capacity: capacity)
        let buffer = storage.buffer.assumingMemoryBound(to: Byte.self)
        var outputSpan = OutputSpan<Byte>(buffer: buffer, initializedCount: 0)
        try outputSpanInitializer(&outputSpan)
        self.count = outputSpan.finalize(for: buffer)
        self.startOffsetInStorage = 0
    }


    @inlinable
    public mutating func append<E: Error>(
        additionalRawCapacity: Int, 
        initializingWith outputSpanInitializer: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E) {

        _assessForWrite()

        storage.allocateEnoughCapacityIfNeeded(for: endOffsetInStorage + additionalRawCapacity)

        let buffer = storage.buffer[endOffsetInStorage...]
        var outputSpan = OutputRawSpan(buffer: buffer, initializedCount: 0)
        try outputSpanInitializer(&outputSpan)

        self.count += outputSpan.finalize(for: buffer)

    }


    @inlinable
    public mutating func append<E: Error>(
        additionalCapacity: Int, 
        initializingWith outputSpanInitializer: (inout OutputSpan<Byte>) throws(E) -> Void
    ) throws(E) {

        _assessForWrite()

        storage.allocateEnoughCapacityIfNeeded(for: endOffsetInStorage + additionalCapacity)

        let buffer = storage.buffer.assumingMemoryBound(to: Byte.self)[endOffsetInStorage...]
        var outputSpan = OutputSpan<Byte>(buffer: buffer, initializedCount: 0)
        try outputSpanInitializer(&outputSpan)

        self.count += outputSpan.finalize(for: buffer)

    }

}