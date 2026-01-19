#if canImport(WinSDK)

import PlatformCLib



public struct WindowsSelfRelativeSecurityDescriptor: ~Copyable {

    let psd: UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>

    init(psd: consuming UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>) {
        self.psd = psd
        precondition(self.isValid(), "Invalid SECURITY_DESCRIPTOR pointer")
    }

    public init(unsafeOwningSdPtr: PSECURITY_DESCRIPTOR, allocator: WindowsMemoryAllocatorType) {
        self.init(
            psd: .init(owningPointer: unsafeOwningSdPtr.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self), 
            allocator: allocator.mappedInternalAllocatorType)
        )
    }

    public func withUnsafeSdPtr<R: ~Copyable, E: Error>(_ body: (PSECURITY_DESCRIPTOR) throws(E) -> R) throws(E) -> R {
        let result = try body(psd.unsafelyCastedMutableRawPtr)
        precondition(self.isValid(), "SECURITY_DESCRIPTOR pointer corrupted")
        return result
    }

    public func isValid() -> Bool {
        return IsValidSecurityDescriptor(psd.unsafelyCastedMutableRawPtr)
    }

    public func fullyParsedDescriptor() throws(SystemError) -> WindowsSecurityDescriptor {
        try .init(unsafeFromSecurityDescriptorPtr: psd.unownedView())
    }

}



extension WindowsSelfRelativeSecurityDescriptor {

    public var dacl: WindowsRawAclView? {
        .init(psd: psd.unownedView(), type: .dacl)
    }

    public var sacl: WindowsRawAclView? {
        .init(psd: psd.unownedView(), type: .sacl)
    }

    public var control: (control: WindowsSecurityDescriptorControl, revision: DWORD) {
        let (control, revision) = try! WindowsAPI.getControl(from: psd.unownedView())
        return (.init(unsafeRawValue: control), revision)
    }

    public var owner: (sid: WindowsSid.View, defauted: Bool) {
        let (ownerSidPtr, defaulted) = try! WindowsAPI.getOwnerSid(from: psd.unownedView())
        return (.init(psid: ownerSidPtr), defaulted)
    }

    public var group: (sid: WindowsSid.View, defauted: Bool) {
        let (groupSidPtr, defaulted) = try! WindowsAPI.getGroupSid(from: psd.unownedView())
        return (.init(psid: groupSidPtr), defaulted)
    }

}

#endif 