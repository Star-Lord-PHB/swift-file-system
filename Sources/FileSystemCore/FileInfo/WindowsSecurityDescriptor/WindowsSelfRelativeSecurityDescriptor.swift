#if canImport(WinSDK)

import PlatformCLib



public struct WindowsSelfRelativeSecurityDescriptor: ~Copyable {

    package let psd: UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>

    package init(psd: consuming UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>) {
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

    fileprivate func isValid() -> Bool {
        IsValidSecurityDescriptor(psd.unsafelyCastedMutableRawPtr) && self.control.control.contains(.selfRelative)
    }

    public func fullyParsedDescriptor() -> WindowsSecurityDescriptor {
        do {
            return try .init(unsafeFromSecurityDescriptorPtr: psd.unownedView())
        } catch {
            fatalError(
                """
                Unexpected failure when parsing WindowsSelfRelativeSecurityDescriptor: \(error.code.description).\
                This should not happen since the descriptor should have been validated. It can be a severe memory\
                corruption issue (e.g.: the pointer used to initialize this type is unexpectedly mutated by some\
                other owner) or a bug in the implementation.
                """
            )
        }
    }

    public func makeAbsolute() -> WindowsAbsoluteSecurityDescriptor {
        do {
            return try .init(converting: self)
        } catch {
            fatalError(
                """
                Unexpected failure when converting WindowsSelfRelativeSecurityDescriptor to\
                WindowsAbsoluteSecurityDescriptor: \(error.code.description). This should not happen since the\
                descriptor should have been validated. It can be a severe memory corruption issue (e.g.: the\
                pointer used to initialize this type is unexpectedly mutated by some other owner) or a bug in\
                the implementation.
                """
            )
        }
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