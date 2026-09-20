#if canImport(WinSDK)

import Testing
import SwiftFileSystem
import WinSDK


private typealias Options = UnsafeSystemHandle.OpenOptions

private let genericRead = GENERIC_READ
private let genericWrite = DWORD(bitPattern: GENERIC_WRITE)
private let fileGenericRead = FILE_GENERIC_READ
private let fileGenericWrite = FILE_GENERIC_WRITE
private let appendWrite = FILE_GENERIC_WRITE & ~DWORD(bitPattern: FILE_WRITE_DATA)
private let implicitCreateFileRights = DWORD(bitPattern: FILE_READ_ATTRIBUTES | SYNCHRONIZE)



extension UnsafeSystemHandleAPITests.OpenOptionsTests {

    @Suite("Windows derivation")
    struct WindowsDerivationTests {}

}



extension UnsafeSystemHandleAPITests.OpenOptionsTests.WindowsDerivationTests {

    // The access mode derives the data rights only; every right beyond reading and writing the
    // data is requested explicitly through `windowsExtraAccess`.
    @Test(arguments: [
        (.readOnly, genericRead),
        (.writeOnly, genericWrite),
        (.readWrite, genericRead | genericWrite),
        (.none, 0),
    ] as [(Options.AccessMode, Options.FlagType)])
    func `Access mode derives only the data access`(
        access: UnsafeSystemHandle.OpenOptions.AccessMode,
        expected: DWORD
    ) {

        #expect(Options(access: access).accessModeFlags == expected)

    }


    @Test
    func `Append derives the file generic write rights without write-data`() {

        let writeOnly = Options(access: .writeOnly, append: true)
        let readWrite = Options(access: .readWrite, append: true)

        #expect(writeOnly.accessModeFlags == appendWrite)
        #expect(readWrite.accessModeFlags == genericRead | appendWrite)

    }


    @Test
    func `Truncate adds generic write to the access mask`() {

        let options = Options(access: .readOnly, truncate: true)

        #expect(options.accessModeFlags == genericRead | genericWrite)

    }


    @Test
    func `Extra Windows access is added on top of the derived mask`() {

        let metadataOnly = Options(access: .none, windowsExtraAccess: .writeAttributes)
        let readWithSecurity = Options(access: .readOnly, windowsExtraAccess: [.writeDAC, .writeOwner])

        #expect(metadataOnly.accessModeFlags == DWORD(FILE_WRITE_ATTRIBUTES))
        #expect(readWithSecurity.accessModeFlags == genericRead | DWORD(WRITE_DAC | WRITE_OWNER))

    }


    // The estimate stands in for the rights a `CreateFileW` open actually granted: the generic
    // rights expand the way the object manager maps them for files, and the two rights
    // `CreateFileW` adds to every request are always present.
    @Test
    func `Estimated mapped access expands generic rights and adds the implicit CreateFileW rights`() {

        #expect(Options(access: .readOnly).estimatedMappedWindowsAccess.rawValue == genericRead | fileGenericRead)
        #expect(
            Options(access: .writeOnly).estimatedMappedWindowsAccess.rawValue
                == genericWrite | fileGenericWrite | DWORD(FILE_READ_ATTRIBUTES)
        )
        #expect(
            Options(access: .readWrite).estimatedMappedWindowsAccess.rawValue
                == genericRead | genericWrite | fileGenericRead | fileGenericWrite
        )
        #expect(
            Options(access: .writeOnly, append: true).estimatedMappedWindowsAccess.rawValue
                == appendWrite | DWORD(FILE_READ_ATTRIBUTES)
        )
        #expect(Options(access: .none).estimatedMappedWindowsAccess.rawValue == implicitCreateFileRights)
        #expect(
            Options(access: .none, windowsExtraAccess: .writeAttributes).estimatedMappedWindowsAccess.rawValue
                == DWORD(FILE_WRITE_ATTRIBUTES) | implicitCreateFileRights
        )

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
            Options(followSymlink: false).openFlags
                == DWORD(FILE_ATTRIBUTE_NORMAL) | DWORD(FILE_FLAG_OPEN_REPARSE_POINT)
        )

    }


    // Non-blocking is not a semantic option: overlapped I/O is requested through the
    // native-flag diff instead.
    @Test
    func `Overlapped-IO diff constant wraps its native flag`() {

        #expect(Options.NativeOpenFlag.windows.overlappedIO.rawValue == DWORD(FILE_FLAG_OVERLAPPED))

    }


    @Test
    func `Open-flags diff applies inserts and removes without a jurisdiction mask`() {

        var options = Options(followSymlink: false)

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

        #expect(options.openFlags == DWORD(FILE_ATTRIBUTE_NORMAL))
        #expect(options.accessModeFlags == genericRead)

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
