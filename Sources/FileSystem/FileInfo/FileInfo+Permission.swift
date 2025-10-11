import Foundation
import SystemPackage


extension FileInfo {

    public struct Permission: Sendable {

        #if canImport(WinSDK)

        // TODO: define permissions on Windows

        #else

        public var rawValue: CModeT

        @inlinable
        public init(rawValue: CModeT) {
            self.rawValue = rawValue
        }

        #endif // canImport(WinSDK)

    }

}



#if !canImport(WinSDK)
extension FileInfo.Permission: OptionSet {

    @inlinable
    public init(rawValue: FilePermissions) {
        self.rawValue = rawValue.rawValue
    }

    @inlinable public static var ownerRead: FileInfo.Permission { .init(rawValue: .ownerRead) }
    @inlinable public static var ownerWrite: FileInfo.Permission { .init(rawValue: .ownerWrite) }
    @inlinable public static var ownerExecute: FileInfo.Permission { .init(rawValue: .ownerExecute) }
    @inlinable public static var groupRead: FileInfo.Permission { .init(rawValue: .groupRead) }
    @inlinable public static var groupWrite: FileInfo.Permission { .init(rawValue: .groupWrite) }
    @inlinable public static var groupExecute: FileInfo.Permission { .init(rawValue: .groupExecute) }
    @inlinable public static var otherRead: FileInfo.Permission { .init(rawValue: .otherRead) }
    @inlinable public static var otherWrite: FileInfo.Permission { .init(rawValue: .otherWrite) }
    @inlinable public static var otherExecute: FileInfo.Permission { .init(rawValue: .otherExecute) }
    @inlinable public static var setUserID: FileInfo.Permission { .init(rawValue: .setUserID) }
    @inlinable public static var setGroupID: FileInfo.Permission { .init(rawValue: .setGroupID) }
    @inlinable public static var saveText: FileInfo.Permission { .init(rawValue: .saveText) }

    @inlinable
    public static func | (lhs: FileInfo.Permission, rhs: FileInfo.Permission) -> FileInfo.Permission {
        return lhs.union(rhs)
    }

}
#endif



extension FileInfo {

    public func canRead(by user: borrowing FileInfo.User) -> Bool {

    #if os(Windows)
        // TODO 
    #else 
        if (user.uid == owner.uid) {
            return permissions.contains(.ownerRead)
        } else if (user.gid == owner.gid) {
            return permissions.contains(.groupRead)
        } else {
            return permissions.contains(.otherRead)
        }
    #endif 

    }


    public func canWrite(by user: borrowing FileInfo.User) -> Bool {

    #if os(Windows)
        // TODO 
    #else 
        if (user.uid == owner.uid) {
            return permissions.contains(.ownerWrite)
        } else if (user.gid == owner.gid) {
            return permissions.contains(.groupWrite)
        } else {
            return permissions.contains(.otherWrite)
        }
    #endif 

    }


    public func canExecute(by user: borrowing FileInfo.User) -> Bool {

    #if os(Windows)
        // TODO 
    #else 
        if (user.uid == owner.uid) {
            return permissions.contains(.ownerExecute)
        } else if (user.gid == owner.gid) {
            return permissions.contains(.groupExecute)
        } else {
            return permissions.contains(.otherExecute)
        }
    #endif 

    }

}