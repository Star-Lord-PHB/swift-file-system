import Foundation
import SystemPackage



public struct FileError: Error, LocalizedError, CustomStringConvertible {

    public let code: ErrorCode
    public let operationDescription: OperationDescription


    @inlinable
    public init(code: ErrorCode, operationDescription: OperationDescription) {
        self.code = code
        self.operationDescription = operationDescription
    }


    @inlinable
    public var description: String {
        "\(operationDescription): \(code.description) (\(code.rawValue))"
    }


    @inlinable
    public var errorDescription: String { description }

}



extension FileError {

    public struct OperationDescription: Sendable, ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {

        public let description: String 

        public init(stringLiteral: String) {
            self.description = stringLiteral
        }

        public init(_ string: String) {
            self.description = string 
        }

        public static func fetchingInfo(for path: FilePath) -> Self {
            "Fetching info for file at \(path)"
        }

    }

}



#if !canImport(WinSDK)
extension FileError {

    public enum ErrorCode: CInt, Sendable, CustomStringConvertible {

        case operationNotPermitted
        case noSuchFileOrDirectory
        case noSuchProcess
        case interruptedSystemCall
        case ioError
        case noSuchDeviceOrAddress
        case argumentListTooLong
        case badFileDescriptor
        case resourceTemporarilyUnavailable
        case permissionDenied
        case badAddress
        case blockDeviceRequired
        case deviceOrResourceBusy
        case fileExists
        case crossDeviceLink
        case noSuchDevice
        case notADirectory
        case isADirectory
        case invalidArgument
        case tooManyOpenFilesInSystem
        case tooManyOpenFiles
        case textFileBusy
        case fileTooLarge
        case noSpaceLeftOnDevice
        case illegalSeek
        case readOnlyFileSystem
        case tooManyLinks
        case brokenPipe
        case resourceDeadlockAvoided
        case fileNameTooLong
        case noLocksAvailable
        case functionNotImplemented
        case directoryNotEmpty
        case tooManySymbolicLinks
        case valueTooLarge
        case staleFileHandle

        #if canImport(Glibc) || canImport(Musl)
        case structureNeedsCleaning
        case noMediumFound
        case wrongMediumType
        #endif

        @inlinable public static var wouldBlock: Self { .resourceTemporarilyUnavailable }
        
        @inlinable
        public init(rawValue: CInt) {
            self = .init(posixErrorCode: .init(rawValue: rawValue) ?? .EIO) ?? .ioError
        }

        @usableFromInline
        init?(posixErrorCode: POSIXErrorCode) {
            switch posixErrorCode {
                case .EPERM:        self = .operationNotPermitted
                case .ENOENT:       self = .noSuchFileOrDirectory
                case .ESRCH:        self = .noSuchProcess
                case .EINTR:        self = .interruptedSystemCall
                case .EIO:          self = .ioError
                case .ENXIO:        self = .noSuchDeviceOrAddress
                case .E2BIG:        self = .argumentListTooLong
                case .EBADF:        self = .badFileDescriptor
                case .EAGAIN:       self = .resourceTemporarilyUnavailable
                case .EACCES:       self = .permissionDenied
                case .EFAULT:       self = .badAddress
                case .ENOTBLK:      self = .blockDeviceRequired
                case .EBUSY:        self = .deviceOrResourceBusy
                case .EEXIST:       self = .fileExists
                case .EXDEV:        self = .crossDeviceLink
                case .ENODEV:       self = .noSuchDevice
                case .ENOTDIR:      self = .notADirectory
                case .EISDIR:       self = .isADirectory
                case .EINVAL:       self = .invalidArgument
                case .ENFILE:       self = .tooManyOpenFilesInSystem
                case .EMFILE:       self = .tooManyOpenFiles
                case .ETXTBSY:      self = .textFileBusy
                case .EFBIG:        self = .fileTooLarge
                case .ENOSPC:       self = .noSpaceLeftOnDevice
                case .ESPIPE:       self = .illegalSeek
                case .EROFS:        self = .readOnlyFileSystem
                case .EMLINK:       self = .tooManyLinks
                case .EPIPE:        self = .brokenPipe
                case .EDEADLK:      self = .resourceDeadlockAvoided
                case .ENAMETOOLONG: self = .fileNameTooLong
                case .ENOLCK:       self = .noLocksAvailable
                case .ENOSYS:       self = .functionNotImplemented
                case .ENOTEMPTY:    self = .directoryNotEmpty
                case .ELOOP:        self = .tooManySymbolicLinks
                case .EOVERFLOW:    self = .valueTooLarge
                case .ESTALE:       self = .staleFileHandle
                #if canImport(Glibc) || canImport(Musl)
                case .EUCLEAN:      self = .structureNeedsCleaning
                case .ENOMEDIUM:    self = .noMediumFound
                case .EMEDIUMTYPE:  self = .wrongMediumType
                #endif
                default: return nil
            }
        }


