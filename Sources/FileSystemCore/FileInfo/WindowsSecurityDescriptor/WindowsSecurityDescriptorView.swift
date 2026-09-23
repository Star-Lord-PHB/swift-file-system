#if canImport(WinSDK)

import PlatformCLib


/// An unowned view of a Windows Security Descriptor
public struct WindowsSecurityDescriptorView: ~Escapable {

    package let psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>

    @_lifetime(copy psd)
    package init(psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) {
        self.psd = psd
    }

    /// Creates an unowned view from a pointer to a native SECURITY_DESCRIPTOR.
    /// 
    /// - Warning: The caller must ensure that the pointer is valid throughout the lifetime of the view.
    public init(unsafePSD: PSECURITY_DESCRIPTOR) {
        self.psd = .init(unownedPointer: unsafePSD.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self))
    }

}



extension WindowsSecurityDescriptorView {

    /// The revision number of the security descriptor
    public var revision: DWORD {
        var revision = 0 as DWORD
        var control = 0 as SECURITY_DESCRIPTOR_CONTROL
        GetSecurityDescriptorControl(psd.unsafelyCastedMutableRawPtr, &control, &revision)
        return revision
    }

    /// The control flags of the security descriptor
    public var control: WindowsSecurityDescriptorControl {
        get {
            return .make(unsafeExtractingFromPSD: psd).control
        }
    }

    /// The DACL
    public var dacl: WindowsRawAcl.View? {
        @_lifetime(copy self)
        get {
            WindowsRawAclStateView(unsafeExtractingFromPSD: psd, type: .dacl).value
        }
    }

    /// The SACL
    public var sacl: WindowsRawAcl.View? {
        @_lifetime(copy self)
        get {
            WindowsRawAclStateView(unsafeExtractingFromPSD: psd, type: .sacl).value
        }
    }


    /// The owner SID
    public var owner: WindowsSid.View? {
        @_lifetime(copy self)
        get {
            WindowsSid.View.make(unsafeExtractingOwnerFromPSD: psd)?.sid
        }
    }


    /// The group SID
    public var group: WindowsSid.View? {
        @_lifetime(copy self)
        get {
            WindowsSid.View.make(unsafeExtractingGroupFromPSD: psd)?.sid
        }
    }

}



extension WindowsSecurityDescriptorView: @unchecked Sendable {}

#endif
