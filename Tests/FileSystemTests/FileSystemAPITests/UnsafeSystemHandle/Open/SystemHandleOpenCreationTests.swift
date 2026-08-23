import Testing
import Foundation
import SwiftFileSystem



extension UnsafeSystemHandleAPITests.OpenTests {

    @Test
    func `Missing file open reports notFound`() throws {

        let path = workspace.path("missing")

        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly()))
        }

        #expect(error?.kind == .notFound)

    }


    @Test
    func `createIfMissing creates a missing file`() throws {

        let path = workspace.path("created")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), creation: .createIfMissing)
        )

        let payload = Data("Hello".utf8)

        try handle.write(contentsOf: payload.bytes)
        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Hello".utf8))

    }


    @Test
    func `createIfMissing opens an existing file without truncation`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .readWrite(), creation: .createIfMissing)
        )

        #expect(try handle.tell() == 0)

        var buffer = Data(count: 12)

        try #expect(handle.read(into: buffer.mutableBytes) == 12)

        #expect(buffer == Data("Hello Swift!".utf8))

        try handle.close()

    }


    @Test
    func `assertMissing creates a missing file`() throws {

        let path = workspace.path("created")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), creation: .assertMissing)
        )

        let payload = Data("Hello".utf8)

        try handle.write(contentsOf: payload.bytes)
        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Hello".utf8))

    }


    @Test
    func `assertMissing reports alreadyExists for an existing file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "keep")

        let error = #expect(throws: LowLevelError.self) {
            _ = try UnsafeSystemHandle.open(
                at: path,
                openOptions: .init(access: .writeOnly(), creation: .assertMissing)
            )
        }

        #expect(error?.kind == .alreadyExists)
        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("keep".utf8))

    }


    @Test
    func `Truncate open erases existing contents`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), truncate: true)
        )

        #expect(try handle.tell() == 0)

        let payload = Data("Hi".utf8)

        try handle.write(contentsOf: payload.bytes)
        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Hi".utf8))

    }


    @Test
    func `Truncate with createIfMissing creates a missing file`() throws {

        let path = workspace.path("created")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), creation: .createIfMissing, truncate: true)
        )

        let payload = Data("Hi".utf8)

        try handle.write(contentsOf: payload.bytes)
        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Hi".utf8))

    }

}
