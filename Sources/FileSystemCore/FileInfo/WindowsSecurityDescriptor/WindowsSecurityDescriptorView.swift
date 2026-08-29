#if canImport(WinSDK)

import PlatformCLib

public struct WindowsSecurityDescriptorView: ~Escapable {

    package let psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>

    @_lifetime(copy psd)
    package init(psd: UnsafeUnownedPointer<SECURITY_DESCRIPTOR>) {
        self.psd = psd
    }

    public init(unsafePSD: PSECURITY_DESCRIPTOR) {
        self.psd = .init(unownedPointer: unsafePSD.assumingMemoryBound(to: SECURITY_DESCRIPTOR.self))
    }

}



extension WindowsSecurityDescriptorView {

    public var revision: DWORD {
        var revision = 0 as DWORD
        var control = 0 as SECURITY_DESCRIPTOR_CONTROL
        GetSecurityDescriptorControl(psd.unsafelyCastedMutableRawPtr, &control, &revision)
        return revision
    }

    public var control: WindowsSecurityDescriptorControl {
        get {
            return .make(unsafeExtractingFromPSD: psd).control
        }
    }

    public var dacl: WindowsRawAcl.View? {
        @_lifetime(copy self)
        get {
            WindowsRawAclStateView(unsafeExtractingFromPSD: psd, type: .dacl).value
        }
    }

    public var sacl: WindowsRawAcl.View? {
        @_lifetime(copy self)
        get {
            WindowsRawAclStateView(unsafeExtractingFromPSD: psd, type: .sacl).value
        }
    }


    public var owner: WindowsSid.View? {
        @_lifetime(copy self)
        get {
            WindowsSid.View.make(unsafeExtractingOwnerFromPSD: psd)?.sid
        }
    }


    public var group: WindowsSid.View? {
        @_lifetime(copy self)
        get {
            WindowsSid.View.make(unsafeExtractingGroupFromPSD: psd)?.sid
        }
    }

}



// A read-only view whose storage the lifetime system keeps immutably borrowed for as long
// as the view lives, so concurrent reads from any thread are safe (the same argument that
// makes RawSpan Sendable); @unchecked only because the stored pointer wrapper is not
// Sendable. Mutating the storage through an Unsafe escape hatch while a view is shared
// remains the caller's responsibility, exactly as it is single-threaded.
extension WindowsSecurityDescriptorView: @unchecked Sendable {}

#endif