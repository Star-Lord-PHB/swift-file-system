import PlatformCLib



public struct ByteBuffer {

    @usableFromInline var storage: Storage

    @_alwaysEmitIntoClient public internal(set) var count: Int
    @usableFromInline var startOffsetInStorage: Int

    @inlinable var endOffsetInStorage: Int { startOffsetInStorage + count }
    @inlinable var rangeInStorage: Range<Int> { startOffsetInStorage ..< endOffsetInStorage }
    @inlinable public var capacity: Int { storage.capacity }

    @inlinable 
    public init() {
        self.storage = Storage(capacity: 0)
        self.count = 0
        self.startOffsetInStorage = 0
    }


    @inlinable
    public init(repeating value: Byte, count: Int) {
        precondition(count >= 0, "count must be non-negative")
        self.storage = Storage(repeating: value, count: count)
        self.count = count
        self.startOffsetInStorage = 0
    }


    @inlinable
    public init(count: Int) {
        precondition(count >= 0, "count must be non-negative")
        self.storage = Storage(capacity: count, zeroed: true)
        self.count = count
        self.startOffsetInStorage = 0
    }


    @inlinable
    public init(capacity: Int) {
        precondition(capacity >= 0, "capacity must be non-negative")
        self.storage = Storage(capacity: capacity)
        self.count = 0
        self.startOffsetInStorage = 0
    }


    @inlinable
    public init(_ byteBuffer: ByteBuffer) {
        if byteBuffer.isEmpty {
            self.storage = Storage(capacity: 0)
            self.count = 0
            self.startOffsetInStorage = 0
        } else {
            self.storage = byteBuffer.storage
            self.count = byteBuffer.count
            self.startOffsetInStorage = byteBuffer.startOffsetInStorage
        }
    }


    @inlinable
    public init(_ byteBufferSlice: Slice<ByteBuffer>) {
        if byteBufferSlice.isEmpty {
            self.storage = Storage(capacity: 0)
            self.count = 0
            self.startOffsetInStorage = 0
        } else {
            self.storage = byteBufferSlice.base.storage
            self.count = byteBufferSlice.count
            self.startOffsetInStorage = byteBufferSlice.base.startOffsetInStorage + byteBufferSlice.startIndex
        }
    }


    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Byte {
        self.storage = Storage(capacity: 0)
        self.count = 0
        self.startOffsetInStorage = 0
        self.append(contentsOf: elements)
    }

}



extension ByteBuffer: @unchecked Sendable { }



extension ByteBuffer: CustomStringConvertible {

    @inlinable
    public var description: String {
        "ByteBuffer(count: \(count) bytes)"
    }

}



extension ByteBuffer: ExpressibleByArrayLiteral {

    @inlinable
    public init(arrayLiteral elements: Byte...) {
        self.init(elements)
    }

}



extension ByteBuffer: Equatable, Hashable {

    @inlinable
    public static func == (lhs: ByteBuffer, rhs: ByteBuffer) -> Bool {
        if lhs.storage.baseAddress == rhs.storage.baseAddress && lhs.startOffsetInStorage == rhs.startOffsetInStorage && lhs.count == rhs.count {
            return true
        }
        guard lhs.count == rhs.count else { return false }
        guard 
            let lhsPtr = lhs.storage.baseAddress?.advanced(by: lhs.startOffsetInStorage), 
            let rhsPtr = rhs.storage.baseAddress?.advanced(by: rhs.startOffsetInStorage) 
        else { return false }
        return memcmp(lhsPtr, rhsPtr, lhs.count) == 0
    }

    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        // TODO: Consider a way of hashing for large buffers? 
        hasher.combine(bytes: .init(rebasing: storage.buffer[rangeInStorage]))
    }

}



extension ByteBuffer {

    @inlinable
    mutating func _assessForWrite() {
        if !isKnownUniquelyReferenced(&storage) {
            self.storage = storage.copy(range: rangeInStorage)
            self.startOffsetInStorage = 0
        }
    }


    @inlinable
    func indexInStorage(for index: Int) -> Int {
        return startOffsetInStorage + index
    }


    @inlinable
    func rangeInStorage(for range: Range<Int>) -> Range<Int> {
        return (startOffsetInStorage + range.lowerBound) ..< (startOffsetInStorage + range.upperBound)
    }


    @inlinable
    public mutating func shrinkToFit() {
        _assessForWrite()
        storage.resize(forAtLeast: endOffsetInStorage)
    }


    @inlinable
    public mutating func reserveCapacity(_ capacity: Int) {
        _assessForWrite()
        storage.allocateEnoughCapacityIfNeeded(for: startOffsetInStorage + capacity)
    }


    @inlinable
    func preconditionValidIndex(_ index: Int, file: StaticString = #file, line: UInt = #line) {
        precondition(index >= 0 && index < count, "Index out of bounds", file: file, line: line)
    }


    @inlinable
    func preconditionValidRange(_ range: Range<Int>, file: StaticString = #file, line: UInt = #line) {
        precondition(range.lowerBound >= 0 && range.upperBound <= count, "Range out of bounds", file: file, line: line)
    }

}



extension ByteBuffer {

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
    public mutating func store(_ bytes: UnsafeRawBufferPointer, toOffset offset: Int) {
        preconditionValidRange(offset ..< offset + bytes.count)
        _assessForWrite()
        storage.copyBytes(from: bytes, toOffset: offset)
    }


