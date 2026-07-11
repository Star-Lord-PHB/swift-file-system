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
            _accessForNoAppendWrite()
            storage[indexInStorage(for: index)] = newValue
        }
    }

}



extension ByteBuffer: RangeReplaceableCollection {

    @inlinable
    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C : Collection, Byte == C.Element {

        preconditionValidRange(subrange)

        let logicalSubrange = subrange
        let newElementsCount = newElements.count
        let newCountRequired = count - logicalSubrange.count + newElementsCount

        // No changes made to the buffer in this case. COW not triggered
        guard logicalSubrange.count != 0 || newElementsCount != 0 else { return }

        let subrangeInOldStorage = rangeInStorage(for: logicalSubrange)
        let leadingRangeInOldStorage = self.startOffsetInStorage ..< subrangeInOldStorage.lowerBound
        let trailingRangeInOldStorage = subrangeInOldStorage.upperBound ..< self.endOffsetInStorage

        if isNotUnique() {

            let newStorage = Storage(capacityForAtLeast: newCountRequired, zeroed: false)

            newStorage[0...].copyBytes(from: self.storage[leadingRangeInOldStorage])
            newStorage[(logicalSubrange.lowerBound + newElementsCount)...].copyBytes(from: self.storage[trailingRangeInOldStorage])

            self.storage = newStorage
            self.startOffsetInStorage = 0

        } else if newCountRequired > storage.capacity {

            let newBuffer = Storage.allocateBuffer(forAtLeast: newCountRequired)

            newBuffer.copyBytes(from: self.storage[leadingRangeInOldStorage])
            newBuffer[(logicalSubrange.lowerBound + newElementsCount)...].copyBytes(from: self.storage[trailingRangeInOldStorage])

            self.storage.swapBuffer(newBuffer)
            self.startOffsetInStorage = 0

        } else if newCountRequired > capacity {

            storage[0...].copyBytes(from: self.storage[leadingRangeInOldStorage])
            storage[(subrangeInOldStorage.lowerBound + newElementsCount)...].copyBytes(from: self.storage[trailingRangeInOldStorage])

            self.startOffsetInStorage = 0

        } else if newElementsCount != logicalSubrange.count && trailingRangeInOldStorage.count > 0 {

            storage[(subrangeInOldStorage.lowerBound + newElementsCount)...].copyBytes(from: self.storage[trailingRangeInOldStorage])

        }

        self.count = newCountRequired

        guard newElementsCount > 0 else { return }

        _writeBytes(newElements, to: logicalSubrange.lowerBound)

    }


    @inlinable
    public mutating func append<S>(contentsOf newElements: S) where S : Sequence, Byte == S.Element {
        append(bytes: newElements)
    }


    @inlinable
    public mutating func append(_ newElement: Byte) {
        self._ensureEnoughLogicalCapacityAndRebaseIfNeeded(for: count + 1)
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
        _accessForNoAppendWrite()
        var buffer = UnsafeMutableBufferPointer<Byte>(rebasing: storage.buffer.assumingMemoryBound(to: Byte.self)[rangeInStorage])
        let bufferCpy = buffer
        let result = try body(&buffer)
        precondition(buffer.baseAddress == bufferCpy.baseAddress, "replacing the buffer is not allowed")
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
