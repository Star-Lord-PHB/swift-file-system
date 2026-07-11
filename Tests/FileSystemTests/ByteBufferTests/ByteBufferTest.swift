import Foundation
import Testing
@testable import SwiftFileSystem
@testable import FileSystemCore



@Suite("ByteBuffer")
final class ByteBufferTest {}



extension ByteBufferTest {

    static func sequentialBytes(count: Int, startingAt start: UInt8 = 0) -> [UInt8] {
        (0 ..< count).map { start &+ UInt8(truncatingIfNeeded: $0) }
    }


    static func expectBytes<C: Collection>(
        _ actual: C,
        equals expected: [UInt8],
        sourceLocation: SourceLocation = #_sourceLocation
    ) where C.Element == UInt8 {
        #expect(
            Array(actual) == expected,
            "Byte sequences are not equal",
            sourceLocation: sourceLocation
        )
    }


    static func expectBytes<C: Collection, E: Sequence>(
        _ actual: C,
        equals expected: E,
        sourceLocation: SourceLocation = #_sourceLocation
    ) where C.Element == UInt8, E.Element == UInt8 {
        #expect(
            Array(actual) == Array(expected),
            "Byte sequences are not equal",
            sourceLocation: sourceLocation
        )
    }


    static func expectBytes(
        _ actual: UnsafeRawBufferPointer,
        equals expected: [UInt8],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            Array(actual) == expected,
            "Byte sequences are not equal",
            sourceLocation: sourceLocation
        )
    }


    static func expectBytes<E: Sequence>(
        _ actual: UnsafeRawBufferPointer,
        equals expected: E,
        sourceLocation: SourceLocation = #_sourceLocation
    ) where E.Element == UInt8 {
        #expect(
            Array(actual) == Array(expected),
            "Byte sequences are not equal",
            sourceLocation: sourceLocation
        )
    }


    static func bytes<T>(of value: T) -> [UInt8] {
        var value = value
        return withUnsafeBytes(of: &value) { Array($0) }
    }


    static func makeUniqueSliceBackedBuffer(
        sourceCount: Int = 32,
        sliceRange: Range<Int>
    ) -> ByteBuffer {
        let source = ByteBuffer(sequentialBytes(count: sourceCount))
        return ByteBuffer(source[sliceRange])
    }

}



extension ByteBufferTest {

    struct TrivialRecord: Equatable {
        var count: UInt32 = 0x0102_0304
        var delta: Int16 = -123
        var flag: Bool = true
    }


    struct NonContiguousBytes: Collection, ExpressibleByArrayLiteral {

        private var storage: [UInt8]

        init(_ storage: [UInt8]) {
            self.storage = storage
        }

        init(arrayLiteral elements: UInt8...) {
            self.storage = elements
        }

        var startIndex: Int { storage.startIndex }
        var endIndex: Int { storage.endIndex }

        func index(after i: Int) -> Int {
            storage.index(after: i)
        }

        subscript(position: Int) -> UInt8 {
            storage[position]
        }

    }


    struct GeneratedBytes: Sequence {

        let count: Int
        let start: UInt8

        init(count: Int, start: UInt8 = 0) {
            self.count = count
            self.start = start
        }

        func makeIterator() -> Iterator {
            Iterator(remaining: count, nextValue: start)
        }

        struct Iterator: IteratorProtocol {

            var remaining: Int
            var nextValue: UInt8

            mutating func next() -> UInt8? {
                guard remaining > 0 else { return nil }
                defer {
                    remaining -= 1
                    nextValue &+= 1
                }
                return nextValue
            }

        }

    }

}
