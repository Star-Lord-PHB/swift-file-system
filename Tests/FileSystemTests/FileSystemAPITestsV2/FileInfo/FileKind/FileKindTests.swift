import PlatformCLib
import Testing
import SwiftFileSystem



extension FileInfoAPITests {

    @Suite("File kind")
    struct FileKindTests {}

}



extension FileInfoAPITests.FileKindTests {

    #if !canImport(WinSDK)
    @Test(
        arguments: [
            (mode_t(S_IFREG), .regular),
            (mode_t(S_IFDIR), .directory),
            (mode_t(S_IFLNK), .symlink),
            (mode_t(S_IFSOCK), .socket),
            (mode_t(S_IFBLK), .block),
            (mode_t(S_IFCHR), .character),
            (mode_t(S_IFIFO), .fifo)
        ] as [(mode_t, FileKind)]
    )
    func `POSIX modes map to file kinds`(_ mode: mode_t, _ expected: FileKind) {

        #expect(FileKind(mode: mode) == expected)

    }


    @Test
    func `POSIX mapping ignores permission bits`() {

        let mode = mode_t(S_IFREG) | mode_t(0o751)

        #expect(FileKind(mode: mode) == .regular)

    }


    @Test
    func `Unknown POSIX mode maps to unknown`() {

        #expect(FileKind(mode: 0) == .unknown)

    }
    #endif

}
