#if canImport(WinSDK)

import Testing
import Foundation
import SwiftFileSystem
import WinSDK



// A pending result borrows the handle it was started on. Under the current ownership checker that
// borrow spans the rest of the function whenever the handle is a `let` binding, and a nested scope
// does not end it, so tests that start an operation directly in the test body let the handle close
// on deinit instead of calling close(). Starting the operation inside a closure ends the borrow
// with the closure, so those tests still close explicitly. Binding the handle to a `var` also
// lifts the restriction - the asymmetry looks like a checker artifact rather than intended
// semantics - but it costs a never-mutated warning per site and is not worth it here, since the
// Lifecycle suite already covers both release paths.
extension UnsafeSystemHandleAPITests.WindowsTests {

    @Suite("Overlapped IO")
    struct OverlappedTests {

        typealias Support = UnsafeSystemHandleAPITests.Support

        let workspace: Support.Workspace


        init() throws {
            workspace = try Support.Workspace()
        }

    }

}



extension UnsafeSystemHandleAPITests.WindowsTests.OverlappedTests {

    @Test
    func `Overlapped offset round-trips a negative value`() {

        var overlapped = WindowsOverlapped(offset: -1)

        // The end-of-file sentinel is 0xFFFFFFFF in both halves, so the offset accessors have to
        // convert by bit pattern rather than by numeric value.
        #expect(overlapped.offset == -1)

        overlapped.offset = 0x1_0000_0002

        #expect(overlapped.offset == 0x1_0000_0002)

        overlapped.offset = -1

        #expect(overlapped.offset == -1)

    }


    @Test
    func `Overlapped read at an offset leaves the file pointer`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .readOnly(), noBlocking: true)
        )

        var buffer = Data(count: 5)
        var overlapped = WindowsOverlapped(offset: 6)

        let pending = try handle.read(into: buffer.mutableBytes, overlapped: &overlapped)

        try #expect(pending.wait() == 5)

        #expect(try handle.tell() == 0)
        #expect(buffer == Data("Swift".utf8))

    }


    @Test
    func `Two overlapped reads are outstanding at once`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .readOnly(), noBlocking: true)
        )

        var head = Data(count: 5)
        var tail = Data(count: 5)
        var headOverlapped = WindowsOverlapped()
        var tailOverlapped = WindowsOverlapped(offset: 6)

        let (headBytesRead, tailBytesRead) = try head.withUnsafeMutableBytes { headPointer in
            try tail.withUnsafeMutableBytes { tailPointer in
                let headPending = try handle.read(into: headPointer, overlapped: &headOverlapped)
                let tailPending = try handle.read(into: tailPointer, overlapped: &tailOverlapped)
                let tailResult = try tailPending.wait()
                let headResult = try headPending.wait()
                return (headResult, tailResult)
            }
        }

        #expect(headBytesRead == 5)
        #expect(tailBytesRead == 5)
        #expect(head == Data("Hello".utf8))
        #expect(tail == Data("Swift".utf8))
        #expect(try handle.tell() == 0)

        try handle.close()

    }


    @Test
    func `Overlapped read into a buffer slice lands in the slice`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .readOnly(), noBlocking: true)
        )

        var buffer = Data(repeating: 0xFF, count: 7)
        var overlapped = WindowsOverlapped(offset: 6)

        let bytesRead = try buffer.withUnsafeMutableBytes { pointer in
            let pending = try handle.read(into: pointer[2..<7], overlapped: &overlapped)
            return try pending.wait()
        }

        #expect(bytesRead == 5)
        #expect(buffer == Data([0xFF, 0xFF]) + Data("Swift".utf8))

        try handle.close()

    }


    @Test
    func `Overlapped write at an offset leaves the file pointer`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), noBlocking: true)
        )

        let payload = Data("World".utf8)
        let greeting = Data("Howdy".utf8)
        var overlapped = WindowsOverlapped(offset: 6)

        let pending = try handle.write(contentsOf: payload.bytes, overlapped: &overlapped)

        try #expect(pending.wait() == 5)
        #expect(try handle.tell() == 0)

        // Once the result has been waited on, the same overlapped takes a new offset and drives
        // the next operation.
        overlapped.offset = 0

        let secondPending = try handle.write(contentsOf: greeting.bytes, overlapped: &overlapped)

        try #expect(secondPending.wait() == 5)

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Howdy World!".utf8))

    }


    @Test
    func `The end-of-file sentinel writes at the file end`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), noBlocking: true)
        )

        // An offset of -1 is 0xFFFFFFFF in both OVERLAPPED halves, which the kernel resolves to
        // the end of the file at write time. AppendHandle relies on this for its append-at-end
        // semantics on Windows.
        var overlapped = WindowsOverlapped(offset: -1)
        let first = Data(" pipe".utf8)
        let second = Data("line".utf8)

        let firstPending = try handle.write(contentsOf: first.bytes, overlapped: &overlapped)

        try #expect(firstPending.wait() == 5)

        // The same overlapped drives the second append: the kernel leaves the offset halves
        // alone, so the sentinel still resolves to the new end of the file.
        let secondPending = try handle.write(contentsOf: second.bytes, overlapped: &overlapped)

        try #expect(secondPending.wait() == 4)

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Hello pipeline".utf8))

    }


    @Test
    func `Overlapped read past the end reports handleEOF`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .readOnly(), noBlocking: true)
        )

        let error = #expect(throws: LowLevelError.self) {
            var buffer = Data(count: 4)
            var overlapped = WindowsOverlapped(offset: 100)
            let pending = try handle.read(into: buffer.mutableBytes, overlapped: &overlapped)
            return try pending.wait()
        }

        #expect(error?.systemCode == .handleEOF)

        try handle.close()

    }

}

#endif
