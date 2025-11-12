import PlatformCLib



public struct ByteBuffer {

    @usableFromInline var storage: Storage

    @inlinable public var capacity: Int { storage.capacity }
    @_alwaysEmitIntoClient public internal(set) var count: Int


    @inlinable 
    public init() {
        self.storage = Storage(capacity: 0)
        self.count = 0
    }


    @inlinable
    public init(repeating value: Byte, count: Int) {
        precondition(count >= 0, "count must be non-negative")
        self.storage = Storage(repeating: value, count: count)
        self.count = count
    }


    @inlinable
    public init(count: Int) {
        precondition(count >= 0, "count must be non-negative")
        self.storage = Storage(capacity: count, zeroed: true)
        self.count = count
    }


    @inlinable
    public init(capacity: Int) {
        precondition(capacity >= 0, "capacity must be non-negative")
        self.storage = Storage(capacity: capacity)
        self.count = 0
    }


    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == Byte {
        self.storage = Storage(capacity: 0)
        self.count = 0
        self.append(contentsOf: elements)
    }

}



extension ByteBuffer {

    @inlinable
    mutating func _assessForWrite() {
        if !isKnownUniquelyReferenced(&storage) {
            self.storage = storage.copy()
        }
    }


    @inlinable
    public mutating func shrinkToFit() {
        _assessForWrite()
        storage.resize(forAtLeast: count)
    }


    @inlinable
    public mutating func reserveCapacity(_ capacity: Int) {
        _assessForWrite()
        storage.allocateEnoughCapacityIfNeeded(for: capacity)
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
        init(capacity: Int, zeroed: Bool = false) {
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
                free(baseAddress)
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
        func copy() -> Storage {
            let newStorage = Storage(capacity: capacity)
            newStorage.copyBytes(from: .init(buffer))
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


        @usableFromInline
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