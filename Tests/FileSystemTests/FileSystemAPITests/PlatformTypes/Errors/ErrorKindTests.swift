import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.ErrorTests {

    @Suite("Error kind")
    struct ErrorKindTests {}

}



extension PlatformTypesAPITests.ErrorTests.ErrorKindTests {

    // NOTE: `.windows.permissionDeniedOrIsADirectory` is declared on every platform so that
    // cross-platform callers can consume it without conditional compilation. It stands for a
    // Windows open path that cannot tell the two causes apart, so it matches both of them
    // while neither of them matches it back.

    @Test(
        arguments: [
            .notFound, .permissionDenied, .alreadyExists, .invalidInput, .isADirectory,
            .notADirectory, .notASymlink, .notEmptyDirectory, .invalidHandle, .noEnoughSpace,
            .nameTooLong, .unsupported, .arithmeticOverflow, .pathResolutionFailed, .unknown,
            .windows.permissionDeniedOrIsADirectory
        ] as [PlatformErrorKind]
    )
    func `A kind always matches itself`(_ kind: PlatformErrorKind) {

        #expect(kind.maybe(kind))

    }


    @Test
    func `Ambiguous kind matches both of the kinds it covers`() {

        let ambiguousKind = PlatformErrorKind.windows.permissionDeniedOrIsADirectory

        #expect(ambiguousKind.maybe(.permissionDenied))
        #expect(ambiguousKind.maybe(.isADirectory))

    }


    @Test
    func `Ambiguous kind matching is one directional`() {

        let ambiguousKind = PlatformErrorKind.windows.permissionDeniedOrIsADirectory

        #expect(PlatformErrorKind.permissionDenied.maybe(ambiguousKind) == false)
        #expect(PlatformErrorKind.isADirectory.maybe(ambiguousKind) == false)

    }


    @Test
    func `Ambiguous kind is not equal to the kinds it covers`() {

        let ambiguousKind = PlatformErrorKind.windows.permissionDeniedOrIsADirectory

        #expect(ambiguousKind != .permissionDenied)
        #expect(ambiguousKind != .isADirectory)

    }


    @Test
    func `Unrelated kinds do not match`() {

        let ambiguousKind = PlatformErrorKind.windows.permissionDeniedOrIsADirectory

        #expect(PlatformErrorKind.notFound.maybe(.permissionDenied) == false)
        #expect(ambiguousKind.maybe(.notFound) == false)

    }

}
