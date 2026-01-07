#if canImport(WinSDK)

import PlatformCLib



public struct WindowsSid {

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
            .init(unownedResource: self.storage.psid.unsafeResourcePtr)
        }
    }

    init(psid: consuming UnsafeOwnedAutoResource) {
        self.storage = .init(psid: psid)
        precondition(self.isValid(), "Invalid SID pointer")
    }

    public init?(sidStr: String) {
        guard let sidPtr = try? WindowsAPI.stringToPsid(sidStr: sidStr) else {
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

    public func withUnsafePSid<R: ~Copyable, E: Error>(_ body: (PSECURITY_DESCRIPTOR) throws(E) -> R) throws(E) -> R {
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

        var string: String {
            return try! WindowsAPI.pSidToString(sidPtr: psid)
        }

        func isValid() -> Bool {
            return IsValidSid(psid.unsafeResourcePtr)
        }

        func checkedString() throws(SystemError) -> String {
            return try WindowsAPI.pSidToString(sidPtr: psid)
        }

        func withUnsafePSid<R: ~Copyable, E: Error>(_ body: (PSECURITY_DESCRIPTOR) throws(E) -> R) throws(E) -> R {
            let result = try body(psid.unsafeResourcePtr)
            precondition(isValid(), "SID pointer corrupted")
            return result
        }

    }

}

#endif