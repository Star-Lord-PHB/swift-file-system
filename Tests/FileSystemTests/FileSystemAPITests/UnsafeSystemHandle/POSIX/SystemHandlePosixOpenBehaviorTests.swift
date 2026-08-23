#if !canImport(WinSDK)

import Testing
import Foundation
import SwiftFileSystem
import PlatformCLib



extension UnsafeSystemHandleAPITests.PosixTests {

    @Test(arguments: [true, false])
    func `closeOnExec controls FD_CLOEXEC`(closeOnExec: Bool) throws {

        let path = try workspace.makeFile(at: "file")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(closeOnExec: closeOnExec)
        )

        let descriptorFlags = fcntl(handle.unsafeRawHandle, F_GETFD)

        try #require(descriptorFlags >= 0)
        #expect(((descriptorFlags & FD_CLOEXEC) != 0) == closeOnExec)

        try handle.close()

    }


    #if canImport(Darwin)

    // NOTE: Semantic noFollow derives O_SYMLINK on Darwin: the symlink itself opens instead of
    // failing. Other POSIX platforms derive O_NOFOLLOW and report ELOOP; see the sibling test.
    @Test
    func `noFollow opens the symlink itself`() throws {

        let target = try workspace.makeFile(at: "target", contents: "data")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let handle = try UnsafeSystemHandle.open(at: link, openOptions: .init(noFollow: true))

        #expect(try handle.type() == .symlink)

        try handle.close()

    }

    #else

    // NOTE: On Darwin the same options open the symlink itself; see the sibling test.
    @Test
    func `noFollow reports pathResolutionFailed on a symlink`() throws {

        let target = try workspace.makeFile(at: "target", contents: "data")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.open(at: link, openOptions: .init(noFollow: true))
        }

        #expect(error?.kind == .pathResolutionFailed)
        #expect(error?.systemCode == .tooManyLevelSymbolicLinks)

    }

    #endif


    // NOTE: Unlike semantic noFollow, the .posix.noFollow diff constant is O_NOFOLLOW on every
    // POSIX platform including Darwin, so opening a symlink with it fails uniformly.
    @Test
    func `Inserted noFollow flag rejects a symlink`() throws {

        let target = try workspace.makeFile(at: "target", contents: "data")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.open(
                at: link,
                openOptions: .init(platformOpenFlagsDiff: .inserted(.posix.noFollow))
            )
        }

        #expect(error?.kind == .pathResolutionFailed)
        #expect(error?.systemCode == .tooManyLevelSymbolicLinks)

    }


    @Test
    func `noFollow open of a regular file succeeds`() throws {

        let path = try workspace.makeFile(at: "file", contents: "data")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(noFollow: true))

        #expect(try handle.type() == .regular)

        try handle.close()

    }


    @Test
    func `Directory flag on a regular file reports notADirectory`() throws {

        let path = try workspace.makeFile(at: "file")

        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.open(
                at: path,
                openOptions: .init(platformOpenFlagsDiff: .inserted(.posix.directory))
            )
        }

        #expect(error?.systemCode == .notADirectory)

    }


    #if !(canImport(Darwin) || os(OpenBSD))

    // NOTE: Metadata-only access derives O_PATH here; Darwin and OpenBSD have no O_PATH and fall
    // back to a plain read-only descriptor, so this restriction is not portable.
    @Test
    func `Metadata-only open permits metadata queries but rejects reads`() throws {

        let path = try workspace.makeFile(at: "file", contents: "data")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .readOnly(metadataOnly: true))
        )

        #expect(try handle.type() == .regular)

        let error = #expect(throws: LowLevelError.self) {
            var buffer = Data(count: 1)
            _ = try handle.read(into: buffer.mutableBytes)
        }

        #expect(error?.systemCode == .badFileDescriptor)

        try handle.close()

    }


    // NOTE: O_NOFOLLOW alone fails on a symlink; paired with O_PATH it addresses the symlink
    // itself, which is the portable way to hold a metadata handle to a link here.
    @Test
    func `Metadata-only noFollow opens a symlink and reads its metadata`() throws {

        let target = try workspace.makeFile(at: "target", contents: "data")
        let link = try workspace.makeSymlink(at: "link", pointingTo: target)

        let handle = try UnsafeSystemHandle.open(
            at: link,
            openOptions: .init(access: .readOnly(metadataOnly: true), noFollow: true)
        )

        #expect(try handle.type() == .symlink)

        try handle.close()

    }

    #endif

}

#endif
