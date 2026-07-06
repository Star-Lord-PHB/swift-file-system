import SystemPackage
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
    public var rawValue: CInterop.PlatformFileAttribute


    @inlinable
    public init(rawValue: CInterop.PlatformFileAttribute) {
        self.rawValue = rawValue
    }


    @inlinable 
    public var isReadOnly: Bool? {
        get { _isReadOnly }
        set { _isReadOnly = newValue }
    }

    @inlinable
    public var isImmutable: Bool? {
        get { _isImmutable }
        set { _isImmutable = newValue }
    }

    @inlinable 
    public var isCompressed: Bool? {
        _isCompressed
    }

    @inlinable 
    public var isAppendOnly: Bool? {
        get { _isAppendOnly }
        set { _isAppendOnly = newValue }
    }

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
    #elseif canImport(Glibc) || canImport(Musl)
    public typealias CurrentPlatform = Linux
    #elseif canImport(WinSDK)
    public typealias CurrentPlatform = Windows
    #else 
    public typealias CurrentPlatform = UnknownPlatform
    #endif

    @inlinable
    public static var currentPlatform: CurrentPlatform.Type { CurrentPlatform.self }

}