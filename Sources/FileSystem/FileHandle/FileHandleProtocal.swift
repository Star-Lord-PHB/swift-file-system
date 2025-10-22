import SystemPackage
import Foundation

#if canImport(WinSDK)
import WinSDK
#endif



public enum FileSeekWhence: CInt {

    case beginning
    case current
    case end

    public var rawValue: CInt {
        #if canImport(WinSDK)
        switch self {
            case .beginning: WinSDK.FILE_BEGIN
            case .current: WinSDK.FILE_CURRENT
            case .end: WinSDK.FILE_END
        }
        #else 
        switch self {
            case .beginning: SEEK_SET
            case .current: SEEK_CUR
            case .end: SEEK_END
        }
        #endif
    }

    public init?(rawValue: CInt) {
        #if canImport(WinSDK)
        switch rawValue {
            case WinSDK.FILE_BEGIN: self = .beginning
            case WinSDK.FILE_CURRENT: self = .current
            case WinSDK.FILE_END: self = .end
            default: return nil
        }
        #else 
        switch rawValue {
            case SEEK_SET: self = .beginning
            case SEEK_CUR: self = .current
            case SEEK_END: self = .end
            default: return nil
        }
        #endif
    }
    
}



public protocol FileHandleProtocol: ~Copyable {

    #if canImport(WinSDK)
    typealias SystemHandleType = WinSDK.HANDLE
    #else 
    typealias SystemHandleType = CInt
    #endif 

    var path: FilePath { get }

    consuming func close() throws(FileError)

    func withUnsafeSystemHandle<R, E: Error>(_ body: (SystemHandleType) throws(E) -> R) throws(E) -> R

}



extension FileHandleProtocol where Self: ~Copyable {

    public func fileInfo() throws(FileError) -> FileInfo {
        try withUnsafeSystemHandle { (handle) throws(FileError) in 
            try .init(unsafeSystemHandle: handle, path: path)
        }
    }

}



public protocol SeekableFileHandleProtocol: ~Copyable, FileHandleProtocol {

    @discardableResult
    func seek(to offset: Int64, relativeTo whence: FileSeekWhence) throws(FileError) -> Int64

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