import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.ErrorTests {

    @Suite("Platform error")
    struct PlatformErrorTests {

        typealias ErrorTests = PlatformTypesAPITests.ErrorTests

    }

}



extension PlatformTypesAPITests.ErrorTests.PlatformErrorTests {

    private struct SampleUnderlyingError: Error, Equatable {}


    @Test
    func `Success code is not an error`() {

        #expect(PlatformError(systemCode: .success, operation: .open("file")) == nil)

    }


    @Test
    func `Low-level cause exposes its kind and system code`() throws {

        let lowLevelError = try #require(LowLevelError(systemCode: ErrorTests.notFoundCode))

        let error = PlatformError(lowLevelError: lowLevelError, operation: .open("file"))

        #expect(error.kind == .notFound)
        #expect(error.systemCode == ErrorTests.notFoundCode)
        #expect(error.underlyingError as? LowLevelError == lowLevelError)
        #expect(error.operation == .open("file"))

    }


    @Test
    func `Explicit kind overrides the low-level kind and preserves the system code`() throws {

        let lowLevelError = try #require(LowLevelError(systemCode: ErrorTests.notFoundCode))

        let error = PlatformError(
            lowLevelError: lowLevelError,
            kind: .unsupported,
            operation: .open("file")
        )

        #expect(error.kind == .unsupported)
        #expect(error.systemCode == ErrorTests.notFoundCode)

    }


    @Test
    func `Underlying error cause reports no system code`() {

        let error = PlatformError(
            error: SampleUnderlyingError(),
            kind: .unsupported,
            operation: .fetchMeta("file")
        )

        #expect(error.systemCode == nil)
        #expect(error.kind == .unsupported)
        #expect(error.underlyingError as? SampleUnderlyingError == SampleUnderlyingError())

    }


    @Test
    func `Unknown error carries no system code`() {

        let error = PlatformError.unknown(operation: .remove("file"))

        #expect(error.systemCode == nil)
        #expect(error.kind == .unknown)
        #expect(error.operation == .remove("file"))

    }


    @Test
    func `Custom operation names compare by their text`() {

        let literalName: PlatformError.CustomOperationName = "syncVolume"
        let describedName = PlatformError.CustomOperationName(
            name: "syncVolume",
            description: { "Sync the volume" }
        )
        let otherName: PlatformError.CustomOperationName = "trimVolume"

        #expect(literalName == describedName)
        #expect(literalName.hashValue == describedName.hashValue)
        #expect(literalName != otherName)
        #expect(PlatformError.Operation.custom(name: literalName) == .custom(name: describedName))

    }

}
