import PlatformCLib



public struct FileIdentifier: Sendable, Equatable, Hashable {

    public let fileId: PlatformInteropTypes.FileId
    public let deviceId: PlatformInteropTypes.DeviceId

    public init(fileId: PlatformInteropTypes.FileId, deviceId: PlatformInteropTypes.DeviceId) {
        self.fileId = fileId
        self.deviceId = deviceId
    }

}



#if canImport(WinSDK)
extension FileIdentifier {

    public init(fileId: FILE_ID_128, deviceId: UInt64) {
        self.fileId = fileId.uint128
        self.deviceId = deviceId
    }

}



extension FILE_ID_128 {
    public var uint128: UInt128 {
        withUnsafeBytes(of: self.Identifier) { ptr in 
            ptr.withMemoryRebound(to: UInt128.self) { reboundPtr in
                reboundPtr[0]
            }
        }
    }
}
#endif
