#if canImport(WinSDK)

import Testing
import Foundation
import SwiftFileSystem
import WinSDK



// Opening a reparse point with a truncating disposition can replace the symlink itself with an
// empty file, so open() refuses that combination unless the caller states a native disposition
// explicitly. The guard reads the effective open flags rather than the semantic noFollow
// property, and these tests pin both directions of that distinction.
extension UnsafeSystemHandleAPITests.WindowsTests {

    @Test
    func `No-follow truncate without an override is unsupported`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")

        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.open(
                at: path,
                openOptions: .init(access: .writeOnly(), truncate: true, noFollow: true)
            )
        }

        #expect(error?.kind == .unsupported)
        #expect(error?.systemCode == nil)
        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("contents".utf8))

    }


    @Test
    func `Inserted reparse-point flag also triggers the guard`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")

        // The semantic noFollow stays false: the flag arrives through the native diff, and the
        // guard still sees it in the effective open flags.
        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.open(
                at: path,
                openOptions: .init(
                    access: .writeOnly(),
                    truncate: true,
                    platformOpenFlagsDiff: .inserted(.windows.openReparsePoint)
                )
            )
        }

        #expect(error?.kind == .unsupported)
        #expect(error?.systemCode == nil)

    }


    @Test
    func `Removing the reparse-point flag lifts the guard`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")

        // The semantic noFollow is set, but the diff takes the flag back out, so the effective
        // open flags no longer carry it.
        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(
                access: .writeOnly(),
                truncate: true,
                noFollow: true,
                platformOpenFlagsDiff: .removed(.windows.openReparsePoint)
            )
        )

        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)).isEmpty)

    }


    @Test
    func `A creation override opts into no-follow truncate`() throws {

        let path = try workspace.makeFile(at: "file", contents: "contents")

        var options = UnsafeSystemHandle.OpenOptions(
            access: .writeOnly(),
            truncate: true,
            noFollow: true
        )
        options.platformCreationFlagsOverride = .windows.truncateExisting

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: options)

        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)).isEmpty)

    }


    @Test
    func `assertMissing is exempt from the guard`() throws {

        let path = workspace.path("created")

        // CREATE_NEW cannot overwrite an existing symlink, so the combination is safe and the
        // guard leaves it alone.
        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(
                access: .writeOnly(),
                creation: .assertMissing,
                truncate: true,
                noFollow: true
            )
        )

        let payload = Data("created".utf8)

        try #expect(handle.write(contentsOf: payload.bytes) == 7)
        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("created".utf8))

    }


    @Test
    func `No-follow truncate on a symlink fails and leaves the link intact`() throws {

        let target = try workspace.makeFile(at: "target", contents: "target contents")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.open(
                at: link,
                openOptions: .init(access: .writeOnly(), truncate: true, noFollow: true)
            )
        }

        #expect(error?.kind == .unsupported)

        let linkHandle = try UnsafeSystemHandle.open(at: link, openOptions: .init(noFollow: true))

        #expect(try linkHandle.type() == .symlink)
        #expect(try Data(contentsOf: URL(filePath: target.string)) == Data("target contents".utf8))

        try linkHandle.close()

    }

}

#endif
