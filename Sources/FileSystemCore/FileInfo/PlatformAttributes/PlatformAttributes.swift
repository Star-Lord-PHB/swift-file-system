import CFileSystem


@usableFromInline
protocol PlatformFileAttributesProtocol: Sendable, ExpressibleByArrayLiteral {}



extension PlatformFileAttributesProtocol {

    @usableFromInline static var _allWithNameAsArray: [(Self, StaticString)]? { nil }
    @usableFromInline static var _all: Self { [] }

    @usableFromInline
    var _isReadOnly: Bool? {
        get { nil }
        set {  }
    }
    @usableFromInline
    var _isImmutable: Bool? {
        get { nil }
        set { }
    }
    @usableFromInline
    var _isCompressed: Bool? {
        nil
    }
    @usableFromInline
    var _isAppendOnly: Bool? {
        get { nil }
        set {  }
    }
    @usableFromInline
    var _isEncrypted: Bool? {
        nil
    }

}



public struct PlatformFileAttributes: PlatformFileAttributesProtocol, OptionSet, Hashable {

    @_alwaysEmitIntoClient
    public var rawValue: PlatformInteropTypes.FileAttribute


    @inlinable
    public init(rawValue: PlatformInteropTypes.FileAttribute) {
        self.rawValue = rawValue
    }


    /// Whether the file is read-only, and `nil` if not available on the current platform
    /// 
    /// Supported on FreeBSD and Windows
    @inlinable 
    public var isReadOnly: Bool? {
        get { _isReadOnly }
        set { _isReadOnly = newValue }
    }

    /// Whether the file is immutable, and `nil` if not available on the current platform
    /// 
    /// Supported on BSD, Darwin and Linux
    @inlinable
    public var isImmutable: Bool? {
        get { _isImmutable }
        set { _isImmutable = newValue }
    }

    /// Whether the file is compressed, and `nil` if not available on the current platform
    /// 
    /// Supported on Darwin, Linux and Windows
    @inlinable 
    public var isCompressed: Bool? {
        _isCompressed
    }

    /// Whether the file is append-only, and `nil` if not available on the current platform
    /// 
    /// Supported on BSD, Darwin and Linux
    @inlinable 
    public var isAppendOnly: Bool? {
        get { _isAppendOnly }
        set { _isAppendOnly = newValue }
    }

    /// Whether the file is encrypted, and `nil` if not available on the current platform
    /// 
    /// Supported on Linux and Windows
    @inlinable 
    public var isEncrypted: Bool? {
        _isEncrypted
    }


    @inlinable public static var all: Self { _all }

}



extension PlatformFileAttributes: CustomStringConvertible {

    @inlinable
    public var description: String {
        let componentString = Self._allWithNameAsArray?
            .compactMap { (attr, name) in
                self.contains(attr) ? name.description : nil
            }
            .joined(separator: ", ")
        if let componentString {
            return "0x\(String(rawValue, radix: 16)) [\(componentString)]"
        } else {
            return "0x\(String(rawValue, radix: 16))"
        }
    }
    
}



extension PlatformFileAttributes {

    public enum UnknownPlatform {}

    #if canImport(Darwin)
    public typealias CurrentPlatform = Darwin
    #elseif os(FreeBSD)
    public typealias CurrentPlatform = FreeBSD
    #elseif os(OpenBSD)
    public typealias CurrentPlatform = OpenBSD
    #elseif os(Linux) || os(Android)
    public typealias CurrentPlatform = Linux
    #elseif canImport(WinSDK)
    public typealias CurrentPlatform = Windows
    #else 
    public typealias CurrentPlatform = UnknownPlatform
    #endif

    /// Namespace for platform specific file attributes on the current platform
    @inlinable
    public static var currentPlatform: CurrentPlatform.Type { CurrentPlatform.self }

}