    @inlinable
    public mutating func store(_ bytes: UnsafeRawBufferPointer.SubSequence, toOffset offset: Int) {
        preconditionValidRange(offset ..< offset + bytes.count)
        _assessForWrite()
        storage.copyBytes(from: .init(rebasing: bytes), toOffset: offset)
    }


    @inlinable
    public mutating func append<T>(rawBytesOf value: T) {
        _assessForWrite()
        let valueSize = MemoryLayout<T>.size
        storage.allocateEnoughCapacityIfNeeded(for: endOffsetInStorage + valueSize)
        storage.buffer.storeBytes(of: value, toByteOffset: endOffsetInStorage, as: T.self)
        self.count += valueSize
    }

}



extension ByteBuffer {

    public typealias Byte = UnsafeMutableRawBufferPointer.Element

    @usableFromInline
    final class Storage {

        @usableFromInline var buffer: UnsafeMutableRawBufferPointer = .init(start: nil, count: 0)

        @inlinable var capacity: Int { buffer.count }
        @inlinable var baseAddress: UnsafeMutableRawPointer? { buffer.baseAddress }


        @inlinable
        init(capacity: Int) {
            assertValidCapacity(capacity)
            if capacity > 0 {
                buffer = .init(start: malloc(capacity), count: capacity)
            }
        }


        @inlinable
        init(capacity: Int, zeroed: Bool) {
            assertValidCapacity(capacity)
            if capacity > 0 {
                if zeroed {
                    buffer = .init(start: calloc(capacity, MemoryLayout<Byte>.size), count: capacity)
                } else {
                    buffer = .init(start: malloc(capacity), count: capacity)
                }
            }
        }


        @inlinable
        init(repeating value: Byte, count: Int) {
            assertValidCapacity(count)
            if count > 0 {
                buffer = .init(start: malloc(count).initializeMemory(as: Byte.self, repeating: value, count: count), count: count)
            }
        }


        deinit {
            if let baseAddress = buffer.baseAddress {
                PlatformCLib.free(baseAddress)
            }
        }


        @inlinable
        subscript(_ index: Int) -> Byte {
            get { 
                assertValidIndex(index)
                return buffer[index]
            }
            set { 
                assertValidIndex(index)
                buffer[index] = newValue
            }
        }


        @inlinable
        subscript(_ range: Range<Int>) -> Slice<UnsafeMutableRawBufferPointer> {
            assertValidRange(range)
            return buffer[range]
        }


        @inlinable
        func copyBytes(from buffer: UnsafeRawBufferPointer, toOffset offset: Int = 0) {
            assertValidRange(offset ..< offset + buffer.count)
            guard let destBaseAddress = self.buffer.baseAddress, let srcBaseAddress = buffer.baseAddress else { return }
            destBaseAddress.advanced(by: offset).copyMemory(from: srcBaseAddress, byteCount: buffer.count)
        }


        @inlinable
        func pointer(to index: Int) -> UnsafeMutableRawPointer {
            assertValidIndex(index)
            return buffer.baseAddress!.advanced(by: index)
        }


        @inlinable
        func copy(range: Range<Int>) -> Storage {
            let newStorage = Storage(capacity: recommendedCapacity(forAtLeast: range.count))
            newStorage.copyBytes(from: .init(rebasing: buffer[range]))
            return newStorage
        }


        @inlinable
        func resize(toExactly capacity: Int) {
            assertValidCapacity(capacity)
            guard capacity != self.capacity else { return }
            if capacity == 0 {
                if let baseAddress = buffer.baseAddress {
                    free(baseAddress)
                }
                buffer = .init(start: nil, count: 0)
            } else {
                buffer = .init(start: realloc(buffer.baseAddress, capacity), count: capacity)
            }
        }


        @inlinable
        func resize(forAtLeast capacity: Int) {
            resize(toExactly: recommendedCapacity(forAtLeast: capacity))
        }


        @inlinable
        func allocateEnoughCapacityIfNeeded(for bytes: Int) {
            let requiredCapacity = recommendedCapacity(forAtLeast: bytes)
            if requiredCapacity > capacity {
                resize(toExactly: requiredCapacity)
            }
        }


        @inlinable
        func recommendedCapacity(forAtLeast n: Int) -> Int {

            guard n > 0 else { return 0 }
            guard n > 16 else { return 16 }

            var n = n - 1

            n |= n >> 1
            n |= n >> 2
            n |= n >> 4
            n |= n >> 8
            n |= n >> 16
            if Int.bitWidth == 64 {
                n |= n >> 32
            }

            if n < Int.max {
                n = n + 1
            }

            return n

        }


        @inlinable
        func assertValidIndex(_ index: Int, file: StaticString = #file, line: UInt = #line) {
            assert(index >= 0 && index < capacity, "Index out of bounds", file: file, line: line)
        }

        @inlinable
        func assertValidRange(_ range: Range<Int>, file: StaticString = #file, line: UInt = #line) {
            assert(range.lowerBound >= 0 && range.upperBound <= capacity, "Range out of bounds", file: file, line: line)
        }

        @inlinable
        func assertValidCapacity(_ capacity: Int, file: StaticString = #file, line: UInt = #line) {
            assert(capacity >= 0, "Capacity must be non-negative", file: file, line: line)
        }

    }

}