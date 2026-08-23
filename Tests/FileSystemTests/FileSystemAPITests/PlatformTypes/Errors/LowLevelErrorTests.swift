import Testing
import SwiftFileSystem



extension PlatformTypesAPITests.ErrorTests {

    @Suite("Low-level error")
    struct LowLevelErrorTests {

        typealias ErrorTests = PlatformTypesAPITests.ErrorTests

    }

}



extension PlatformTypesAPITests.ErrorTests.LowLevelErrorTests {

    @Test
    func `Success code is not an error`() {

        #expect(LowLevelError(systemCode: .success) == nil)
        #expect(LowLevelError(rawSystemCode: LowLevelError.successCode) == nil)

    }


    @Test
    func `Absent system code produces an unknown error`() throws {

        let error = try #require(LowLevelError(systemCode: nil))

        #expect(error.systemCode == nil)
        #expect(error.kind == .unknown)

    }


    @Test
    func `System code maps to its default kind`() throws {

        let error = try #require(LowLevelError(systemCode: ErrorTests.notFoundCode))

        #expect(error.systemCode == ErrorTests.notFoundCode)
        #expect(error.kind == .notFound)

    }


    @Test
    func `Explicit kind overrides the default mapping and preserves the system code`() throws {

        let error = try #require(LowLevelError(systemCode: ErrorTests.notFoundCode, kind: .unsupported))

        #expect(error.systemCode == ErrorTests.notFoundCode)
        #expect(error.kind == .unsupported)

    }


    @Test
    func `Library generated error carries no system code`() {

        let semanticError = LowLevelError(kind: .unsupported)

        #expect(semanticError.systemCode == nil)
        #expect(semanticError.kind == .unsupported)
        #expect(LowLevelError.unknown.systemCode == nil)
        #expect(LowLevelError.unknown.kind == .unknown)

    }

}
