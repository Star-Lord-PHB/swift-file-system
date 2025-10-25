import SystemPackage
import Foundation

#if canImport(WinSDK)
import WinSDK
#endif



public struct UnsafeSystemHandle: ~Copyable {

    #if canImport(WinSDK)
    public typealias SystemHandleType = WinSDK.HANDLE
    #else 
    public typealias SystemHandleType = CInt
    #endif

    public let unsafeRawHandle: SystemHandleType


    public init(owningRawHandle handle: SystemHandleType) {
        self.unsafeRawHandle = handle 
    }


    deinit {
        try? Self._close(unsafeRawHandle)
    }


    func unownedHandle() -> UnsafeUnownedSystemHandle {
        return .init(unsafeRawHandle: unsafeRawHandle)
    }


    public consuming func close() throws(SystemError) {
        let handle = self.unsafeRawHandle
        discard self
        try Self._close(handle)
    }


    private static func _close(_ handle: SystemHandleType) throws(SystemError) {

        #if canImport(WinSDK)
        try execThrowingCFunction {
            CloseHandle(handle)
        }
        #else 
        try execThrowingCFunction {
            close(handle)
        }
        #endif

    }

}


struct UnsafeUnownedSystemHandle {

    #if canImport(WinSDK)
    public typealias SystemHandleType = WinSDK.HANDLE
    #else 
    public typealias SystemHandleType = CInt
    #endif

    let unsafeRawHandle: SystemHandleType

}



extension UnsafeSystemHandle {

    public static func openDir(at path: FilePath) throws(SystemError) -> UnsafeSystemHandle {

        #if canImport(WinSDK)

        let openFlags = DWORD(FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED | FILE_FLAG_BACKUP_SEMANTICS)

        let handle = path.string.withCString(encodedAs: UTF16.self) { cStr in
            CreateFileW(cStr, GENERIC_READ, DWORD(FILE_SHARE_READ), nil, DWORD(OPEN_EXISTING), openFlags, nil)
        }
        guard let handle, handle != INVALID_HANDLE_VALUE else {
            try SystemError.assertError()
        }

        return .init(owningRawHandle: handle)

        #else

        let handle = open(path.string, O_RDONLY | O_DIRECTORY)
        guard handle >= 0 else {
            try FileError.assertError(operationDescription: .openingHandle(forFileAt: path))
        }

        return .init(owningRawHandle: handle)
        
        #endif 

    }

}