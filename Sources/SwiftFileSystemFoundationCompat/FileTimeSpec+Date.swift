import struct Foundation.Date
import struct Foundation.TimeInterval
import struct SwiftFileSystem.FileTimeSpec



extension Date {
    @usableFromInline static let timeIntervalBetween1601AndReferenceDate: TimeInterval = 12622780800
}



extension FileTimeSpec {
    
    public init(from date: Date) {
        #if canImport(WinSDK)
        let timeInterval = date.timeIntervalSinceReferenceDate + Date.timeIntervalBetween1601AndReferenceDate
        #else
        let timeInterval = date.timeIntervalSinceReferenceDate + Date.timeIntervalBetween1970AndReferenceDate
        #endif
        let seconds = Int(timeInterval)
        let nanoseconds = Int((timeInterval - TimeInterval(seconds)) * 1_000_000_000)
        self.init(seconds: seconds, nanoseconds: nanoseconds)
    }
    
    
    @inlinable
    public var date: Date {
        #if canImport(WinSDK)
        .init(timeIntervalSinceReferenceDate: TimeInterval(seconds) - Date.timeIntervalBetween1601AndReferenceDate + TimeInterval(nanoseconds) / 1_000_000_000)
        #else
        .init(timeIntervalSinceReferenceDate: TimeInterval(seconds) - Date.timeIntervalBetween1970AndReferenceDate + TimeInterval(nanoseconds) / 1_000_000_000)
        #endif
    }
    
}
