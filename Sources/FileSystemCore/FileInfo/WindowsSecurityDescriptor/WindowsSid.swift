#if canImport(WinSDK)

import PlatformCLib



public struct WindowsSid: @unchecked Sendable {

    private class Storage {
        var psid: UnsafeOwnedAutoResource
        init(psid: consuming UnsafeOwnedAutoResource) {
            self.psid = psid
        }
    }

    private let storage: Storage

    package var view: View {
        @_lifetime(borrow self)
        get {
            .init(psid: psid)
        }
    }

    package var psid: UnsafeUnownedResource {
        @_lifetime(borrow self)
        get {
            _overrideLifetime(self.storage.psid.unownedView(), borrowing: self)
        }
    }

    package init(psid: consuming UnsafeOwnedAutoResource) {
        self.storage = .init(psid: psid)
        precondition(IsValidSid(storage.psid.unsafeResourcePtr), "Invalid SID pointer")
    }

    public init?(string: String) {
        guard let sidPtr = try? Self.psid(fromString: string) else {
            return nil
        }
        self.init(psid: sidPtr)
    }

    public init(unsafeOwningPSid: PSID, freeingFunc: @escaping (PSID) -> Void) {
        self.init(psid: .init(owningResource: unsafeOwningPSid, freeingFunc: freeingFunc))
    }

    public var string: String {
        return try! Self.string(fromPSid: storage.psid)
    }

    public func withUnsafePSid<R: ~Copyable, E: Error>(_ body: (PSID) throws(E) -> R) throws(E) -> R {
        let result = try body(storage.psid.unsafeResourcePtr)
        precondition(IsValidSid(storage.psid.unsafeResourcePtr), "SID pointer corrupted")
        return result
    }


    public struct View: ~Escapable {

        let psid: UnsafeUnownedResource

        @_lifetime(copy psid)
        init(psid: UnsafeUnownedResource) {
            self.psid = psid
            precondition(IsValidSid(psid.unsafeResourcePtr), "Invalid SID pointer")
        }

        public var string: String {
            return try! WindowsSid.string(fromPSid: psid)
        }

        public func withUnsafePSid<R: ~Copyable, E: Error>(_ body: (PSID) throws(E) -> R) throws(E) -> R {
            let result = try body(psid.unsafeResourcePtr)
            precondition(IsValidSid(psid.unsafeResourcePtr), "SID pointer corrupted")
            return result
        }

    }

}


extension WindowsSid: Equatable, Hashable {

    public static func == (lhs: WindowsSid, rhs: WindowsSid) -> Bool {
        return EqualSid(lhs.psid.unsafeResourcePtr, rhs.psid.unsafeResourcePtr)
    }


    public func hash(into hasher: inout Hasher) {
        let length = GetLengthSid(psid.unsafeResourcePtr)
        let bufferPtr = UnsafeRawBufferPointer(start: psid.unsafeResourcePtr, count: Int(length))
        hasher.combine(bytes: bufferPtr)
    }

}



extension WindowsSid.View {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return EqualSid(lhs.psid.unsafeResourcePtr, rhs.psid.unsafeResourcePtr)
    }


    public func hash(into hasher: inout Hasher) {
        let length = GetLengthSid(psid.unsafeResourcePtr)
        let bufferPtr = UnsafeRawBufferPointer(start: psid.unsafeResourcePtr, count: Int(length))
        hasher.combine(bytes: bufferPtr)
    }

}



extension WindowsSid: CustomStringConvertible {

    public var description: String { string }

}



extension WindowsSid {

    public static var everyone: WindowsSid              { try! createWellKnownSid(type: WinWorldSid) }
    public static var administrators: WindowsSid        { try! createWellKnownSid(type: WinBuiltinAdministratorsSid) }
    public static var system: WindowsSid                { try! createWellKnownSid(type: WinLocalSystemSid) }
    public static var authenticatedUsers: WindowsSid    { try! createWellKnownSid(type: WinAuthenticatedUserSid) }
    public static var users: WindowsSid                 { try! createWellKnownSid(type: WinBuiltinUsersSid) }
    public static var localService: WindowsSid          { try! createWellKnownSid(type: WinLocalServiceSid) }
    public static var networkService: WindowsSid        { try! createWellKnownSid(type: WinNetworkServiceSid) }
    public static var annonymous: WindowsSid            { try! createWellKnownSid(type: WinAnonymousSid) }

