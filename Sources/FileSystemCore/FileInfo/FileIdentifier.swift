import PlatformCLib
import SystemPackage



public struct FileIdentifier: Sendable, Equatable, Hashable {

    public let fileId: CInterop.FileId
    public let deviceId: CInterop.DeviceId

    public init(fileId: CInterop.FileId, deviceId: CInterop.DeviceId) {
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