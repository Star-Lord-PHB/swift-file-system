#if os(Linux) || os(Android)

import Foundation
import PlatformCLib
import SystemPackage
import Testing
import FileSystemCore

@testable import SwiftFileSystem



extension FileSystemAPITests.CopyTests {

    /// The Linux file content copy tries `copy_file_range`, then `sendfile`, then a read/write loop,
    /// handing over while nothing has been copied yet. Which one a pair of files ends up with
    /// depends on their filesystems and on the kernel, so each test first makes the same calls on
    /// the same source (`probeContentMechanism(for:)`) and expects the mechanism they settle on.
    /// It is observed on the copy context after the first content step, and the copy is then
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

    /// The mechanism the copy's first content step settles on for `src`, found by making the same
    /// calls in the same order from `src` into a fresh workspace file, handing over on the same
    /// results as `copyFileContentStep`. Reading `src` may push its access time, so probe before
    /// capturing its snapshot.
    private func probeContentMechanism(
        for src: FilePath,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> ContentCopyMechanism {

        let srcDescriptor = src.withPlatformString { open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW) }
        try #require(srcDescriptor >= 0, sourceLocation: sourceLocation)
        defer { close(srcDescriptor) }
        let probe = try workspace.makeFile(at: "content-mechanism-probe")
        let dstDescriptor = probe.withPlatformString { open($0, O_WRONLY | O_CLOEXEC | O_NOFOLLOW) }
        try #require(dstDescriptor >= 0, sourceLocation: sourceLocation)
        defer { close(dstDescriptor) }

        var srcOffset = 0 as off_t
        var dstOffset = 0 as off_t
        var copied: Int
        repeat {
            copied = copy_file_range(srcDescriptor, &srcOffset, dstDescriptor, &dstOffset, 4096, 0)
        } while copied < 0 && errno == EINTR
        if copied > 0 { return .copyFileRange }
        try #require(
            copied == 0 || errno == ENOSYS || errno == EOPNOTSUPP || errno == EXDEV || errno == EINVAL,
            "copy_file_range failed with errno \(errno), which the copy does not hand over on",
            sourceLocation: sourceLocation
        )

        repeat {
            copied = sendfile(dstDescriptor, srcDescriptor, &srcOffset, 4096)
        } while copied < 0 && errno == EINTR
        if copied >= 0 { return .sendfile }
        try #require(
            errno == EINVAL || errno == ENOSYS,
            "sendfile failed with errno \(errno), which the copy does not hand over on",
            sourceLocation: sourceLocation
        )
        return .readWrite

    }


    @Test
    func `A source on the workspace filesystem is copied with the first mechanism that accepts it`() throws {

        let chunk = CopyTests.contentCopyChunkSize
        let src = try workspace.makeLargeFile(at: "src.bin", byteCount: 2 * chunk)
        let dst = workspace.path("dst.bin")
        let expectedMechanism = try probeContentMechanism(for: src)
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
        #expect(CopyTests.contentMechanism(of: handler) == expectedMechanism)
        #expect(handler.perform().itemErrors == nil)
        try Support.expectItem(at: dst, matches: srcSnapshot, using: .copiedItem)

    }


    @Test
    func `A source on another device is copied with the first mechanism that accepts it`() throws {

        // The test executable is read-only input on whatever device holds the build products;
        // the copy goes into the workspace.
        let src = FilePath(try #require(Bundle.main.executablePath))
        let srcDevice = try Support.ItemMetadata.captureIdentifier(at: src).deviceId
        let workspaceDevice = try Support.ItemMetadata.captureIdentifier(at: workspace.root).deviceId
        if srcDevice == workspaceDevice {
            try Test.cancel("The test executable is on the workspace's device")
        }
        let expectedMechanism = try probeContentMechanism(for: src)
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
    func `A procfs source is copied with the first mechanism that accepts it`() throws {

        // procfs files report a size of 0, so whichever mechanism takes them must read until the
        // end instead of trusting the size. The source is only read.
        let src: FilePath = "/proc/self/status"
        let descriptor = src.withPlatformString { open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW) }
        if descriptor < 0 && (errno == ENOENT || errno == EACCES) {
            try Test.cancel("A readable /proc/self/status is unavailable")
        }
        try #require(descriptor >= 0)
        close(descriptor)
        let expectedMechanism = try probeContentMechanism(for: src)
        let dst = workspace.path("status.txt")
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
        let contents = try String(contentsOf: URL(filePath: dst.string), encoding: .utf8)
        #expect(contents.hasPrefix("Name:\t"))
        #expect(contents.contains("\nPid:\t\(ProcessInfo.processInfo.processIdentifier)\n"))

    }

}

#endif
