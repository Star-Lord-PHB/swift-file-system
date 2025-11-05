import PlatformCLib


extension FileError {

    public struct PlatformErrorCode: Sendable, RawRepresentable, CustomStringConvertible {

        #if canImport(WinSDK)
        public typealias RawBitType = DWORD
        #else
        public typealias RawBitType = CInt
        #endif


        public let rawValue: RawBitType


        public init?(rawValue: RawBitType) {
            guard rawValue != 0 else { return nil }
            self.rawValue = rawValue
        }

    }

}



extension FileError.PlatformErrorCode {

    @inlinable
    public var description: String {
        #if canImport(WinSDK)
        return errorCodeDescription(for: rawValue) ?? "Unknown error"
        #else
        guard let message = strerror(rawValue) else { return "Unknown error" }
        return String(cString: message)
        #endif
    }


    @inlinable
    public static func fromLastError() -> FileError.PlatformErrorCode? {
        #if canImport(WinSDK)
        return .init(rawValue: GetLastError())
        #else
        return .init(rawValue: errno)
        #endif
    }

}



extension FileError {

    @inlinable
    public init?(code: PlatformErrorCode.RawBitType, operationDescription: OperationDescription) {
        guard let errorCode = PlatformErrorCode(rawValue: code) else { return nil }
        self.init(code: errorCode, operationDescription: operationDescription)
    }


    @inlinable
    public static func fromLastError(operationDescription: @autoclosure () -> OperationDescription) -> FileError? {
        guard let errorCode = PlatformErrorCode.fromLastError() else { return nil }
        return .init(code: errorCode, operationDescription: operationDescription())
    }


    @inlinable
    public static func assertError(operationDescription: OperationDescription) throws(FileError) -> Never {
        let errorCode = PlatformErrorCode.fromLastError()
        throw FileError(code: errorCode, operationDescription: operationDescription)
    }


    @inlinable
    public static func check(operationDescription: @autoclosure () -> OperationDescription) throws(FileError) {
        if let error = fromLastError(operationDescription: operationDescription()) {
            throw error
        }
    }

}