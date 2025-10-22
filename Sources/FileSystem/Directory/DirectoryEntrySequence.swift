import SystemPackage

import Foundation
import CFileSystem



public struct DirectoryEntrySequence: DirectoryEntrySequenceProtocol, ~Escapable, ~Copyable {

    private let handle: DirectoryHandle.SystemHandleType
    public let path: FilePath
    public let recursive: Bool


    @_lifetime(borrow handle)
    init(handle: borrowing DirectoryHandle, recursive: Bool) {
        self.init(
            systemHandle: handle.withUnsafeSystemHandle(\.self), 
            path: handle.path, 
            recursive: recursive
        )
    }


    @_lifetime(immortal)
    init(systemHandle: DirectoryHandle.SystemHandleType, path: FilePath, recursive: Bool) {
        self.handle = systemHandle
        self.path = path
        self.recursive = recursive
    }


    @_lifetime(copy self)
    public func makeIterator() -> Iterator {
        do {
            if recursive {
                return try DirectoryIterator.recursive(DirectoryEntryRecursiveIterator(path: path))
            } else {
                return try DirectoryIterator.direct(DirectoryEntryDirectIterator(handle: handle, path: path))
            }
        } catch {
            return DirectoryIterator.openError(DirectoryEntryErrorIterator(error: error))
        }
    }

}



extension DirectoryEntrySequence {

    public struct DirectoryEntryDirectIterator: DirectoryEntryIteratorProtocol, ~Escapable, ~Copyable {

        #if canImport(WinSDK)
        #error("Not implemented")
        #else
        private var dirStream: OpaquePointer
        #endif

        public let rootPath: FilePath

        public private(set) var ended: Bool = false


        @_lifetime(immortal)
        fileprivate init(handle: DirectoryHandle.SystemHandleType, path: FilePath) throws(FileError) {

            #if canImport(WinSDK)

            fatalError("Not implemented")

            #else

            guard let dirStream = fdopendir(handle) else {
                try FileError.assertError(operationDescription: .openingDirStream(forDirectoryAt: path))
            }

            self.dirStream = .init(UnsafeRawPointer(dirStream))
            self.rootPath = path

            #endif

        }


        public mutating func next() -> Result<DirectoryEntry, FileError>? {
            
            guard !ended else { return nil }
        
            do {
                if let entry = try nextThrowing() {
                    return .success(entry)
                } else {
                    ended = true
                    return nil
                }
            } catch {
                ended = true
                return .failure(error)
            }

        }


        func nextThrowing() throws(FileError) -> DirectoryEntry? {

            #if canImport(WinSDK)

            fatalError("Not implemented")

            #else

            errno = 0

            guard let dirEntryPtr = readdir(.init(dirStream)) else {
                try FileError.check(operationDescription: .readingDirEntries(at: rootPath))
                return nil
            }

            let nameLen = withUnsafeBytes(of: &dirEntryPtr.pointee.d_name) { $0.count }

            let name = dirEntryPtr.pointer(to: \.d_name)?.withMemoryRebound(to: CChar.self, capacity: nameLen) { pointer in
                String(cString: pointer)
            }

            let type = FileInfo.FileType(d_type: dirEntryPtr.pointee.d_type)

            guard let name, let entry = DirectoryEntry(path: rootPath.appending(name), type: type) else {
                throw FileError.unknown(operationDescription: .readingDirEntries(at: rootPath))
            }

            return entry

            #endif 

        }

    }


    public struct DirectoryEntryRecursiveIterator: DirectoryEntryIteratorProtocol, ~Escapable, ~Copyable {

        #if canImport(WinSDK)
        #error("Not implemented")
        #else
        private var entryStream: UnsafeMutablePointer<FTS>
        #endif

        public let rootPath: FilePath

        public private(set) var ended: Bool = false


        @_lifetime(immortal)
        fileprivate init(path: FilePath) throws(FileError) {

            #if canImport(WinSDK)

            fatalError("Not implemented")

            #else

            let entryStream = path.string.withCString { cStr in 
                fts_open([UnsafeMutablePointer<CChar>(mutating: cStr), nil], FTS_PHYSICAL | FTS_NOCHDIR | FTS_SEEDOT, nil)
            }
            guard let entryStream else {
                try FileError.assertError(operationDescription: .openingDirStream(forDirectoryAt: path))
            }

            self.entryStream = entryStream
            self.rootPath = path

            #endif

        }


        public mutating func next() -> Result<DirectoryEntry, FileError>? {

            guard !ended else { return nil }
        
            do {
                if let entry = try nextThrowing() {
                    return .success(entry)
                } else {
                    ended = true
                    return nil
                }
            } catch {
                ended = true
                return .failure(error)
            }

        }


        func nextThrowing() throws(FileError) -> DirectoryEntry? {

            guard !ended else { return nil }
        
            #if canImport(WinSDK)

            fatalError("Not implemented")

            #else

            errno = 0

            while let entry = fts_read(entryStream) {

                if entry.pointee.fts_level == FTS_ROOTLEVEL { continue }

                switch Int32(entry.pointee.fts_info) {
                    case FTS_ERR: 
                        throw .init(code: .init(rawValue: entry.pointee.fts_errno), operationDescription: .readingDirEntries(at: rootPath))
                    default: break
                }

                switch Int32(entry.pointee.fts_info) {
                    case FTS_NS:        continue
                    case FTS_NSOK:      continue
                    case FTS_DNR:       continue
                    case FTS_DP:        continue   
                    case FTS_DC:        continue
                    default:            break
                }

                let entryPath = FilePath(String(cString: entry.pointee.fts_path))

                let fileType = switch Int32(entry.pointee.fts_info) {
                    case FTS_F:         .regular
                    case FTS_D:         .directory
                    case FTS_DOT:       .directory
                    case FTS_DEFAULT:   .init(mode: entry.pointee.fts_statp.pointee.st_mode)
                    case FTS_SL:        .symlink
                    case FTS_SLNONE:    .symlink
                    default:            .unknown
                } as FileInfo.FileType

                guard let directoryEntry = DirectoryEntry(path: entryPath, type: fileType) else {
                    throw .unknown(operationDescription: .readingDirEntries(at: rootPath))
                }

                return directoryEntry

            }

            try FileError.check(operationDescription: .readingDirEntries(at: rootPath))

            return nil

            #endif

        }

    }



    public struct DirectoryEntryErrorIterator: DirectoryEntryIteratorProtocol {

        public let error: FileError
        public private(set) var ended: Bool = false


        fileprivate init(error: FileError) {
            self.error = error
        }


        public mutating func next() -> Result<DirectoryEntry, FileError>? {
            guard !ended else { return nil }
            ended = true
            return .failure(error)
        }

    }


    public enum DirectoryIterator: DirectoryEntryIteratorProtocol, ~Escapable, ~Copyable {

        case direct(DirectoryEntryDirectIterator)
        case recursive(DirectoryEntryRecursiveIterator)
        case openError(DirectoryEntryErrorIterator)

        public mutating func next() -> Result<DirectoryEntry, FileError>? {
            switch self {
                case .direct(var iterator):
                    let result = iterator.next()
                    self = .direct(iterator)
                    return result
                case .recursive(var iterator):
                    let result = iterator.next()
                    self = .recursive(iterator)
                    return result
                case .openError(var iterator):
                    let result = iterator.next()
                    self = .openError(iterator)
                    return result
            }
        }

    }

}



extension OpaquePointer {
    fileprivate init(_ ptr: OpaquePointer) {
        self = ptr
    }
}