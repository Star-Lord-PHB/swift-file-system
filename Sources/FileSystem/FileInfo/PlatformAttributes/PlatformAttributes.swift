import SystemPackage
import CFileSystem

#if canImport(WinSDK)
import WinSDK
#endif



protocol PlatformFileAttributesProtocol: Sendable, OptionSet, Hashable, CustomStringConvertible where RawValue == RawBitType, Self.Element == Self {
    associatedtype RawBitType: FixedWidthInteger
    static var _allWithNameAsArray: [(Self, StaticString)]? { get }
    static var _all: Self { get }
}


extension PlatformFileAttributesProtocol {

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


    @inlinable
    public static func | (left: Self, right: Self) -> Self {
        .init(rawValue: left.rawValue | right.rawValue)
    }


    @usableFromInline static var _allWithNameAsArray: [(Self, StaticString)]? { nil }
    @usableFromInline static var _all: Self { [] }
    @inlinable public static var all: Self { _all }

}



public struct PlatformFileAttributes: PlatformFileAttributesProtocol {

    public typealias RawBitType = CInterop.PlatformFileAttribute


    @_alwaysEmitIntoClient
    public var rawValue: RawBitType


    @inlinable
    public init(rawValue: RawBitType) {
        self.rawValue = rawValue
    }


    @inlinable
    mutating func set(_ value: Bool, for attr: RawBitType) {
        if value {
            rawValue |= attr
        } else {
            rawValue &= ~attr
        }
    }

}