#if canImport(WinSDK)

import PlatformCLib


public protocol WindowRawAclProtocol: ~Copyable, ~Escapable {
    func withUnsafePACL<R: ~Copyable, E: Error>(_ operation: (PACL) throws(E) -> R) throws(E) -> R
}



extension WindowRawAclProtocol where Self: ~Copyable & ~Escapable {

    public var revision: BYTE {
        return self.withUnsafePACL { pacl in
            pacl.pointee.AclRevision
        }
    }

    public var aceCount: WORD {
        return self.withUnsafePACL { pacl in
            pacl.pointee.AceCount
        }
    }

    public subscript(_ index: Int) -> WindowsRawAceView {
        @_lifetime(borrow self)
        get {
            precondition(index >= 0 && index < Int(self.aceCount), "Index out of bounds")
            let acePtr = self.withUnsafePACL { pacl in
                var acePtr = nil as LPVOID?
                do throws(LowLevelError) {
                    try execThrowingCFunction {
                        GetAce(pacl, DWORD(index), &acePtr)
                    }
                    guard let acePtr else {
                        try LowLevelError.assertError()
                    }
                    return acePtr
                } catch {
                    fatalError("Failed to get ACE at index \(index): \(error)")
                }
            }
            return .init(pace: .init(unownedPointer: acePtr))
        }
    }

    public func forEach<E: Error>(_ body: (WindowsRawAceView) throws(E) -> Void) throws(E) {
        for i in 0 ..< Int(self.aceCount) {
            try body(self[i])
        }
    }


    public func map<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T) throws(E) -> [T] {
        var results = [T]()
        for i in 0 ..< Int(self.aceCount) {
            let result = try transform(self[i])
            results.append(result)
        }
        return results
    }


    public func reduce<T: ~Copyable, E: Error>(
        _ initialResult: consuming T,
        _ nextPartialResult: (consuming T, WindowsRawAceView) throws(E) -> T
    ) throws(E) -> T {
        var result = initialResult
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            result = try nextPartialResult(result, aceView)
        }
        return result
    }

    public func compactMap<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T?) throws(E) -> [T] {
        var results = [T]()
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            if let result = try transform(aceView) {
                results.append(result)
            }
        }
        return results
    }

    public func reduce<T: ~Copyable, E: Error>(
        into initialResult: consuming T,
        _ updateAccumulatingResult: (inout T, WindowsRawAceView) throws(E) -> Void
    ) throws(E) -> T {
        var result = initialResult
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            try updateAccumulatingResult(&result, aceView)
        }
        return result
    }

    public var first: WindowsRawAceView? {
        @_lifetime(borrow self)
        get {
            guard self.aceCount > 0 else { return nil }
            return self[0]
        }
    }


    @_lifetime(borrow self)
    public func first(where predicate: (WindowsRawAceView) throws -> Bool) rethrows -> WindowsRawAceView? {
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            if try predicate(aceView) {
                return aceView
            }
        }
        return nil
    }

}



public struct WindowsRawAceView: ~Escapable {

    package let pace: UnsafeUnownedRawPointer

    @_lifetime(copy pace)
    package init(pace: UnsafeUnownedRawPointer) {
        self.pace = pace
    }

    @_lifetime(immortal)
    package init(unsafeBorrowingAcePtr: LPVOID) {
        self.pace = .init(unownedPointer: unsafeBorrowingAcePtr)
    }

    public var type: WindowsACEType {
        let headerPtr = pace.bindMemory(to: ACE_HEADER.self, capacity: 1)
        return .init(rawValue: headerPtr.pointee.AceType)
    }

    public var flags: WindowsACEFlags {
        let headerPtr = pace.bindMemory(to: ACE_HEADER.self, capacity: 1)
        return .init(rawValue: headerPtr.pointee.AceFlags)
    }

    public var size: WORD {
        let headerPtr = pace.bindMemory(to: ACE_HEADER.self, capacity: 1)
        return headerPtr.pointee.AceSize
    }

    public var permission: (sid: WindowsSid.View, mask: WindowsAccessMask) {
        @_lifetime(copy self)
        get {
            let mask: WindowsAccessMask
            let sid: WindowsSid.View

            switch type {
                case .allow: do {
                    let allowAcePtr = pace.bindMemory(to: ACCESS_ALLOWED_ACE.self, capacity: 1)
                    mask = .init(rawValue: allowAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: allowAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
                case .deny: do {
                    let denyAcePtr = pace.bindMemory(to: ACCESS_DENIED_ACE.self, capacity: 1)
                    mask = .init(rawValue: denyAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: denyAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
                case .audit: do {
                    let auditAcePtr = pace.bindMemory(to: SYSTEM_AUDIT_ACE.self, capacity: 1)
                    mask = .init(rawValue: auditAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: auditAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
                case .alarm: do {
                    let alarmAcePtr = pace.bindMemory(to: SYSTEM_ALARM_ACE.self, capacity: 1)
                    mask = .init(rawValue: alarmAcePtr.pointee.Mask)
                    sid = .init(psid: .init(unownedResource: alarmAcePtr.pointer(to: \.SidStart).unsafelyCastedMutableRawPtr))
                }
            }

            return (sid: sid, mask: mask)
        }
    }

}

#endif
