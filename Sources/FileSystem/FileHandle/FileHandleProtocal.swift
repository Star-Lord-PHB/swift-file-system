import SystemPackage
import Foundation

#if canImport(WinSDK)
import WinSDK
#endif



public protocol FileHandleProtocol: ~Copyable {

    var path: FilePath { get }

    consuming func close() throws(FileError)

    func withUnsafeSystemHandle<R: ~Copyable, E: Error>(_ body: (borrowing UnsafeSystemHandle) throws(E) -> R) throws(E) -> R

}



extension FileHandleProtocol where Self: ~Copyable {

    public func fileInfo() throws(FileError) -> FileInfo {
        try withUnsafeSystemHandle { (sysHandle) throws(FileError) in 
            try .init(unsafeSystemHandle: sysHandle, path: path)
        }
    }

}



public protocol SeekableFileHandleProtocol: ~Copyable, FileHandleProtocol {

    @discardableResult
    func seek(to offset: Int64, relativeTo whence: UnsafeSystemHandle.SeekWhence) throws(FileError) -> Int64

}



extension SeekableFileHandleProtocol where Self: ~Copyable {

    public var currentOffset: Int64 {
        get throws(FileError) {
            try seek(to: 0, relativeTo: .current)
        }
    }

}



public protocol ReadFileHandleProtocol: ~Copyable, SeekableFileHandleProtocol {

    func read(fromOffset offset: Int64?, length: Int64?, into buffer: inout ByteBuffer) throws(FileError)

}



extension ReadFileHandleProtocol where Self: ~Copyable {

    public func read(length: Int64? = nil, into buffer: inout ByteBuffer) throws(FileError) {
        try read(fromOffset: nil, length: length, into: &buffer)
    }


    public func read(fromOffset offset: Int64?, into buffer: inout ByteBuffer) throws(FileError) {
        try read(fromOffset: offset, length: Int64(buffer.count), into: &buffer)
    }


    public func read(fromOffset offset: Int64? = nil, length: Int64) throws(FileError) -> ByteBuffer {
        var buffer = ByteBuffer(count: Int(length))
        try read(fromOffset: offset, length: length, into: &buffer)
        return buffer
    }

}



public protocol WriteFileHandleProtocol: ~Copyable, SeekableFileHandleProtocol {

    func write(_ data: some ContiguousBytes, toOffset offset: Int64?) throws(FileError) -> Int64

    func resize(to size: Int64) throws(FileError)

    func synchronize() throws(FileError)

}



extension WriteFileHandleProtocol where Self: ~Copyable {

    public func write(_ data: some ContiguousBytes) throws(FileError) -> Int64 {
        try write(data, toOffset: nil)
    }

}



public typealias ReadWriteFileHandleProtocol = ReadFileHandleProtocol & WriteFileHandleProtocol



public protocol DirectoryHandleProtocol: ~Copyable, FileHandleProtocol {

    // TODO: Migrate to associatedtype when non-copyable associated types in protocols are supported
    // associatedtype DirectoryEntrySequenceType: DirectoryEntrySequenceProtocol & ~Escapable & ~Copyable 
    typealias DirectoryEntrySequenceType = any (DirectoryEntrySequenceProtocol & ~Escapable & ~Copyable)

    func directEntries() throws(FileError) -> [DirectoryEntry]

    @_lifetime(borrow self)
    func entrySequence(recursive: Bool) throws(FileError) -> DirectoryEntrySequenceType

}