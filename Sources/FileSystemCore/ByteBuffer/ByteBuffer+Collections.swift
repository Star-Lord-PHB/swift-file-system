import PlatformCLib


extension ByteBuffer: RandomAccessCollection, MutableCollection {

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { count }


    @inlinable
    public subscript(index: Int) -> Byte {
        get {
            preconditionValidIndex(index)
            return storage[indexInStorage(for: index)] 
        }
        set { 
            preconditionValidIndex(index)
            _assessForWrite()
            storage[indexInStorage(for: index)] = newValue
        }
    }

}



extension ByteBuffer: RangeReplaceableCollection {

    @inlinable
    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C : Collection, Byte == C.Element {

        preconditionValidRange(subrange)
        
        _assessForWrite()

        let subrange = rangeInStorage(for: subrange)
        let newElementsCount = newElements.count

        if newElementsCount != subrange.count {

            let tailSegmentCurrentStartIndex = subrange.upperBound
            let tailSegmentCount = count - tailSegmentCurrentStartIndex

            let newCountRequired = count - subrange.count + newElementsCount
            storage.allocateEnoughCapacityIfNeeded(for: newCountRequired)

            if tailSegmentCount > 0 {
                let tailSegmentDestStartIndex = subrange.lowerBound + newElementsCount
                memmove(
                    storage.pointer(to: tailSegmentDestStartIndex), 
                    storage.pointer(to: tailSegmentCurrentStartIndex), 
                    tailSegmentCount
                )
            }

            self.count = newCountRequired

        }

        guard newElementsCount > 0 else { return }

        _writeBytes(newElements, to: subrange.lowerBound)

    }


    @inlinable
    public mutating func append<S>(contentsOf newElements: S) where S : Sequence, Byte == S.Element {
        append(bytes: newElements)
    }


    @inlinable
    public mutating func append(_ newElement: Byte) {
        _assessForWrite()
        storage.allocateEnoughCapacityIfNeeded(for: endOffsetInStorage + 1)
        storage[endOffsetInStorage] = newElement
        count += 1
    }

}



extension ByteBuffer {

    @inlinable
    public func withContiguousStorageIfAvailable<R: ~Copyable, E: Error>(_ body: (UnsafeBufferPointer<Byte>) throws(E) -> R) throws(E) -> R? {
        return try withUnsafeBufferPointer(body)
    }


    @inlinable
    public mutating func withContiguousMutableStorageIfAvailable<R: ~Copyable, E: Error>(
        _ body: (inout UnsafeMutableBufferPointer<Byte>
    ) throws(E) -> R) throws(E) -> R? {
        // _assessForWrite() will be called in the withUnsafeMutableBufferPointer method
        // so we don't need to call it here again
        return try withUnsafeMutableBufferPointer(body)
    }


    @inlinable
    public func withUnsafeBufferPointer<R: ~Copyable, E: Error>(_ body: (UnsafeBufferPointer<Byte>) throws(E) -> R) throws(E) -> R {
        return try body(.init(rebasing: storage.buffer.assumingMemoryBound(to: Byte.self)[rangeInStorage]))
    }


    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R: ~Copyable, E: Error>(
        _ body: (inout UnsafeMutableBufferPointer<Byte>
    ) throws(E) -> R) throws(E) -> R {
        _assessForWrite()
        var buffer = UnsafeMutableBufferPointer<Byte>(rebasing: storage.buffer.assumingMemoryBound(to: Byte.self)[rangeInStorage])
        let result = try body(&buffer)
        precondition(UnsafeMutableRawPointer(buffer.baseAddress) == storage.buffer.baseAddress, "replacing the buffer is not allowed")
        precondition(buffer.count == count, "replacing the buffer is not allowed")
        return result
    }
    
    
    @inlinable
    public func withUnsafeBytes<R: ~Copyable, E: Error>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        try self.withUnsafeBufferPointer { (buffer) throws(E) in
            try body(.init(buffer))
        }
    }
    
    
    @inlinable
    public mutating func withUnsafeMutableBytes<R: ~Copyable, E: Error>(_ body: (UnsafeMutableRawBufferPointer) throws(E) -> R) throws(E) -> R {
        try self.withUnsafeMutableBufferPointer { (buffer) throws(E) in
            try body(.init(buffer))
        }
    }

}
