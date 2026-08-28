#if !canImport(WinSDK)

import Testing
import SwiftFileSystem
import PlatformCLib


private typealias Options = UnsafeSystemHandle.OpenOptions



extension UnsafeSystemHandleAPITests.OpenOptionsTests {

    @Suite("POSIX derivation")
    struct PosixDerivationTests {}

}



extension UnsafeSystemHandleAPITests.OpenOptionsTests.PosixDerivationTests {

    @Test(arguments: [
        (.never, 0),
        (.createIfMissing, O_CREAT),
        (.assertMissing, O_CREAT | O_EXCL),
    ] as [(Options.CreationOptions, CInt)])
    func `Semantic creation derives the creation flags`(
        creation: UnsafeSystemHandle.OpenOptions.CreationOptions,
        expected: CInt
    ) {

        #expect(Options(creation: creation).creationFlags == expected)

    }


    @Test
    func `Semantic options derive the corresponding open flags`() {

        let options = Options(truncate: true, append: true, closeOnExec: true)

        #expect(options.openFlags == O_TRUNC | O_APPEND | O_CLOEXEC)

    }


    // Non-blocking is not a semantic option: O_NONBLOCK and FILE_FLAG_OVERLAPPED are
    // different concepts, so callers request each through the native-flag diff.
    @Test
    func `Non-blocking and no-ctty diff constants wrap their native flags`() {

        #expect(Options.NativeOpenFlag.posix.nonBlocking.rawValue == O_NONBLOCK)
        #expect(Options.NativeOpenFlag.posix.noCtty.rawValue == O_NOCTTY)

    }


    @Test
    func `noFollow derives the platform no-follow flag`() {

        let options = Options(noFollow: true, closeOnExec: false)

        // NOTE: On Darwin the semantic noFollow derives O_SYMLINK (open the symlink itself), while
        // the `.posix.noFollow` diff constant stays O_NOFOLLOW (fail on a symlink). The two are
        // different flags with different semantics there; on other POSIX platforms both are
        // O_NOFOLLOW.
        #if canImport(Darwin)
        #expect(options.openFlags == O_SYMLINK)
        #else
        #expect(options.openFlags == O_NOFOLLOW)
        #endif

        #expect(Options.NativeOpenFlag.posix.noFollow.rawValue == O_NOFOLLOW)

    }


    @Test
    func `Metadata-only access derives the path flag where available`() {

        #if !(canImport(Darwin) || os(OpenBSD))
        #expect(Options(access: .readOnly(metadataOnly: true)).accessModeFlags == O_RDONLY | __O_PATH)
        #expect(Options(access: .none).accessModeFlags == O_RDONLY | __O_PATH)
        #expect(Options.NativeAccessModeFlag.posix.path.rawValue == __O_PATH)
        #else
        #expect(Options(access: .readOnly(metadataOnly: true)).accessModeFlags == O_RDONLY)
        #expect(Options(access: .none).accessModeFlags == O_RDONLY)
        #expect(Options.NativeAccessModeFlag.posix.path.rawValue == 0)
        #endif

    }


    @Test
    func `Open-flags diff removes a derived flag`() {

        var options = Options()

        #expect(options.openFlags == O_CLOEXEC)

        options.platformOpenFlagsDiff.remove(.posix.closeOnExec)

        #expect(options.openFlags == 0)

    }


    @Test
    func `Access-mode diff bits outside the access jurisdiction are dropped`() {

        var options = Options(truncate: true, closeOnExec: false)

        options.platformAccessModeFlagsDiff.insert(O_APPEND)
        options.platformAccessModeFlagsDiff.remove(O_TRUNC)

        #expect(options.accessModeFlags == O_RDONLY)
        #expect(options.openFlags == O_TRUNC)

    }


    @Test
    func `Open-flags diff drops access and creation bits`() {

        var options = Options(closeOnExec: false)

        options.platformOpenFlagsDiff.insert(O_RDWR | O_CREAT | O_EXCL)
        #if !(canImport(Darwin) || os(OpenBSD))
        options.platformOpenFlagsDiff.insert(__O_PATH)
        #endif

        #expect(options.openFlags == 0)
        #expect(options.accessModeFlags == O_RDONLY)
        #expect(options.creationFlags == 0)

    }


    @Test
    func `Creation override keeps only the creation bits`() {

        var options = Options(access: .writeOnly())

        options.platformCreationFlagsOverride = .init(rawValue: O_CREAT | O_EXCL | O_TRUNC | O_APPEND)

        #expect(options.creationFlags == O_CREAT | O_EXCL)

    }


    @Test
    func `Creation override replaces the semantic creation in both directions`() {

        var options = Options(creation: .createIfMissing)

        options.platformCreationFlagsOverride = .init(rawValue: 0)
        #expect(options.creationFlags == 0)

        options.platformCreationFlagsOverride = .posix.exclusiveCreate
        #expect(options.creationFlags == O_CREAT | O_EXCL)

        options.platformCreationFlagsOverride = nil
        #expect(options.creationFlags == O_CREAT)

    }


    @Test
    func `Foreign-platform diff constants are no-ops`() {

        var options = Options(closeOnExec: false)

        // NOTE: Windows-only diff constants have rawValue 0 on POSIX so that cross-platform code
        // can insert them without conditional compilation.
        options.platformOpenFlagsDiff.insert([.windows.backupSemantics, .windows.overlappedIO])
        options.platformAccessModeFlagsDiff.insert(.windows.genericWrite)

        #expect(options.openFlags == 0)
        #expect(options.accessModeFlags == O_RDONLY)

    }

}

#endif
