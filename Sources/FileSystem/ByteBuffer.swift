import Foundation


public struct ByteBuffer {

    var storage: Data

    public var count: Int {
        storage.count
    }


    public init(count: Int) {
        self.storage = Data(count: count)
    }


    public subscript(index: Int) -> UInt8 {
        get { storage[index] }
        set { storage[index] = newValue }
    }


    public mutating func withUnsafeMutableBytes<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
        try storage.withUnsafeMutableBytes { rawBufferPointer in
            try body(rawBufferPointer)
        }
    }


    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try storage.withUnsafeBytes { rawBufferPointer in
            try body(rawBufferPointer)
        }
    }

}



extension ByteBuffer {

    public var data: Data {
        storage
    }

}