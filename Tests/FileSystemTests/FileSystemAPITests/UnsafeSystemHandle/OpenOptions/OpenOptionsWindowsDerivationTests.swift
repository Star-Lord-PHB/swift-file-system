#if canImport(WinSDK)

import Testing
import SwiftFileSystem
import WinSDK


private typealias Options = UnsafeSystemHandle.OpenOptions

private let readMeta = DWORD(bitPattern: FILE_READ_ATTRIBUTES | READ_CONTROL)
private let writeMeta = DWORD(bitPattern: FILE_WRITE_ATTRIBUTES | WRITE_DAC | WRITE_OWNER | READ_CONTROL)
private let genericWrite = DWORD(bitPattern: GENERIC_WRITE)



extension UnsafeSystemHandleAPITests.OpenOptionsTests {

    @Suite("Windows derivation")
    struct WindowsDerivationTests {}

}



extension UnsafeSystemHandleAPITests.OpenOptionsTests.WindowsDerivationTests {

    @Test(arguments: [
        (.readOnly(), GENERIC_READ | readMeta),
        (.readOnly(metadataOnly: true), readMeta),
        (.writeOnly(), genericWrite | writeMeta),
        (.writeOnly(metadataOnly: true), writeMeta),
        (.readWrite(), GENERIC_READ | genericWrite | readMeta | writeMeta),
        (.readWrite(metadataOnly: true), readMeta | writeMeta),
        (.none, 0),
    ] as [(Options.AccessMode, Options.FlagType)])
    func `Access mode derives the exact access mask`(
        access: UnsafeSystemHandle.OpenOptions.AccessMode,
        expected: DWORD
    ) {

        #expect(Options(access: access).accessModeFlags == expected)

    }


    @Test
    func `Append derives append-data instead of generic write`() {

        let writeOnly = Options(access: .writeOnly(), append: true)
        let readWrite = Options(access: .readWrite(), append: true)

        #expect(writeOnly.accessModeFlags == DWORD(bitPattern: FILE_APPEND_DATA) | writeMeta)
        #expect(readWrite.accessModeFlags == GENERIC_READ | DWORD(bitPattern: FILE_APPEND_DATA) | readMeta | writeMeta)

    }


    @Test
    func `Truncate adds generic write to the access mask`() {

        let options = Options(access: .readOnly(), truncate: true)

        #expect(options.accessModeFlags == GENERIC_READ | readMeta | genericWrite)

    }


    @Test(arguments: [
        (creation: .never, truncate: false, expected: DWORD(OPEN_EXISTING)),
        (creation: .never, truncate: true, expected: DWORD(TRUNCATE_EXISTING)),
        (creation: .createIfMissing, truncate: false, expected: DWORD(OPEN_ALWAYS)),
        (creation: .createIfMissing, truncate: true, expected: DWORD(CREATE_ALWAYS)),
        (creation: .assertMissing, truncate: false, expected: DWORD(CREATE_NEW)),
        (creation: .assertMissing, truncate: true, expected: DWORD(CREATE_NEW)),
    ] as [(Options.CreationOptions, Bool, DWORD)])
    func `Disposition derives from creation and truncate`(
        creation: UnsafeSystemHandle.OpenOptions.CreationOptions, truncate: Bool, expected: DWORD
    ) {

        #expect(Options(creation: creation, truncate: truncate).creationFlags == expected)

    }


    @Test
    func `Creation override replaces the derived disposition in both directions`() {

        var options = Options(creation: .createIfMissing)

        options.platformCreationFlagsOverride = .windows.truncateExisting
        #expect(options.creationFlags == DWORD(TRUNCATE_EXISTING))

        options.platformCreationFlagsOverride = nil
        #expect(options.creationFlags == DWORD(OPEN_ALWAYS))

    }


    @Test
    func `Semantic options derive the flags and attributes`() {

        #expect(Options().openFlags == DWORD(FILE_ATTRIBUTE_NORMAL))
        #expect(
            Options(noFollow: true).openFlags
                == DWORD(FILE_ATTRIBUTE_NORMAL) | DWORD(FILE_FLAG_OPEN_REPARSE_POINT)
        )
        #expect(
            Options(noBlocking: true).openFlags
                == DWORD(FILE_ATTRIBUTE_NORMAL) | DWORD(FILE_FLAG_OVERLAPPED)
        )

    }


    @Test
    func `Open-flags diff applies inserts and removes without a jurisdiction mask`() {

        var options = Options(noFollow: true)

        options.platformOpenFlagsDiff.insert(.windows.backupSemantics)
        options.platformOpenFlagsDiff.remove(.windows.openReparsePoint)

        #expect(options.openFlags == DWORD(FILE_ATTRIBUTE_NORMAL) | DWORD(FILE_FLAG_BACKUP_SEMANTICS))

    }


    @Test
    func `Foreign-platform diff constants are no-ops`() {

        var options = Options()

        // NOTE: POSIX-only diff constants have rawValue 0 on Windows so that cross-platform code
        // can insert them without conditional compilation.
        options.platformOpenFlagsDiff.insert([.posix.directory, .posix.closeOnExec])
        options.platformAccessModeFlagsDiff.insert(.posix.path)

        #expect(options.openFlags == DWORD(FILE_ATTRIBUTE_NORMAL))
        #expect(options.accessModeFlags == GENERIC_READ | readMeta)

    }


    @Test
    func `Share mode defaults to read write delete`() {

        let expected = DWORD(FILE_SHARE_READ) | DWORD(FILE_SHARE_WRITE) | DWORD(FILE_SHARE_DELETE)

        #expect(Options().windowsShareMode.rawValue == expected)

    }


    @Test
    func `closeOnExec controls handle inheritance in the security attributes`() {

        #expect(Options(closeOnExec: true).securityAttributes.bInheritHandle.boolValue == false)
        #expect(Options(closeOnExec: false).securityAttributes.bInheritHandle.boolValue == true)

    }

}

#endif
