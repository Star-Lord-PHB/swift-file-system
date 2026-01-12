#if canImport(WinSDK)

import PlatformCLib



public struct WindowsSid: @unchecked Sendable {

    // TODO: switch to raw pointer implementation to avoid reference counting overhead

    private class Storage {
        var psid: UnsafeOwnedAutoResource
        init(psid: consuming UnsafeOwnedAutoResource) {
            self.psid = psid
        }
    }

    private let storage: Storage

    var view: View {
        @_lifetime(borrow self)
        get {
            .init(psid: psid)
        }
    }

    var psid: UnsafeUnownedResource {
        @_lifetime(borrow self)
        get {
            _overrideLifetime(self.storage.psid.unownedView(), borrowing: self)
        }
    }

    init(psid: consuming UnsafeOwnedAutoResource) {
        self.storage = .init(psid: psid)
        precondition(self.isValid(), "Invalid SID pointer")
    }

    public init?(string: String) {
        guard let sidPtr = try? WindowsAPI.stringToPsid(sidStr: string) else {
            return nil
        }
        self.storage = .init(psid: sidPtr)
    }

    public init(unsafeOwningPSid: PSID, freeingFunc: @escaping (PSID) -> Void) {
        self.init(psid: .init(owningResource: unsafeOwningPSid, freeingFunc: freeingFunc))
    }

    public var string: String {
        return try! WindowsAPI.pSidToString(sidPtr: storage.psid.unownedView())
    }

    public func isValid() -> Bool {
        return IsValidSid(storage.psid.unsafeResourcePtr)
    }

    public func checkedString() throws(SystemError) -> String {
        return try WindowsAPI.pSidToString(sidPtr: storage.psid.unownedView())
    }

    public func withUnsafePSid<R: ~Copyable, E: Error>(_ body: (PSID) throws(E) -> R) throws(E) -> R {
        let result = try body(storage.psid.unsafeResourcePtr)
        precondition(self.isValid(), "SID pointer corrupted")
        return result
    }


    public struct View: ~Escapable {

        let psid: UnsafeUnownedResource

        @_lifetime(copy psid)
        init(psid: UnsafeUnownedResource) {
            self.psid = psid
            precondition(isValid(), "Invalid SID pointer")
        }

        public var string: String {
            return try! WindowsAPI.pSidToString(sidPtr: psid)
        }

        public func isValid() -> Bool {
            return IsValidSid(psid.unsafeResourcePtr)
        }

        public func checkedString() throws(SystemError) -> String {
            return try WindowsAPI.pSidToString(sidPtr: psid)
        }

        public func withUnsafePSid<R: ~Copyable, E: Error>(_ body: (PSID) throws(E) -> R) throws(E) -> R {
            let result = try body(psid.unsafeResourcePtr)
            precondition(isValid(), "SID pointer corrupted")
            return result
        }

    }

}


extension WindowsSid: Equatable, Hashable {

    public static func == (lhs: WindowsSid, rhs: WindowsSid) -> Bool {
        return WindowsAPI.equalSid(sid1: lhs.psid, sid2: rhs.psid)
    }


    public func hash(into hasher: inout Hasher) {
        let length = WindowsAPI.getSidLength(sidPtr: psid)
        let bufferPtr = UnsafeRawBufferPointer(start: psid.unsafeResourcePtr, count: Int(length))
        hasher.combine(bytes: bufferPtr)
    }

}



extension WindowsSid.View {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return WindowsAPI.equalSid(sid1: lhs.psid, sid2: rhs.psid)
    }


    public func hash(into hasher: inout Hasher) {
        let length = WindowsAPI.getSidLength(sidPtr: psid)
        let bufferPtr = UnsafeRawBufferPointer(start: psid.unsafeResourcePtr, count: Int(length))
        hasher.combine(bytes: bufferPtr)
    }

}



extension WindowsSid: CustomStringConvertible {

    public var description: String { string }

}



extension WindowsSid {

    public static var everyone: WindowsSid              { .init(psid: try! WindowsAPI.createWellKnownSid(type: WinWorldSid)) }
    public static var administrators: WindowsSid        { .init(psid: try! WindowsAPI.createWellKnownSid(type: WinBuiltinAdministratorsSid)) }
    public static var system: WindowsSid                { .init(psid: try! WindowsAPI.createWellKnownSid(type: WinLocalSystemSid)) }
    public static var authenticatedUsers: WindowsSid    { .init(psid: try! WindowsAPI.createWellKnownSid(type: WinAuthenticatedUserSid)) }
    public static var users: WindowsSid                 { .init(psid: try! WindowsAPI.createWellKnownSid(type: WinBuiltinUsersSid)) }
    public static var localService: WindowsSid          { .init(psid: try! WindowsAPI.createWellKnownSid(type: WinLocalServiceSid)) }
    public static var networkService: WindowsSid        { .init(psid: try! WindowsAPI.createWellKnownSid(type: WinNetworkServiceSid)) }
    public static var annonymous: WindowsSid            { .init(psid: try! WindowsAPI.createWellKnownSid(type: WinAnonymousSid)) }

    public static var creatorOwner: WindowsSid          { .init(psid: try! WindowsAPI.createWellKnownSid(type: WinCreatorOwnerSid)) }
    public static var creatorGroup: WindowsSid          { .init(psid: try! WindowsAPI.createWellKnownSid(type: WinCreatorGroupSid)) }

}

#endif