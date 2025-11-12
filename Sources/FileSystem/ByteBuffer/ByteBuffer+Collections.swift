import PlatformCLib
import Foundation


extension ByteBuffer: RandomAccessCollection, MutableCollection {

    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { count }


    @inlinable
    public subscript(index: Int) -> UInt8 {
        get { 
            preconditionValidIndex(index)
            return storage[index] 
        }
        set { 
            preconditionValidIndex(index)
            _assessForWrite()
            storage[index] = newValue
        }
    }

}



extension ByteBuffer {

    // 32 bytes inline buffer
    @usableFromInline
    typealias InlineBuffer = (
        Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte,
        Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte,
        Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte,
        Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte
    )

}



extension ByteBuffer: RangeReplaceableCollection {

    @inlinable
    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C : Collection, UInt8 == C.Element {

        preconditionValidRange(subrange)
        
        _assessForWrite()

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

        let continuousStorageAvailable = newElements.withContiguousStorageIfAvailable { buffer in
            storage.copyBytes(from: .init(buffer), toOffset: subrange.lowerBound)
            return true
        } ?? false

        guard (_slowPath(!continuousStorageAvailable)) else { return }

        if C.self is any ContiguousBytes {
            (newElements as! any ContiguousBytes).withUnsafeBytes { buffer in 
                storage.copyBytes(from: buffer, toOffset: subrange.lowerBound)
            }
            return
        }

        var inlineBuffer = InlineBuffer(
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
        var inlineBufferWrittenCount = 0
        var writePtr = storage.pointer(to: subrange.lowerBound)
        
        for byte in newElements {

            if inlineBufferWrittenCount == MemoryLayout<InlineBuffer>.size {
                assert(
                    writePtr + inlineBufferWrittenCount <= storage.baseAddress! + (subrange.lowerBound + newElementsCount),
                    "writing beyond subrange"
                )
                Swift.withUnsafeBytes(of: &inlineBuffer) { buffer in 
                    writePtr.copyMemory(from: buffer.baseAddress!, byteCount: inlineBufferWrittenCount)
                }
                writePtr += inlineBufferWrittenCount
                inlineBufferWrittenCount = 0
            }

            Swift.withUnsafeMutableBytes(of: &inlineBuffer) { buffer in 
                buffer[inlineBufferWrittenCount] = byte
            }
            inlineBufferWrittenCount += 1

        }

        if inlineBufferWrittenCount > 0 {
            Swift.withUnsafeBytes(of: &inlineBuffer) { buffer in 
                assert(
                    writePtr + inlineBufferWrittenCount <= storage.baseAddress! + (subrange.lowerBound + newElementsCount), 
                    "writing beyond subrange"
                )
                writePtr.copyMemory(from: buffer.baseAddress!, byteCount: inlineBufferWrittenCount)
            }
        }

    }


    @inlinable
    public mutating func append<S>(contentsOf newElements: S) where S : Sequence, UInt8 == S.Element {

        _assessForWrite()

        let contiguousStorageAvailable = newElements.withContiguousStorageIfAvailable { buffer in
            storage.allocateEnoughCapacityIfNeeded(for: count + buffer.count)
            storage.copyBytes(from: .init(buffer), toOffset: count)
            count += buffer.count
            return true
        } ?? false

        guard (_slowPath(!contiguousStorageAvailable)) else { return }

        if S.self is any ContiguousBytes {
            (newElements as! any ContiguousBytes).withUnsafeBytes { buffer in
                storage.allocateEnoughCapacityIfNeeded(for: count + buffer.count)
                storage.copyBytes(from: .init(buffer), toOffset: count)
                count += buffer.count
            }
            return
        }

        // Try to pre-allocate enough capacity if possible base on the type of the sequence
        switch S.self {
            case is any RandomAccessCollection.Type: do {
                let newElementsCount = (newElements as! any RandomAccessCollection).count
                storage.allocateEnoughCapacityIfNeeded(for: count + newElementsCount)
            }
            // MARK: TODO: Compare the performance of this case with the default case
            // case is any Collection.Type: do {
            //     let collectionNewElements = newElements as! any Collection
            //     let newElementsCount = collectionNewElements.count
            //     storage._allocateEnoughCapacityIfNeeded(forAdditional: newElementsCount)
            //     newElements = collectionNewElements as! S
            // }
            default: do {
                storage.allocateEnoughCapacityIfNeeded(for: count + newElements.underestimatedCount)
            }
        }

        var inlineBuffer = InlineBuffer(
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
        var inlineBufferWrittenCount = 0

        for byte in newElements {
            if inlineBufferWrittenCount == MemoryLayout<InlineBuffer>.size {
                Swift.withUnsafeBytes(of: &inlineBuffer) { buffer in
                    storage.allocateEnoughCapacityIfNeeded(for: count + buffer.count)
                    storage.copyBytes(from: .init(buffer), toOffset: count)
                    count += buffer.count
                }
                inlineBufferWrittenCount = 0
            }
            Swift.withUnsafeMutableBytes(of: &inlineBuffer) { buffer in
                buffer[inlineBufferWrittenCount] = byte
            }
            inlineBufferWrittenCount += 1
        }

        if inlineBufferWrittenCount > 0 {
            Swift.withUnsafeBytes(of: &inlineBuffer) { buffer in
                storage.allocateEnoughCapacityIfNeeded(for: count + inlineBufferWrittenCount)
                storage.copyBytes(from: .init(rebasing: buffer.prefix(inlineBufferWrittenCount)), toOffset: count)
                count += inlineBufferWrittenCount
            }
        }

    }


    @inlinable
    public mutating func append(_ newElement: UInt8) {
        _assessForWrite()
        storage.allocateEnoughCapacityIfNeeded(for: count + 1)
        storage[count] = newElement
        count += 1
    }

}



extension ByteBuffer {

    @inlinable
    public func withContiguousStorageIfAvailable<R: ~Copyable, E: Error>(_ body: (UnsafeBufferPointer<UInt8>) throws(E) -> R) throws(E) -> R? {
        return try withUnsafeBufferPointer(body)
    }


    @inlinable
    public mutating func withContiguousMutableStorageIfAvailable<R: ~Copyable, E: Error>(
        _ body: (inout UnsafeMutableBufferPointer<UInt8>
    ) throws(E) -> R) throws(E) -> R? {
        // _assessForWrite() will be called in the withUnsafeMutableBufferPointer method
        // so we don't need to call it here again
        return try withUnsafeMutableBufferPointer(body)
    }


    @inlinable
    public func withUnsafeBufferPointer<R: ~Copyable, E: Error>(_ body: (UnsafeBufferPointer<UInt8>) throws(E) -> R) throws(E) -> R {
        return try body(.init(storage.buffer.assumingMemoryBound(to: UInt8.self)))
    }


    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R: ~Copyable, E: Error>(
        _ body: (inout UnsafeMutableBufferPointer<UInt8>
    ) throws(E) -> R) throws(E) -> R {
        _assessForWrite()
        var buffer = storage.buffer.assumingMemoryBound(to: UInt8.self)
        let result = try body(&buffer)
        precondition(UnsafeMutableRawPointer(buffer.baseAddress) == storage.buffer.baseAddress, "replacing the buffer is not allowed")
        precondition(buffer.count == count, "replacing the buffer is not allowed")
        return result
    }

}