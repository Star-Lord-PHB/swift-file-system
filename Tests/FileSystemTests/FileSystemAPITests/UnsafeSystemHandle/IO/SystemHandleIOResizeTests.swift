import Testing
import Foundation
import SwiftFileSystem



extension UnsafeSystemHandleAPITests.IOTests {

    @Test
    func `Truncate to a size shrinks the file`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly()))

        try handle.truncate(to: 5)
        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Hello".utf8))

    }


    @Test
    func `Truncate to a size extends the file with zeros`() throws {

        let path = try workspace.makeFile(at: "file", contents: "AB")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly()))

        try handle.truncate(to: 5)
        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("AB".utf8) + Data([0, 0, 0]))

    }


    @Test
    func `Truncate preserves the current offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly()))

        // NOTE: POSIX ftruncate never touches the offset. The Windows implementation moves the
        // file pointer to cut at the requested size, and must restore it afterwards - including
        // to a position beyond the new EOF.
        try handle.seek(to: 8)
        try handle.truncate(to: 5)

        #expect(try handle.tell() == 8)

        try handle.seek(to: 2)
        try handle.truncate(to: 20)

        #expect(try handle.tell() == 2)

        try handle.close()

    }


    @Test
    func `Parameterless truncate cuts at the current offset`() throws {

        let path = try workspace.makeFile(at: "file", contents: "Hello Swift!")

        let handle = try UnsafeSystemHandle.open(at: path, openOptions: .init(access: .writeOnly()))

        try handle.seek(to: 5)
        try handle.truncate()

        #expect(try handle.tell() == 5)

        try handle.close()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Hello".utf8))

    }


    @Test
    func `fsync succeeds and written data is visible`() throws {

        let path = workspace.path("out")

        let handle = try UnsafeSystemHandle.open(
            at: path,
            openOptions: .init(access: .writeOnly(), creation: .createIfMissing)
        )

        let payload = Data("Hello".utf8)

        try handle.write(contentsOf: payload.bytes)
        try handle.fsync()

        #expect(try Data(contentsOf: URL(filePath: path.string)) == Data("Hello".utf8))

        try handle.close()

    }

}
