//
//  ByteBuffer+BasicAccess.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/6/25.
//


extension ByteBuffer {
    
    // 32 bytes inline buffer
    @usableFromInline
    typealias InlineBuffer = (
        Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte,
        Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte,
        Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte,
        Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte
    )
    
    
    @inlinable
    public func load<T>(fromOffset offset: Int, as type: T.Type) -> T {
        preconditionValidRange(offset ..< offset + MemoryLayout<T>.size)
        return storage.buffer.loadUnaligned(fromByteOffset: indexInStorage(for: offset), as: type)
    }
    
    
    @inlinable
    public mutating func store<T>(rawBytesOf value: T, toOffset offset: Int) {
        preconditionValidRange(offset ..< offset + MemoryLayout<T>.size)
        _accessForNoAppendWrite()
        storage.buffer.storeBytes(of: value, toByteOffset: indexInStorage(for: offset), as: T.self)
    }
    
    
    @inlinable
    public mutating func store<Bytes: Collection>(bytes: Bytes, toOffset offset: Int) where Bytes.Element == Element {
        
        let byteCountToStore = bytes.count

        preconditionValidRange(offset ..< offset + byteCountToStore)
        guard byteCountToStore > 0 else { return }
        
        _accessForNoAppendWrite()
        
        _writeBytes(bytes, to: offset)
        
    }
    
    
    @inlinable
    public mutating func append<T>(rawBytesOf value: T) {
        let valueSize = MemoryLayout<T>.size
        self._ensureEnoughLogicalCapacityAndRebaseIfNeeded(for: count + valueSize)
        storage.buffer.storeBytes(of: value, toByteOffset: endOffsetInStorage, as: T.self)
        self.count += valueSize
    }
    
    
    @inlinable
    public mutating func append<Bytes: Sequence>(bytes: Bytes) where Bytes.Element == Element {
        
        let contiguousStorageAvailable = bytes.withContiguousStorageIfAvailable { buffer in
            self._ensureEnoughLogicalCapacityAndRebaseIfNeeded(for: count + buffer.count)
            storage[endOffsetInStorage...].copyBytes(from: buffer)
            count += buffer.count
            return true
        } ?? false
        
        guard (_slowPath(!contiguousStorageAvailable)) else { return }
        
        // Try to pre-allocate enough capacity if possible base on the type of the sequence
        switch Bytes.self {
            case is any RandomAccessCollection.Type: do {
                let newElementsCount = (bytes as! any RandomAccessCollection).count
                self._ensureEnoughLogicalCapacityAndRebaseIfNeeded(for: count + newElementsCount)
            }
            default: do {
                self._ensureEnoughLogicalCapacityAndRebaseIfNeeded(for: count + bytes.underestimatedCount)
            }
        }
        
        var inlineBuffer = InlineBuffer(
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
        var inlineBufferWrittenCount = 0
        
        for byte in bytes {
            if inlineBufferWrittenCount == MemoryLayout<InlineBuffer>.size {
                Swift.withUnsafeBytes(of: &inlineBuffer) { buffer in
                    self._ensureEnoughLogicalCapacityAndRebaseIfNeeded(for: count + buffer.count)
                    storage[endOffsetInStorage...].copyBytes(from: buffer)
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
                self._ensureEnoughLogicalCapacityAndRebaseIfNeeded(for: count + inlineBufferWrittenCount)
                storage[endOffsetInStorage...].copyBytes(from: buffer.prefix(inlineBufferWrittenCount))
                count += inlineBufferWrittenCount
            }
        }
        
    }
    
}
