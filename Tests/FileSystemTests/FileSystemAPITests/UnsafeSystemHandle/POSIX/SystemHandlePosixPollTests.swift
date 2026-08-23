#if !canImport(WinSDK)

import Testing
import Foundation
import SwiftFileSystem
import PlatformCLib



// poll and setNonBlocking on anonymous pipes. Every poll passes an explicit zero timeout and
// every read happens on a non-blocking descriptor, so no call here can block.
extension UnsafeSystemHandleAPITests.PosixTests {

    @Test
    func `poll times out on an empty pipe`() throws {

        let handles = try UnsafeSystemHandle.pipe()

        #expect(try handles.readHandle.poll(listening: .read, waitMilliseconds: 0) == nil)

    }


    @Test
    func `poll reports readable after a write`() throws {

        let handles = try UnsafeSystemHandle.pipe()

        let payload = Data("x".utf8)

        try handles.writeHandle.write(contentsOf: payload.bytes)

        let events = try handles.readHandle.poll(listening: .read, waitMilliseconds: 0)

        #expect(events?.contains(.pollIn) == true)

    }


    @Test
    func `poll reports writable on the write end`() throws {

        let handles = try UnsafeSystemHandle.pipe()

        let events = try handles.writeHandle.poll(listening: .write, waitMilliseconds: 0)

        #expect(events?.contains(.pollOut) == true)

    }


    @Test
    func `poll reports hangup after the write end closes`() throws {

        let handles = try UnsafeSystemHandle.pipe()
        let readHandle = handles.readHandle
        let writeHandle = handles.writeHandle

        try writeHandle.close()

        let events = try readHandle.poll(listening: .read, waitMilliseconds: 0)

        #expect(events?.contains(.pollHup) == true)

        try readHandle.close()

    }


    @Test
    func `setNonBlocking sets and clears O_NONBLOCK`() throws {

        let handles = try UnsafeSystemHandle.pipe()
        let readHandle = handles.readHandle

        try readHandle.setNonBlocking(true)

        let rawFlags = fcntl(readHandle.unsafeRawHandle, F_GETFL)

        try #require(rawFlags >= 0)
        #expect(rawFlags & O_NONBLOCK != 0)

        try readHandle.setNonBlocking(false)

        let clearedRawFlags = fcntl(readHandle.unsafeRawHandle, F_GETFL)

        try #require(clearedRawFlags >= 0)
        #expect(clearedRawFlags & O_NONBLOCK == 0)

        try readHandle.close()

    }


    @Test
    func `Non-blocking read on an empty pipe reports wouldBlock`() throws {

        let handles = try UnsafeSystemHandle.pipe()
        let readHandle = handles.readHandle
        // The write end stays open so the empty pipe reports wouldBlock instead of EOF.
        let writeHandle = handles.writeHandle

        try readHandle.setNonBlocking(true)

        let error = #expect(throws: LowLevelError.self) {
            var buffer = Data(count: 1)
            _ = try readHandle.read(into: buffer.mutableBytes)
        }

        #expect(error?.systemCode == .wouldBlock)

        try readHandle.close()
        try writeHandle.close()

    }

}

#endif
