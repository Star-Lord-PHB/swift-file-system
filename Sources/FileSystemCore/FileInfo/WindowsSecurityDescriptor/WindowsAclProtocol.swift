#if canImport(WinSDK)

import PlatformCLib


/// Protocol for all types of Windows ACLs for shared APIs.
public protocol WindowRawAclProtocol: ~Copyable, ~Escapable {
    /// Access the underlying ACL pointer in a closure for reading.
    ///
    /// - Warning: Do not return or store the pointer outside the closure, and do not modify the ACL through it.
    func withUnsafePACL<R: ~Copyable, E: Error>(_ operation: (PACL) throws(E) -> R) throws(E) -> R
}



extension WindowRawAclProtocol where Self: ~Copyable & ~Escapable {

    /// The revision number of the ACL.
    public var revision: BYTE {
        return self.withUnsafePACL { pacl in
            pacl.pointee.AclRevision
        }
    }

    /// The total count of ACEs in this ACL.
    public var aceCount: WORD {
        return self.withUnsafePACL { pacl in
            pacl.pointee.AceCount
        }
    }

    /// Access the ACE at the specified index.
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

    /// Iterates over each ACE in the ACL with the given closure.
    /// - Parameter body: A closure for accessing each ACE.
    public func forEach<E: Error>(_ body: (WindowsRawAceView) throws(E) -> Void) throws(E) {
        for i in 0 ..< Int(self.aceCount) {
            try body(self[i])
        }
    }


    /// Creates a new array by transforming each ACE with the given closure.
    /// - Parameter transform: A closure that transforms each ACE into a new value.
    public func map<T, E: Error>(_ transform: (WindowsRawAceView) throws(E) -> T) throws(E) -> [T] {
        var results = [T]()
        for i in 0 ..< Int(self.aceCount) {
            let result = try transform(self[i])
            results.append(result)
        }
        return results
    }


    /// Aggregates the ACEs in the ACL into a single value by applying a closure to each ACE and an accumulating result.
    /// - Parameters:
    ///   - initialResult: The initial value to start the aggregation.
    ///   - nextPartialResult: A closure forms a new accumulated value from the current accumulated value and the next ACE.
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

    /// Creates a new array by transforming each ACE with the given closure, filtering out any nil results.
    /// - Parameter transform: A closure that transforms each ACE into an optional new value.
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

    /// Aggregates the ACEs in the ACL into a single value by applying a closure to each ACE and an accumulating result.
    /// - Parameters:
    ///   - initialResult: The initial value to start the aggregation.
    ///   - updateAccumulatingResult: A closure that updates the accumulated value with the next ACE.
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

    /// Returns the first ACE in the ACL, or nil if the ACL is empty.
    public var first: WindowsRawAceView? {
        @_lifetime(borrow self)
        get {
            guard self.aceCount > 0 else { return nil }
            return self[0]
        }
    }


    /// Finds the first ACE in the ACL that satisfies the given predicate, or nil if no such ACE exists.
    /// - Parameter predicate: A closure checking whether an ACE satisfies a certain condition.
    /// - Returns: The first ACE that satisfies the predicate, or nil if no such ACE exists.
    @_lifetime(borrow self)
    public func first<E: Error>(where predicate: (WindowsRawAceView) throws(E) -> Bool) throws(E) -> WindowsRawAceView? {
        for i in 0 ..< Int(self.aceCount) {
            let aceView = self[i]
            if try predicate(aceView) {
                return aceView
            }
        }
        return nil
    }

}



/// Unowned view of a Windows ACE.
public struct WindowsRawAceView: ~Escapable {

    package let pace: UnsafeUnownedRawPointer

    @_lifetime(copy pace)
    package init(pace: UnsafeUnownedRawPointer) {
        self.pace = pace
    }

    /// The type of the ACE.
    public var type: WindowsACEType {
        let header = pace.unsafeRawPtr.load(as: ACE_HEADER.self)
        return .init(rawValue: header.AceType)
    }

    /// The flags associated with the ACE.
    public var flags: WindowsACEFlags {
        let header = pace.unsafeRawPtr.load(as: ACE_HEADER.self)
        return .init(rawValue: header.AceFlags)
    }

    /// The size in bytes of the ACE.
    public var size: WORD {
        let header = pace.unsafeRawPtr.load(as: ACE_HEADER.self)
        return header.AceSize
    }

    /// The permission associated with the ACE, including the SID and access mask.
    public var permission: (sid: WindowsSid.View, mask: WindowsAccessMask) {
        @_lifetime(copy self)
        get {
            let (maskOffset, sidOffset) = switch type {
                case .allow: (MemoryLayout<ACCESS_ALLOWED_ACE>.offset(of: \.Mask)!, MemoryLayout<ACCESS_ALLOWED_ACE>.offset(of: \.SidStart)!)
                case .deny:  (MemoryLayout<ACCESS_DENIED_ACE>.offset(of: \.Mask)!, MemoryLayout<ACCESS_DENIED_ACE>.offset(of: \.SidStart)!)
                case .audit: (MemoryLayout<SYSTEM_AUDIT_ACE>.offset(of: \.Mask)!, MemoryLayout<SYSTEM_AUDIT_ACE>.offset(of: \.SidStart)!)
                case .alarm: (MemoryLayout<SYSTEM_ALARM_ACE>.offset(of: \.Mask)!, MemoryLayout<SYSTEM_ALARM_ACE>.offset(of: \.SidStart)!)
            }

            let mask = WindowsAccessMask(rawValue: pace.unsafeRawPtr.load(fromByteOffset: maskOffset, as: ACCESS_MASK.self))
            let sid = WindowsSid.View(psid: .init(unownedResource: pace.unsafelyCastedMutableRawPtr + sidOffset))

            return (sid: sid, mask: mask)
        }
    }

}



// A read-only view into an ACL that the lifetime system keeps immutably borrowed for as long as
// the view lives, so concurrent reads are safe; @unchecked only because the stored pointer
// wrapper is not Sendable.
extension WindowsRawAceView: @unchecked Sendable {}

#endif