        @inlinable
        public var rawValue: CInt {
            switch self {
                case .operationNotPermitted:            POSIXErrorCode.EPERM.rawValue
                case .noSuchFileOrDirectory:            POSIXErrorCode.ENOENT.rawValue
                case .noSuchProcess:                    POSIXErrorCode.ESRCH.rawValue
                case .interruptedSystemCall:            POSIXErrorCode.EINTR.rawValue
                case .ioError:                          POSIXErrorCode.EIO.rawValue
                case .noSuchDeviceOrAddress:            POSIXErrorCode.ENXIO.rawValue
                case .argumentListTooLong:              POSIXErrorCode.E2BIG.rawValue
                case .badFileDescriptor:                POSIXErrorCode.EBADF.rawValue
                case .resourceTemporarilyUnavailable:   POSIXErrorCode.EAGAIN.rawValue
                case .permissionDenied:                 POSIXErrorCode.EACCES.rawValue
                case .badAddress:                       POSIXErrorCode.EFAULT.rawValue
                case .blockDeviceRequired:              POSIXErrorCode.ENOTBLK.rawValue
                case .deviceOrResourceBusy:             POSIXErrorCode.EBUSY.rawValue
                case .fileExists:                       POSIXErrorCode.EEXIST.rawValue
                case .crossDeviceLink:                  POSIXErrorCode.EXDEV.rawValue
                case .noSuchDevice:                     POSIXErrorCode.ENODEV.rawValue
                case .notADirectory:                    POSIXErrorCode.ENOTDIR.rawValue
                case .isADirectory:                     POSIXErrorCode.EISDIR.rawValue
                case .invalidArgument:                  POSIXErrorCode.EINVAL.rawValue
                case .tooManyOpenFilesInSystem:         POSIXErrorCode.ENFILE.rawValue
                case .tooManyOpenFiles:                 POSIXErrorCode.EMFILE.rawValue
                case .textFileBusy:                     POSIXErrorCode.ETXTBSY.rawValue
                case .fileTooLarge:                     POSIXErrorCode.EFBIG.rawValue
                case .noSpaceLeftOnDevice:              POSIXErrorCode.ENOSPC.rawValue
                case .illegalSeek:                      POSIXErrorCode.ESPIPE.rawValue
                case .readOnlyFileSystem:               POSIXErrorCode.EROFS.rawValue
                case .tooManyLinks:                     POSIXErrorCode.EMLINK.rawValue
                case .brokenPipe:                       POSIXErrorCode.EPIPE.rawValue
                case .resourceDeadlockAvoided:          POSIXErrorCode.EDEADLK.rawValue
                case .fileNameTooLong:                  POSIXErrorCode.ENAMETOOLONG.rawValue
                case .noLocksAvailable:                 POSIXErrorCode.ENOLCK.rawValue
                case .functionNotImplemented:           POSIXErrorCode.ENOSYS.rawValue
                case .directoryNotEmpty:                POSIXErrorCode.ENOTEMPTY.rawValue
                case .tooManySymbolicLinks:             POSIXErrorCode.ELOOP.rawValue
                case .valueTooLarge:                    POSIXErrorCode.EOVERFLOW.rawValue
                case .staleFileHandle:                  POSIXErrorCode.ESTALE.rawValue
                #if canImport(Glibc) || canImport(Musl)
                case .structureNeedsCleaning:          POSIXErrorCode.EUCLEAN.rawValue
                case .noMediumFound:                   POSIXErrorCode.ENOMEDIUM.rawValue
                case .wrongMediumType:                 POSIXErrorCode.EMEDIUMTYPE.rawValue
                #endif
            }
        }


        @inlinable
        public var description: String {
            .init(cString: strerror(rawValue))
        }

    }


    @inlinable
    public init(code: CInt, operationDescription: OperationDescription) {
        self.init(code: .init(rawValue: code), operationDescription: operationDescription)
    }


    @inlinable
    public static func fromErrno(operationDescription: OperationDescription) -> FileError {
        return .init(code: errno, operationDescription: operationDescription)
    }


    // @inlinable
    // public static func fetchingFileInfo(at path: FilePath) -> FileError {
    //     return .fromErrno(operationDescription: "Fetching info for file at \(path)")
    // }

}
#endif