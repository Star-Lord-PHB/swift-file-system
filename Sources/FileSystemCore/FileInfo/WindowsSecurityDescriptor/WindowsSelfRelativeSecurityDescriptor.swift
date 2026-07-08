#if canImport(WinSDK)

import PlatformCLib
import struct SystemPackage.FilePermissions
import struct SystemPackage.CModeT



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

    public var view: WindowsSecurityDescriptorView {
        .init(psd: psd.unownedView())
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
        return .init(unsafeFromSecurityDescriptorPtr: psd.unownedView())
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

    public var dacl: WindowsRawAclState {
        .init(unsafeExtractingFromPSD: psd.unownedView(), type: .dacl)
    }

    public var sacl: WindowsRawAclState {
        .init(unsafeExtractingFromPSD: psd.unownedView(), type: .sacl)
    }

    public var control: (control: WindowsSecurityDescriptorControl, revision: DWORD) {
        return WindowsSecurityDescriptorControl.make(unsafeExtractingFromPSD: psd.unownedView())
    }

    public var owner: (sid: WindowsSid.View, defaulted: Bool)? {
        return WindowsSid.View.make(unsafeExtractingOwnerFromPSD: psd.unownedView())
    }

    public var group: (sid: WindowsSid.View, defaulted: Bool)? {
        return WindowsSid.View.make(unsafeExtractingGroupFromPSD: psd.unownedView())
    }

}



extension WindowsSelfRelativeSecurityDescriptor {

    package init(converting absoluteDescriptor: borrowing WindowsAbsoluteSecurityDescriptor) throws(SystemError) {
        try self.init(converting: absoluteDescriptor.psd.unownedView().immutableCast())
    }


    package init(converting absoluteDescriptor: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) throws(SystemError) {

        var selfRelativeSDSize = 0 as DWORD
        guard 
            MakeSelfRelativeSD(absoluteDescriptor.unsafelyCastedMutableRawPtr, nil, &selfRelativeSDSize) == false, 
            GetLastError() == ERROR_INSUFFICIENT_BUFFER 
        else {
            try SystemError.assertError()
        }

        let selfRelativeSDPtr = UnsafeOwnedRawAutoPointer.swiftAllocate(
            byteCount: Int(selfRelativeSDSize), 
            alignment: MemoryLayout<SECURITY_DESCRIPTOR>.alignment
        ).assumingMemoryBound(to: SECURITY_DESCRIPTOR.self)

        try execThrowingCFunction {
            MakeSelfRelativeSD(absoluteDescriptor.unsafelyCastedMutableRawPtr, selfRelativeSDPtr.unsafelyCastedMutableRawPtr, &selfRelativeSDSize)
        }

        self.init(psd: selfRelativeSDPtr)

    }

}

#endif 
