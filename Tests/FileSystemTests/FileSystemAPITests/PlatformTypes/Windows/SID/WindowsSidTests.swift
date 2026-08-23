#if canImport(WinSDK)

import PlatformCLib
import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.WindowsSecurityTests {

    @Suite("SID")
    struct WindowsSidTests {}

}



extension PlatformTypesAPITests.WindowsSecurityTests.WindowsSidTests {

    /// Counts how often a SID handed to `init(unsafeOwningPSid:freeingFunc:)` is released.
    private final class SidFreeCounter {

        private(set) var count = 0

        func recordFree() {
            count += 1
        }

    }


    /// Copies `sid` into a freshly allocated buffer owned by the returned value, reporting
    /// every release to `counter`.
    private static func makeOwnedCopy(
        of sid: WindowsSid,
        reportingFreesTo counter: SidFreeCounter
    ) -> WindowsSid {
        let length = sid.withUnsafePSid { GetLengthSid($0) }
        let copy = UnsafeMutableRawPointer.allocate(
            byteCount: Int(length),
            alignment: MemoryLayout<DWORD>.alignment
        )
        _ = sid.withUnsafePSid { CopySid(length, copy, $0) }
        return WindowsSid(unsafeOwningPSid: copy) { pointer in
            counter.recordFree()
            pointer.deallocate()
        }
    }

    @Test(
        arguments: [
            "S-1-1-0",
            "S-1-3-0",
            "S-1-5-11",
            "S-1-5-18",
            "S-1-5-32-544",
            "S-1-5-21-1004336348-1177238915-682003330-512"
        ]
    )
    func `SID strings round trip`(_ sidString: String) throws {

        let sid = try #require(WindowsSid(string: sidString))

        #expect(sid.string == sidString)

    }


    @Test(
        arguments: [
            "",
            "not-a-sid",
            "S-",
            "S-1-",
            "X-1-1-0"
        ]
    )
    func `Malformed SID strings are rejected`(_ sidString: String) {

        #expect(WindowsSid(string: sidString) == nil)

    }


    @Test(
        arguments: [
            (.everyone, "S-1-1-0"),
            (.creatorOwner, "S-1-3-0"),
            (.creatorGroup, "S-1-3-1"),
            (.anonymous, "S-1-5-7"),
            (.authenticatedUsers, "S-1-5-11"),
            (.system, "S-1-5-18"),
            (.localService, "S-1-5-19"),
            (.networkService, "S-1-5-20"),
            (.administrators, "S-1-5-32-544"),
            (.users, "S-1-5-32-545")
        ] as [(WindowsSid, String)]
    )
    func `Well-known SIDs match their canonical strings`(_ sid: WindowsSid, _ sidString: String) {

        #expect(sid.string == sidString)

    }


    @Test
    func `SIDs from different construction paths compare equal`() throws {

        let wellKnownSid = WindowsSid.everyone
        let parsedSid = try #require(WindowsSid(string: "S-1-1-0"))

        #expect(wellKnownSid == parsedSid)
        #expect(wellKnownSid.hashValue == parsedSid.hashValue)

    }


    @Test
    func `Different SIDs compare unequal`() {

        #expect(WindowsSid.everyone != WindowsSid.system)

    }


    @Test
    func `withUnsafePSid yields a valid pointer to the same SID`() {

        let sid = WindowsSid.administrators
        let otherSid = WindowsSid.administrators

        sid.withUnsafePSid { sidPointer in
            #expect(IsValidSid(sidPointer))
            otherSid.withUnsafePSid { otherPointer in
                #expect(EqualSid(sidPointer, otherPointer))
            }
        }

    }


    @Test
    func `Owning initializer frees the SID through its freeing function`() {

        let counter = SidFreeCounter()

        do {
            let sid = Self.makeOwnedCopy(of: .everyone, reportingFreesTo: counter)

            #expect(sid == WindowsSid.everyone)
            #expect(counter.count == 0)
        }

        #expect(counter.count == 1)

    }


    @Test
    func `View exposes the same string as its source`() {

        let sid = WindowsSid.administrators

        #expect(sid.view.string == sid.string)

    }


    @Test
    func `Detached view outlives its source`() {

        let detachedSid: WindowsSid = {
            let source = WindowsSid.administrators
            return source.view.detach()
        }()

        #expect(detachedSid == WindowsSid.administrators)
        #expect(detachedSid.string == "S-1-5-32-544")

    }


    @Test
    func `Views compare by the SID they point at`() throws {

        let everyoneSid = WindowsSid.everyone
        let parsedEveryoneSid = try #require(WindowsSid(string: "S-1-1-0"))
        let systemSid = WindowsSid.system

        // `View` is `~Escapable` and carries `==` without conforming to `Equatable`, which the
        // `#expect` macro cannot rewrite, so the comparisons are made before the assertion.
        let matchesParsedSid = everyoneSid.view == parsedEveryoneSid.view
        let matchesSystemSid = everyoneSid.view == systemSid.view

        #expect(matchesParsedSid)
        #expect(matchesSystemSid == false)

    }

}

#endif
