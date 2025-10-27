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


    public mutating func withUnsafeMutableBytes<R, E: Error>(_ body: (UnsafeMutableRawBufferPointer) throws(E) -> R) throws(E) -> R {
        do {
            return try storage.withUnsafeMutableBytes { rawBufferPointer in
                try body(rawBufferPointer)
            }
        } catch let error as E {
            throw error
        } catch {
            fatalError("Expect error of type \(E.self), but got: \(error)")
        }
    }


    public func withUnsafeBytes<R, E: Error>(_ body: (UnsafeRawBufferPointer) throws(E) -> R) throws(E) -> R {
        do {
            return try storage.withUnsafeBytes { rawBufferPointer in
                try body(rawBufferPointer)
            }
        } catch let error as E {
            throw error
        } catch {
            fatalError("Expect error of type \(E.self), but got: \(error)")
        }
    }

}



extension ByteBuffer {

    public var data: Data {
        storage
    }

}