#if canImport(WinSDK)

import PlatformCLib
import struct SystemPackage.FilePermissions
import struct SystemPackage.CModeT



/// Wrapper for Windows SECURITY_DESCRIPTOR that is self-relative
public struct WindowsSelfRelativeSecurityDescriptor: ~Copyable {

    package let psd: UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>

    package init(psd: consuming UnsafeOwnedAutoPointer<SECURITY_DESCRIPTOR>) {
        self.psd = psd
        precondition(self.isValid(), "Invalid SECURITY_DESCRIPTOR pointer")
    }

    /// Create a new self-relative security descriptor from an existing pointer to a SECURITY_DESCRIPTOR.
    /// 
    /// - Parameters:
    ///   - sdPtr: A pointer to a SECURITY_DESCRIPTOR, whose ownership is transferred to this new instance.
    ///   - allocator: The allocator used to manage the memory of the SECURITY_DESCRIPTOR.
    /// 
    /// - Attention: The provided security descriptor must be self-relative.
    public init(unsafeOwningSdPtr sdPtr: PSECURITY_DESCRIPTOR, allocator: WindowsMemoryAllocatorType) {
        self.init(
            psd: .init(owningPointer: sdPtr.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self), 
            allocator: allocator.mappedInternalAllocatorType)
        )
    }

    /// Gets an unowned view of the security descriptor.
    public var view: WindowsSecurityDescriptorView {
        .init(psd: psd.unownedView())
    }

    /// Access the underlying SECURITY_DESCRIPTOR pointer in a closure.
    /// - Parameter body: A closure for accessing the SECURITY_DESCRIPTOR pointer.
    /// 
    /// - Warning: Do not return or store the pointer outside of the closure.
    public func withUnsafeSdPtr<R: ~Copyable, E: Error>(_ body: (PSECURITY_DESCRIPTOR) throws(E) -> R) throws(E) -> R {
        let result = try body(psd.unsafelyCastedMutableRawPtr)
        precondition(self.isValid(), "SECURITY_DESCRIPTOR pointer corrupted")
        return result
    }

    fileprivate func isValid() -> Bool {
        IsValidSecurityDescriptor(psd.unsafelyCastedMutableRawPtr) && self.control.contains(.selfRelative)
    }

    /// Creates a fully parsed representation of the security descriptor.
    public func fullyParsedDescriptor() -> WindowsSecurityDescriptor {
        return .init(unsafeFromSecurityDescriptorPtr: psd.unownedView())
    }

    /// Create an absolute copy of the self-relative security descriptor.
    public func makeAbsolute() -> WindowsAbsoluteSecurityDescriptor {
        do {
            return try .init(converting: self)
        } catch {
            fatalError(
                """
                Unexpected failure when converting WindowsSelfRelativeSecurityDescriptor to\
                WindowsAbsoluteSecurityDescriptor: \(error). This should not happen since the\
                descriptor should have been validated. It can be a severe memory corruption issue (e.g.: the\
                pointer used to initialize this type is unexpectedly mutated by some other owner) or a bug in\
                the implementation.
                """
            )
        }
    }

}



extension WindowsSelfRelativeSecurityDescriptor {

    /// The DACL state
    public var dacl: WindowsRawAclStateView {
        .init(unsafeExtractingFromPSD: psd.unownedView(), type: .dacl)
    }

    /// The SACL state
    public var sacl: WindowsRawAclStateView {
        .init(unsafeExtractingFromPSD: psd.unownedView(), type: .sacl)
    }

    /// The control flags and the revision number of the security descriptor.
    public var control: WindowsSecurityDescriptorControl {
        return WindowsSecurityDescriptorControl.make(unsafeExtractingFromPSD: psd.unownedView()).control
    }

    public var revision: DWORD {
        return WindowsSecurityDescriptorControl.make(unsafeExtractingFromPSD: psd.unownedView()).revision
    }

    /// The owner SID and whether it is defaulted, if present.
    public var owner: (sid: WindowsSid.View, defaulted: Bool)? {
        return WindowsSid.View.make(unsafeExtractingOwnerFromPSD: psd.unownedView())
    }

    /// The group SID and whether it is defaulted, if present.
    public var group: (sid: WindowsSid.View, defaulted: Bool)? {
        return WindowsSid.View.make(unsafeExtractingGroupFromPSD: psd.unownedView())
    }

}



extension WindowsSelfRelativeSecurityDescriptor {

    package init(converting absoluteDescriptor: borrowing WindowsAbsoluteSecurityDescriptor) throws(LowLevelError) {
        try self.init(converting: absoluteDescriptor.psd.unownedView().immutableCast())
    }


    package init(converting absoluteDescriptor: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) throws(LowLevelError) {

        var selfRelativeSDSize = 0 as DWORD
        guard 
            MakeSelfRelativeSD(absoluteDescriptor.unsafelyCastedMutableRawPtr, nil, &selfRelativeSDSize) == false, 
            GetLastError() == ERROR_INSUFFICIENT_BUFFER 
        else {
            try LowLevelError.assertError()
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
