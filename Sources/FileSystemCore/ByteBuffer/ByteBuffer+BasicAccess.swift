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
        return storage.buffer.loadUnaligned(fromByteOffset: offset, as: type)
    }
    
    
    @inlinable
    public mutating func store<T>(rawBytesOf value: T, toOffset offset: Int) {
        preconditionValidRange(offset ..< offset + MemoryLayout<T>.size)
        _assessForWrite()
        storage.buffer.storeBytes(of: value, toByteOffset: offset, as: T.self)
    }
    
    
    @inlinable
    public mutating func store<Bytes: Collection>(bytes: Bytes, toOffset offset: Int) where Bytes.Element == Element {
        
        let byteCountToStore = bytes.count
        preconditionValidRange(offset ..< offset + byteCountToStore)
        _assessForWrite()
        
        _writeBytes(bytes, to: offset)
        
    }
    
    
    @inlinable
    public mutating func append<T>(rawBytesOf value: T) {
        _assessForWrite()
        let valueSize = MemoryLayout<T>.size
        storage.allocateEnoughCapacityIfNeeded(for: endOffsetInStorage + valueSize)
        storage.buffer.storeBytes(of: value, toByteOffset: endOffsetInStorage, as: T.self)
        self.count += valueSize
    }
    
    
    @inlinable
    public mutating func append<Bytes: Sequence>(bytes: Bytes) where Bytes.Element == Element {
        
        _assessForWrite()
        
        let contiguousStorageAvailable = bytes.withContiguousStorageIfAvailable { buffer in
            storage.allocateEnoughCapacityIfNeeded(for: endOffsetInStorage + buffer.count)
            storage.copyBytes(from: .init(buffer), toOffset: endOffsetInStorage)
            count += buffer.count
            return true
        } ?? false
        
        guard (_slowPath(!contiguousStorageAvailable)) else { return }
        
        // Try to pre-allocate enough capacity if possible base on the type of the sequence
        switch Bytes.self {
            case is any RandomAccessCollection.Type: do {
                let newElementsCount = (bytes as! any RandomAccessCollection).count
                storage.allocateEnoughCapacityIfNeeded(for: endOffsetInStorage + newElementsCount)
            }
            // MARK: TODO: Compare the performance of this case with the default case
            // case is any Collection.Type: do {
            //     let collectionNewElements = newElements as! any Collection
            //     let newElementsCount = collectionNewElements.count
            //     storage._allocateEnoughCapacityIfNeeded(forAdditional: newElementsCount)
            //     newElements = collectionNewElements as! S
            // }
            default: do {
                storage.allocateEnoughCapacityIfNeeded(for: endOffsetInStorage + bytes.underestimatedCount)
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
                    storage.allocateEnoughCapacityIfNeeded(for: endOffsetInStorage + buffer.count)
                    storage.copyBytes(from: .init(buffer), toOffset: endOffsetInStorage)
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
                storage.allocateEnoughCapacityIfNeeded(for: endOffsetInStorage + inlineBufferWrittenCount)
                storage.copyBytes(from: .init(rebasing: buffer.prefix(inlineBufferWrittenCount)), toOffset: endOffsetInStorage)
                count += inlineBufferWrittenCount
            }
        }
        
    }
    
}
