#if os(Linux) || os(Android)

import Foundation
import SystemPackage
import Testing
import FileSystemCore

@testable import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    /// The Linux file content copy tries `copy_file_range`, then `sendfile`, then a read/write loop.
    /// Which one a pair of files ends up with depends on their filesystems and on the kernel; it
    /// is observed on the copy context after the first content step, and the copy is then
    /// finished to check the bytes.
    @Suite("Linux file content")
    struct LinuxFileContentCopyTests {

        typealias Support = FileSystemAPITests.Support
        typealias CopyTests = FileSystemAPITests.CopyTests
        typealias ContentCopyMechanism = CopyItemHandler<
            FileOperationOptions.RecursiveCopyCollectAndReturnStrategy
        >.CopyFileContentContext.ContentCopyMechanism

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension FileSystemAPITests.CopyTests.LinuxFileContentCopyTests {

    @Test
    func `A source on the workspace filesystem is copied with copy_file_range`() throws {

        let chunk = CopyTests.contentCopyChunkSize
        let src = try workspace.makeLargeFile(at: "src.bin", byteCount: 2 * chunk)
        let dst = workspace.path("dst.bin")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            cancellationToken: .init(),
            errorStrategy: .collectAndReturn
        )

        // Registration, then the first block.
        #expect(handler.copyStep() == .paused)
        #expect(handler.copyStep() == .paused)
        #expect(CopyTests.contentMechanism(of: handler) == .copyFileRange)
        #expect(handler.perform().itemErrors == nil)
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `A source on another device is copied through the cross-filesystem mechanism`() throws {

        // The test executable is read-only input on whatever device holds the build products;
        // the copy goes into the workspace.
        let src = FilePath(try #require(Bundle.main.executablePath))
        let srcDevice = try Support.ItemMetadata.captureIdentifier(at: src).deviceId
        let workspaceDevice = try Support.ItemMetadata.captureIdentifier(at: workspace.root).deviceId
        if srcDevice == workspaceDevice {
            try Test.cancel("The test executable is on the workspace's device")
        }
        // `copy_file_range` crosses filesystems from 5.3 and refuses to from 5.19, where the
        // copy falls back to `sendfile`.
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let expectedMechanism = switch (version.majorVersion, version.minorVersion) {
            case (6..., _), (5, 19...): .sendfile
            case (5, 3...): .copyFileRange
            default: try Test.cancel("Kernel \(version.majorVersion).\(version.minorVersion) is too old")
        } as ContentCopyMechanism
        let dst = workspace.path("executable-copy")
        let srcSnapshot = try Support.ItemSnapshot.capture(at: src)
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            cancellationToken: .init(),
            errorStrategy: .collectAndReturn
        )

        #expect(handler.copyStep() == .paused)
        #expect(handler.copyStep() == .paused)
        #expect(CopyTests.contentMechanism(of: handler) == expectedMechanism)
        #expect(handler.perform().itemErrors == nil)
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .logicalContents)

    }


    @Test
    func `A procfs source is copied through the read/write loop`() throws {

        // procfs files report a size of 0 and support neither in-kernel mechanism; the loop
        // reads until the end instead of trusting the size. The source is only read.
        let src: FilePath = "/proc/self/status"
        let descriptor = src.withPlatformString { open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW) }
        if descriptor < 0 && (errno == ENOENT || errno == EACCES) {
            try Test.cancel("A readable /proc/self/status is unavailable")
        }
        try #require(descriptor >= 0)
        close(descriptor)
        let dst = workspace.path("status.txt")
        var handler = CopyItemHandler(
            srcRootPath: src,
            dstRootPath: dst,
            cancellationToken: .init(),
            errorStrategy: .collectAndReturn
        )

        #expect(handler.copyStep() == .paused)
        #expect(handler.copyStep() == .paused)
        #expect(CopyTests.contentMechanism(of: handler) == .readWrite)
        #expect(handler.perform().itemErrors == nil)
        let contents = try String(contentsOf: URL(filePath: dst.string), encoding: .utf8)
        #expect(contents.hasPrefix("Name:\t"))
        #expect(contents.contains("\nPid:\t\(ProcessInfo.processInfo.processIdentifier)\n"))

    }

}

#endif
