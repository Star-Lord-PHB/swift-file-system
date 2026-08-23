import Testing
import SwiftFileSystem



extension FileInfoAPITests {

    @Suite("Platform file attributes")
    struct PlatformFileAttributeTests {}

}



extension FileInfoAPITests.PlatformFileAttributeTests {

    @Test(.enabled(if: ~PlatformFileAttributes.all.rawValue != 0))
    func `Raw value initializer preserves unknown bits`() {

        let unknownBit = (~PlatformFileAttributes.all.rawValue) & (PlatformFileAttributes.all.rawValue &+ 1)

        let attributes = PlatformFileAttributes(rawValue: unknownBit)

        #expect(attributes.rawValue == unknownBit)

    }
}
