//
//  ByteBuffer+Storage.swift
//  swift-file-system
//
//  Created by SerikaPHB  on 2026/6/25.
//


extension ByteBuffer {
    
    public typealias Byte = UnsafeMutableRawBufferPointer.Element
    
    @usableFromInline
    final class Storage {
        
        @_alwaysEmitIntoClient fileprivate(set) var buffer: UnsafeMutableRawBufferPointer = .init(start: nil, count: 0)
        
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


        @inlinable 
        init(capacityForAtLeast byteCount: Int, zeroed: Bool = false) {
            precondition(byteCount >= 0, "Byte count must be non-negative")
            let recommendedCapacity = Self.recommendedCapacity(forAtLeast: byteCount)
            if recommendedCapacity > 0 {
                if zeroed {
                    buffer = .init(start: calloc(recommendedCapacity, MemoryLayout<Byte>.size), count: recommendedCapacity)
                } else {
                    buffer = .init(start: malloc(recommendedCapacity), count: recommendedCapacity)
                }
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
        subscript(_ range: PartialRangeFrom<Int>) -> Slice<UnsafeMutableRawBufferPointer> {
            assertValidRange(range.lowerBound ..< range.lowerBound)
            return buffer[range]
        }


        @inlinable
        func swapBuffer(_ newBuffer: UnsafeMutableRawBufferPointer) {
            if let baseAddress = buffer.baseAddress {
                PlatformCLib.free(baseAddress)
            }
            buffer = newBuffer
        }
        
        
        @inlinable
        func copyBytes(from buffer: UnsafeRawBufferPointer) {
            assertValidRange(0 ..< buffer.count)
            guard 
                let destBaseAddress = self.buffer.baseAddress, 
                let srcBaseAddress = buffer.baseAddress 
            else { return }
            let byteCountToCopy = Swift.min(buffer.count, self.capacity)
            destBaseAddress.copyMemory(from: srcBaseAddress, byteCount: byteCountToCopy)
        }


        @inlinable
        func copyBytes(from buffer: Slice<UnsafeRawBufferPointer>) {
            copyBytes(from: .init(rebasing: buffer))
        }


        @inlinable
        func copyBytes(from buffer: Slice<UnsafeMutableRawBufferPointer>) {
            copyBytes(from: .init(rebasing: buffer))
        }
        
        
        @inlinable
        func pointer(to index: Int) -> UnsafeMutableRawPointer {
            assertValidIndex(index)
            return buffer.baseAddress!.advanced(by: index)
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


        @inlinable
        static func recommendedCapacity(forAtLeast n: Int) -> Int {
            
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
        static func allocateBuffer(byteCount: Int) -> UnsafeMutableRawBufferPointer {
            return .init(start: malloc(byteCount), count: byteCount)
        }


        @inlinable
        static func allocateBuffer(forAtLeast byteCount: Int) -> UnsafeMutableRawBufferPointer {
            let recommendedCapacity = Self.recommendedCapacity(forAtLeast: byteCount)
            return allocateBuffer(byteCount: recommendedCapacity)
        }
        
    }
    
}