    public static var creatorOwner: WindowsSid          { try! createWellKnownSid(type: WinCreatorOwnerSid) }
    public static var creatorGroup: WindowsSid          { try! createWellKnownSid(type: WinCreatorGroupSid) }


    package static func createWellKnownSid(type: WELL_KNOWN_SID_TYPE, domainSid: UnsafeUnownedResource? = nil) throws(SystemError) -> Self {

        // 256 bytes should be enough for any well-known SID
        var buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: 256, alignment: MemoryLayout<UInt8>.alignment)
        var size = DWORD(buffer.count)
        do {
            try execThrowingCFunction {
                CreateWellKnownSid(type, domainSid?.unsafeResourcePtr, buffer.baseAddress!, &size)
            }
            return .init(psid: .init(owningResource: buffer.baseAddress!, freeingFunc: { $0.deallocate() }))
        } catch let error where error.code == .system(.insufficientBuffer) {
            // ignore this error and retry
        }

        buffer.deallocate()
        buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<UInt8>.alignment)
        try execThrowingCFunction {
            CreateWellKnownSid(type, domainSid?.unsafeResourcePtr, buffer.baseAddress!, &size)
        }
        return .init(psid: .init(owningResource: buffer.baseAddress!, freeingFunc: { $0.deallocate() }))

    }

}



extension WindowsSid {

    package static func string(fromPSid sidPtr: UnsafeUnownedResource) throws(SystemError) -> String {

        var sidStrPtr = nil as LPWSTR?
        try execThrowingCFunction {
            ConvertSidToStringSidW(sidPtr.unsafeResourcePtr, &sidStrPtr)
        }
        guard let sidStrPtr else {
            try SystemError.assertError()
        }
        defer { LocalFree(sidStrPtr) }

        return String(decodingCString: sidStrPtr, as: UTF16.self)

    }


    package static func string(fromPSid sidPtr: borrowing UnsafeOwnedAutoResource) throws(SystemError) -> String {
        return try string(fromPSid: sidPtr.unownedView())
    }


    package static func psid(fromString sidStr: String) throws(SystemError) -> UnsafeOwnedAutoResource {

        var sidPtr = nil as PSID?
        try execThrowingCFunction {
            sidStr.withCString(encodedAs: UTF16.self) { sidStrPtr in 
                ConvertStringSidToSidW(sidStrPtr, &sidPtr)
            }
        }

        guard let sidPtr else {
            try SystemError.assertError()
        }

        return .init(owningResource: sidPtr, freeingFunc: { LocalFree($0) })

    }

}



extension WindowsSid.View {

    @_lifetime(copy psd)
    package static func make(
        unsafeExtractingOwnerFromPSD psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>
    ) -> (sid: Self, defaulted: Bool) {
        
        var ownerSidPtr = nil as PSID?
        var ownerDefaulted = false as WindowsBool
        GetSecurityDescriptorOwner(psd.unsafelyCastedMutableRawPtr, &ownerSidPtr, &ownerDefaulted)

        guard let ownerSidPtr else {
            fatalError("Failed to get owner SID from SECURITY_DESCRIPTOR")
        }
        
        return (.init(psid: .init(unownedResource: ownerSidPtr)), ownerDefaulted.boolValue)

    }


    @_lifetime(copy psd)
    package static func make(
        unsafeExtractingGroupFromPSD psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>
    ) -> (sid: Self, defaulted: Bool) {
        
        var groupSidPtr = nil as PSID?
        var groupDefaulted = false as WindowsBool
        GetSecurityDescriptorGroup(psd.unsafelyCastedMutableRawPtr, &groupSidPtr, &groupDefaulted)

        guard let groupSidPtr else {
            fatalError("Failed to get group SID from SECURITY_DESCRIPTOR")
        }
        
        return (.init(psid: .init(unownedResource: groupSidPtr)), groupDefaulted.boolValue)

    }

}


#endif