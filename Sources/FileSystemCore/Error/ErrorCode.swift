import PlatformCLib



/// Wrapper of the platform-specific error code.
public struct SystemErrorCode: Sendable, RawRepresentable, CustomStringConvertible {

    #if canImport(WinSDK)
    /// The error code representing success.
    public static var success: SystemErrorCode { .init(rawValue: DWORD(ERROR_SUCCESS)) }
    #else
    /// The error code representing success.
    public static var success: SystemErrorCode { .init(rawValue: 0) }
    #endif


    /// The native error code value.
    public let rawValue: PlatformInteropTypes.ErrorCode


    /// Create from a native error code value.
    public init(rawValue: PlatformInteropTypes.ErrorCode) {
        self.rawValue = rawValue
    }

}



extension SystemErrorCode: Equatable, Hashable { }



extension SystemErrorCode {

    @inlinable
    public var description: String {
        #if canImport(WinSDK)
        return errorCodeDescription(for: rawValue) ?? "Unknown error"
        #else
        guard let message = strerror(rawValue) else { return "Unknown error" }
        return String(cString: message)
        #endif
    }


    /// Create a ``SystemErrorCode`` from the last reported error code of the current thread.
    @inlinable
    public static func fromLastError() -> Self {
        #if canImport(WinSDK)
        return .init(rawValue: GetLastError())
        #else
        return .init(rawValue: errno)
        #endif
    }

}



#if canImport(WinSDK)
extension SystemErrorCode {

    @usableFromInline
    func errorCodeDescription(for error: DWORD) -> String? {

        var buffer = nil as LPWSTR?

        let size = withUnsafeMutablePointer(to: &buffer) { ptrToBuffer in
            ptrToBuffer.withMemoryRebound(to: LPWSTR.Pointee.self, capacity: 1) { wrappedPtrToBuffer in
                FormatMessageW(
                    DWORD(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS),
                    nil,
                    error,
                    makeLanguageIdentifier(USHORT(LANG_NEUTRAL), USHORT(SUBLANG_DEFAULT)),
                    wrappedPtrToBuffer,
                    0,
                    nil
                )
            }
        }

        guard size > 0, let buffer else { return nil }

        let message = String(decodingCString: buffer, as: UTF16.self)

        LocalFree(buffer)

        return message

    }

}
#endif
